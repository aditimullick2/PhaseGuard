"""
Multi-Window Detection Engine
Model-agnostic temporal inference layer for audio deepfake detection
"""
import numpy as np
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum
import time

from .detector_interface import DeepfakeDetector, DetectionResult


class AggregationMethod(Enum):
    """Aggregation methods for window scores."""
    MEAN = "mean"
    MEDIAN = "median"
    MAX = "max"
    MIN = "min"
    PERCENTILE_90 = "percentile_90"
    PERCENTILE_75 = "percentile_75"
    PERCENTILE_25 = "percentile_25"


@dataclass
class WindowConfig:
    """Configuration for window segmentation."""
    window_seconds: float = 3.0
    hop_seconds: float = 1.0
    min_audio_seconds: float = 1.0
    max_audio_seconds: float = 60.0
    max_windows: int = 100

    def __post_init__(self):
        """Validate configuration."""
        if self.window_seconds <= 0:
            raise ValueError("window_seconds must be positive")
        if self.hop_seconds <= 0:
            raise ValueError("hop_seconds must be positive")
        if self.hop_seconds > self.window_seconds:
            raise ValueError("hop_seconds cannot exceed window_seconds")
        if self.min_audio_seconds <= 0:
            raise ValueError("min_audio_seconds must be positive")
        if self.max_audio_seconds < self.min_audio_seconds:
            raise ValueError("max_audio_seconds must be >= min_audio_seconds")
        if self.max_windows <= 0:
            raise ValueError("max_windows must be positive")


@dataclass
class WindowResult:
    """Result for a single window."""
    window_index: int
    start_seconds: float
    end_seconds: float
    duration_seconds: float
    score: float
    decision: str
    model_name: str
    inference_latency_ms: float
    status: str = "success"
    error: Optional[str] = None

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "window_index": self.window_index,
            "start_seconds": self.start_seconds,
            "end_seconds": self.end_seconds,
            "duration_seconds": self.duration_seconds,
            "score": self.score,
            "decision": self.decision,
            "model_name": self.model_name,
            "inference_latency_ms": self.inference_latency_ms,
            "status": self.status,
            "error": self.error
        }


@dataclass
class MultiWindowResult:
    """Result for multi-window detection."""
    model: str
    aggregation: str
    window_count: int
    successful_windows: int
    failed_windows: int
    aggregated_score: float
    windows: List[WindowResult] = field(default_factory=list)
    status: str = "success"
    total_latency_ms: float = 0.0
    window_generation_ms: float = 0.0
    aggregation_ms: float = 0.0
    mean_window_latency_ms: float = 0.0

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "model": self.model,
            "aggregation": self.aggregation,
            "window_count": self.window_count,
            "successful_windows": self.successful_windows,
            "failed_windows": self.failed_windows,
            "aggregated_score": self.aggregated_score,
            "windows": [w.to_dict() for w in self.windows],
            "status": self.status,
            "latency": {
                "total_ms": self.total_latency_ms,
                "window_generation_ms": self.window_generation_ms,
                "aggregation_ms": self.aggregation_ms,
                "mean_window_ms": self.mean_window_latency_ms
            }
        }


