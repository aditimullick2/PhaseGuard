"""
Inference Performance Benchmark for PhaseGuard Detection Models
Measures latency, memory usage, and performance characteristics
"""
import time
import psutil
import os
import json
from typing import Dict, List
import numpy as np

# Import real detectors
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.adapters.aasist_l_adapter import AASISTLDetector
from detection.adapters.specrnet_adapter import SpecRNetAdapter
from detection.detector_interface import ThresholdConfig


class InferenceBenchmark:
    """Benchmark inference performance for detection models."""

    def __init__(self, model_name: str):
        """
        Initialize benchmark for a specific model.

        Args:
            model_name: Name of the model to benchmark
        """
        self.model_name = model_name
        self.latencies = []
        self.memory_usage = []

    def benchmark_inference(self, predictor, audio_data: np.ndarray,
                          num_warmup: int = 10, num_measured: int = 100) -> Dict:
        """
        Benchmark inference performance with warmup and measured phases.

        Args:
            predictor: Function that takes audio and returns result
            audio_data: Test audio data
            num_warmup: Number of warmup runs
            num_measured: Number of measured runs

        Returns:
            Benchmark results
        """
        print(f"Benchmarking {self.model_name} with {num_warmup} warmup + {num_measured} measured runs...")

        # Warmup phase
        print(f"  Warmup phase: {num_warmup} runs...")
        for i in range(num_warmup):
            try:
                predictor(audio_data)
            except Exception as e:
                print(f"  Warmup run {i+1} failed: {e}")
                continue

        # Measured phase
        print(f"  Measured phase: {num_measured} runs...")
        for i in range(num_measured):
            start_time = time.time()

            # Measure memory before
            process = psutil.Process(os.getpid())
            mem_before = process.memory_info().rss / (1024 * 1024)  # MB

            try:
                result = predictor(audio_data)
            except Exception as e:
                print(f"  Measured run {i+1} failed: {e}")
                continue

            # Measure memory after
            mem_after = process.memory_info().rss / (1024 * 1024)  # MB
            latency_ms = (time.time() - start_time) * 1000

            self.latencies.append(latency_ms)
            self.memory_usage.append(mem_after - mem_before)

        # Calculate statistics
        if not self.latencies:
            return {"error": "No successful runs"}

        latencies = np.array(self.latencies)
        memory_changes = np.array(self.memory_usage)

        return {
            "model": self.model_name,
            "num_warmup": num_warmup,
            "num_measured": len(self.latencies),
            "avg_latency_ms": float(np.mean(latencies)),
            "p50_latency_ms": float(np.percentile(latencies, 50)),
            "p95_latency_ms": float(np.percentile(latencies, 95)),
            "min_latency_ms": float(np.min(latencies)),
            "max_latency_ms": float(np.max(latencies)),
            "avg_memory_mb": float(np.mean(memory_changes)),
            "peak_memory_mb": float(np.max(memory_changes)),
            "latencies": [float(l) for l in latencies]
        }


def create_aasist_l_predictor(audio_duration: float = 4.0) -> callable:
    """
    Create real AASIST-L predictor.

    Args:
        audio_duration: Duration of audio in seconds

    Returns:
        Predictor function
    """
    sample_rate = 16000
    target_samples = 64600  # AASIST-L expects exactly 64600 samples

    detector = AASISTLDetector()
    detector.initialize()

    def predictor(audio: np.ndarray) -> Dict:
        # AASIST-L handles its own padding/cropping
        return detector.predict(audio)

    return predictor


def create_specrnet_predictor(audio_duration: float = 3.0) -> callable:
    """
    Create real SpecRNet predictor.

    Args:
        audio_duration: Duration of audio in seconds

    Returns:
        Predictor function
    """
    sample_rate = 16000
    num_samples = int(sample_rate * audio_duration)

    detector = SpecRNetAdapter()
    detector.initialize()

    def predictor(audio: np.ndarray) -> Dict:
        # SpecRNet adapter uses bytes internally
        # Convert numpy array to bytes
        audio_bytes = (audio * 32767).astype(np.int16).tobytes()
        return detector.predict(audio)

    return predictor


def main():
    """Main benchmark function."""
    print("PhaseGuard Inference Performance Benchmark (Real Models)")
    print("=" * 60)

    # Create dummy audio data
    sample_rate = 16000
    audio_duration = 4.0  # 4 seconds for AASIST-L
    audio_data = np.random.randn(int(sample_rate * audio_duration)).astype(np.float32)

    # Benchmark real models
    real_models = [
        ("AASIST-L", create_aasist_l_predictor(audio_duration)),
        ("SpecRNet", create_specrnet_predictor(3.0))
    ]

    all_results = {}

    for model_name, predictor in real_models:
        print(f"\nBenchmarking {model_name}...")
        benchmark = InferenceBenchmark(model_name)

        results = benchmark.benchmark_inference(predictor, audio_data, num_warmup=10, num_measured=100)
        all_results[model_name] = results

        # Print results
        if "error" not in results:
            print(f"  Warmup: {results['num_warmup']} runs")
            print(f"  Measured: {results['num_measured']} runs")
            print(f"  Average Latency: {results['avg_latency_ms']:.2f}ms")
            print(f"  P50 Latency: {results['p50_latency_ms']:.2f}ms")
            print(f"  P95 Latency: {results['p95_latency_ms']:.2f}ms")
            print(f"  Min Latency: {results['min_latency_ms']:.2f}ms")
            print(f"  Max Latency: {results['max_latency_ms']:.2f}ms")
            print(f"  Avg Memory: {results['avg_memory_mb']:.2f}MB")
            print(f"  Peak Memory: {results['peak_memory_mb']:.2f}MB")
        else:
            print(f"  Error: {results['error']}")

    # Save results
    with open("benchmark_results.json", "w") as f:
        json.dump(all_results, f, indent=2)

    print("\n" + "=" * 60)
    print("Benchmark results saved to benchmark_results.json")
    print("=" * 60)


if __name__ == "__main__":
    main()
