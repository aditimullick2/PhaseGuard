"""
voice/__init__.py — Voice/TTS provider abstraction for PhaseGuard.

This module provides a clean abstraction over multiple TTS providers:
- Fish Audio (primary for this implementation)
- Future: XTTS, ElevenLabs, or other fallback providers

All voice cloning and TTS operations go through this abstraction,
keeping provider-specific logic isolated.
"""

from .provider import TTSProvider, FishTTSProvider
from .service import VoiceService
from .models import VoiceProfile, TTSError

__all__ = [
    "TTSProvider",
    "FishTTSProvider",
    "VoiceService",
    "VoiceProfile",
    "TTSError",
]
