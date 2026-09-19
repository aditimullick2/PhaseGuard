"""
Window Configuration for PhaseGuard Streaming Detection
Configurable 3-6 second windowing for streaming call audio
"""
import os
from typing import Tuple


class WindowConfig:
    """Configuration for audio windowing in streaming detection."""

    def __init__(self):
        """Initialize window configuration from environment variables."""
        self.window_seconds = float(os.getenv("DETECTION_WINDOW_SECONDS", "3.0"))
        self.hop_seconds = float(os.getenv("DETECTION_HOP_SECONDS", "1.0"))
        self.min_suspicious_windows = int(os.getenv("MIN_SUSPICIOUS_WINDOWS", "2"))
        self.min_synthetic_windows = int(os.getenv("MIN_SYNTHETIC_WINDOWS", "3"))

        # Validate configuration
        self._validate_config()

    def _validate_config(self) -> None:
        """Validate window configuration."""
        if not (3.0 <= self.window_seconds <= 6.0):
            raise ValueError(f"Window seconds must be between 3-6, got {self.window_seconds}")

        if not (0.5 <= self.hop_seconds <= 2.0):
            raise ValueError(f"Hop seconds must be between 0.5-2.0, got {self.hop_seconds}")

        if self.hop_seconds >= self.window_seconds:
            raise ValueError(f"Hop must be smaller than window (hop={self.hop_seconds}, window={self.window_seconds})")

    def get_window_hop_samples(self, sample_rate: int = 16000) -> Tuple[int, int]:
        """
        Get window and hop sizes in samples.

        Args:
            sample_rate: Audio sample rate

        Returns:
            Tuple of (window_samples, hop_samples)
        """
        window_samples = int(self.window_seconds * sample_rate)
        hop_samples = int(self.hop_seconds * sample_rate)
        return window_samples, hop_samples

    def is_decision_ready(self, synthetic_count: int, suspicious_count: int) -> Tuple[bool, str]:
        """
        Determine if enough windows are available for decision.

        Args:
            synthetic_count: Number of SYNTHETIC classifications
            suspicious_count: Number of SUSPICIOUS classifications

        Returns:
            Tuple of (ready, decision_type)
        """
        if synthetic_count >= self.min_synthetic_windows:
            return True, "SYNTHETIC"
        elif suspicious_count >= self.min_suspicious_windows:
            return True, "SUSPICIOUS"
        else:
            return False, "INSUFFICIENT_EVIDENCE"


# Global window config instance
_window_config: WindowConfig = None


def get_window_config() -> WindowConfig:
    """Get or create global window configuration instance."""
    global _window_config
    if _window_config is None:
        _window_config = WindowConfig()
    return _window_config
