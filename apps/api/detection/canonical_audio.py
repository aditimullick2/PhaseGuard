"""
Canonical Audio Representation
Standardized audio representation for all detector adapters
"""
import numpy as np
import librosa
import soundfile as sf
import io
from typing import Optional, Tuple, Dict, Any
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class CanonicalAudio:
    """
    Canonical audio representation containing all preprocessing information.

    This provides a standardized interface for all detector adapters while
    allowing model-specific preprocessing to be applied.
    """
    waveform: np.ndarray  # Audio waveform (numpy array)
    sample_rate: int  # Sample rate in Hz
    duration: float  # Duration in seconds
    channels: int  # Number of channels (1 = mono, 2 = stereo)
    source_format: str  # Original format (wav, mp3, ogg, etc.)
    source_path: Optional[str] = None  # Original file path
    metadata: Optional[Dict[str, Any]] = None  # Additional metadata

    def __post_init__(self):
        """Validate canonical audio properties."""
        if self.waveform is None:
            raise ValueError("Waveform cannot be None")

        if self.sample_rate <= 0:
            raise ValueError(f"Invalid sample rate: {self.sample_rate}")

        if self.duration <= 0:
            raise ValueError(f"Invalid duration: {self.duration}")

        if self.channels not in [1, 2]:
            raise ValueError(f"Invalid channel count: {self.channels}")

        if self.metadata is None:
            self.metadata = {}

    def is_mono(self) -> bool:
        """Check if audio is mono."""
        return self.channels == 1

    def is_stereo(self) -> bool:
        """Check if audio is stereo."""
        return self.channels == 2

    def get_shape(self) -> Tuple[int, ...]:
        """Get waveform shape."""
        return self.waveform.shape

    def get_num_samples(self) -> int:
        """Get number of samples."""
        return len(self.waveform)

    def copy(self) -> 'CanonicalAudio':
        """Create a copy of the canonical audio."""
        return CanonicalAudio(
            waveform=self.waveform.copy(),
            sample_rate=self.sample_rate,
            duration=self.duration,
            channels=self.channels,
            source_format=self.source_format,
            source_path=self.source_path,
            metadata=self.metadata.copy() if self.metadata else None
        )


