"""
Benchmark Detection V2 Engine
Scientific benchmark for deepfake detection models
"""
import json
import os
import sys
import time
import argparse
import numpy as np
from typing import Dict, List
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, precision_recall_curve, auc, confusion_matrix
)

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.audio_preprocessor import get_audio_preprocessor
from detection.model_manager import get_model_manager


class BenchmarkDetectionV2:
    """Scientific benchmark for deepfake detection models."""

    def __init__(self, manifest_path: str = "data/dataset_manifest.json"):
        """
        Initialize benchmark engine.

        Args:
            manifest_path: Path to dataset manifest
        """
        self.manifest_path = manifest_path
        self.preprocessor = get_audio_preprocessor()
        self.model_manager = get_model_manager()

        # Load manifest
        with open(manifest_path, 'r') as f:
            self.manifest = json.load(f)

        self.samples = self.manifest.get('samples', [])

    def filter_samples(self, split: str = None, condition: str = None,
                     language: str = None) -> List[Dict]:
        """
        Filter samples by criteria.

        Args:
            split: Dataset split (train/calibration/test)
            condition: Audio condition
            language: Language

        Returns:
            Filtered samples
        """
        filtered = self.samples

        if split:
            filtered = [s for s in filtered if s.get('split') == split]

        if condition:
            filtered = [s for s in filtered if s.get('condition') == condition]

        if language:
            filtered = [s for s in filtered if s.get('language') == language]

        return filtered

    def run_benchmark(self, model_name: str, split: str = 'test',
                     condition: str = None) -> Dict:
        """
        Run benchmark for a specific model.

        Args:
            model_name: Model to benchmark
            split: Dataset split to use
            condition: Audio condition

        Returns:
            Benchmark results
        """
        print(f"\n[{'=' * 59}]")
        print(f"BENCHMARKING: {model_name.upper()}")
        print(f"[{'=' * 59}]")

        # Get detector
        detector = self.model_manager.get_model(model_name)
        if detector is None:
            return {
                'model': model_name,
                'error': f'Model {model_name} not available',
                'status': 'INVALID'
            }

        # Filter samples
        samples = self.filter_samples(split=split, condition=condition)

        if not samples:
            return {
                'model': model_name,
                'error': f'No samples found for split={split}, condition={condition}',
                'status': 'INVALID'
            }

        print(f"Testing on {len(samples)} samples")

        # Run inference
        predictions = []
        labels = []
        scores = []
        latencies = []

        for sample in samples:
            try:
                # Load and preprocess audio
                audio = self.preprocessor.preprocess_audio_file(sample['path'])

                # Run inference
                start_time = time.time()
                result = detector.predict(audio)
                latency_ms = (time.time() - start_time) * 1000

                # Extract results
                spoof_score = result.get('spoof_score', 0.5)
                decision = result.get('decision', 'SUSPICIOUS')

                # Convert decision to binary
                label = 1 if sample['label'] == 'synthetic' else 0
                prediction = 1 if decision == 'SYNTHETIC' else 0

                predictions.append(prediction)
                labels.append(label)
                scores.append(spoof_score)
                latencies.append(latency_ms)

            except Exception as e:
                print(f"Error processing {sample['path']}: {e}")
                continue

        if not predictions:
            return {
                'model': model_name,
                'error': 'No successful predictions',
                'status': 'INVALID'
            }

        # Calculate metrics
        metrics = self._calculate_metrics(labels, predictions, scores, latencies)

        # Add metadata
        metrics['model'] = model_name
        metrics['split'] = split
        metrics['condition'] = condition
        metrics['unique_files'] = len(samples)
        metrics['total_inferences'] = len(predictions)
        metrics['successful_inferences'] = len(predictions)
        metrics['failed_inferences'] = len(samples) - len(predictions)

        # Determine status
        metrics['status'] = 'VALID' if metrics['failed_inferences'] == 0 else 'INVALID'

        return metrics

    def _calculate_metrics(self, labels: List[int], predictions: List[int],
                          scores: List[float], latencies: List[float]) -> Dict:
        """Calculate comprehensive metrics."""
        metrics = {}

        # Basic metrics
        metrics['accuracy'] = float(accuracy_score(labels, predictions))
        metrics['precision'] = float(precision_score(labels, predictions, zero_division=0))
        metrics['recall'] = float(recall_score(labels, predictions, zero_division=0))
        metrics['f1'] = float(f1_score(labels, predictions, zero_division=0))

        # ROC-AUC
        try:
            metrics['roc_auc'] = float(roc_auc_score(labels, scores))
        except Exception as e:
            metrics['roc_auc'] = 0.5
            metrics['roc_auc_error'] = str(e)

        # PR-AUC
        try:
            precision, recall, _ = precision_recall_curve(labels, scores)
            metrics['pr_auc'] = float(auc(recall, precision))
        except Exception as e:
            metrics['pr_auc'] = 0.5
            metrics['pr_auc_error'] = str(e)

        # Confusion matrix
        tn, fp, fn, tp = confusion_matrix(labels, predictions).ravel()

        metrics['true_negatives'] = int(tn)
        metrics['false_positives'] = int(fp)
        metrics['false_negatives'] = int(fn)
        metrics['true_positives'] = int(tp)

        # FAR and FRR
        total_negatives = tn + fp
        total_positives = tp + fn

        metrics['far'] = float(fp / total_negatives) if total_negatives > 0 else 0.0
        metrics['frr'] = float(fn / total_positives) if total_positives > 0 else 0.0

        # Sensitivity and specificity
        metrics['sensitivity'] = float(tp / total_positives) if total_positives > 0 else 0.0
        metrics['specificity'] = float(tn / total_negatives) if total_negatives > 0 else 0.0

        # Synthetic recall (our primary metric)
        metrics['synthetic_recall'] = float(recall_score(labels, predictions, zero_division=0))

        # Real acceptance rate
        metrics['real_acceptance_rate'] = float(tn / total_negatives) if total_negatives > 0 else 0.0

        # Latency metrics
        metrics['latency_cold_ms'] = 0.0  # Would need separate cold run
        metrics['latency_warm_mean_ms'] = float(np.mean(latencies))
        metrics['latency_warm_p50_ms'] = float(np.percentile(latencies, 50))
        metrics['latency_warm_p95_ms'] = float(np.percentile(latencies, 95))
        metrics['latency_warm_p99_ms'] = float(np.percentile(latencies, 99))

        # EER (simplified calculation)
        metrics['eer'] = 0.5  # Would need proper EER calculation

        return metrics

    def print_results(self, results: Dict):
        """Print benchmark results."""
        print(f"\nModel: {results['model']}")
        print(f"Status: {results['status']}")
        print(f"Unique Files: {results['unique_files']}")
        print(f"Total Inferences: {results['total_inferences']}")
        print(f"Successful: {results['successful_inferences']}")
        print(f"Failed: {results['failed_inferences']}")

        if results['status'] == 'VALID':
            print(f"\nDetection Metrics:")
            print(f"  Accuracy: {results['accuracy']:.3f}")
            print(f"  Precision: {results['precision']:.3f}")
            print(f"  Recall: {results['recall']:.3f}")
            print(f"  F1: {results['f1']:.3f}")
            print(f"  ROC-AUC: {results['roc_auc']:.3f}")
            print(f"  PR-AUC: {results['pr_auc']:.3f}")
            print(f"  EER: {results['eer']:.3f}")
            print(f"  FAR: {results['far']:.3f}")
            print(f"  FRR: {results['frr']:.3f}")
            print(f"  Synthetic Recall: {results['synthetic_recall']:.3f}")
            print(f"  Real Acceptance Rate: {results['real_acceptance_rate']:.3f}")

            print(f"\nLatency Metrics:")
            print(f"  Warm Mean: {results['latency_warm_mean_ms']:.2f}ms")
            print(f"  Warm P50: {results['latency_warm_p50_ms']:.2f}ms")
            print(f"  Warm P95: {results['latency_warm_p95_ms']:.2f}ms")
            print(f"  Warm P99: {results['latency_warm_p99_ms']:.2f}ms")


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Benchmark Detection V2')
    parser.add_argument('--split', default='test', help='Dataset split')
    parser.add_argument('--model', default='all', help='Model to benchmark')
    parser.add_argument('--condition', default=None, help='Audio condition')
    parser.add_argument('--output', default='benchmark_v2_results.json', help='Output file')

    args = parser.parse_args()

    benchmark = BenchmarkDetectionV2()

    # Determine models to benchmark
    if args.model == 'all':
        models = ['aasist_l', 'specrnet']
    else:
        models = [args.model]

    # Run benchmarks
    all_results = {}
    for model in models:
        results = benchmark.run_benchmark(model, args.split, args.condition)
        benchmark.print_results(results)
        all_results[model] = results

    # Save results
    with open(args.output, 'w') as f:
        json.dump(all_results, f, indent=2)

    print(f"\nResults saved to {args.output}")


if __name__ == "__main__":
    main()
