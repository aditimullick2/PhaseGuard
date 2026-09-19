"""
PhaseGuard Deepfake Detection Service
Main service for unified deepfake detection with model registry
"""
import time
import uuid
from typing import Dict, Optional
import numpy as np

from .model_registry import get_model_registry, ModelType
from .detector_interface import DeepfakeDetector, DetectionResult, ThresholdConfig, ScoreAggregator
from .audio_preprocessor import get_audio_preprocessor
from .adapters.specrnet_adapter import SpecRNetAdapter
from .adapters.aasist_l_adapter import AASISTLDetector


class DetectionService:
    """Main detection service with model registry and unified interface."""

    def __init__(self, mobile_model: ModelType = ModelType.VOICESHIELD,
                 backend_model: ModelType = ModelType.SPECRNET):
        """
        Initialize detection service.

        Args:
            mobile_model: Model to use for mobile detection
            backend_model: Model to use for backend detection
        """
        self.model_registry = get_model_registry()
        self.preprocessor = get_audio_preprocessor()
        self.mobile_model_type = mobile_model
        self.backend_model_type = backend_model

        self.mobile_detector: Optional[DeepfakeDetector] = None
        self.backend_detector: Optional[DeepfakeDetector] = None

        self.score_aggregator = ScoreAggregator(window_size=5, aggregation_method="mean")
        self.threshold_config = ThresholdConfig()

        self._is_initialized = False

    def initialize(self) -> bool:
        """Initialize detection service with available models."""
        try:
            # Initialize backend detector based on model type
            if self.backend_model_type == ModelType.SPECRNET:
                self.backend_detector = SpecRNetAdapter(self.threshold_config)
                self.backend_detector.initialize()
            elif self.backend_model_type == ModelType.AASIST_L:
                self.backend_detector = AASISTLDetector(threshold_config=self.threshold_config)
                self.backend_detector.initialize()
            else:
                print(f"Backend model {self.backend_model_type} not implemented yet")
                return False

            # Mobile detector would be implemented similarly
            # For now, we use backend detector as primary

            self._is_initialized = True
            print(f"Detection service initialized with {self.backend_model_type.value}")
            return True

        except Exception as e:
            print(f"Failed to initialize detection service: {e}")
            return False

    def detect_audio(self, audio_bytes: bytes, use_backend: bool = True) -> Dict:
        """
        Detect deepfake in audio bytes.

        Args:
            audio_bytes: Raw audio bytes
            use_backend: Whether to use backend detection

        Returns:
            Detection result with unified format
        """
        if not self._is_initialized:
            return self._create_error_result("Service not initialized")

        try:
            start_time = time.time()

            # For SpecRNet adapter, pass raw bytes directly
            # SpecRNet service handles its own preprocessing
            if use_backend and self.backend_detector:
                # SpecRNet adapter expects raw bytes, not preprocessed array
                if hasattr(self.backend_detector, 'predict_with_bytes'):
                    result = self.backend_detector.predict_with_bytes(audio_bytes)
                else:
                    # Fallback: preprocess and use predict
                    audio = self.preprocessor.preprocess_audio_bytes(audio_bytes)
                    result = self.backend_detector.predict(audio)
            else:
                result = self._create_error_result("No detector available")

            # Add rolling score
            if "spoof_score" in result:
                raw_score = result["spoof_score"]
                smoothed_score = self.score_aggregator.add_score(raw_score)
                result["raw_score"] = raw_score
                result["smoothed_score"] = smoothed_score

            # Add request ID
            result["request_id"] = str(uuid.uuid4())

            # Add total latency
            total_latency = (time.time() - start_time) * 1000
            result["latency_ms"] = total_latency

            return result

        except Exception as e:
            print(f"Error in audio detection: {e}")
            return self._create_error_result(str(e))

    def detect_streaming(self, audio_chunk: np.ndarray) -> Dict:
        """
        Detect deepfake in streaming audio chunk.

        Args:
            audio_chunk: Audio chunk for streaming detection

        Returns:
            Detection result for the chunk
        """
        if not self._is_initialized:
            return self._create_error_result("Service not initialized")

        try:
            if self.backend_detector:
                result = self.backend_detector.predict_stream(audio_chunk)

                # Add rolling score
                if "spoof_score" in result:
                    raw_score = result["spoof_score"]
                    smoothed_score = self.score_aggregator.add_score(raw_score)
                    result["raw_score"] = raw_score
                    result["smoothed_score"] = smoothed_score

                return result
            else:
                return self._create_error_result("No detector available")

        except Exception as e:
            print(f"Error in streaming detection: {e}")
            return self._create_error_result(str(e))

    def get_health(self) -> Dict:
        """
        Get detection service health status.

        Returns:
            Health status with model availability
        """
        # Get current backend model info
        backend_info = {}
        if self.backend_detector and self._is_initialized:
            try:
                backend_info = self.backend_detector.get_info()
            except Exception as e:
                backend_info = {"error": str(e)}

        return {
            "service": "deepfake-detector",
            "is_initialized": self._is_initialized,
            "mobile_model": self.mobile_model_type.value,
            "backend_model": self.backend_model_type.value,
            "backend_model_info": backend_info,
            "models": {
                model_type.value: {
                    "available": config.available,
                    "accuracy": config.accuracy,
                    "latency_ms": config.latency_ms
                }
                for model_type, config in self.model_registry.models.items()
            }
        }

    def update_thresholds(self, real_threshold: float = None,
                        suspicious_low: float = None,
                        suspicious_high: float = None,
                        synthetic_threshold: float = None) -> None:
        """
        Update detection thresholds.

        Args:
            real_threshold: Threshold for REAL decision
            suspicious_low: Lower threshold for SUSPICIOUS
            suspicious_high: Upper threshold for SUSPICIOUS
            synthetic_threshold: Threshold for SYNTHETIC
        """
        if real_threshold is not None:
            self.threshold_config.real_threshold = real_threshold
        if suspicious_low is not None:
            self.threshold_config.suspicious_low = suspicious_low
        if suspicious_high is not None:
            self.threshold_config.suspicious_high = suspicious_high
        if synthetic_threshold is not None:
            self.threshold_config.synthetic_threshold = synthetic_threshold

    def reset_aggregator(self) -> None:
        """Reset the rolling score aggregator."""
        self.score_aggregator.reset()

    def release(self) -> None:
        """Release detection service resources."""
        if self.backend_detector:
            self.backend_detector.release()
        self._is_initialized = False

    def _create_error_result(self, error: str) -> Dict:
        """Create error result."""
        return DetectionResult(
            spoof_score=0.0,
            bonafide_score=1.0,
            decision="REAL",
            model="unknown",
            latency_ms=0.0,
            confidence=0.0
        ).to_dict()


# Global detection service instance
_detection_service: Optional[DetectionService] = None


def get_detection_service() -> DetectionService:
    """Get or create global detection service instance."""
    global _detection_service
    if _detection_service is None:
        _detection_service = DetectionService()
        _detection_service.initialize()
    return _detection_service