class MultiWindowDetector:
    """Model-agnostic multi-window detection engine."""

    def __init__(self,
                 detector: DeepfakeDetector,
                 config: Optional[WindowConfig] = None,
                 aggregation: str = "mean"):
        """
        Initialize multi-window detector.

        Args:
            detector: Underlying detector (AASIST-L, SpecRNet, etc.)
            config: Window configuration
            aggregation: Aggregation method (mean, median, max, min, percentile)
        """
        self.detector = detector
        self.config = config or WindowConfig()
        self.aggregation = aggregation

        # Validate aggregation method
        try:
            AggregationMethod(aggregation)
        except ValueError:
            raise ValueError(f"Invalid aggregation method: {aggregation}")

    def generate_windows(self, audio: np.ndarray, sample_rate: int) -> List[Dict]:
        """
        Generate window segments from audio.

        Args:
            audio: Audio array
            sample_rate: Sample rate in Hz

        Returns:
            List of window specifications
        """
        duration = len(audio) / sample_rate

        # Check minimum duration
        if duration < self.config.min_audio_seconds:
            return []  # Insufficient audio

        # Check maximum duration
        if duration > self.config.max_audio_seconds:
            return []  # Audio too long

        # Calculate window parameters
        window_samples = int(self.config.window_seconds * sample_rate)
        hop_samples = int(self.config.hop_seconds * sample_rate)

        # Generate windows
        windows = []
        window_index = 0

        start_sample = 0
        while start_sample + window_samples <= len(audio):
            end_sample = start_sample + window_samples

            # Check max windows limit
            if window_index >= self.config.max_windows:
                break

            start_seconds = start_sample / sample_rate
            end_seconds = end_sample / sample_rate

            windows.append({
                "window_index": window_index,
                "start_sample": start_sample,
                "end_sample": end_sample,
                "start_seconds": start_seconds,
                "end_seconds": end_seconds,
                "duration_seconds": end_seconds - start_seconds
            })

            start_sample += hop_samples
            window_index += 1

        return windows

    def process_window(self,
                      audio: np.ndarray,
                      window_spec: Dict,
                      sample_rate: int) -> WindowResult:
        """
        Process a single window.

        Args:
            audio: Full audio array
            window_spec: Window specification
            sample_rate: Sample rate

        Returns:
            Window result
        """
        start_sample = window_spec["start_sample"]
        end_sample = window_spec["end_sample"]

        # Extract window
        window_audio = audio[start_sample:end_sample]

        try:
            # Run detector on window
            start_time = time.time()
            result_dict = self.detector.predict(window_audio)
            latency_ms = (time.time() - start_time) * 1000

            # Extract scores
            spoof_score = result_dict.get("spoof_score", 0.5)
            decision = result_dict.get("decision", "REAL")
            model_name = result_dict.get("model", "unknown")

            return WindowResult(
                window_index=window_spec["window_index"],
                start_seconds=window_spec["start_seconds"],
                end_seconds=window_spec["end_seconds"],
                duration_seconds=window_spec["duration_seconds"],
                score=spoof_score,
                decision=decision,
                model_name=model_name,
                inference_latency_ms=latency_ms,
                status="success"
            )

        except Exception as e:
            return WindowResult(
                window_index=window_spec["window_index"],
                start_seconds=window_spec["start_seconds"],
                end_seconds=window_spec["end_seconds"],
                duration_seconds=window_spec["duration_seconds"],
                score=0.0,
                decision="REAL",
                model_name="unknown",
                inference_latency_ms=0.0,
                status="failed",
                error=str(e)
            )

    def aggregate_scores(self, window_results: List[WindowResult]) -> float:
        """
        Aggregate window scores.

        Args:
            window_results: List of window results

        Returns:
            Aggregated score
        """
        # Filter successful windows only
        successful_results = [w for w in window_results if w.status == "success"]

        if not successful_results:
            return 0.5  # No valid windows

        scores = [w.score for w in successful_results]

        if self.aggregation == AggregationMethod.MEAN.value:
            return np.mean(scores)
        elif self.aggregation == AggregationMethod.MEDIAN.value:
            return np.median(scores)
        elif self.aggregation == AggregationMethod.MAX.value:
            return np.max(scores)
        elif self.aggregation == AggregationMethod.MIN.value:
            return np.min(scores)
        elif self.aggregation == AggregationMethod.PERCENTILE_90.value:
            return np.percentile(scores, 90)
        elif self.aggregation == AggregationMethod.PERCENTILE_75.value:
            return np.percentile(scores, 75)
        elif self.aggregation == AggregationMethod.PERCENTILE_25.value:
            return np.percentile(scores, 25)
        else:
            return np.mean(scores)  # Default to mean

    def detect(self, audio: np.ndarray, sample_rate: int = 16000) -> MultiWindowResult:
        """
        Run multi-window detection on audio.

        Args:
            audio: Audio array
            sample_rate: Sample rate in Hz

        Returns:
            Multi-window detection result
        """
        total_start = time.time()

        # Check if detector is initialized
        if not hasattr(self.detector, '_is_initialized') or not self.detector._is_initialized:
            return MultiWindowResult(
                model="unknown",
                aggregation=self.aggregation,
                window_count=0,
                successful_windows=0,
                failed_windows=0,
                aggregated_score=0.5,
                status="detector_not_initialized"
            )

        # Generate windows
        window_gen_start = time.time()
        window_specs = self.generate_windows(audio, sample_rate)
        window_generation_ms = (time.time() - window_gen_start) * 1000

        # Check if windows were generated
        if not window_specs:
            return MultiWindowResult(
                model=self.detector.__class__.__name__,
                aggregation=self.aggregation,
                window_count=0,
                successful_windows=0,
                failed_windows=0,
                aggregated_score=0.5,
                status="insufficient_audio",
                window_generation_ms=window_generation_ms
            )

        # Process each window
        window_results = []
        successful_count = 0
        failed_count = 0
        total_window_latency = 0.0

        for window_spec in window_specs:
            window_result = self.process_window(audio, window_spec, sample_rate)
            window_results.append(window_result)

            if window_result.status == "success":
                successful_count += 1
                total_window_latency += window_result.inference_latency_ms
            else:
                failed_count += 1

        # Aggregate scores
        agg_start = time.time()
        aggregated_score = self.aggregate_scores(window_results)
        aggregation_ms = (time.time() - agg_start) * 1000

        # Calculate latency statistics
        mean_window_latency = total_window_latency / successful_count if successful_count > 0 else 0.0
        total_latency = (time.time() - total_start) * 1000

        # Determine overall status
        if successful_count == 0:
            status = "all_windows_failed"
        elif failed_count > 0:
            status = "partial_success"
        else:
            status = "success"

        return MultiWindowResult(
            model=self.detector.__class__.__name__,
            aggregation=self.aggregation,
            window_count=len(window_results),
            successful_windows=successful_count,
            failed_windows=failed_count,
            aggregated_score=aggregated_score,
            windows=window_results,
            status=status,
            total_latency_ms=total_latency,
            window_generation_ms=window_generation_ms,
            aggregation_ms=aggregation_ms,
            mean_window_latency_ms=mean_window_latency
        )
