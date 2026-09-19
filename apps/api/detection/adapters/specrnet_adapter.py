"""
SpecRNet Adapter for PhaseGuard Detection Interface
Wraps existing SpecRNet service to match unified detector interface
"""
import numpy as np
import time
from typing import Dict
from ..detector_interface import DeepfakeDetector, DetectionResult, ThresholdConfig
from ..audio_preprocessor import get_audio_preprocessor
from services.specrnet_service import get_specrnet_service


class SpecRNetAdapter(DeepfakeDetector):
    """SpecRNet model adapter for unified detection interface."""

    def __init__(self, threshold_config: ThresholdConfig = None):
        """
        Initialize SpecRNet adapter.

        Args:
            threshold_config: Custom threshold configuration
        """
        self.specrnet_service = get_specrnet_service()
        self.preprocessor = get_audio_preprocessor()
        self.threshold_config = threshold_config or ThresholdConfig()
        self._is_initialized = False

    def initialize(self) -> bool:
        """Initialize SpecRNet model."""
        try:
            self._is_initialized = self.specrnet_service.load_model()
            return self._is_initialized
        except Exception as e:
            print(f"Failed to initialize SpecRNet: {e}")
            return False

    def predict(self, audio: np.ndarray) -> Dict:
        """
        Run prediction on audio array.

        Args:
            audio: Preprocessed audio array (float32, 16kHz, mono)

        Returns:
            Detection result with spoof_score, bonafide_score, decision
        """
        if not self._is_initialized:
            return self._create_error_result("Model not initialized")

        try:
            start_time = time.time()

            # Convert audio array to WAV bytes for SpecRNet service
            # SpecRNet service expects WAV file bytes, not raw PCM
            import io
            import soundfile as sf

            # Create WAV bytes from numpy array
            with io.BytesIO() as buffer:
                sf.write(buffer, audio, self.preprocessor.target_sr, format='WAV')
                audio_bytes = buffer.getvalue()

            # Run SpecRNet detection
            result = self.specrnet_service.detect_deepfake(audio_bytes)

            latency_ms = (time.time() - start_time) * 1000

            if "error" in result:
                return self._create_error_result(result["error"], latency_ms)

            # Convert to unified format
            confidence = result.get("confidence", 0.0)
            is_synthetic = result.get("is_synthetic", False)

            # Handle edge case where confidence is very low or 0.0
            if confidence < 0.01:
                # Default to uncertain
                spoof_score = 0.5
                bonafide_score = 0.5
            else:
                # SpecRNet outputs probability in [0,1] range
                # The confidence value is the raw probability
                # We use this directly as the spoof_score
                spoof_score = confidence
                bonafide_score = 1.0 - confidence

            decision = self.threshold_config.classify(spoof_score)

            detection_result = DetectionResult(
                spoof_score=spoof_score,
                bonafide_score=bonafide_score,
                decision=decision,
                model="SpecRNet",
                latency_ms=round(latency_ms, 2),
                confidence=confidence
            )

            result_dict = detection_result.to_dict()
            result_dict["inference_time_ms"] = result.get("inference_time_ms", latency_ms)
            return result_dict

        except Exception as e:
            print(f"Error in SpecRNet prediction: {e}")
            return self._create_error_result(str(e))

    def predict_with_bytes(self, audio_bytes: bytes) -> Dict:
        """
        Run prediction on raw audio bytes (bypasses preprocessing).

        Args:
            audio_bytes: Raw audio bytes

        Returns:
            Detection result with spoof_score, bonafide_score, decision
        """
        if not self._is_initialized:
            return self._create_error_result("Model not initialized")

        try:
            start_time = time.time()

            # Run SpecRNet detection directly with bytes
            result = self.specrnet_service.detect_deepfake(audio_bytes)

            latency_ms = (time.time() - start_time) * 1000

            if "error" in result:
                return self._create_error_result(result["error"], latency_ms)

            # Convert to unified format
            confidence = result.get("confidence", 0.0)
            is_synthetic = result.get("is_synthetic", False)

            # Handle edge case where confidence is very low or 0.0
            if confidence < 0.01:
                # Default to uncertain
                spoof_score = 0.5
                bonafide_score = 0.5
            else:
                # SpecRNet outputs probability in [0,1] range
                # The confidence value is the raw probability
                # We use this directly as the spoof_score
                spoof_score = confidence
                bonafide_score = 1.0 - confidence

            decision = self.threshold_config.classify(spoof_score)

            detection_result = DetectionResult(
                spoof_score=spoof_score,
                bonafide_score=bonafide_score,
                decision=decision,
                model="SpecRNet",
                latency_ms=round(latency_ms, 2),
                confidence=confidence
            )

            result_dict = detection_result.to_dict()
            result_dict["inference_time_ms"] = result.get("inference_time_ms", latency_ms)
            return result_dict

        except Exception as e:
            print(f"Error in SpecRNet prediction: {e}")
            return self._create_error_result(str(e))

    def predict_stream(self, audio_chunk: np.ndarray) -> Dict:
        """
        Run prediction on streaming audio chunk.

        Args:
            audio_chunk: Audio chunk for streaming detection

        Returns:
            Detection result for the chunk
        """
        # For streaming, treat chunk as full audio for now
        return self.predict(audio_chunk)

    def release(self) -> None:
        """Release SpecRNet resources."""
        # SpecRNet service manages its own lifecycle
        pass

    def get_info(self) -> Dict:
        """Get SpecRNet detector information."""
        if not self._is_initialized:
            return {"error": "Model not initialized"}

        try:
            model_info = self.specrnet_service.get_model_info()
            return {
                "model": "SpecRNet",
                "type": "web_backend",
                "parameters": model_info.get("parameters", 0),
                "device": model_info.get("device", "cpu"),
                "input_shape": model_info.get("input_shape", "unknown"),
                "output_shape": model_info.get("output_shape", "unknown"),
                "is_loaded": True
            }
        except Exception as e:
            return {"error": str(e)}

    def _create_error_result(self, error: str, latency_ms: float = 0.0) -> Dict:
        """Create error result."""
        return DetectionResult(
            spoof_score=0.0,
            bonafide_score=1.0,
            decision="REAL",
            model="SpecRNet",
            latency_ms=round(latency_ms, 2),
            confidence=0.0
        ).to_dict()
