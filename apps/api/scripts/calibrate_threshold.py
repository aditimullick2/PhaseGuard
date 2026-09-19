"""
Threshold Calibration Framework
Calibrates detection thresholds using calibration dataset only
"""
import json
import os
import sys
import numpy as np
from typing import Dict, List
from sklearn.metrics import (
    precision_score, recall_score, f1_score,
    confusion_matrix, roc_curve
)

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.audio_preprocessor import get_audio_preprocessor
from detection.model_manager import get_model_manager


class ThresholdCalibrator:
    """Calibrates detection thresholds using calibration dataset."""

    def __init__(self, manifest_path: str = "data/dataset_manifest.json"):
        """
        Initialize threshold calibrator.

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

    def calibrate_model(self, model_name: str, split: str = 'calibration',
                      condition: str = None) -> Dict:
        """
        Calibrate thresholds for a specific model.

        Args:
            model_name: Model to calibrate
            split: Dataset split (should be 'calibration')
            condition: Audio condition

        Returns:
            Calibration results
        """
        print(f"\n[{'=' * 59}]")
        print(f"CALIBRATING: {model_name.upper()}")
        print(f"[{'=' * 59}]")

        # Validate split
        if split == 'test':
            print("⚠️  WARNING: Using test set for calibration is not recommended!")
            print("Use --force to override")

        # Get detector
        detector = self.model_manager.get_model(model_name)
        if detector is None:
            return {
                'model': model_name,
                'error': f'Model {model_name} not available',
                'status': 'INVALID'
            }

        # Filter samples
        samples = [s for s in self.samples if s.get('split') == split]
        if condition:
            samples = [s for s in samples if s.get('condition') == condition]

        if not samples:
            return {
                'model': model_name,
                'error': f'No samples found for split={split}, condition={condition}',
                'status': 'INVALID'
            }

        print(f"Calibrating on {len(samples)} samples")

        # Collect scores and labels
        scores = []
        labels = []

        for sample in samples:
            try:
                # Load and preprocess audio
                audio = self.preprocessor.preprocess_audio_file(sample['path'])

                # Run inference
                result = detector.predict(audio)
                spoof_score = result.get('spoof_score', 0.5)

                label = 1 if sample['label'] == 'synthetic' else 0

                scores.append(spoof_score)
                labels.append(label)

            except Exception as e:
                print(f"Error processing {sample['path']}: {e}")
                continue

        if not scores:
            return {
                'model': model_name,
                'error': 'No successful predictions',
                'status': 'INVALID'
            }

        # Perform threshold sweep
        calibration_results = self._threshold_sweep(scores, labels)

        # Add metadata
        calibration_results['model'] = model_name
        calibration_results['split'] = split
        calibration_results['condition'] = condition
        calibration_results['calibration_samples'] = len(scores)
        calibration_results['status'] = 'VALID'

        return calibration_results

    def _threshold_sweep(self, scores: List[float], labels: List[int]) -> Dict:
        """
        Perform threshold sweep from 0.01 to 0.99.

        Args:
            scores: Spoof scores
            labels: Ground truth labels

        Returns:
            Calibration results
        """
        results = {
            'threshold_candidates': []
        }

        # Threshold sweep
        for threshold in np.arange(0.01, 0.99, 0.01):
            predictions = [1 if score >= threshold else 0 for score in scores]

            try:
                precision = float(precision_score(labels, predictions, zero_division=0))
                recall = float(recall_score(labels, predictions, zero_division=0))
                f1 = float(f1_score(labels, predictions, zero_division=0))

                tn, fp, fn, tp = confusion_matrix(labels, predictions).ravel()

                far = float(fp / (fp + tn)) if (fp + tn) > 0 else 0.0
                frr = float(fn / (fn + tp)) if (fn + tp) > 0 else 0.0

                balanced_accuracy = float((recall + (tn / (tn + fp))) / 2) if (tn + fp) > 0 else 0.0

                # Youden's J statistic
                youden_j = recall + (tn / (tn + fp)) - 1 if (tn + fp) > 0 else 0.0

                results['threshold_candidates'].append({
                    'threshold': round(threshold, 2),
                    'precision': precision,
                    'recall': recall,
                    'f1': f1,
                    'far': far,
                    'frr': frr,
                    'balanced_accuracy': balanced_accuracy,
                    'youden_j': youden_j
                })

            except Exception as e:
                continue

        # Find optimal thresholds by different criteria
        if results['threshold_candidates']:
            best_f1 = max(results['threshold_candidates'], key=lambda x: x['f1'])
            best_recall = max(results['threshold_candidates'], key=lambda x: x['recall'])
            best_precision = max(results['threshold_candidates'], key=lambda x: x['precision'])
            best_youden_j = max(results['threshold_candidates'], key=lambda x: x['youden_j'])
            best_balanced = max(results['threshold_candidates'], key=lambda x: x['balanced_accuracy'])

            results['best_f1'] = best_f1
            results['best_recall'] = best_recall
            results['best_precision'] = best_precision
            results['best_youden_j'] = best_youden_j
            results['best_balanced_accuracy'] = best_balanced

        return results

    def print_results(self, results: Dict):
        """Print calibration results."""
        print(f"\nModel: {results['model']}")
        print(f"Status: {results['status']}")
        print(f"Calibration Samples: {results['calibration_samples']}")

        if results['status'] == 'VALID':
            print(f"\nOptimal Thresholds:")

            if 'best_f1' in results:
                print(f"  Best F1 (threshold={results['best_f1']['threshold']:.2f}):")
                print(f"    F1: {results['best_f1']['f1']:.3f}")
                print(f"    Precision: {results['best_f1']['precision']:.3f}")
                print(f"    Recall: {results['best_f1']['recall']:.3f}")

            if 'best_recall' in results:
                print(f"  Best Recall (threshold={results['best_recall']['threshold']:.2f}):")
                print(f"    Recall: {results['best_recall']['recall']:.3f}")
                print(f"    F1: {results['best_recall']['f1']:.3f}")

            if 'best_precision' in results:
                print(f"  Best Precision (threshold={results['best_precision']['threshold']:.2f}):")
                print(f"    Precision: {results['best_precision']['precision']:.3f}")
                print(f"    F1: {results['best_precision']['f1']:.3f}")


def main():
    """Main function."""
    import argparse

    parser = argparse.ArgumentParser(description='Threshold Calibration')
    parser.add_argument('--model', default='aasist_l', help='Model to calibrate')
    parser.add_argument('--split', default='calibration', help='Dataset split')
    parser.add_argument('--condition', default=None, help='Audio condition')
    parser.add_argument('--force', action='store_true', help='Force test set calibration')
    parser.add_argument('--output', default='threshold_calibration_results.json', help='Output file')

    args = parser.parse_args()

    # Warn about test set calibration
    if args.split == 'test' and not args.force:
        print("ERROR: Cannot use test set for calibration without --force")
        return

    calibrator = ThresholdCalibrator()
    results = calibrator.calibrate_model(args.model, args.split, args.condition)
    calibrator.print_results(results)

    # Save results
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\nCalibration results saved to {args.output}")


if __name__ == "__main__":
    main()
