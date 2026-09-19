"""
SpecRNet Service for Fast Deepfake Detection
Lightweight, CPU-optimized audio deepfake detection using SpecRNet architecture.
"""
import torch
import torch.nn as nn
import numpy as np
import librosa
import io
from typing import Dict, Optional
import sys
import os

# Add SpecRNet model path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'models', 'specrnet'))

from model import SpecRNet
from config import get_specrnet_config


class SpecRNetService:
    """SpecRNet-based deepfake detection service for fast CPU inference."""

    def __init__(self, device: str = "cpu"):
        """
        Initialize SpecRNet service.

        Args:
            device: Device to run inference on ('cpu' or 'cuda')
        """
        self.device = device
        self.model: Optional[SpecRNet] = None
        self.is_loaded = False

    def load_model(self) -> bool:
        """Load SpecRNet model."""
        try:
            print("Loading SpecRNet model...")

            # Get SpecRNet configuration
            specrnet_config = get_specrnet_config(input_channels=1)

            # Initialize model
            self.model = SpecRNet(specrnet_config, device=self.device)
            self.model = self.model.to(self.device)
            self.model.eval()

            self.is_loaded = True
            print("SpecRNet model loaded successfully on device: {}".format(self.device))
            return True

        except Exception as e:
            print(f"Failed to load SpecRNet model: {e}")
            return False

    def preprocess_audio(self, audio_bytes: bytes, sr: int = 16000) -> torch.Tensor:
        """
        Preprocess audio bytes to spectrogram format for SpecRNet.

        Args:
            audio_bytes: Raw audio bytes
            sr: Sample rate (default 16000)

        Returns:
            Preprocessed spectrogram tensor
        """
        try:
            # Load audio
            audio, _ = librosa.load(io.BytesIO(audio_bytes), sr=sr, mono=True)

            # Trim/pad to 3 seconds (paper suggests 3-6 seconds)
            target_samples = sr * 3
            if len(audio) > target_samples:
                audio = audio[:target_samples]
            elif len(audio) < target_samples:
                audio = np.pad(audio, (0, target_samples - len(audio)))

            # Convert to mel-spectrogram with better parameters
            mel_spec = librosa.feature.melspectrogram(
                y=audio,
                sr=sr,
                n_mels=80,
                n_fft=1024,
                hop_length=512,
                fmin=0,
                fmax=8000
            )

            # Convert to log scale with better reference
            mel_spec = librosa.power_to_db(mel_spec, ref=np.max)

            # Standardize instead of normalize (zero mean, unit variance)
            mean = mel_spec.mean()
            std = mel_spec.std()
            if std > 1e-8:
                mel_spec = (mel_spec - mean) / std

            # Reshape for SpecRNet: [batch, channels, height, width]
            mel_spec = mel_spec[np.newaxis, np.newaxis, :, :]  # Add batch and channel dims

            # Convert to tensor
            tensor = torch.FloatTensor(mel_spec).to(self.device)

            return tensor

        except Exception as e:
            print(f"Error preprocessing audio: {e}")
            raise

    def detect_deepfake(self, audio_bytes: bytes) -> Dict:
        """
        Detect if audio is deepfake using SpecRNet.

        Args:
            audio_bytes: Raw audio bytes

        Returns:
            Detection result with confidence and metrics
        """
        if not self.is_loaded:
            if not self.load_model():
                return {
                    "is_synthetic": False,
                    "confidence": 0.0,
                    "error": "Model failed to load",
                    "model": "SpecRNet"
                }

        try:
            import time
            start_time = time.time()

            # Preprocess audio
            input_tensor = self.preprocess_audio(audio_bytes)

            # Run inference
            with torch.no_grad():
                output = self.model(input_tensor)

            # Get probability (SpecRNet outputs single value in [0,1])
            probability = torch.sigmoid(output).item()

            inference_time = (time.time() - start_time) * 1000  # Convert to ms

            # Use raw probability without adaptive threshold for diagnostic analysis
            # The adaptive threshold may be interfering with score separation
            is_synthetic = probability >= 0.5

            return {
                "is_synthetic": is_synthetic,
                "confidence": probability,
                "inference_time_ms": round(inference_time, 2),
                "model": "SpecRNet",
                "device": self.device,
                "method": "Fast CPU inference"
            }

        except Exception as e:
            print(f"Error in SpecRNet inference: {e}")
            return {
                "is_synthetic": False,
                "confidence": 0.0,
                "error": str(e),
                "model": "SpecRNet"
            }

    def get_model_info(self) -> Dict:
        """Get model information."""
        if not self.is_loaded:
            return {"error": "Model not loaded"}

        try:
            # Count parameters
            param_count = sum(p.numel() for p in self.model.parameters())

            return {
                "model": "SpecRNet",
                "device": self.device,
                "parameters": param_count,
                "is_loaded": True,
                "input_shape": "[batch, 1, 80, 404]",
                "output_shape": "[batch, 1]"
            }
        except Exception as e:
            return {"error": str(e)}


# Global instance
_specrnet_service: Optional[SpecRNetService] = None


def get_specrnet_service() -> SpecRNetService:
    """Get or create global SpecRNet service instance."""
    global _specrnet_service
    if _specrnet_service is None:
        _specrnet_service = SpecRNetService(device="cpu")
        _specrnet_service.load_model()
    return _specrnet_service
