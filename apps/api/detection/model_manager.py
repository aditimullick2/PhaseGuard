"""
Model Manager for PhaseGuard Detection
Singleton pattern to load models once and reuse them
"""
import os
from typing import Dict, Optional
from .adapters.aasist_l_adapter import AASISTLDetector
from .adapters.specrnet_adapter import SpecRNetAdapter
from .detector_interface import ThresholdConfig


class ModelManager:
    """Singleton manager for detection models."""

    _instance: Optional['ModelManager'] = None
    _models: Dict[str, object] = {}
    _load_counts: Dict[str, int] = {}
    _is_initialized = False

    def __new__(cls):
        """Implement singleton pattern."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """Initialize model manager."""
        # Force reinitialization for testing fixes
        if not self._is_initialized:
            self._initialize_models()

    def force_reload(self):
        """Force reload all models (for testing)."""
        print("[MODEL RELOAD] Forcing model reload...")
        self._models.clear()
        self._load_counts.clear()
        self._is_initialized = False
        self._initialize_models()

    def _initialize_models(self):
        """Initialize all models once at startup."""
        print("[MODEL INIT] Initializing PhaseGuard Model Manager...")

        threshold_config = ThresholdConfig()

        # Initialize AASIST-L
        print("[MODEL INIT] Loading AASIST-L...")
        try:
            aasist_l = AASISTLDetector(threshold_config=threshold_config)
            if aasist_l.initialize():
                self._models['aasist_l'] = aasist_l
                self._load_counts['aasist_l'] = 1
                print("[MODEL INIT] AASIST-L loaded successfully (load_count=1)")
            else:
                print("[MODEL INIT] AASIST-L failed to initialize")
        except Exception as e:
            print(f"[MODEL INIT] AASIST-L error: {e}")

        # Initialize SpecRNet
        print("[MODEL INIT] Loading SpecRNet...")
        try:
            specrnet = SpecRNetAdapter(threshold_config=threshold_config)
            if specrnet.initialize():
                self._models['specrnet'] = specrnet
                self._load_counts['specrnet'] = 1
                print("[MODEL INIT] SpecRNet loaded successfully (load_count=1)")
            else:
                print("[MODEL INIT] SpecRNet failed to initialize")
        except Exception as e:
            print(f"[MODEL INIT] SpecRNet error: {e}")

        self._is_initialized = True
        print(f"[MODEL INIT] Model Manager initialized. Available models: {list(self._models.keys())}")

    def get_model(self, model_name: str):
        """Get cached model instance."""
        model_key = model_name.lower()
        if model_key in self._models:
            print(f"[MODEL REQUEST] Using cached {model_name} session")
            return self._models[model_key]
        else:
            print(f"[MODEL REQUEST] Model {model_name} not available")
            return None

    def get_load_count(self, model_name: str) -> int:
        """Get number of times model was loaded (should be 1)."""
        return self._load_counts.get(model_name.lower(), 0)

    def get_status(self) -> Dict:
        """Get model manager status."""
        return {
            "is_initialized": self._is_initialized,
            "available_models": list(self._models.keys()),
            "load_counts": self._load_counts,
            "models": {
                name: {
                    "available": True,
                    "load_count": count
                }
                for name, count in self._load_counts.items()
            }
        }


# Global instance
_model_manager: Optional[ModelManager] = None


def get_model_manager() -> ModelManager:
    """Get or create global model manager instance."""
    global _model_manager
    if _model_manager is None:
        _model_manager = ModelManager()
    return _model_manager
