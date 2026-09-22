"""
factcheck/stt.py — Speech-to-text ingestion via Groq Whisper.

Design:
  - A third AudioBufferManager consumer ("stt") accumulates audio until a
    configurable utterance chunk size is reached (default 3-5 seconds).
  - Silence gating: skip sending all-zero (silent) chunks to avoid wasting
    Groq API calls on silence.
  - Groq Whisper (whisper-large-v3) handles Hindi and English natively;
    code-switching/Hinglish is handled reasonably well by the model.
  - For heavily Hindi/non-English audio, language_router.py can redirect
    to Bhashini (Government of India API) or Sarvam AI as a fallback.

Rate limit awareness:
  - Groq Whisper has a free-tier limit (~100 hours/day, ~40 RPM).
  - We gate on minimum chunk size to avoid rapid-fire tiny requests.
  - Exponential backoff on 429 responses.

This module is called from the STT asyncio task in ws/call_socket.py,
which runs on its own cadence independent of bispectrum and tremor loops.
"""

from __future__ import annotations

import asyncio
import io
import logging
import wave

import numpy as np

logger = logging.getLogger(__name__)

# Minimum audio length before sending to Whisper (seconds)
_MIN_CHUNK_SECONDS = 2.0
# Maximum (send anyway to avoid unbounded accumulation)
_MAX_CHUNK_SECONDS = 5.0
# Silence threshold: RMS below this -> skip Whisper call
_SILENCE_RMS_THRESHOLD = 0.005


def _float32_to_wav_bytes(audio: np.ndarray, fs: int = 16_000) -> bytes:
    """Convert float32 numpy array to WAV bytes (PCM16) for Whisper upload."""
    pcm16 = (audio * 32768.0).clip(-32768, 32767).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(fs)
        wf.writeframes(pcm16.tobytes())
    return buf.getvalue()


def _is_silent(audio: np.ndarray, threshold: float = _SILENCE_RMS_THRESHOLD) -> bool:
    """Return True if the audio chunk is effectively silent (save API calls)."""
    rms = float(np.sqrt(np.mean(audio ** 2)))
    return rms < threshold


async def transcribe_chunk(
    audio: np.ndarray,
    fs: int = 16_000,
    language: str | None = None,
    call_id: str = "",
) -> str | None:
    """
    Send an audio chunk to Groq Whisper for transcription.

    Parameters
    ----------
    audio : np.ndarray
        Float32 audio chunk (mono, fs Hz).
    fs : int
        Sample rate.
    language : str or None
        ISO language code hint ('hi' for Hindi, 'en' for English, None = auto).
        Auto-detection is used when language_router hasn't determined the language.
    call_id : str
        For logging only.

    Returns
    -------
    str or None
        Transcribed text, or None if silent / API error.
    """
    if _is_silent(audio):
        logger.debug("STT: silent chunk skipped for call_id=%r", call_id)
        return None

    from core.config import get_settings
    cfg = get_settings()

    if not cfg.groq_api_key:
        logger.warning("STT: GROQ_API_KEY not set — transcription unavailable")
        return None

    from groq import AsyncGroq, RateLimitError

    client = AsyncGroq(api_key=cfg.groq_api_key)
    wav_bytes = _float32_to_wav_bytes(audio, fs)

    # Exponential backoff for Groq rate limits
    max_retries = 3
    backoff = 1.0

    for attempt in range(max_retries):
        try:
            transcription = await client.audio.transcriptions.create(
                file=("audio.wav", wav_bytes, "audio/wav"),
                model=cfg.groq_stt_model,
                response_format="text",
                language=language,  # None = auto-detect, dynamically updated by language_router
                temperature=0.0,    # Deterministic for forensic reliability
            )
            text = transcription.strip() if transcription else ""
            # P0: Enhanced logging for language detection debugging
            logger.info(
                "STT[%s]: lang_param=%s transcript=%r (attempt %d)", 
                call_id, 
                language if language else "AUTO", 
                text[:80], 
                attempt + 1
            )
            return text if text else None

        except RateLimitError:
            if attempt < max_retries - 1:
                logger.warning(
                    "STT: Groq rate limit hit (attempt %d/%d), backing off %.1fs",
                    attempt + 1,
                    max_retries,
                    backoff,
                )
                await asyncio.sleep(backoff)
                backoff *= 2.0
            else:
                logger.error("STT: Groq rate limit — all retries exhausted for call_id=%r", call_id)
                return None

        except Exception as exc:
            logger.error("STT: Whisper API error for call_id=%r: %s", call_id, exc)
            return None

    return None


class STTAccumulator:
    """
    Manages utterance-level audio accumulation for STT with proper speech-end detection.
    
    Instead of fixed time windows, uses silence detection to determine when
    the speaker has finished speaking, then transcribes the complete utterance.
    """

    def __init__(self, fs: int = 16_000) -> None:
        self._fs = fs
        self._min_samples = int(_MIN_CHUNK_SECONDS * fs)  # Minimum 2 seconds
        self._max_samples = int(_MAX_CHUNK_SECONDS * fs)  # Maximum 5 seconds
        self._accumulated: list[np.ndarray] = []
        self._total_samples: int = 0
        self._silence_samples: int = 0  # Track consecutive silent samples
        self._silence_threshold_samples = int(0.5 * fs)  # 500ms silence to trigger end-of-speech
        self._has_spoken: bool = False  # Track if we've detected actual speech

    def add(self, chunk: np.ndarray) -> None:
        """Add an audio chunk to the accumulator."""
        rms = float(np.sqrt(np.mean(chunk ** 2)))
        is_silent = rms < _SILENCE_RMS_THRESHOLD
        
        if not is_silent:
            self._has_spoken = True
            self._silence_samples = 0  # Reset silence counter on speech
        else:
            self._silence_samples += len(chunk)
        
        self._accumulated.append(chunk)
        self._total_samples += len(chunk)

    def ready(self) -> bool:
        """
        Return True if we have enough audio AND end-of-speech detected.
        
        Conditions:
        1. Minimum duration met (2s)
        2. Speech has been detected (not just silence)
        3. Silence threshold reached (500ms) OR max duration reached (5s)
        """
        if not self._has_spoken:
            return False
            
        if self._total_samples < self._min_samples:
            return False
            
        # Ready if we have enough silence OR hit max duration
        silence_detected = self._silence_samples >= self._silence_threshold_samples
        max_duration_reached = self._total_samples >= self._max_samples
        
        return silence_detected or max_duration_reached

    def get_chunk(self) -> np.ndarray | None:
        """
        Return the accumulated audio if ready, and reset the accumulator.
        Returns None if not yet ready.
        """
        if not self.ready():
            return None
        
        audio = np.concatenate(self._accumulated)
        # Trim to max length to avoid very long segments
        if len(audio) > self._max_samples:
            audio = audio[: self._max_samples]
        
        # Reset for next utterance
        self._accumulated = []
        self._total_samples = 0
        self._silence_samples = 0
        self._has_spoken = False
        
        return audio

    def force_get(self) -> np.ndarray | None:
        """Return whatever has accumulated (used on call end)."""
        if not self._accumulated:
            return None
        audio = np.concatenate(self._accumulated)
        self._accumulated = []
        self._total_samples = 0
        self._silence_samples = 0
        self._has_spoken = False
        return audio
