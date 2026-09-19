"""
Multi-Detector Fallback Service for PhaseGuard

Provides fallback detection across multiple deepfake detection systems:
1. Vocalyx (HuggingFace Wav2Vec2) - Production-grade
2. final-voice-deepfake (ElevenLabs CNN) - ElevenLabs specific
3. VoiceGuard Pro (Acoustic Forensics) - Feature-based
4. VoiceShield (Local Mobile) - Final fallback

Fallback Architecture:
- Try 1: Vocalyx (HuggingFace)
- Try 2: final-voice-deepfake (if Vocalyx fails)
- Try 3: VoiceGuard Pro (if both web fail)
- Try 4: VoiceShield Local (if all web fail)

Enhanced with:
- Audio preprocessing (noise reduction, normalization)
- Threshold calibration for better accuracy
- Confidence adjustment for low-confidence cases
"""

from __future__ import annotations
import os
import sys
import logging
from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from enum import Enum
import numpy as np
import torch
import librosa

# Add third-party repositories to path
THIRD_PARTY_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "..", "third-party")
VOCALYX_PATH = os.path.join(THIRD_PARTY_DIR, "vocalyx")
FINAL_VOICE_PATH = os.path.join(THIRD_PARTY_DIR, "final-voice-deepfake")
VOICEGUARD_PATH = os.path.join(THIRD_PARTY_DIR, "voiceguard-pro")

if VOCALYX_PATH not in sys.path:
    sys.path.insert(0, VOCALYX_PATH)
if FINAL_VOICE_PATH not in sys.path:
    sys.path.insert(0, FINAL_VOICE_PATH)
if VOICEGUARD_PATH not in sys.path:
    sys.path.insert(0, VOICEGUARD_PATH)

logger = logging.getLogger(__name__)


def preprocess_audio(waveform: torch.Tensor, original_sr: int = 16000, max_duration: float = 30.0) -> torch.Tensor:
    """
    Preprocess audio for better detection accuracy:
    - Convert to mono if stereo
    - Resample to 16kHz
    - Normalize amplitude
    - Remove DC offset
    - Truncate to max_duration to avoid OOM on large files
    """
    import numpy as np
    
    # Convert to numpy for librosa
    if isinstance(waveform, torch.Tensor):
        audio_np = waveform.squeeze().numpy()
    else:
        audio_np = waveform
    
    # Ensure mono
    if len(audio_np.shape) > 1:
        audio_np = np.mean(audio_np, axis=0)
    
    # Resample to 16kHz if needed
    if original_sr != 16000:
        audio_np = librosa.resample(audio_np, orig_sr=original_sr, target_sr=16000)
    
    # Truncate to max_duration to avoid OOM
    max_samples = int(16000 * max_duration)
    if len(audio_np) > max_samples:
        audio_np = audio_np[:max_samples]
    
    # Remove DC offset
    audio_np = audio_np - np.mean(audio_np)
    
    # Normalize amplitude
    max_val = np.max(np.abs(audio_np))
    if max_val > 0:
        audio_np = audio_np / max_val
    
    # Convert back to tensor
    return torch.FloatTensor(audio_np).unsqueeze(0)


def apply_noise_reduction(audio_np: np.ndarray, sr: int = 16000) -> np.ndarray:
    """
    Apply simple noise reduction using spectral gating
    """
    try:
        # Compute STFT
        stft = librosa.stft(audio_np)
        magnitude = np.abs(stft)
        phase = np.angle(stft)
        
        # Estimate noise from quiet sections
        noise_threshold = np.percentile(magnitude, 10)
        
        # Apply soft gating
        mask = magnitude / (noise_threshold + 1e-8)
        mask = np.clip(mask - 1, 0, 1)  # Only keep components above noise floor
        
        # Apply mask
        clean_stft = stft * mask
        
        # Inverse STFT
        clean_audio = librosa.istft(clean_stft)
        
        return clean_audio
    except:
        # If noise reduction fails, return original
        return audio_np


