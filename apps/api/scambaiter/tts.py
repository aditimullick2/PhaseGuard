"""
scambaiter/tts.py — Text-to-speech for scambaiter audio responses.

Supports multiple TTS backends (configurable via TTS_BACKEND env var):
  - "gtts"        : gTTS (Google TTS, free, requires internet, no key)
  - "elevenlabs"  : ElevenLabs API (best quality, requires key)
  - "google"      : Google Cloud TTS (requires GCP credentials)
  - "mock"        : Returns silence bytes (for testing without TTS credentials)

For an Indian-market deployment, gTTS is the pragmatic default:
  - Free, no API key required
  - Supports Hindi (lang='hi') for authentic-sounding scambaiter responses
  - Adequate quality for a demo; upgrade to ElevenLabs for production

Audio output: PCM16LE bytes at 16kHz mono (same format as the ingestion pipeline),
ready to be sent back over the call's outbound audio path.
"""

from __future__ import annotations

import logging
import os

import numpy as np

logger = logging.getLogger(__name__)

_TTS_BACKEND = os.getenv("TTS_BACKEND", "api")  # Default to 'api' (VoiceService) for voice cloning
_TTS_LANGUAGE = os.getenv("TTS_LANGUAGE", "hi")  # Hindi default for India-market


async def synthesize_speech(text: str, call_id: str = "") -> bytes | None:
    """
    Convert text to PCM16LE audio bytes with intelligent fallback.

    Parameters
    ----------
    text : str
        Text to synthesize (scambaiter response).
    call_id : str
        For logging.

    Returns
    -------
    bytes or None
        Audio bytes (MP3 or PCM16LE), or None on failure.
        
    Fallback Strategy:
    1. Try configured backend (fish, xtts, elevenlabs, google, gtts)
    2. If primary backend fails, automatically fall back to gTTS
    3. If gTTS fails, return mock silence
    """
    backend = _TTS_BACKEND.lower()
    logger.info("TTS[%s]: backend=%r text=%r", call_id, backend, text[:60])

    result = None

    # ── Helper: get voice_id from session for cloning ────────────────────────
    def _get_session_voice_id() -> str | None:
        try:
            from core.connection_manager import manager
            session = manager.get_session(call_id)
            if session:
                # Try user_voice_id first (Fish reference_id), then voice_sample_path
                return getattr(session, "user_voice_id", None)
        except Exception:
            pass
        return None

    # Try primary backend
    if backend == "gtts":
        result = await _gtts_synthesize(text)

    elif backend == "elevenlabs":
        result = await _elevenlabs_synthesize(text)

    elif backend == "google":
        result = await _gcloud_tts_synthesize(text)

    elif backend == "fish":
        # Fish Audio TTS — uses voice clone reference_id if available
        from voice.service import get_voice_service
        try:
            svc = get_voice_service()
            voice_id = _get_session_voice_id()
            res = await svc.synthesize(text, voice_id=voice_id, format="mp3", provider="fish")
            result = res.get("data")
            if result:
                logger.info(
                    "TTS[%s]: Fish synthesis successful (voice_id=%r, %d bytes)",
                    call_id, voice_id, len(result),
                )
        except Exception as exc:
            logger.error("TTS[%s]: Fish failed: %s, falling back to gTTS", call_id, exc)
            result = await _gtts_synthesize(text)

    elif backend == "xtts":
        from core.connection_manager import manager
        session = manager.get_session(call_id)
        if session and session.user_voice_sample_path:
            # Try XTTS with timeout
            try:
                import asyncio
                result = await asyncio.wait_for(
                    _xtts_synthesize(text, session.user_voice_sample_path),
                    timeout=5.0  # 5 second timeout for XTTS
                )
                logger.info("TTS[%s]: XTTS synthesis successful", call_id)
            except asyncio.TimeoutError:
                logger.warning("TTS[%s]: XTTS timeout, falling back to gTTS", call_id)
                result = await _gtts_synthesize(text)
            except Exception as e:
                logger.warning("TTS[%s]: XTTS failed with %s, falling back to gTTS", call_id, e)
                result = await _gtts_synthesize(text)
        else:
            logger.warning("TTS[xtts]: missing user_voice_sample_path for call_id=%r, falling back to gTTS", call_id)
            result = await _gtts_synthesize(text)

    elif backend == "mock":
        return _mock_silence(duration_seconds=2.0)

    elif backend == "api":
        # Generic VoiceService routing (Fish → Sonex → Sarvam → gTTS)
        from voice.service import get_voice_service
        try:
            svc = get_voice_service()
            voice_id = _get_session_voice_id()
            res = await svc.synthesize(text, voice_id=voice_id, format="mp3")
            result = res.get("data")
            if result:
                logger.info(
                    "TTS[%s]: VoiceService (api) synthesis successful using %s (voice_id=%r)",
                    call_id, res.get("provider"), voice_id,
                )
        except Exception as exc:
            logger.error("TTS[%s]: VoiceService (api) failed: %s, falling back to gTTS", call_id, exc)
            result = await _gtts_synthesize(text)

    else:
        logger.warning("TTS: unknown backend %r — falling back to gTTS", backend)
        result = await _gtts_synthesize(text)

    # If primary backend failed, try gTTS as fallback
    if result is None and backend not in ("gtts", "mock"):
        logger.warning("TTS[%s]: primary backend %r failed, falling back to gTTS", call_id, backend)
        result = await _gtts_synthesize(text)

    # If gTTS also failed, return mock silence
    if result is None:
        logger.error("TTS[%s]: all backends failed, returning mock silence", call_id)
        result = _mock_silence(duration_seconds=2.0)

    return result