class CanonicalAudioProcessor:
    """
    Processes audio into canonical representation.

    Pipeline:
    Input → Decode → Mono → Float32 → Resample → Normalization → Silence Handling → CanonicalAudio
    """

    def __init__(self,
                 target_sample_rate: int = 16000,
                 normalize: bool = True,
                 trim_silence: bool = False,
                 trim_threshold_db: float = 20.0):
        """
        Initialize canonical audio processor.

        Args:
            target_sample_rate: Target sample rate for resampling
            normalize: Whether to normalize audio amplitude
            trim_silence: Whether to trim leading/trailing silence
            trim_threshold_db: Threshold for silence trimming in dB
        """
        self.target_sample_rate = target_sample_rate
        self.normalize = normalize
        self.trim_silence = trim_silence
        self.trim_threshold_db = trim_threshold_db

    def load_from_file(self, file_path: str) -> CanonicalAudio:
        """
        Load audio from file and convert to canonical representation.

        Args:
            file_path: Path to audio file

        Returns:
            CanonicalAudio object
        """
        # Load audio
        waveform, sample_rate = librosa.load(file_path, sr=None, mono=False)

        # Detect format from file extension
        source_format = file_path.split('.')[-1].lower()

        # Convert to canonical representation
        return self.process_waveform(
            waveform=waveform,
            sample_rate=sample_rate,
            source_format=source_format,
            source_path=file_path
        )

    def load_from_bytes(self, audio_bytes: bytes, source_format: str = 'wav') -> CanonicalAudio:
        """
        Load audio from bytes and convert to canonical representation.

        Args:
            audio_bytes: Audio data as bytes
            source_format: Audio format (wav, mp3, ogg, etc.)

        Returns:
            CanonicalAudio object
        """
        # Load audio from bytes
        waveform, sample_rate = sf.read(
            io.BytesIO(audio_bytes),
            always_2d=True
        )

        # Transpose to (channels, samples) format for librosa
        waveform = waveform.T

        # Convert to canonical representation
        return self.process_waveform(
            waveform=waveform,
            sample_rate=sample_rate,
            source_format=source_format
        )

    def process_waveform(self,
                        waveform: np.ndarray,
                        sample_rate: int,
                        source_format: str,
                        source_path: Optional[str] = None) -> CanonicalAudio:
        """
        Process raw waveform into canonical representation.

        Args:
            waveform: Audio waveform (numpy array)
            sample_rate: Sample rate in Hz
            source_format: Original audio format
            source_path: Original file path (optional)

        Returns:
            CanonicalAudio object
        """
        # Store original sample rate for metadata
        original_sample_rate = sample_rate
        original_duration = len(waveform) / sample_rate

        # Step 1: Ensure float32
        waveform = waveform.astype(np.float32)

        # Step 2: Convert to mono
        if waveform.ndim > 1:
            if waveform.shape[0] == 2:  # Stereo
                waveform = np.mean(waveform, axis=0)
            else:
                # Handle multi-channel by averaging
                waveform = np.mean(waveform, axis=0)
        channels = 1

        # Step 3: Resample to target sample rate
        if sample_rate != self.target_sample_rate:
            waveform = librosa.resample(
                waveform,
                orig_sr=sample_rate,
                target_sr=self.target_sample_rate
            )
            sample_rate = self.target_sample_rate

        # Step 4: Remove DC offset
        waveform = waveform - np.mean(waveform)

        # Step 5: Safe normalization
        if self.normalize:
            # Normalize to [-1, 1] range with safety margin
            max_val = np.max(np.abs(waveform))
            if max_val > 0:
                # Use 0.95 to avoid clipping
                waveform = waveform / (max_val / 0.95)

        # Step 6: Optional silence trimming
        if self.trim_silence:
            waveform = self._trim_silence(waveform, sample_rate)

        # Calculate duration (after all processing)
        duration = len(waveform) / sample_rate

        # Store preprocessing metadata
        metadata = {
            'preprocessing': {
                'target_sample_rate': self.target_sample_rate,
                'normalized': self.normalize,
                'silence_trimmed': self.trim_silence,
                'dc_removed': True,
                'original_sample_rate': original_sample_rate,
                'original_duration': original_duration
            }
        }

        return CanonicalAudio(
            waveform=waveform,
            sample_rate=sample_rate,
            duration=duration,
            channels=channels,
            source_format=source_format,
            source_path=source_path,
            metadata=metadata
        )

    def _trim_silence(self, waveform: np.ndarray, sample_rate: int) -> np.ndarray:
        """
        Trim leading and trailing silence.

        Args:
            waveform: Audio waveform
            sample_rate: Sample rate

        Returns:
            Trimmed waveform
        """
        # Use librosa's silence trimming
        trimmed, _ = librosa.effects.trim(
            waveform,
            top_db=self.trim_threshold_db
        )
        return trimmed

    def to_model_input(self,
                      canonical_audio: CanonicalAudio,
                      required_length: Optional[int] = None,
                      required_sample_rate: Optional[int] = None) -> np.ndarray:
        """
        Convert canonical audio to model-specific input.

        Args:
            canonical_audio: CanonicalAudio object
            required_length: Required length in samples (optional)
            required_sample_rate: Required sample rate (optional)

        Returns:
            Model input array
        """
        waveform = canonical_audio.waveform.copy()
        sample_rate = canonical_audio.sample_rate

        # Resample if required
        if required_sample_rate and required_sample_rate != sample_rate:
            waveform = librosa.resample(
                waveform,
                orig_sr=sample_rate,
                target_sr=required_sample_rate
            )
            sample_rate = required_sample_rate

        # Pad or truncate to required length
        if required_length:
            current_length = len(waveform)
            if current_length < required_length:
                # Pad with zeros
                padding = required_length - current_length
                waveform = np.pad(waveform, (0, padding), mode='constant')
            elif current_length > required_length:
                # Truncate
                waveform = waveform[:required_length]

        return waveform

    def log_preprocessing_steps(self, canonical_audio: CanonicalAudio):
        """Log preprocessing steps for debugging."""
        logger.debug(f"Canonical Audio Preprocessing:")
        logger.debug(f"  Sample Rate: {canonical_audio.sample_rate} Hz")
        logger.debug(f"  Duration: {canonical_audio.duration:.3f} seconds")
        logger.debug(f"  Channels: {canonical_audio.channels}")
        logger.debug(f"  Source Format: {canonical_audio.source_format}")
        logger.debug(f"  Num Samples: {canonical_audio.get_num_samples()}")
        logger.debug(f"  Shape: {canonical_audio.get_shape()}")

        if canonical_audio.metadata and 'preprocessing' in canonical_audio.metadata:
            logger.debug(f"  Preprocessing: {canonical_audio.metadata['preprocessing']}")


# Convenience function for quick loading
def load_canonical_audio(file_path: str,
                        target_sample_rate: int = 16000,
                        normalize: bool = True) -> CanonicalAudio:
    """
    Convenience function to load audio as canonical representation.

    Args:
        file_path: Path to audio file
        target_sample_rate: Target sample rate
        normalize: Whether to normalize

    Returns:
        CanonicalAudio object
    """
    processor = CanonicalAudioProcessor(
        target_sample_rate=target_sample_rate,
        normalize=normalize
    )
    return processor.load_from_file(file_path)