def calibrate_threshold(spoof_score: float, confidence: float) -> float:
    """
    Calibrate spoof score threshold based on confidence
    More conservative for low-confidence predictions
    """
    # Base threshold - make it more conservative to reduce false positives
    threshold = 0.5
    
    # If confidence is low, require MUCH higher spoof score to classify as synthetic
    if confidence < 0.5:
        threshold = 0.85  # Very conservative
    elif confidence < 0.7:
        threshold = 0.75  # More conservative
    elif confidence < 0.85:
        threshold = 0.65  # Moderately conservative
    
    # Adjust spoof score based on threshold
    if spoof_score < threshold:
        # Scale down spoof score for human classification
        adjusted_score = spoof_score * (spoof_score / threshold)
    else:
        # Scale up spoof score for synthetic classification
        adjusted_score = 0.5 + (spoof_score - 0.5) * 1.1
    
    return np.clip(adjusted_score, 0.0, 1.0)


def adjust_confidence(spoof_score: float, confidence: float, detector_reliability: float = 1.0) -> float:
    """
    Adjust confidence based on spoof score and detector reliability
    Less aggressive penalty for ambiguous scores
    """
    # Reduce confidence for ambiguous scores near 0.5, but less aggressively
    ambiguity_penalty = 0.5 + 0.5 * (1.0 - abs(spoof_score - 0.5) * 2)  # 0.5 at 0.5, 1.0 at 0.0 or 1.0
    
    # Apply detector reliability weight
    adjusted_confidence = confidence * ambiguity_penalty * detector_reliability
    
    # Ensure minimum confidence of 0.1 to avoid zero confidence
    adjusted_confidence = max(adjusted_confidence, 0.1)
    
    return np.clip(adjusted_confidence, 0.0, 1.0)


class DetectorType(Enum):
    VOCALYX = "vocalyx"
    FINAL_VOICE_DEEPFAKE = "final_voice_deepfake"
    VOICEGUARD_PRO = "voiceguard_pro"
    VOICESHIELD_LOCAL = "voiceshield_local"


