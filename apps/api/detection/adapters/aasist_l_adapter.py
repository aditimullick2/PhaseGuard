"""
AASIST-L ONNX Adapter for PhaseGuard Detection
Real AASIST-L model using ONNX Runtime
"""
import numpy as np
import time
import onnxruntime as ort
from typing import Dict, Optional
from ..detector_interface import DeepfakeDetector, DetectionResult, ThresholdConfig
from ..audio_preprocessor import get_audio_preprocessor


class AASISTLDetector(DeepfakeDetector):
    """AASIST-L ONNX model detector for real deepfake detection."""

    def __init__(self, model_path: str = "models/aasist_l/aasist-l.onnx",
                 threshold_config: ThresholdConfig = None):
        """
        Initialize AASIST-L detector.

        Args:
            model_path: Path to AASIST-L ONNX model
            threshold_config: Custom threshold configuration
        """
        self.model_path = model_path
        self.preprocessor = get_audio_preprocessor()
        self.threshold_config = threshold_config or ThresholdConfig()
        self.session: Optional[ort.InferenceSession] = None
        self._is_initialized = False
        self._model_load_time_ms = 0.0

        # Model input/output info
        self.input_name = None
        self.input_shape = None
        self.output_name = None
        self.output_shape = None

    def initialize(self) -> bool:
        """Initialize AASIST-L ONNX model."""
        try:
            print(f"Loading AASIST-L model from {self.model_path}...")
            start_time = time.time()

            # Load ONNX model
            self.session = ort.InferenceSession(self.model_path, providers=['CPUExecutionProvider'])

            # Get input/output info
            inputs = self.session.get_inputs()
            outputs = self.session.get_outputs()

            self.input_name = inputs[0].name
            self.input_shape = inputs[0].shape
            self.output_name = outputs[0].name
            self.output_shape = outputs[0].shape

            print(f"AASIST-L loaded successfully:")
            print(f"  Input: {self.input_name}, shape: {self.input_shape}")
            print(f"  Output: {self.output_name}, shape: {self.output_shape}")

            self._model_load_time_ms = (time.time() - start_time) * 1000
            self._is_initialized = True
            return True

        except Exception as e:
            print(f"Failed to initialize AASIST-L: {e}")
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

            # AASIST-L expects exactly 64600 samples (4.0375 seconds at 16kHz)
            target_samples = 64600

            # Pad or crop to target length
            if len(audio) > target_samples:
                audio = audio[:target_samples]
            elif len(audio) < target_samples:
                audio = np.pad(audio, (0, target_samples - len(audio)))

            # Reshape for model input [batch, samples]
            audio_input = audio.reshape(1, -1).astype(np.float32)

            # Run inference
            outputs = self.session.run([self.output_name], {self.input_name: audio_input})
            logits = outputs[0]  # Shape: [1, 2]

            # Apply softmax to convert logits to probabilities
            probabilities = self._softmax(logits[0])  # Shape: [2]

            # AASIST-L output order: Based on raw model testing, it's [spoof, bonafide]
            # Real sample: [0.1065, 0.8935] -> spoof=0.1065, bonafide=0.8935 (correct for real)
            # Synthetic sample: [1.0000, 0.0000] -> spoof=1.0000, bonafide=0.0000 (correct for synthetic)
            spoof_prob = probabilities[0]
            bona_fide_prob = probabilities[1]

            # Use native model output directly (higher spoof = more synthetic)
            spoof_score = spoof_prob
            bonafide_score = bona_fide_prob

            # Classification
            decision = self.threshold_config.classify(spoof_score)

            latency_ms = (time.time() - start_time) * 1000

            detection_result = DetectionResult(
                spoof_score=float(spoof_score),
                bonafide_score=float(bonafide_score),
                decision=decision,
                model="AASIST-L",
                latency_ms=round(latency_ms, 2),
                confidence=float(spoof_score)
            )

            return detection_result.to_dict()

        except Exception as e:
            print(f"Error in AASIST-L prediction: {e}")
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
        """Release AASIST-L resources."""
        if self.session:
            del self.session
            self.session = None
        self._is_initialized = False

    def get_info(self) -> Dict:
        """Get AASIST-L detector information."""
        if not self._is_initialized:
            return {"error": "Model not initialized"}

        try:
            return {
                "model": "AASIST-L",
                "type": "onnx",
                "runtime": "onnxruntime",
                "model_path": self.model_path,
                "input_name": self.input_name,
                "input_shape": self.input_shape,
                "output_name": self.output_name,
                "output_shape": self.output_shape,
                "model_load_time_ms": round(self._model_load_time_ms, 2),
                "is_loaded": True
            }
        except Exception as e:
            return {"error": str(e)}

    def _softmax(self, x: np.ndarray) -> np.ndarray:
        """Apply softmax function."""
        exp_x = np.exp(x - np.max(x))
        return exp_x / exp_x.sum()

    def _create_error_result(self, error: str, latency_ms: float = 0.0) -> Dict:
        """Create error result."""
        return DetectionResult(
            spoof_score=0.0,
            bonafide_score=1.0,
            decision="REAL",
            model="AASIST-L",
            latency_ms=round(latency_ms, 2),
            confidence=0.0
        ).to_dict()