async def _gtts_synthesize(text: str) -> bytes | None:
    """
    Synthesize via gTTS (free, no key).
    Returns PCM16LE bytes resampled to 16kHz.
    """
    try:
        import asyncio
        import io as _io

        from gtts import gTTS  # type: ignore[import]

        def _sync_gtts() -> bytes:
            tts = gTTS(text=text, lang=_TTS_LANGUAGE, slow=True)
            mp3_buf = _io.BytesIO()
            tts.write_to_fp(mp3_buf)
            return mp3_buf.getvalue()

        loop = asyncio.get_running_loop()
        # gTTS is synchronous — run in executor
        from workers.executor import run_in_dsp_executor
        mp3_bytes = await run_in_dsp_executor(_sync_gtts)

        # Just return MP3 directly. The browser's AudioContext.decodeAudioData
        # handles MP3 perfectly, and avoids any ffmpeg WAV header issues.
        return mp3_bytes

    except Exception as exc:
        logger.error("gTTS synthesis failed: %s", exc)
        return None


async def _elevenlabs_synthesize(text: str) -> bytes | None:
    """
    Synthesize via ElevenLabs API.
    Requires ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID env vars.
    """
    import httpx

    api_key = os.getenv("ELEVENLABS_API_KEY", "")
    voice_id = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")  # default voice

    if not api_key:
        logger.warning("ElevenLabs: ELEVENLABS_API_KEY not set — falling back to gTTS")
        return await _gtts_synthesize(text)

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
                headers={"xi-api-key": api_key, "Content-Type": "application/json"},
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {"stability": 0.6, "similarity_boost": 0.7},
                },
            )
            response.raise_for_status()
            audio_bytes = response.content

            # ElevenLabs returns MP3; convert to PCM16LE
            try:
                import io as _io

                from pydub import AudioSegment

                segment = AudioSegment.from_mp3(_io.BytesIO(audio_bytes))
                segment = segment.set_frame_rate(16000).set_channels(1).set_sample_width(2)
                out_buf = _io.BytesIO()
                segment.export(out_buf, format="wav")
                return out_buf.getvalue()
            except ImportError:
                return audio_bytes

    except Exception as exc:
        logger.error("ElevenLabs synthesis failed: %s", exc)
        return None


async def _gcloud_tts_synthesize(text: str) -> bytes | None:
    """
    Synthesize via Google Cloud Text-to-Speech API.
    Requires GCP credentials (GOOGLE_APPLICATION_CREDENTIALS env var).
    """
    try:
        from google.cloud import texttospeech  # type: ignore[import]

        def _sync_gcloud() -> bytes:
            client = texttospeech.TextToSpeechClient()
            synthesis_input = texttospeech.SynthesisInput(text=text)
            voice = texttospeech.VoiceSelectionParams(
                language_code="hi-IN",
                ssml_gender=texttospeech.SsmlVoiceGender.MALE,
            )
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.LINEAR16,
                sample_rate_hertz=16000,
            )
            response = client.synthesize_speech(
                input=synthesis_input, voice=voice, audio_config=audio_config
            )
            return response.audio_content  # PCM16LE bytes, already at 16kHz

        from workers.executor import run_in_dsp_executor
        return await run_in_dsp_executor(_sync_gcloud)

    except Exception as exc:
        logger.error("Google Cloud TTS failed: %s", exc)
        return None


def _mock_silence(duration_seconds: float = 2.0, fs: int = 16_000) -> bytes:
    """Return PCM16LE silence bytes (for testing without TTS credentials)."""
    n_samples = int(duration_seconds * fs)
    return np.zeros(n_samples, dtype=np.int16).tobytes()

_xtts_model = None

async def _xtts_synthesize(text: str, reference_audio_path: str) -> bytes | None:
    """
    Synthesize via Coqui XTTS-v2 for zero-shot voice cloning.
    """
    try:
        def _sync_xtts() -> bytes:
            global _xtts_model
            from TTS.api import TTS
            import io as _io
            import soundfile as sf
            import librosa
            
            if _xtts_model is None:
                logger.info("TTS: Loading XTTS-v2 model into memory...")
                # Download and load the model (may take some time on first run)
                _xtts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to("cpu")
                
            logger.info("TTS[xtts]: synthesizing %d chars with voice clone %r", len(text), reference_audio_path)
            # XTTS synthesis
            wav = _xtts_model.tts(
                text=text, 
                speaker_wav=reference_audio_path, 
                language=_TTS_LANGUAGE
            )
            
            # XTTS outputs at 24kHz. Resample to 16kHz to match ingestion pipeline
            wav_16k = librosa.resample(np.array(wav), orig_sr=24000, target_sr=16000)
            
            out_buf = _io.BytesIO()
            sf.write(out_buf, wav_16k, 16000, format='WAV', subtype='PCM_16')
            
            return out_buf.getvalue()

        from workers.executor import run_in_dsp_executor
        return await run_in_dsp_executor(_sync_xtts)

    except Exception as exc:
        logger.error("XTTS synthesis failed: %s", exc)
        return None
