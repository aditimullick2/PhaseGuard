"""
Model Registry for PhaseGuard Deepfake Detection
Centralized model management and configuration
"""
from enum import Enum
from typing import Dict, Optional
import os


class ModelType(Enum):
    """Available detection models."""
    SPECRNET = "specrnet"
    VOICESHIELD = "voiceshield"
    DSP_BASELINE = "dsp_baseline"
    AASIST_L = "aasist_l"
    AASIST = "aasist"
    RAWNET2 = "rawnet2"
    RAWGAT_ST = "rawgat_st"


class ModelConfig:
    """Configuration for detection models."""

    def __init__(self, model_type: ModelType, name: str, available: bool = True,
                 accuracy: Optional[str] = None, latency_ms: Optional[int] = None,
                 memory_mb: Optional[int] = None, description: str = ""):
        self.model_type = model_type
        self.name = name
        self.available = available
        self.accuracy = accuracy
        self.latency_ms = latency_ms
        self.memory_mb = memory_mb
        self.description = description


class ModelRegistry:
    """Central registry for all detection models."""

    def __init__(self):
        self.models: Dict[ModelType, ModelConfig] = {}
        self._initialize_registry()

    def _initialize_registry(self):
        """Initialize model registry with known models."""
        # Current existing models
        self.models[ModelType.SPECRNET] = ModelConfig(
            ModelType.SPECRNET, "SpecRNet", available=True,
            accuracy="80% (tested)", latency_ms=85, memory_mb=277,
            description="Lightweight CPU model, good human detection"
        )

        self.models[ModelType.VOICESHIELD] = ModelConfig(
            ModelType.VOICESHIELD, "VoiceShield", available=True,
            accuracy="90% (expected, not tested)", latency_ms=2000, memory_mb=262,
            description="TFLite AST model for Android, Windows testing issue"
        )

        self.models[ModelType.DSP_BASELINE] = ModelConfig(
            ModelType.DSP_BASELINE, "DSP Baseline", available=True,
            accuracy="33-67% (tested)", latency_ms=2100, memory_mb=50,
            description="DSP features + 2D CNN, threshold dependent"
        )

        # New models to implement
        self.models[ModelType.AASIST_L] = ModelConfig(
            ModelType.AASIST_L, "AASIST-L", available=True,
            accuracy="23% (tested)", latency_ms=131, memory_mb=None,
            description="Mobile model, ONNX Runtime, 64600 samples input"
        )

        self.models[ModelType.AASIST] = ModelConfig(
            ModelType.AASIST, "AASIST", available=False,
            accuracy="Not tested", latency_ms=None, memory_mb=None,
            description="Stronger backend model, CPU inference"
        )

        self.models[ModelType.RAWNET2] = ModelConfig(
            ModelType.RAWNET2, "RawNet2", available=False,
            accuracy="Not tested", latency_ms=None, memory_mb=None,
            description="Lightweight CNN-RNN, TFLite ready"
        )

        self.models[ModelType.RAWGAT_ST] = ModelConfig(
            ModelType.RAWGAT_ST, "RawGAT-ST", available=False,
            accuracy="Not tested", latency_ms=None, memory_mb=None,
            description="Graph attention network model"
        )

    def get_model(self, model_type: ModelType) -> Optional[ModelConfig]:
        """Get model configuration by type."""
        return self.models.get(model_type)

    def get_available_models(self) -> Dict[ModelType, ModelConfig]:
        """Get all available models."""
        return {k: v for k, v in self.models.items() if v.available}

    def get_mobile_model(self) -> Optional[ModelConfig]:
        """Get recommended mobile model."""
        # Prefer AASIST-L if available, else VoiceShield
        if self.models[ModelType.AASIST_L].available:
            return self.models[ModelType.AASIST_L]
        elif self.models[ModelType.VOICESHIELD].available:
            return self.models[ModelType.VOICESHIELD]
        return None

    def get_backend_model(self) -> Optional[ModelConfig]:
        """Get recommended backend model."""
        # Prefer AASIST if available, else SpecRNet
        if self.models[ModelType.AASIST].available:
            return self.models[ModelType.AASIST]
        elif self.models[ModelType.SPECRNET].available:
            return self.models[ModelType.SPECRNET]
        return None

    def update_model_status(self, model_type: ModelType, available: bool,
                          accuracy: Optional[str] = None, latency_ms: Optional[int] = None):
        """Update model status after testing."""
        if model_type in self.models:
            self.models[model_type].available = available
            if accuracy is not None:
                self.models[model_type].accuracy = accuracy
            if latency_ms is not None:
                self.models[model_type].latency_ms = latency_ms


# Global model registry instance
_model_registry: Optional[ModelRegistry] = None


def get_model_registry() -> ModelRegistry:
    """Get or create global model registry instance."""
    global _model_registry
    if _model_registry is None:
        _model_registry = ModelRegistry()
    return _model_registry
