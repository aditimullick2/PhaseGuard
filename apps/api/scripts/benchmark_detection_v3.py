"""
Phase 4 Benchmark Detection V3
Scientific benchmark with full 3J/3K/3M integration
"""
import json
import os
import sys
import time
import argparse
import numpy as np
from typing import Dict, List
from collections import defaultdict

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.audio_preprocessor import get_audio_preprocessor
from detection.model_manager import get_model_manager
from detection.multi_window import MultiWindowDetector, WindowConfig, AggregationMethod
from detection.temporal_stability import TemporalStabilityLayer, TemporalConfig
from detection.risk_decision import RiskDecisionLayer, RiskDecisionConfig


class BenchmarkDetectionV3:
    """Scientific benchmark with full 3J/3K/3M integration."""

    def __init__(self, manifest_path: str = "data/manifests/master_manifest.json",
                 mode: str = "regression"):
        """
        Initialize benchmark engine.

        Args:
            manifest_path: Path to dataset manifest
            mode: "regression" or "scientific"
        """
        self.manifest_path = manifest_path
        self.mode = mode
        self.preprocessor = get_audio_preprocessor()
        self.model_manager = get_model_manager()

        # Load manifest
        self.manifest = None
        self.samples = []
        if os.path.exists(manifest_path):
            with open(manifest_path, 'r') as f:
                self.manifest = json.load(f)
            self.samples = self.manifest.get('samples', [])

        # Initialize 3J/3K/3M layers
        self.multi_window = None
        self.temporal = None
        self.risk_decision = None

    def initialize_layers(self):
        """Initialize 3J/3K/3M layers."""
        # Phase 3J
        window_config = WindowConfig(
            window_seconds=3.0,
            hop_seconds=1.0,
            min_audio_seconds=1.0,
            max_audio_seconds=60.0,
            max_windows=100
        )
        self.multi_window = MultiWindowDetector(
            window_config=window_config,
            aggregation=AggregationMethod.MEAN
        )

        # Phase 3K
        temporal_config = TemporalConfig()
        self.temporal = TemporalStabilityLayer(temporal_config)

        # Phase 3M
        risk_config = RiskDecisionConfig()
        self.risk_decision = RiskDecisionLayer(risk_config)

    def benchmark_sample(self, sample: Dict) -> Dict:
        """
        Benchmark a single sample through full pipeline.

        Args:
            sample: Sample metadata

        Returns:
            Benchmark result
        """
        sample_id = sample.get('sample_id', 'unknown')
        file_path = sample.get('file_path')
        label = sample.get('label')

        result = {
            "sample_id": sample_id,
            "label": label,
            "speaker_id": sample.get('speaker_id'),
            "language": sample.get('language'),
            "generator": sample.get('generator'),
            "condition": sample.get('condition'),
            "split": sample.get('split'),
            "status": "unknown",
            "number_of_windows": 0,
            "valid_windows": 0,
            "failed_windows": 0,
            "aggregated_score": None,
            "temporal_state": None,
            "risk_decision": None,
            "confidence": None,
            "decision_reason": None,
            "total_latency_ms": 0,
            "preprocessing_latency_ms": 0,
            "inference_latency_ms": 0,
            "postprocessing_latency_ms": 0,
            "window_results": [],
            "error": None
        }

        try:
            # Load audio
            full_path = os.path.join(os.path.dirname(self.manifest_path), file_path)
            if not os.path.exists(full_path):
                result["status"] = "file_not_found"
                result["error"] = f"File not found: {full_path}"
                return result

            audio_start = time.time()
            audio = self.preprocessor.load_audio(full_path)
            if audio is None:
                result["status"] = "audio_load_failed"
                result["error"] = "Failed to load audio"
                return result

            preprocessing_latency_ms = (time.time() - audio_start) * 1000

            # Get detector
            detector = self.model_manager.get_model("AASIST-L")
            if not detector:
                result["status"] = "detector_not_available"
                result["error"] = "AASIST-L detector not available"
                return result

            # Run through 3J/3K/3M pipeline
            multi_window_start = time.time()
            multi_window_result = self.multi_window.detect(audio, detector)
            multi_window_latency_ms = (time.time() - multi_window_start) * 1000

            if multi_window_result.status in ["insufficient_audio", "detector_not_initialized", "all_windows_failed"]:
                result["status"] = multi_window_result.status
                result["error"] = f"Multi-window failed: {multi_window_result.status}"
                result["preprocessing_latency_ms"] = preprocessing_latency_ms
                result["inference_latency_ms"] = multi_window_latency_ms
                return result

            # Phase 3K
            temporal_start = time.time()
            temporal_result = self.temporal.process_multi_window_result(multi_window_result)
            temporal_latency_ms = (time.time() - temporal_start) * 1000

            # Phase 3M
            decision_start = time.time()
            risk_result = self.risk_decision.make_decision(temporal_result)
            decision_latency_ms = (time.time() - decision_start) * 1000

            # Extract window results
            window_results = []
            for wr in multi_window_result.windows:
                window_results.append({
                    "window_index": wr.window_index,
                    "start_seconds": wr.start_seconds,
                    "end_seconds": wr.end_seconds,
                    "score": wr.score,
                    "status": wr.status,
                    "latency_ms": wr.inference_latency_ms,
                    "error": wr.error
                })

            # Compile result
            result["status"] = "success"
            result["number_of_windows"] = multi_window_result.window_count
            result["valid_windows"] = multi_window_result.successful_windows
            result["failed_windows"] = multi_window_result.failed_windows
            result["aggregated_score"] = multi_window_result.aggregated_score
            result["temporal_state"] = temporal_result.state.value
            result["risk_decision"] = risk_result.risk_decision.value
            result["confidence"] = risk_result.confidence
            result["decision_reason"] = risk_result.decision_reason.value
            result["total_latency_ms"] = preprocessing_latency_ms + multi_window_latency_ms + temporal_latency_ms + decision_latency_ms
            result["preprocessing_latency_ms"] = preprocessing_latency_ms
            result["inference_latency_ms"] = multi_window_latency_ms
            result["postprocessing_latency_ms"] = temporal_latency_ms + decision_latency_ms
            result["window_results"] = window_results

        except Exception as e:
            result["status"] = "error"
            result["error"] = str(e)

        return result

    def benchmark(self, split: str = None) -> Dict:
        """
        Run benchmark on dataset.

        Args:
            split: Dataset split to benchmark

        Returns:
            Benchmark results
        """
        print("=" * 70)
        print(f"PHASE 4 BENCHMARK V3 - MODE: {self.mode.upper()}")
        print("=" * 70)

        if not self.samples:
            return {
                "status": "blocked",
                "message": "No samples in manifest",
                "mode": self.mode,
                "samples": []
            }

        # Filter samples
        if split:
            samples = [s for s in self.samples if s.get('split') == split]
        else:
            samples = self.samples

        print(f"Running benchmark on {len(samples)} samples")

        # Initialize layers
        self.initialize_layers()

        # Benchmark each sample
        results = []
        for sample in samples:
            result = self.benchmark_sample(sample)
            results.append(result)
            print(f"  {sample.get('sample_id', 'unknown')}: {result['status']}")

        # Calculate metrics if in scientific mode and data permits
        metrics = self._calculate_metrics(results) if self.mode == "scientific" else {}

        return {
            "status": "success",
            "mode": self.mode,
            "split": split,
            "total_samples": len(samples),
            "results": results,
            "metrics": metrics
        }

    def _calculate_metrics(self, results: List[Dict]) -> Dict:
        """
        Calculate metrics from benchmark results.

        Args:
            results: Benchmark results

        Returns:
            Metrics dictionary
        """
        # Filter successful results with valid labels
        valid_results = [r for r in results if r['status'] == 'success' and r['label'] in ['real', 'synthetic']]

        if not valid_results:
            return {
                "note": "No valid results for metrics calculation"
            }

        # Check if both classes present
        labels = [r['label'] for r in valid_results]
        real_count = labels.count('real')
        synthetic_count = labels.count('synthetic')

        if real_count == 0 or synthetic_count == 0:
            return {
                "note": f"Metrics require both classes (real: {real_count}, synthetic: {synthetic_count})"
            }

        # Calculate confusion matrix
        tp = sum(1 for r in valid_results if r['label'] == 'synthetic' and r['risk_decision'] == 'HIGH_RISK')
        tn = sum(1 for r in valid_results if r['label'] == 'real' and r['risk_decision'] == 'SAFE')
        fp = sum(1 for r in valid_results if r['label'] == 'real' and r['risk_decision'] == 'HIGH_RISK')
        fn = sum(1 for r in valid_results if r['label'] == 'synthetic' and r['risk_decision'] == 'SAFE')

        # Calculate metrics
        total = tp + tn + fp + fn
        accuracy = (tp + tn) / total if total > 0 else 0
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0
        fnr = fn / (fn + tp) if (fn + tp) > 0 else 0

        return {
            "confusion_matrix": {"tp": tp, "tn": tn, "fp": fp, "fn": fn},
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "fpr": fpr,
            "fnr": fnr,
            "real_count": real_count,
            "synthetic_count": synthetic_count
        }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Phase 4 Benchmark Detection V3")
    parser.add_argument("--manifest", default="data/manifests/master_manifest.json",
                       help="Path to dataset manifest")
    parser.add_argument("--mode", choices=["regression", "scientific"], default="regression",
                       help="Benchmark mode")
    parser.add_argument("--split", choices=["train", "calibration", "test"],
                       help="Dataset split to benchmark")
    args = parser.parse_args()

    # Check for scientific mode requirements
    if args.mode == "scientific" and args.split == "test":
        print("ERROR: Cannot use test set for calibration in scientific mode")
        sys.exit(1)

    benchmark = BenchmarkDetectionV3(args.manifest, args.mode)
    results = benchmark.benchmark(args.split)

    # Save results
    output_dir = "data/reports"
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, f"benchmark_v3_{args.mode}_{args.split}.json")
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to: {output_file}")
    print(f"Status: {results['status']}")
    print(f"Mode: {results['mode']}")
    print(f"Total samples: {results['total_samples']}")

    if results['status'] == 'success' and 'metrics' in results and results['metrics']:
        metrics = results['metrics']
        print("\nMetrics:")
        for key, value in metrics.items():
            if key not in ['confusion_matrix']:
                print(f"  {key}: {value}")

    sys.exit(0)


if __name__ == "__main__":
    main()
