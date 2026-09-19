"""
Unified Detector Interface for PhaseGuard Deepfake Detection
Common interface for all detection models
"""
from abc import ABC, abstractmethod
from typing import Dict, Optional
import numpy as np


class DeepfakeDetector(ABC):
    """Abstract base class for all deepfake detectors."""

    @abstractmethod
    def initialize(self) -> bool:
        """
        Initialize the detector (load model, setup resources).

        Returns:
            True if initialization successful
        """
        pass

    @abstractmethod
    def predict(self, audio: np.ndarray) -> Dict:
        """
        Run prediction on audio array.

        Args:
            audio: Preprocessed audio array (float32, 16kHz, mono)

        Returns:
            Detection result with spoof_score, bonafide_score, decision
        """
        pass

    @abstractmethod
    def predict_stream(self, audio_chunk: np.ndarray) -> Dict:
        """
        Run prediction on streaming audio chunk.

        Args:
            audio_chunk: Audio chunk for streaming detection

        Returns:
            Detection result for the chunk
        """
        pass

    @abstractmethod
    def release(self) -> None:
        """Release detector resources."""
        pass

    @abstractmethod
    def get_info(self) -> Dict:
        """
        Get detector information.

        Returns:
            Detector metadata (model name, parameters, etc.)
        """
        pass


class DetectionResult:
    """Standardized detection result."""

    def __init__(self, spoof_score: float, bonafide_score: float,
                 decision: str, model: str, latency_ms: float,
                 confidence: Optional[float] = None):
        self.spoof_score = spoof_score
        self.bonafide_score = bonafide_score
        self.decision = decision  # REAL, SUSPICIOUS, SYNTHETIC
        self.model = model
        self.latency_ms = latency_ms
        self.confidence = confidence

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "spoof_score": self.spoof_score,
            "bonafide_score": self.bonafide_score,
            "decision": self.decision,
            "model": self.model,
            "latency_ms": self.latency_ms,
            "confidence": self.confidence
        }

    @staticmethod
    def from_dict(data: Dict) -> 'DetectionResult':
        """Create from dictionary."""
        return DetectionResult(
            spoof_score=data.get("spoof_score", 0.0),
            bonafide_score=data.get("bonafide_score", 0.0),
            decision=data.get("decision", "REAL"),
            model=data.get("model", "unknown"),
            latency_ms=data.get("latency_ms", 0),
            confidence=data.get("confidence")
        )


class ThresholdConfig:
    """Configurable thresholds for decision making."""

    def __init__(self, real_threshold: float = 0.11,
                 suspicious_low: float = 0.11,
                 suspicious_high: float = 0.95,
                 synthetic_threshold: float = 0.95):
        """
        Initialize threshold configuration.

        Args:
            real_threshold: Threshold below which audio is classified as REAL
            suspicious_low: Lower bound for SUSPICIOUS range
            suspicious_high: Upper bound for SUSPICIOUS range
            synthetic_threshold: Threshold above which audio is classified as SYNTHETIC

        Note: Thresholds are based on diagnostic benchmark results (AASIST-L optimal ~0.11)
        These should be calibrated with proper validation dataset.
        """
        self.real_threshold = real_threshold
        self.suspicious_low = suspicious_low
        self.suspicious_high = suspicious_high
        self.synthetic_threshold = synthetic_threshold

    def classify(self, spoof_score: float) -> str:
        """
        Classify spoof score into decision.

        Args:
            spoof_score: Spoof probability (0-1)

        Returns:
            Decision: REAL, SUSPICIOUS, or SYNTHETIC
        """
        if spoof_score < self.real_threshold:
            return "REAL"
        elif spoof_score < self.suspicious_high:
            return "SUSPICIOUS"
        else:
            return "SYNTHETIC"


class ScoreAggregator:
    """Rolling score aggregation for streaming detection."""

    def __init__(self, window_size: int = 5, aggregation_method: str = "mean"):
        """
        Initialize score aggregator.

        Args:
            window_size: Number of recent scores to consider
            aggregation_method: mean, median, or ema (exponential moving average)
        """
        self.window_size = window_size
        self.aggregation_method = aggregation_method
        self.scores = []

    def add_score(self, score: float) -> float:
        """
        Add new score and return aggregated score.

        Args:
            score: New spoof score

        Returns:
            Aggregated score
        """
        self.scores.append(score)
        if len(self.scores) > self.window_size:
            self.scores.pop(0)

        return self._aggregate()

    def _aggregate(self) -> float:
        """Aggregate current scores."""
        if not self.scores:
            return 0.0

        if self.aggregation_method == "mean":
            return sum(self.scores) / len(self.scores)
        elif self.aggregation_method == "median":
            sorted_scores = sorted(self.scores)
            return sorted_scores[len(sorted_scores) // 2]
        elif self.aggregation_method == "ema":
            # Simple EMA with alpha=0.5
            alpha = 0.5
            ema = self.scores[0]
            for score in self.scores[1:]:
                ema = alpha * score + (1 - alpha) * ema
            return ema
        else:
            return sum(self.scores) / len(self.scores)

    def get_raw_score(self) -> float:
        """Get the most recent raw score."""
        return self.scores[-1] if self.scores else 0.0

    def get_smoothed_score(self) -> float:
        """Get the aggregated smoothed score."""
        return self._aggregate()

    def reset(self) -> None:
        """Reset the score history."""
        self.scores = []
