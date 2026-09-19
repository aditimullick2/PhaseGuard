"""
voice/models.py — Data models for voice/TTS functionality.
"""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4

from pydantic import BaseModel, ConfigDict, Field


class TTSErrorCode(str, Enum):
    """Error codes for TTS/voice operations."""

    # Provider-specific errors
    FISH_AUTHENTICATION_ERROR = "FISH_AUTHENTICATION_ERROR"
    FISH_RATE_LIMITED = "FISH_RATE_LIMITED"
    FISH_TIMEOUT = "FISH_TIMEOUT"
    FISH_UNAVAILABLE = "FISH_UNAVAILABLE"
    FISH_INVALID_REQUEST = "FISH_INVALID_REQUEST"
    FISH_GENERATION_ERROR = "FISH_GENERATION_ERROR"

    # Unified provider errors
    TTS_PROVIDER_TIMEOUT = "TTS_PROVIDER_TIMEOUT"
    TTS_PROVIDER_RATE_LIMITED = "TTS_PROVIDER_RATE_LIMITED"
    TTS_PROVIDER_UNAVAILABLE = "TTS_PROVIDER_UNAVAILABLE"
    TTS_PROVIDER_AUTH_ERROR = "TTS_PROVIDER_AUTH_ERROR"
    TTS_ALL_PROVIDERS_FAILED = "TTS_ALL_PROVIDERS_FAILED"
    VOICE_CLONE_FAILED = "VOICE_CLONE_FAILED"

    # Generic errors
    VOICE_NOT_FOUND = "VOICE_NOT_FOUND"
    INVALID_AUDIO = "INVALID_AUDIO"
    INVALID_TEXT = "INVALID_TEXT"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    PROVIDER_NOT_CONFIGURED = "PROVIDER_NOT_CONFIGURED"


class TTSError(Exception):
    """Base exception for TTS/voice operations."""

    def __init__(
        self,
        code: TTSErrorCode,
        message: str,
        provider_detail: Optional[str] = None,
    ):
        self.code = code
        self.message = message
        self.provider_detail = provider_detail
        super().__init__(message)


class VoiceProfile(BaseModel):
    """
    Internal voice profile for enrolled voices.

    Stores only minimum metadata. Raw audio samples are NOT persisted
    unless required by the provider for future reference.
    """

    id: str = Field(default_factory=lambda: str(uuid4()))
    provider: str = Field(description="Provider name (e.g., 'fish')")
    provider_voice_id: str = Field(description="Provider-specific voice/model ID")
    display_name: str = Field(description="Human-readable name for the voice")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    status: str = Field(default="active", description="Status: active, deleted, etc.")
    user_id: Optional[str] = Field(default=None, description="Optional user/tenant ID for ownership")
    metadata: dict = Field(default_factory=dict, description="Additional provider-specific metadata")

    model_config = ConfigDict(
        json_encoders={
            datetime: lambda v: v.isoformat(),
        },
    )


class TTSRequest(BaseModel):
    """Request model for TTS synthesis."""

    text: str = Field(..., min_length=1, max_length=10000, description="Text to synthesize")
    voice_id: Optional[str] = Field(default=None, description="Internal voice profile ID")
    format: str = Field(default="mp3", description="Output format (mp3, wav, opus)")
    stream: bool = Field(default=False, description="Whether to stream the response")
    provider: str = Field(default="fish", description="Provider to use")


class TTSResponse(BaseModel):
    """Response model for TTS synthesis."""

    audio_url: Optional[str] = Field(default=None, description="URL to generated audio (if applicable)")
    format: str = Field(description="Audio format")
    duration_seconds: Optional[float] = Field(default=None, description="Audio duration in seconds")
    provider: str = Field(description="Provider used")
    voice_id: Optional[str] = Field(default=None, description="Voice profile ID used")
    fallback_used: bool = Field(default=False, description="True if a fallback provider was used")
    time_to_first_audio_ms: Optional[float] = Field(default=None, description="Time to first audio in ms")
    total_generation_time_ms: Optional[float] = Field(default=None, description="Total generation time in ms")
    request_id: str = Field(default_factory=lambda: str(uuid4()), description="Request ID")


class VoiceEnrollRequest(BaseModel):
    """Request model for voice enrollment."""

    display_name: str = Field(..., min_length=1, max_length=100, description="Display name for the voice")
    enhance_quality: bool = Field(default=True, description="Whether to enhance audio quality")


class VoiceEnrollResponse(BaseModel):
    """Response model for voice enrollment."""

    voice_profile: VoiceProfile
    status: str = Field(description="Enrollment status")
