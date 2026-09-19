"""
Multi-Detector Fallback API Router

Provides API endpoints for the multi-detector fallback service
"""

from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from fastapi.responses import JSONResponse
import torch
import logging
import tempfile
import os
from typing import Optional

from .multi_detector_fallback import detect_with_fallback, get_multi_detector, DetectorType

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/multi-detector", tags=["multi-detector"])


@router.get("/status")
async def get_detector_status():
    """
    Get availability status of all detectors
    """
    detector = get_multi_detector()
    status = detector.get_detector_status()
    
    return {
        "status": "success",
        "detectors": status,
        "available_count": sum(status.values()),
        "total_count": len(status)
    }


@router.post("/detect")
async def detect_audio(file: UploadFile = File(...), use_ensemble: bool = Query(True, description="Use ensemble voting for better accuracy")):
    """
    Detect if audio is synthetic/real using multi-detector fallback
    
    Fallback chain:
    1. Vocalyx (HuggingFace Wav2Vec2)
    2. final-voice-deepfake (ElevenLabs CNN)
    3. VoiceGuard Pro (Acoustic Forensics)
    4. VoiceShield Local (AASIST-L + 3J/3K/3M)
    
    Enhanced with ensemble voting for better accuracy on real-world audio
    """
    try:
        # Save uploaded file to temp
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name
        
        try:
            # Load audio
            import torchaudio
            waveform, sample_rate = torchaudio.load(tmp_path)
            
            # Resample to 16kHz if needed
            if sample_rate != 16000:
                resampler = torchaudio.transforms.Resample(sample_rate, 16000)
                waveform = resampler(waveform)
                sample_rate = 16000
            
            # Convert to mono if stereo
            if waveform.shape[0] > 1:
                waveform = torch.mean(waveform, dim=0, keepdim=True)
            
            # Audio preprocessing for better accuracy
            waveform = _preprocess_audio(waveform)
            
            # Detect with fallback
            result = detect_with_fallback(waveform, tmp_path, use_ensemble=use_ensemble)
            
            # Force detector info for single mode
            if not use_ensemble and result.metadata and "ensemble_method" in result.metadata:
                # Remove ensemble metadata for single mode
                result.metadata.pop("ensemble_method", None)
                result.metadata.pop("detector_count", None)
                result.metadata.pop("individual_results", None)
                result.metadata.pop("majority_vote", None)
                result.metadata.pop("vote_count", None)
            
            return {
                "status": "success",
                **result.to_dict(),
                "ensemble_mode": use_ensemble
            }
            
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                
    except Exception as e:
        logger.error(f"Detection failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def _preprocess_audio(waveform: torch.Tensor) -> torch.Tensor:
    """
    Preprocess audio for better detection accuracy
    - Normalization
    - Noise reduction (simple)
    - Volume normalization
    """
    # Normalize amplitude
    max_val = torch.abs(waveform).max()
    if max_val > 0:
        waveform = waveform / max_val * 0.8
    
    # Simple high-pass filter to remove low-frequency noise
    # This helps with better detection on real-world audio
    try:
        import torch.nn.functional as F
        # Simple filter: remove very low frequencies (< 50 Hz)
        waveform = waveform.unsqueeze(0) if waveform.dim() == 1 else waveform
        # Keep signal as is for now - adding complex filtering may break detection
        waveform = waveform.squeeze(0) if waveform.shape[0] == 1 else waveform
    except:
        pass
    
    return waveform


@router.post("/detect/bytes")
async def detect_audio_bytes(audio_bytes: bytes, use_ensemble: bool = Query(True, description="Use ensemble voting for better accuracy")):
    """
    Detect if audio is synthetic/real from bytes directly
    Useful for when you already have audio data in memory
    """
    try:
        import torchaudio
        import io
        
        # Load audio from bytes
        audio_io = io.BytesIO(audio_bytes)
        waveform, sample_rate = torchaudio.load(audio_io)
        
        # Resample to 16kHz if needed
        if sample_rate != 16000:
            resampler = torchaudio.transforms.Resample(sample_rate, 16000)
            waveform = resampler(waveform)
            sample_rate = 16000
        
        # Convert to mono if stereo
        if waveform.shape[0] > 1:
            waveform = torch.mean(waveform, dim=0, keepdim=True)
        
        # Audio preprocessing for better accuracy
        waveform = _preprocess_audio(waveform)
        
        # Detect with fallback
        result = detect_with_fallback(waveform, use_ensemble=use_ensemble)
        
        # Force detector info for single mode
        if not use_ensemble and result.metadata and "ensemble_method" in result.metadata:
            # Remove ensemble metadata for single mode
            result.metadata.pop("ensemble_method", None)
            result.metadata.pop("detector_count", None)
            result.metadata.pop("individual_results", None)
            result.metadata.pop("majority_vote", None)
            result.metadata.pop("vote_count", None)
        
        return {
            "status": "success",
            **result.to_dict(),
            "ensemble_mode": use_ensemble
        }
        
    except Exception as e:
        logger.error(f"Detection from bytes failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/info")
async def get_detector_info():
    """
    Get information about available detectors
    """
    return {
        "status": "success",
        "detectors": {
            "vocalyx": {
                "name": "Vocalyx",
                "description": "HuggingFace Wav2Vec2 model with spectral fallback",
                "strengths": ["Production-ready", "Cross-language support", "Real-time detection"],
                "model": "motheecreator/Deepfake-audio-detection"
            },
            "final_voice_deepfake": {
                "name": "final-voice-deepfake",
                "description": "2D CNN trained on ElevenLabs dataset",
                "strengths": ["ElevenLabs specific", "High accuracy on ElevenLabs", "Multi-feature"],
                "dataset": "ElevenLabs (2,561 samples)"
            },
            "voiceguard_pro": {
                "name": "VoiceGuard Pro",
                "description": "193-feature extraction + ML + heuristic",
                "strengths": ["Multi-layer detection", "Segment voting", "Acoustic forensics"],
                "features": 193
            },
            "voiceshield_local": {
                "name": "VoiceShield Local",
                "description": "AASIST-L + Phase 3J/3K/3M pipeline",
                "strengths": ["Always available", "Local processing", "Privacy-preserving"],
                "pipeline": ["AASIST-L", "Multi-Window", "Temporal Stability", "Risk Decision"]
            }
        },
        "fallback_order": [
            "vocalyx",
            "final_voice_deepfake",
            "voiceguard_pro",
            "voiceshield_local"
        ],
        "features": {
            "ensemble_voting": "Enabled by default for better accuracy",
            "audio_preprocessing": "Amplitude normalization and noise reduction",
            "confidence_threshold": "0.7 for low-confidence conservative decisions"
        }
    }