@dataclass
class DetectionResult:
    """Standardized detection result across all detectors"""
    detector: DetectorType
    is_spoof: bool
    spoof_score: float  # 0.0 - 1.0 (higher = more synthetic)
    confidence: float  # 0.0 - 1.0 (how certain)
    error: Optional[str] = None
    latency_ms: float = 0.0
    metadata: Optional[Dict[str, Any]] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dict with Python native types for JSON serialization"""
        return {
            "detector": self.detector.value,
            "is_spoof": bool(self.is_spoof),
            "spoof_score": float(self.spoof_score),
            "confidence": float(self.confidence),
            "error": self.error,
            "latency_ms": float(self.latency_ms),
            "metadata": self.metadata
        }


class VocalyxDetector:
    """
    Vocalyx detector integration
    Uses HuggingFace Wav2Vec2 model with spectral fallback
    """
    
    def __init__(self):
        self._loaded = False
        self._detector = None
        self._available = False
        self._try_load()
    
    def _try_load(self):
        """Try to load Vocalyx detector"""
        try:
            from src.antispoofing.deepfake_detector import load_hf_model, detect_spoof
            self._detect_spoof = detect_spoof
            self._load_hf_model = load_hf_model
            
            # Try to load HuggingFace model
            success = self._load_hf_model(model_id="motheecreator/Deepfake-audio-detection")
            if success:
                self._available = True
                self._loaded = True
                logger.info("Vocalyx detector loaded successfully with HuggingFace model")
            else:
                # Still available with spectral fallback
                self._available = True
                self._loaded = True
                logger.info("Vocalyx detector loaded with spectral fallback")
        except Exception as e:
            self._available = False
            logger.warning(f"Vocalyx detector not available: {e}")
    
    def detect(self, waveform: torch.Tensor) -> Optional[DetectionResult]:
        """Detect spoof using Vocalyx"""
        if not self._available:
            return None
        
        import time
        start_time = time.time()
        
        try:
            # Preprocess audio with duration limit to avoid OOM
            waveform = preprocess_audio(waveform, max_duration=15.0)  # 15 seconds max
            
            result = self._detect_spoof(waveform)
            latency_ms = (time.time() - start_time) * 1000
            
            # Use original results without aggressive calibration
            # Only apply light calibration for very low confidence cases
            if result.confidence < 0.3:
                # Very low confidence - be conservative
                is_spoof = result.spoof_score > 0.7  # Require high spoof score
                adjusted_confidence = max(result.confidence, 0.3)
            else:
                is_spoof = result.is_spoof
                adjusted_confidence = result.confidence
            
            return DetectionResult(
                detector=DetectorType.VOCALYX,
                is_spoof=is_spoof,
                spoof_score=result.spoof_score,
                confidence=adjusted_confidence,
                latency_ms=latency_ms,
                metadata={
                    "real_score": result.real_score,
                    "detector_model": result.detector,
                    "features": result.features
                }
            )
        except Exception as e:
            logger.error(f"Vocalyx detection failed: {e}")
            return DetectionResult(
                detector=DetectorType.VOCALYX,
                is_spoof=False,
                spoof_score=0.5,
                confidence=0.0,
                error=str(e),
                latency_ms=(time.time() - start_time) * 1000
            )


class FinalVoiceDeepfakeDetector:
    """
    final-voice-deepfake detector integration
    Uses 2D CNN trained on ElevenLabs dataset
    
    Note: This detector requires trained model files to be present in
    third-party/final-voice-deepfake/model/ directory.
    Users need to train models using their training scripts.
    """
    
    def __init__(self):
        self._loaded = False
        self._available = False
        self._model = None
        self._model_type = 'enhanced'
        self._try_load()
    
    def _try_load(self):
        """Try to load final-voice-deepfake detector"""
        try:
            # Check if model files exist
            model_dir = os.path.join(FINAL_VOICE_PATH, "model")
            model_files = [
                "enhanced_quick_trained.pth",
                "enhanced_model.pth",
                "lightweight_model.pth"
            ]
            
            model_found = False
            for model_file in model_files:
                model_path = os.path.join(model_dir, model_file)
                if os.path.exists(model_path):
                    model_found = True
                    self._model_path = model_path
                    # Set model type based on file
                    if "lightweight" in model_file:
                        self._model_type = "lightweight"
                    else:
                        self._model_type = "enhanced"
                    break
            
            if model_found:
                # Import their modules
                import sys
                original_path = sys.path.copy()
                sys.path.insert(0, FINAL_VOICE_PATH)
                
                try:
                    from src.model import get_model
                    from utils import AudioDataset
                    
                    # Load model
                    self._model = get_model(self._model_type)
                    self._model.load_state_dict(torch.load(self._model_path, map_location=torch.device('cpu')))
                    self._model.eval()
                    
                    self._available = True
                    self._loaded = True
                    logger.info(f"final-voice-deepfake detector loaded ({self._model_type})")
                finally:
                    sys.path = original_path
            else:
                logger.warning("final-voice-deepfake model files not found. Run training scripts in third-party/final-voice-deepfake/")
                self._available = False
        except Exception as e:
            self._available = False
            logger.warning(f"final-voice-deepfake detector not available: {e}")
    
    def detect(self, waveform: torch.Tensor) -> Optional[DetectionResult]:
        """Detect spoof using final-voice-deepfake"""
        if not self._available or self._model is None:
            return None
        
        import time
        import librosa
        import numpy as np
        start_time = time.time()
        
        try:
            # Import their modules
            import sys
            original_path = sys.path.copy()
            sys.path.insert(0, FINAL_VOICE_PATH)
            
            try:
                from utils import AudioDataset
                import torch.nn.functional as F
                
                # Convert waveform to numpy for librosa
                audio_np = waveform.squeeze().numpy()
                sr = 16000
                
                # Use their AudioDataset to extract features
                dataset = AudioDataset.__new__(AudioDataset)
                features = dataset.extract_all_features(audio_np, sr)
                
                # Convert to tensors
                spectral = torch.FloatTensor(features['spectral']).unsqueeze(0)
                mfcc = torch.FloatTensor(features['mfcc']).unsqueeze(0)
                phase = torch.FloatTensor(features['phase']).unsqueeze(0)
                
                # Run inference
                with torch.no_grad():
                    if self._model_type == 'lightweight':
                        output = self._model(spectral)
                    else:
                        output = self._model(spectral, mfcc, phase)
                    
                    probabilities = F.softmax(output, dim=1)
                    confidence, prediction = torch.max(probabilities, 1)
                
                # Map prediction to spoof score
                # Their model: prediction=1 is REAL, prediction=0 is FAKE
                is_spoof = prediction.item() == 0
                spoof_score = 1.0 - confidence.item() if is_spoof else confidence.item()
                confidence_val = confidence.item()
                
                latency_ms = (time.time() - start_time) * 1000
                
                return DetectionResult(
                    detector=DetectorType.FINAL_VOICE_DEEPFAKE,
                    is_spoof=is_spoof,
                    spoof_score=spoof_score,
                    confidence=confidence_val,
                    latency_ms=latency_ms,
                    metadata={
                        "model_type": self._model_type,
                        "prediction": "FAKE" if is_spoof else "REAL",
                        "model_confidence": confidence_val
                    }
                )
            finally:
                sys.path = original_path
                
        except Exception as e:
            logger.error(f"final-voice-deepfake detection failed: {e}")
            return DetectionResult(
                detector=DetectorType.FINAL_VOICE_DEEPFAKE,
                is_spoof=False,
                spoof_score=0.5,
                confidence=0.0,
                error=str(e),
                latency_ms=(time.time() - start_time) * 1000
            )


class VoiceGuardProDetector:
    """
    VoiceGuard Pro detector integration
    Uses 193-feature extraction + ML + heuristic
    
    Note: This detector requires voiceguard_model.pkl to be present in
    third-party/voiceguard-pro/ directory.
    The model file should be created using their training scripts.
    """
    
    def __init__(self):
        self._loaded = False
        self._available = False
        self._model = None
        self._try_load()
    
    def _try_load(self):
        """Try to load VoiceGuard Pro detector"""
        try:
            # Check if model file exists
            model_path = os.path.join(VOICEGUARD_PATH, "voiceguard_model.pkl")
            if os.path.exists(model_path):
                # Import joblib
                import joblib
                
                # Load model
                self._model = joblib.load(model_path)
                
                # Check if model has correct feature count
                if hasattr(self._model, 'n_features_in_') and self._model.n_features_in_ != 193:
                    logger.warning(f"VoiceGuard Pro model expects {self._model.n_features_in_} features, but app extracts 193")
                    self._available = False
                else:
                    self._available = True
                    self._loaded = True
                    logger.info("VoiceGuard Pro detector loaded")
            else:
                logger.warning("VoiceGuard Pro model file not found. Run training in third-party/voiceguard-pro/")
                self._available = False
        except Exception as e:
            self._available = False
            logger.warning(f"VoiceGuard Pro detector not available: {e}")
    
    def detect(self, audio_path: str) -> Optional[DetectionResult]:
        """Detect spoof using VoiceGuard Pro"""
        if not self._available or self._model is None:
            return None
        
        import time
        import numpy as np
        import librosa
        start_time = time.time()
        
        try:
            # Import their feature extraction functions
            import sys
            original_path = sys.path.copy()
            sys.path.insert(0, VOICEGUARD_PATH)
            
            try:
                # Load audio
                y, sr = librosa.load(audio_path, sr=22050, duration=15)
                if y is None or len(y) < 22050*0.3:
                    raise Exception("Audio too short or invalid")
                
                # Extract 193 features (from their app.py)
                n_mfcc = 40
                
                # MFCCs and derivatives
                mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=n_mfcc)
                delta1 = librosa.feature.delta(mfccs)
                delta2 = librosa.feature.delta(mfccs, order=2)
                
                # Spectral features
                sc = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
                sb = librosa.feature.spectral_bandwidth(y=y, sr=sr)[0]
                sf = librosa.feature.spectral_flatness(y=y)[0]
                sro = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
                zc = librosa.feature.zero_crossing_rate(y)[0]
                rm = librosa.feature.rms(y=y)[0]
                
                spectral = np.array([
                    np.mean(sc), np.std(sc),
                    np.mean(sb), np.std(sb),
                    np.mean(sf), np.std(sf),
                    np.mean(sro), np.std(sro),
                    np.mean(zc), np.std(zc),
                    np.mean(rm), np.std(rm),
                ], dtype=np.float32)
                
                # Harmonic-to-Noise Ratio
                try:
                    harmonic, percussive = librosa.effects.hpss(y)
                    hnr_ratio = np.mean(np.abs(harmonic)) / (np.mean(np.abs(percussive)) + 1e-8)
                    hnr_std = np.std(np.abs(harmonic)) / (np.std(np.abs(percussive)) + 1e-8)
                except:
                    hnr_ratio, hnr_std = 1.0, 1.0
                hnr_feats = np.array([hnr_ratio, hnr_std], dtype=np.float32)
                
                # Spectral Contrast
                try:
                    contrast = librosa.feature.spectral_contrast(y=y, sr=sr, n_bands=6)
                    contrast_mean = np.mean(contrast, axis=1)
                except:
                    contrast_mean = np.zeros(7, dtype=np.float32)
                
                # Combine all features (193 total)
                features = np.concatenate([
                    np.mean(mfccs, axis=1),    # 40
                    np.std(mfccs, axis=1),     # 40
                    np.mean(delta1, axis=1),   # 40
                    np.mean(delta2, axis=1),   # 40
                    spectral,                   # 12
                    hnr_feats,                  # 2
                    contrast_mean,              # 7
                    np.mean(librosa.feature.chroma_stft(y=y, sr=sr), axis=1),  # 12
                ]).astype(np.float32)
                
                # Check feature count
                if len(features) != 193:
                    raise Exception(f"Expected 193 features, got {len(features)}")
                
                # Run prediction
                probs = self._model.predict_proba(features.reshape(1, -1))[0]
                classes = list(self._model.classes_)
                
                # Find fake class index
                fake_idx = classes.index(1) if 1 in classes else -1
                if fake_idx >= 0:
                    ai_score = float(probs[fake_idx]) * 100.0
                else:
                    ai_score = 50.0
                
                # Convert to spoof score (0-1)
                spoof_score = ai_score / 100.0
                confidence = abs(ai_score - 50.0) / 50.0  # Distance from uncertainty
                
                latency_ms = (time.time() - start_time) * 1000
                
                return DetectionResult(
                    detector=DetectorType.VOICEGUARD_PRO,
                    is_spoof=ai_score >= 50.0,
                    spoof_score=spoof_score,
                    confidence=confidence,
                    latency_ms=latency_ms,
                    metadata={
                        "ai_score": ai_score,
                        "feature_count": len(features)
                    }
                )
            finally:
                sys.path = original_path
                
        except Exception as e:
            logger.error(f"VoiceGuard Pro detection failed: {e}")
            return DetectionResult(
                detector=DetectorType.VOICEGUARD_PRO,
                is_spoof=False,
                spoof_score=0.5,
                confidence=0.0,
                error=str(e),
                latency_ms=(time.time() - start_time) * 1000
            )


class VoiceShieldLocalDetector:
    """
    VoiceShield local mobile detector
    Final fallback when all web detectors fail
    """
    
    def __init__(self):
        self._available = True  # Always available locally
        logger.info("VoiceShield local detector initialized")
    
    def detect(self, waveform: torch.Tensor) -> DetectionResult:
        """Detect spoof using VoiceShield local"""
        import time
        start_time = time.time()
        
        try:
            # Preprocess audio with duration limit to avoid OOM
            waveform = preprocess_audio(waveform, max_duration=15.0)  # 15 seconds max
            
            # Simplified VoiceShield detection using Vocalyx spectral fallback
            # This ensures it always works without complex pipeline integration
            from src.antispoofing.deepfake_detector import SpectralAntiSpoof
            
            detector = SpectralAntiSpoof()
            result = detector.predict(waveform)
            
            latency_ms = (time.time() - start_time) * 1000
            
            # Use original results without aggressive calibration
            return DetectionResult(
                detector=DetectorType.VOICESHIELD_LOCAL,
                is_spoof=result.is_spoof,
                spoof_score=result.spoof_score,
                confidence=max(result.confidence, 0.3),  # Ensure minimum confidence
                latency_ms=latency_ms,
                metadata={
                    "method": "spectral_fallback",
                    "detector_model": result.detector,
                    "features": result.features
                }
            )
        except Exception as e:
            logger.error(f"VoiceShield local detection failed: {e}")
            return DetectionResult(
                detector=DetectorType.VOICESHIELD_LOCAL,
                is_spoof=False,
                spoof_score=0.5,
                confidence=0.0,
                error=str(e),
                latency_ms=(time.time() - start_time) * 1000
            )


class MultiDetectorFallback:
    """
    Multi-detector fallback orchestration
    Tries detectors in order and falls back to next on failure
    
    Enhanced with ensemble voting for better accuracy
    """
    
    def __init__(self, use_ensemble: bool = True):
        self.vocalyx = VocalyxDetector()
        self.final_voice = FinalVoiceDeepfakeDetector()
        self.voiceguard = VoiceGuardProDetector()
        self.voiceshield = VoiceShieldLocalDetector()
        self.use_ensemble = use_ensemble
        
        logger.info("Multi-detector fallback initialized")
        logger.info(f"Vocalyx available: {self.vocalyx._available}")
        logger.info(f"final-voice-deepfake available: {self.final_voice._available}")
        logger.info(f"VoiceGuard Pro available: {self.voiceguard._available}")
        logger.info(f"VoiceShield local available: {self.voiceshield._available}")
        logger.info(f"Ensemble voting: {use_ensemble}")
    
    def detect(self, waveform: torch.Tensor, audio_path: Optional[str] = None) -> DetectionResult:
        """
        Detect spoof with fallback chain
        Order: Vocalyx → final-voice-deepfake → VoiceGuard Pro → VoiceShield Local
        
        Enhanced with ensemble voting for better accuracy
        """
        detectors = [
            ("Vocalyx", self.vocalyx),
            ("final-voice-deepfake", self.final_voice),
            ("VoiceGuard Pro", self.voiceguard),
            ("VoiceShield Local", self.voiceshield)
        ]
        
        last_error = None
        results = []
        
        # If ensemble is disabled, only try first successful detector
        if not self.use_ensemble:
            for name, detector in detectors:
                logger.info(f"Trying detector: {name} (single mode)")
                
                try:
                    # Call appropriate detect method
                    if name == "VoiceGuard Pro":
                        # VoiceGuard Pro needs audio path
                        if audio_path:
                            result = detector.detect(audio_path)
                        else:
                            result = None
                    else:
                        result = detector.detect(waveform)
                    
                    if result is None:
                        logger.warning(f"{name} detector returned None")
                        continue
                    
                    if result.error and result.confidence == 0.0:
                        logger.warning(f"{name} detector failed: {result.error}")
                        last_error = result.error
                        continue
                    
                    # Return first successful result
                    logger.info(f"{name} detector succeeded: spoof_score={result.spoof_score}, confidence={result.confidence}")
                    return result
                    
                except Exception as e:
                    logger.error(f"{name} detector raised exception: {e}")
                    last_error = str(e)
                    continue
            
            # All detectors failed
            logger.error("All detectors failed, returning error result")
            return DetectionResult(
                detector=DetectorType.VOICESHIELD_LOCAL,
                is_spoof=False,
                spoof_score=0.5,
                confidence=0.0,
                error=f"All detectors failed. Last error: {last_error}",
                latency_ms=0.0
            )
        
        # Ensemble mode: collect results from all available detectors
        for name, detector in detectors:
            logger.info(f"Trying detector: {name} (ensemble mode)")
            
            try:
                # Call appropriate detect method
                if name == "VoiceGuard Pro":
                    # VoiceGuard Pro needs audio path
                    if audio_path:
                        result = detector.detect(audio_path)
                    else:
                        result = None
                else:
                    result = detector.detect(waveform)
                
                if result is None:
                    logger.warning(f"{name} detector returned None")
                    continue
                
                if result.error and result.confidence == 0.0:
                    logger.warning(f"{name} detector failed: {result.error}")
                    last_error = result.error
                    continue
                
                # Store successful result
                results.append((name, result))
                logger.info(f"{name} detector succeeded: spoof_score={result.spoof_score}, confidence={result.confidence}")
                
            except Exception as e:
                logger.error(f"{name} detector raised exception: {e}")
                last_error = str(e)
                continue
        
        # Use ensemble voting if multiple results available
        if len(results) >= 2:
            return self._ensemble_vote(results)
        
        # Fallback to single detector (first successful)
        if results:
            return results[0][1]
        
        # All detectors failed, return VoiceShield result even if it has error
        logger.error("All detectors failed, returning last attempted result")
        return DetectionResult(
            detector=DetectorType.VOICESHIELD_LOCAL,
            is_spoof=False,
            spoof_score=0.5,
            confidence=0.0,
            error=f"All detectors failed. Last error: {last_error}",
            latency_ms=0.0
        )
    
    def _ensemble_vote(self, results: list) -> DetectionResult:
        """
        Ensemble voting from multiple detectors
        Uses weighted voting based on confidence and detector reliability
        Simplified to be less aggressive
        """
        # Extract spoof scores and confidences
        spoof_scores = []
        confidences = []
        weights = []
        
        # Assign weights based on detector reliability
        weight_map = {
            "Vocalyx": 1.0,          # High weight for HuggingFace model
            "final-voice-deepfake": 0.8,  # Good for ElevenLabs specific
            "VoiceGuard Pro": 0.7,       # Good for acoustic features
            "VoiceShield Local": 0.5     # Lower weight for fallback
        }
        
        for name, result in results:
            spoof_scores.append(result.spoof_score)
            confidences.append(result.confidence)
            weights.append(weight_map.get(name, 0.5))
        
        # Weighted average
        total_weight = sum(weights)
        weighted_spoof = sum(s * w for s, w in zip(spoof_scores, weights)) / total_weight
        weighted_confidence = sum(c * w for c, w in zip(confidences, weights)) / total_weight
        
        # Majority vote on binary decision
        is_spoof_votes = sum(1 for _, r in results if r.is_spoof)
        total_votes = len(results)
        
        # Simple majority vote
        is_spoof = is_spoof_votes > (total_votes / 2)
        
        # Calculate combined latency
        avg_latency = sum(r.latency_ms for _, r in results) / len(results)
        
        # Return ensemble result
        return DetectionResult(
            detector=DetectorType.VOICESHIELD_LOCAL,  # Use this to indicate ensemble
            is_spoof=is_spoof,
            spoof_score=weighted_spoof,
            confidence=weighted_confidence,
            latency_ms=avg_latency,
            metadata={
                "ensemble_method": "weighted_voting",
                "detector_count": len(results),
                "individual_results": [
                    {"name": name, "spoof_score": r.spoof_score, "confidence": r.confidence}
                    for name, r in results
                ],
                "majority_vote": is_spoof,
                "vote_count": f"{is_spoof_votes}/{total_votes}"
            }
        )
    
    def get_detector_status(self) -> Dict[str, bool]:
        """Get availability status of all detectors"""
        return {
            "vocalyx": self.vocalyx._available,
            "final_voice_deepfake": self.final_voice._available,
            "voiceguard_pro": self.voiceguard._available,
            "voiceshield_local": self.voiceshield._available
        }


# Global instance
_multi_detector: Optional[MultiDetectorFallback] = None
_current_ensemble_mode: Optional[bool] = None


def get_multi_detector(use_ensemble: bool = True) -> MultiDetectorFallback:
    """Get or create global multi-detector instance"""
    global _multi_detector, _current_ensemble_mode
    
    # Recreate instance if ensemble mode changed
    if _multi_detector is None or _current_ensemble_mode != use_ensemble:
        _multi_detector = MultiDetectorFallback(use_ensemble=use_ensemble)
        _current_ensemble_mode = use_ensemble
    
    return _multi_detector


def detect_with_fallback(waveform: torch.Tensor, audio_path: Optional[str] = None, use_ensemble: bool = True) -> DetectionResult:
    """
    Convenience function to detect with fallback
    This is the main entry point for PhaseGuard API
    
    Args:
        waveform: Audio waveform tensor
        audio_path: Optional audio file path
        use_ensemble: Whether to use ensemble voting (default True)
    """
    detector = get_multi_detector(use_ensemble=use_ensemble)
    return detector.detect(waveform, audio_path)
