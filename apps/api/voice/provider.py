"""
voice/provider.py — TTS provider abstraction and Fish Audio implementation.

Defines the TTSProvider interface and implements FishTTSProvider using the
official Fish Audio API (https://api.fish.audio).

Fish API documentation verified:
- TTS endpoint: POST /v1/tts
- Model creation: POST /model
- Model: s2.1-pro-free (free tier)
- Authentication: Bearer token in Authorization header
- Model selection via `model` header
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from typing import Optional

import httpx

from core.config import get_settings
from voice.models import TTSError, TTSErrorCode, VoiceProfile

logger = logging.getLogger(__name__)


class TTSProvider(ABC):
    """
    Abstract base class for TTS providers.

    All provider implementations must implement these methods.
    This allows PhaseGuard to switch between providers without changing
    the rest of the application.
    """

    @abstractmethod
    async def synthesize(
        self,
        text: str,
        voice_id: Optional[str] = None,
        format: str = "mp3",
    ) -> bytes:
        """
        Synthesize text to audio.

        Parameters
        ----------
        text : str
            Text to synthesize.
        voice_id : str, optional
            Provider-specific voice ID or internal voice profile ID.
        format : str
            Output format (mp3, wav, opus).

        Returns
        -------
        bytes
            Audio data.
        """
        pass

    @abstractmethod
    async def stream(
        self,
        text: str,
        voice_id: Optional[str] = None,
        format: str = "mp3",
    ):
        """
        Stream synthesized audio.

        Yields audio chunks as they are generated.

        Parameters
        ----------
        text : str
            Text to synthesize.
        voice_id : str, optional
            Provider-specific voice ID.
        format : str
            Output format.

        Yields
        ------
        bytes
            Audio chunks.
        """
        pass

    @abstractmethod
    async def health_check(self) -> bool:
        """
        Check if the provider is available.

        Returns
        -------
        bool
            True if provider is healthy.
        """
        pass

    @abstractmethod
    def supports_voice_cloning(self) -> bool:
        """
        Check if provider supports voice cloning.

        Returns
        -------
        bool
            True if voice cloning is supported.
        """
        pass

    @abstractmethod
    async def create_voice_reference(
        self,
        audio_data: bytes,
        display_name: str,
        user_id: Optional[str] = None,
    ) -> VoiceProfile:
        """
        Create a voice reference from audio sample.

        Parameters
        ----------
        audio_data : bytes
            Audio sample data.
        display_name : str
            Display name for the voice.
        user_id : str, optional
            User/tenant ID for ownership tracking.

        Returns
        -------
        VoiceProfile
            Created voice profile.
        """
        pass


class FishTTSProvider(TTSProvider):
    """
    Fish Audio TTS provider implementation.

    Uses the Fish Audio API for TTS and voice cloning.
    Documentation: https://docs.fish.audio

    Configuration:
    - FISH_API_KEY: API key from Fish Audio
    - FISH_MODEL: Model to use (default: s2.1-pro-free)
    - FISH_BASE_URL: API base URL (default: https://api.fish.audio)
    """

    def __init__(self):
        self.cfg = get_settings()
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def client(self) -> httpx.AsyncClient:
        """Lazy-initialize HTTP client."""
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.cfg.fish_base_url,
                timeout=30.0,
            )
        return self._client

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None

    def _get_headers(self, model: Optional[str] = None) -> dict:
        """Build request headers with authentication."""
        headers = {
            "Authorization": f"Bearer {self.cfg.fish_api_key}",
            "Content-Type": "application/json",
        }
        if model:
            headers["model"] = model
        return headers

    async def synthesize(
        self,
        text: str,
        voice_id: Optional[str] = None,
        format: str = "mp3",
    ) -> bytes:
        """
        Synthesize text using Fish Audio TTS.

        Parameters
        ----------
        text : str
            Text to synthesize.
        voice_id : str, optional
            Fish Audio model ID (reference_id) or internal voice profile ID.
        format : str
            Output format (mp3, wav, opus).

        Returns
        -------
        bytes
            Audio data in requested format.

        Raises
        ------
        TTSError
            If synthesis fails.
        """
        if not self.cfg.fish_api_key:
            raise TTSError(
                code=TTSErrorCode.PROVIDER_NOT_CONFIGURED,
                message="Fish Audio API key not configured",
            )

        # Build request body per Fish API spec
        request_body = {
            "text": text,
            "format": format,
            "normalize": True,
        }

        # Add voice reference if provided
        if voice_id:
            request_body["reference_id"] = voice_id

        try:
            response = await self.client.post(
                "/v1/tts",
                headers=self._get_headers(model=self.cfg.fish_model),
                json=request_body,
            )
            response.raise_for_status()
            return response.content

        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code
            if status_code == 401:
                raise TTSError(
                    code=TTSErrorCode.FISH_AUTHENTICATION_ERROR,
                    message="Fish Audio authentication failed",
                    provider_detail=str(e),
                )
            elif status_code == 402:
                raise TTSError(
                    code=TTSErrorCode.FISH_RATE_LIMITED,
                    message="Fish Audio rate limit or payment required",
                    provider_detail=str(e),
                )
            elif status_code == 503:
                raise TTSError(
                    code=TTSErrorCode.FISH_UNAVAILABLE,
                    message="Fish Audio service unavailable",
                    provider_detail=str(e),
                )
            else:
                raise TTSError(
                    code=TTSErrorCode.FISH_INVALID_REQUEST,
                    message=f"Fish Audio request failed: {status_code}",
                    provider_detail=str(e),
                )

        except httpx.TimeoutException as e:
            raise TTSError(
                code=TTSErrorCode.FISH_TIMEOUT,
                message="Fish Audio request timeout",
                provider_detail=str(e),
            )

        except Exception as e:
            logger.error(f"Fish Audio synthesis error: {e}")
            raise TTSError(
                code=TTSErrorCode.FISH_GENERATION_ERROR,
                message="Fish Audio synthesis failed",
                provider_detail=str(e),
            )

    async def stream(
        self,
        text: str,
        voice_id: Optional[str] = None,
        format: str = "mp3",
    ):
        """
        Stream synthesized audio from Fish Audio.

        Note: Fish Audio's REST API returns the full audio at once.
        For true streaming, use their WebSocket endpoint.
        This implementation yields the full response as a single chunk.

        Parameters
        ----------
        text : str
            Text to synthesize.
        voice_id : str, optional
            Fish Audio model ID.
        format : str
            Output format.

        Yields
        ------
        bytes
            Audio chunks.
        """
        audio_bytes = await self.synthesize(text, voice_id, format)
        yield audio_bytes

    async def health_check(self) -> bool:
        """
        Check Fish Audio service health.

        Attempts a simple TTS request with minimal text.

        Returns
        -------
        bool
            True if service is healthy.
        """
        if not self.cfg.fish_api_key:
            return False

        try:
            # Use a minimal text for health check
            await self.synthesize("Hi", format="mp3")
            return True
        except Exception as e:
            logger.warning(f"Fish Audio health check failed: {e}")
            return False

    def supports_voice_cloning(self) -> bool:
        """
        Fish Audio supports voice cloning via the /model endpoint.

        Returns
        -------
        bool
            True.
        """
        return True

    async def create_voice_reference(
        self,
        audio_data: bytes,
        display_name: str,
        user_id: Optional[str] = None,
    ) -> VoiceProfile:
        """
        Create a voice model in Fish Audio from audio sample.

        Uses the Fish Audio /model endpoint with train_mode=fast.

        Parameters
        ----------
        audio_data : bytes
            Audio sample data (WAV, MP3, etc.).
        display_name : str
            Display name for the voice.
        user_id : str, optional
            User/tenant ID for ownership tracking.

        Returns
        -------
        VoiceProfile
            Created voice profile with Fish Audio model ID.

        Raises
        ------
        TTSError
            If voice creation fails.
        """
        if not self.cfg.fish_api_key:
            raise TTSError(
                code=TTSErrorCode.PROVIDER_NOT_CONFIGURED,
                message="Fish Audio API key not configured",
            )

        # Prepare multipart form data per Fish API spec
        files = {
            "voices": ("voice_sample.wav", audio_data, "audio/wav"),
        }

        data = {
            "type": "tts",
            "title": display_name,
            "train_mode": "fast",
            "visibility": "private",
            "enhance_audio_quality": "true",
        }

        try:
            response = await self.client.post(
                "/model",
                headers={"Authorization": f"Bearer {self.cfg.fish_api_key}"},
                files=files,
                data=data,
            )
            response.raise_for_status()

            result = response.json()
            fish_model_id = result.get("_id") or result.get("id")

            if not fish_model_id:
                raise TTSError(
                    code=TTSErrorCode.FISH_GENERATION_ERROR,
                    message="Fish Audio did not return a model ID",
                    provider_detail=str(result),
                )

            return VoiceProfile(
                provider="fish",
                provider_voice_id=fish_model_id,
                display_name=display_name,
                user_id=user_id,
                metadata={"fish_response": result},
            )

        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code
            if status_code == 401:
                raise TTSError(
                    code=TTSErrorCode.FISH_AUTHENTICATION_ERROR,
                    message="Fish Audio authentication failed",
                    provider_detail=str(e),
                )
            elif status_code == 402:
                raise TTSError(
                    code=TTSErrorCode.FISH_RATE_LIMITED,
                    message="Fish Audio rate limit or payment required",
                    provider_detail=str(e),
                )
            else:
                raise TTSError(
                    code=TTSErrorCode.FISH_INVALID_REQUEST,
                    message=f"Fish Audio voice creation failed: {status_code}",
                    provider_detail=str(e),
                )

        except Exception as e:
            logger.error(f"Fish Audio voice creation error: {e}")
            raise TTSError(
                code=TTSErrorCode.FISH_GENERATION_ERROR,
                message="Fish Audio voice creation failed",
                provider_detail=str(e),
            )

class SonexTTSProvider(TTSProvider):
    """
    Sonex Pāṇini TTS provider implementation.
    """
    def __init__(self):
        self.cfg = get_settings()
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.cfg.sonex_base_url,
                timeout=30.0,
            )
        return self._client

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    def _get_headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.cfg.sonex_api_key}",
            "Content-Type": "application/json",
        }

    def _handle_error(self, e: Exception, context: str):
        if isinstance(e, httpx.HTTPStatusError):
            status = e.response.status_code
            if status == 401:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_AUTH_ERROR, f"Sonex auth failed: {context}", str(e))
            elif status == 429:
                retry_after = e.response.headers.get("Retry-After", "1")
                raise TTSError(TTSErrorCode.TTS_PROVIDER_RATE_LIMITED, f"Sonex rate limited (Retry-After: {retry_after}): {context}", str(e))
            elif status >= 500:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sonex unavailable: {context}", str(e))
            else:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sonex bad request ({status}): {context}", str(e))
        elif isinstance(e, httpx.TimeoutException):
            raise TTSError(TTSErrorCode.TTS_PROVIDER_TIMEOUT, f"Sonex timeout: {context}", str(e))
        else:
            raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sonex error: {context}", str(e))

    async def synthesize(self, text: str, voice_id: Optional[str] = None, format: str = "mp3") -> bytes:
        if not self.cfg.sonex_api_key:
            raise TTSError(TTSErrorCode.PROVIDER_NOT_CONFIGURED, "Sonex API key not configured")
        
        request_body = {"text": text, "format": format}
        if voice_id:
            request_body["voice_id"] = voice_id

        try:
            response = await self.client.post("/v1/speech", headers=self._get_headers(), json=request_body)
            response.raise_for_status()
            return response.content
        except Exception as e:
            self._handle_error(e, "synthesize")

    async def stream(self, text: str, voice_id: Optional[str] = None, format: str = "mp3"):
        if not self.cfg.sonex_api_key:
            raise TTSError(TTSErrorCode.PROVIDER_NOT_CONFIGURED, "Sonex API key not configured")
        
        request_body = {"text": text, "format": format}
        if voice_id:
            request_body["voice_id"] = voice_id

        try:
            async with self.client.stream("POST", "/v1/speech/stream", headers=self._get_headers(), json=request_body) as response:
                response.raise_for_status()
                async for chunk in response.aiter_bytes():
                    yield chunk
        except Exception as e:
            self._handle_error(e, "stream")

    async def health_check(self) -> bool:
        if not self.cfg.sonex_api_key:
            return False
        try:
            await self.synthesize("test", format="mp3")
            return True
        except:
            return False

    def supports_voice_cloning(self) -> bool:
        return True

    async def create_voice_reference(self, audio_data: bytes, display_name: str, user_id: Optional[str] = None) -> VoiceProfile:
        if not self.cfg.sonex_api_key:
            raise TTSError(TTSErrorCode.PROVIDER_NOT_CONFIGURED, "Sonex API key not configured")

        files = {"audio": ("sample.wav", audio_data, "audio/wav")}
        data = {"name": display_name}

        try:
            response = await self.client.post("/v1/voices/clone", headers={"Authorization": f"Bearer {self.cfg.sonex_api_key}"}, files=files, data=data)
            response.raise_for_status()
            result = response.json()
            voice_id = result.get("id") or result.get("voice_id")
            if not voice_id:
                raise TTSError(TTSErrorCode.VOICE_CLONE_FAILED, "Sonex clone failed: no ID", str(result))
            
            return VoiceProfile(
                provider="sonex",
                provider_voice_id=voice_id,
                display_name=display_name,
                user_id=user_id,
                metadata={"sonex_response": result},
            )
        except Exception as e:
            self._handle_error(e, "create_voice_reference")

class SarvamTTSProvider(TTSProvider):
    """
    Sarvam Bulbul V3 TTS provider implementation.
    """
    def __init__(self):
        self.cfg = get_settings()
        self._client: Optional[httpx.AsyncClient] = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.cfg.sarvam_base_url,
                timeout=30.0,
            )
        return self._client

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    def _get_headers(self) -> dict:
        return {
            "api-subscription-key": self.cfg.sarvam_api_key,
            "Content-Type": "application/json",
        }

    def _handle_error(self, e: Exception, context: str):
        if isinstance(e, httpx.HTTPStatusError):
            status = e.response.status_code
            if status == 401:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_AUTH_ERROR, f"Sarvam auth failed: {context}", str(e))
            elif status == 429:
                retry_after = e.response.headers.get("Retry-After", "1")
                raise TTSError(TTSErrorCode.TTS_PROVIDER_RATE_LIMITED, f"Sarvam rate limited (Retry-After: {retry_after}): {context}", str(e))
            elif status >= 500:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sarvam unavailable: {context}", str(e))
            else:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sarvam bad request ({status}): {context}", str(e))
        elif isinstance(e, httpx.TimeoutException):
            raise TTSError(TTSErrorCode.TTS_PROVIDER_TIMEOUT, f"Sarvam timeout: {context}", str(e))
        else:
            raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, f"Sarvam error: {context}", str(e))

    async def synthesize(self, text: str, voice_id: Optional[str] = None, format: str = "mp3") -> bytes:
        if not self.cfg.sarvam_api_key:
            raise TTSError(TTSErrorCode.PROVIDER_NOT_CONFIGURED, "Sarvam API key not configured")
        
        # Sarvam requires predefined speakers like 'meera'
        speaker = voice_id if voice_id else "meera"
        
        request_body = {
            "inputs": [text],
            "target_language_code": "hi-IN",
            "speaker": speaker,
            "pitch": 0,
            "pace": 1.0,
            "loudness": 1.0,
            "speech_sample_rate": 8000,
            "enable_preprocessing": True,
            "model": self.cfg.sarvam_model
        }

        try:
            response = await self.client.post("/text-to-speech", headers=self._get_headers(), json=request_body)
            response.raise_for_status()
            
            data = response.json()
            if "audios" in data and len(data["audios"]) > 0:
                import base64
                return base64.b64decode(data["audios"][0])
            else:
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, "Sarvam returned no audio", str(data))
        except Exception as e:
            self._handle_error(e, "synthesize")

    async def stream(self, text: str, voice_id: Optional[str] = None, format: str = "mp3"):
        # Sarvam doesn't explicitly support HTTP chunked streaming for Bulbul v3.
        audio_bytes = await self.synthesize(text, voice_id, format)
        yield audio_bytes

    async def health_check(self) -> bool:
        if not self.cfg.sarvam_api_key:
            return False
        try:
            await self.synthesize("test", format="mp3")
            return True
        except:
            return False

    def supports_voice_cloning(self) -> bool:
        return False

    async def create_voice_reference(self, audio_data: bytes, display_name: str, user_id: Optional[str] = None) -> VoiceProfile:
        raise TTSError(TTSErrorCode.VOICE_CLONE_FAILED, "Sarvam does not support dynamic voice cloning in current API")
