"""
voice/router.py — FastAPI router for voice/TTS endpoints.
"""

from __future__ import annotations

import io
import logging
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import Response, StreamingResponse

from core.auth import require_call_token
from core.config import get_settings
from database import get_db_session
from voice.models import (
    TTSError,
    TTSErrorCode,
    TTSRequest,
    TTSResponse,
    VoiceEnrollRequest,
    VoiceEnrollResponse,
    VoiceProfile,
)
from voice.service import get_voice_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/voice", tags=["voice"])

async def get_current_user():
    return None

@router.post("/tts")
async def text_to_speech(
    request: TTSRequest,
    db = Depends(get_db_session),
    current_user = Depends(get_current_user),
):
    service = get_voice_service(db_session=db)

    try:
        result = await service.synthesize(
            text=request.text,
            voice_id=request.voice_id,
            format=request.format,
            provider=request.provider
        )
        
        audio_bytes = result["data"]
        
        media_type = "audio/mpeg" if request.format == "mp3" else "audio/wav"
        
        response = StreamingResponse(
            io.BytesIO(audio_bytes),
            media_type=media_type,
            headers={
                "Content-Disposition": f"attachment; filename=speech.{request.format}",
                "X-TTS-Provider": result["provider"],
                "X-TTS-Fallback-Used": str(result["fallback_used"]).lower(),
                "X-TTS-Total-Generation-Time-Ms": str(result["total_generation_time_ms"]),
                "X-TTS-Time-To-First-Audio-Ms": str(result["time_to_first_audio_ms"])
            }
        )
        return response

    except TTSError as e:
        status_code = 500
        if e.code in [TTSErrorCode.PROVIDER_NOT_CONFIGURED, TTSErrorCode.VOICE_NOT_FOUND, TTSErrorCode.INVALID_TEXT]:
            status_code = 400
        elif e.code == TTSErrorCode.TTS_PROVIDER_AUTH_ERROR:
            status_code = 401
        elif e.code == TTSErrorCode.TTS_PROVIDER_RATE_LIMITED:
            status_code = 429
        elif e.code in [TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, TTSErrorCode.TTS_ALL_PROVIDERS_FAILED]:
            status_code = 503

        raise HTTPException(
            status_code=status_code,
            detail={
                "code": e.code.value,
                "message": e.message,
                "provider_detail": e.provider_detail,
                "requestId": "unknown" 
            },
        )

@router.post("/stream")
async def stream_text_to_speech(
    request: TTSRequest,
    db = Depends(get_db_session),
    current_user = Depends(get_current_user),
):
    service = get_voice_service(db_session=db)

    try:
        generator, provider_name, fallback_used = await service.stream(
            text=request.text,
            voice_id=request.voice_id,
            format=request.format,
            provider=request.provider
        )
        
        media_type = "audio/mpeg" if request.format == "mp3" else "audio/wav"
        
        return StreamingResponse(
            generator,
            media_type=media_type,
            headers={
                "X-TTS-Provider": provider_name,
                "X-TTS-Fallback-Used": str(fallback_used).lower(),
            }
        )

    except TTSError as e:
        status_code = 500
        if e.code in [TTSErrorCode.PROVIDER_NOT_CONFIGURED, TTSErrorCode.VOICE_NOT_FOUND, TTSErrorCode.INVALID_TEXT]:
            status_code = 400
        elif e.code == TTSErrorCode.TTS_PROVIDER_AUTH_ERROR:
            status_code = 401
        elif e.code == TTSErrorCode.TTS_PROVIDER_RATE_LIMITED:
            status_code = 429
        elif e.code in [TTSErrorCode.TTS_PROVIDER_UNAVAILABLE, TTSErrorCode.TTS_ALL_PROVIDERS_FAILED]:
            status_code = 503

        raise HTTPException(
            status_code=status_code,
            detail={
                "code": e.code.value,
                "message": e.message,
                "provider_detail": e.provider_detail,
                "requestId": "unknown"
            },
        )

@router.post("/enroll", response_model=VoiceEnrollResponse)
async def enroll_voice(
    audio: UploadFile = File(...),
    display_name: str = Form(...),
    enhance_quality: bool = Form(True),
    db = Depends(get_db_session),
    current_user = Depends(get_current_user),
) -> VoiceEnrollResponse:
    cfg = get_settings()
    filename = audio.filename.lower() if audio.filename else ""
    valid_extensions = ['.wav', '.mp3', '.ogg', '.m4a', '.flac']
    
    if not any(ext in filename for ext in valid_extensions):
        raise HTTPException(status_code=400, detail="Invalid file type.")

    audio_data = await audio.read()
    if len(audio_data) > 10 * 1024 * 1024 or len(audio_data) < 1024:
        raise HTTPException(status_code=400, detail="Invalid file size.")

    # Create a new session for voice enrollment to avoid concurrency issues
    from database import get_engine
    from sqlalchemy.ext.asyncio import AsyncSession
    
    engine = get_engine()
    async with AsyncSession(engine) as enrollment_db:
        service = get_voice_service(db_session=enrollment_db)
        
        providers_to_try = ["fish", "sonex"]
        last_error = None
        voice_profile = None

        for provider_name in providers_to_try:
            try:
                provider = service.get_provider(provider_name)
                if not provider.supports_voice_cloning():
                    continue
                    
                voice_profile = await provider.create_voice_reference(
                    audio_data=audio_data,
                    display_name=display_name,
                    user_id=current_user.get("id") if current_user else None,
                )
                break
            except TTSError as e:
                logger.warning(f"Failed to clone voice with {provider_name}: {e}")
                last_error = e

        if not voice_profile:
            if last_error:
                raise HTTPException(status_code=500, detail=str(last_error))
            raise HTTPException(status_code=500, detail="All cloning providers failed.")

        await service.create_voice_profile(voice_profile)

    return VoiceEnrollResponse(
        voice_profile=voice_profile,
        status="enrolled",
    )

@router.get("/health")
async def health_check(db = Depends(get_db_session)):
    service = get_voice_service(db_session=db)
    return await service.health_check()

@router.get("/voices", response_model=list[VoiceProfile])
async def list_voices(
    db = Depends(get_db_session),
    current_user = Depends(get_current_user),
) -> list[VoiceProfile]:
    service = get_voice_service(db_session=db)
    user_id = current_user.get("id") if current_user else None
    return await service.list_voice_profiles(user_id=user_id)

@router.delete("/voices/{voice_id}")
async def delete_voice(
    voice_id: str,
    db = Depends(get_db_session),
    current_user = Depends(get_current_user),
):
    service = get_voice_service(db_session=db)
    profile = await service.get_voice_profile(voice_id)
    if profile and current_user and profile.user_id and profile.user_id != current_user.get("id"):
        raise HTTPException(status_code=403, detail="Forbidden")

    deleted = await service.delete_voice_profile(voice_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Not found")

    return {"status": "deleted", "voice_id": voice_id}
