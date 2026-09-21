"""
voice/service.py — Voice service for TTS routing and voice profile management.
"""

from __future__ import annotations

import json
import logging
import time
from typing import Optional, AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession

from database import VoiceProfileDB
from voice.models import TTSError, TTSErrorCode, VoiceProfile
from voice.provider import FishTTSProvider, SonexTTSProvider, SarvamTTSProvider, GTTSProvider, TTSProvider
from core.config import get_settings

logger = logging.getLogger(__name__)


class VoiceService:
    """
    Service for managing voice profiles and TTS operations.
    """

    def __init__(self, db_session: Optional[AsyncSession] = None):
        self._db_session: Optional[AsyncSession] = db_session
        self._providers = {
            "fish": FishTTSProvider(),
            "sonex": SonexTTSProvider(),
            "sarvam": SarvamTTSProvider(),
            "gtts": GTTSProvider()  # Add GTTS as fallback
        }

    def get_provider(self, name: str) -> TTSProvider:
        if name not in self._providers:
            raise TTSError(
                code=TTSErrorCode.PROVIDER_NOT_CONFIGURED,
                message=f"Unknown TTS provider: {name}",
            )
        return self._providers[name]

    async def create_voice_profile(self, profile: VoiceProfile) -> VoiceProfile:
        if self._db_session:
            db_profile = VoiceProfileDB(
                id=profile.id,
                provider=profile.provider,
                provider_voice_id=profile.provider_voice_id,
                display_name=profile.display_name,
                status=profile.status,
                user_id=profile.user_id,
                profile_metadata=json.dumps(profile.metadata) if profile.metadata else None,
            )
            self._db_session.add(db_profile)
            await self._db_session.commit()
            await self._db_session.refresh(db_profile)
        else:
            if not hasattr(self, '_voice_profiles'):
                self._voice_profiles = {}
            self._voice_profiles[profile.id] = profile
        return profile

    async def get_voice_profile(self, voice_id: str) -> Optional[VoiceProfile]:
        if self._db_session:
            from sqlalchemy import select
            result = await self._db_session.execute(
                select(VoiceProfileDB).where(VoiceProfileDB.id == voice_id)
            )
            db_profile = result.scalar_one_or_none()
            if db_profile:
                return VoiceProfile(
                    id=db_profile.id,
                    provider=db_profile.provider,
                    provider_voice_id=db_profile.provider_voice_id,
                    display_name=db_profile.display_name,
                    status=db_profile.status,
                    user_id=db_profile.user_id,
                    created_at=db_profile.created_at,
                    metadata=json.loads(db_profile.profile_metadata) if db_profile.profile_metadata else None,
                )
        else:
            if not hasattr(self, '_voice_profiles'):
                self._voice_profiles = {}
            return self._voice_profiles.get(voice_id)
        return None

    async def resolve_provider_voice_id(self, voice_id: str) -> Optional[str]:
        profile = await self.get_voice_profile(voice_id)
        if profile:
            return profile.provider_voice_id
        return voice_id

    async def delete_voice_profile(self, voice_id: str) -> bool:
        if self._db_session:
            from sqlalchemy import delete
            result = await self._db_session.execute(
                delete(VoiceProfileDB).where(VoiceProfileDB.id == voice_id)
            )
            await self._db_session.commit()
            return result.rowcount > 0
        else:
            if not hasattr(self, '_voice_profiles'):
                self._voice_profiles = {}
            if voice_id in self._voice_profiles:
                del self._voice_profiles[voice_id]
                return True
        return False

    async def list_voice_profiles(self, user_id: Optional[str] = None) -> list[VoiceProfile]:
        if self._db_session:
            from sqlalchemy import select
            query = select(VoiceProfileDB)
            if user_id:
                query = query.where(VoiceProfileDB.user_id == user_id)
            result = await self._db_session.execute(query)
            db_profiles = result.scalars().all()
            profiles = []
            for db_profile in db_profiles:
                profiles.append(VoiceProfile(
                    id=db_profile.id,
                    provider=db_profile.provider,
                    provider_voice_id=db_profile.provider_voice_id,
                    display_name=db_profile.display_name,
                    status=db_profile.status,
                    user_id=db_profile.user_id,
                    created_at=db_profile.created_at,
                    metadata=json.loads(db_profile.profile_metadata) if db_profile.profile_metadata else None,
                ))
            return profiles
        else:
            if not hasattr(self, '_voice_profiles'):
                self._voice_profiles = {}
            profiles = list(self._voice_profiles.values())
            if user_id:
                profiles = [p for p in profiles if p.user_id == user_id]
            return profiles

    async def _execute_with_fallback(self, method_name: str, text: str, voice_id: Optional[str], format: str, initial_provider: str = "auto"):
        providers_to_try = ["fish", "sonex", "sarvam", "gtts"] if initial_provider == "auto" else [initial_provider]
        
        last_error = None
        for i, provider_name in enumerate(providers_to_try):
            try:
                provider = self.get_provider(provider_name)
            except TTSError:
                continue # Skip if provider not configured
            
            provider_voice_id = None
            if voice_id:
                profile = await self.get_voice_profile(voice_id)
                if profile:
                    if profile.provider == provider_name:
                        provider_voice_id = profile.provider_voice_id
                    else:
                        logger.warning(f"Voice profile {voice_id} is for {profile.provider}, but trying {provider_name}. Using default.")
                        provider_voice_id = None
                else:
                    provider_voice_id = voice_id

            try:
                start_time = time.time()
                
                if method_name == "synthesize":
                    result = await provider.synthesize(text, provider_voice_id, format)
                    total_time = (time.time() - start_time) * 1000
                    
                    return {
                        "data": result,
                        "provider": provider_name,
                        "fallback_used": i > 0,
                        "total_generation_time_ms": total_time,
                        "time_to_first_audio_ms": total_time
                    }
                elif method_name == "stream":
                    return provider.stream(text, provider_voice_id, format), provider_name, (i > 0)
                    
            except TTSError as e:
                logger.warning(f"Provider {provider_name} failed: {e.code} - {e.message}")
                last_error = e
                if e.code in [TTSErrorCode.INVALID_TEXT, TTSErrorCode.UNSUPPORTED_FORMAT]:
                    raise
            except Exception as e:
                logger.warning(f"Provider {provider_name} unexpected failure: {str(e)}")
                last_error = e

        if last_error:
            if initial_provider == "auto":
                raise TTSError(
                    code=TTSErrorCode.TTS_ALL_PROVIDERS_FAILED,
                    message="All configured TTS providers failed",
                    provider_detail=str(last_error)
                )
            else:
                if isinstance(last_error, TTSError):
                    raise last_error
                raise TTSError(TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, "Provider failed", str(last_error))
        
        raise TTSError(TTSErrorCode.TTS_ALL_PROVIDERS_FAILED, "No providers available")

    async def synthesize(self, text: str, voice_id: Optional[str] = None, format: str = "mp3", provider: str = "auto") -> dict:
        return await self._execute_with_fallback("synthesize", text, voice_id, format, provider)

    async def stream(self, text: str, voice_id: Optional[str] = None, format: str = "mp3", provider: str = "auto"):
        return await self._execute_with_fallback("stream", text, voice_id, format, provider)

    async def health_check(self) -> dict:
        health_status = {
            "service": "phaseguard-voice",
            "providers": {}
        }
        
        for name, provider in self._providers.items():
            enabled = True
            try:
                is_healthy = await provider.health_check()
            except:
                is_healthy = False
            health_status["providers"][name] = {
                "enabled": enabled,
                "available": is_healthy
            }
            
        return health_status


_voice_service: Optional[VoiceService] = None

def get_voice_service(db_session: Optional[AsyncSession] = None) -> VoiceService:
    global _voice_service
    if _voice_service is None:
        _voice_service = VoiceService(db_session=db_session)
    elif db_session and getattr(_voice_service, '_db_session', None) != db_session:
        _voice_service._db_session = db_session
    return _voice_service
