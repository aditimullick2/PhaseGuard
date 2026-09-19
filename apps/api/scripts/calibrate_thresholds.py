"""
Threshold Calibration Script for PhaseGuard Deepfake Detection
Finds optimal thresholds using validation dataset
"""
import numpy as np
import os
import json
from typing import Dict, List, Tuple
import pandas as pd
from sklearn.metrics import roc_curve, auc, confusion_matrix


class ThresholdCalibrator:
    """Calibrate detection thresholds using validation dataset."""

    def __init__(self, validation_scores: List[Tuple[float, int]]):
        """
        Initialize calibrator with validation scores.

        Args:
            validation_scores: List of (spoof_score, label) tuples
                             where label: 0 = real, 1 = synthetic
        """
        self.scores = np.array([score for score, _ in validation_scores])
        self.labels = np.array([label for _, label in validation_scores])

    def find_eer_threshold(self) -> Tuple[float, float]:
        """
        Find Equal Error Rate threshold.

        Returns:
            Tuple of (threshold, eer)
        """
        fpr, tpr, thresholds = roc_curve(self.labels, self.scores)
        eer_idx = np.nanargmin(np.absolute(fpr - (1 - tpr)))
        eer = fpr[eer_idx]
        eer_threshold = thresholds[eer_idx]
        return eer_threshold, eer

    def find_high_recall_threshold(self, target_recall: float = 0.95) -> float:
        """
        Find threshold for high recall (detect most synthetic samples).

        Args:
            target_recall: Target recall rate

        Returns:
            Threshold for target recall
        """
        fpr, tpr, thresholds = roc_curve(self.labels, self.scores)
        idx = np.where(tpr >= target_recall)[0]
        if len(idx) > 0:
            return thresholds[idx[0]]
        return 0.5  # Default

    def find_high_precision_threshold(self, target_precision: float = 0.95) -> float:
        """
        Find threshold for high precision (avoid false positives).

        Args:
            target_precision: Target precision rate

        Returns:
            Threshold for target precision
        """
        fpr, tpr, thresholds = roc_curve(self.labels, self.scores)
        # Precision = TP / (TP + FP)
        for threshold in thresholds:
            predictions = (self.scores >= threshold).astype(int)
            tp = np.sum((predictions == 1) & (self.labels == 1))
            fp = np.sum((predictions == 1) & (self.labels == 0))
            precision = tp / (tp + fp) if (tp + fp) > 0 else 0

            if precision >= target_precision:
                return threshold

        return 0.8  # Default

    def calculate_metrics(self, threshold: float) -> Dict:
        """
        Calculate detection metrics at given threshold.

        Args:
            threshold: Decision threshold

        Returns:
            Dictionary of metrics
        """
        predictions = (self.scores >= threshold).astype(int)

        # Confusion matrix
        tn, fp, fn, tp = confusion_matrix(self.labels, predictions).ravel()

        # Calculate metrics
        far = fp / (fp + tn) if (fp + tn) > 0 else 0  # False Accept Rate
        frr = fn / (fn + tp) if (fn + tp) > 0 else 0  # False Reject Rate
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0

        return {
            "threshold": threshold,
            "far": far,
            "frr": frr,
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "confusion_matrix": {"tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp)}
        }

    def generate_calibration_report(self) -> Dict:
        """
        Generate comprehensive calibration report.

        Returns:
            Calibration report with recommended thresholds
        """
        eer_threshold, eer = self.find_eer_threshold()
        high_recall_threshold = self.find_high_recall_threshold(0.95)
        high_precision_threshold = self.find_high_precision_threshold(0.95)

        eer_metrics = self.calculate_metrics(eer_threshold)
        recall_metrics = self.calculate_metrics(high_recall_threshold)
        precision_metrics = self.calculate_metrics(high_precision_threshold)

        return {
            "eer_threshold": eer_threshold,
            "eer": eer,
            "eer_metrics": eer_metrics,
            "high_recall_threshold": high_recall_threshold,
            "high_recall_metrics": recall_metrics,
            "high_precision_threshold": high_precision_threshold,
            "high_precision_metrics": precision_metrics,
            "recommended_config": {
                "real_threshold": eer_threshold,
                "suspicious_low": eer_threshold,
                "suspicious_high": high_recall_threshold,
                "synthetic_threshold": high_precision_threshold
            }
        }


def load_validation_dataset(dataset_path: str) -> List[Tuple[float, int]]:
    """
    Load validation dataset from CSV manifest.

    Args:
        dataset_path: Path to dataset manifest CSV

    Returns:
        List of (spoof_score, label) tuples
    """
    # This would load from actual dataset
    # For now, return empty list as placeholder
    if os.path.exists(dataset_path):
        print(f"Loading validation dataset from {dataset_path}")
        # TODO: Implement actual CSV loading
        return []
    else:
        print(f"Dataset manifest not found at {dataset_path}")
        return []


def main():
    """Main calibration function."""
    print("PhaseGuard Threshold Calibration")
    print("=" * 50)

    # Load validation dataset
    validation_scores = load_validation_dataset("data/dataset_manifest.csv")

    if not validation_scores:
        print("No validation data available. Using default thresholds.")
        # Return default calibration based on typical deepfake detection
        report = {
            "eer_threshold": 0.5,
            "eer": 0.5,
            "eer_metrics": {},
            "high_recall_threshold": 0.3,
            "high_recall_metrics": {},
            "high_precision_threshold": 0.7,
            "high_precision_metrics": {},
            "recommended_config": {
                "real_threshold": 0.3,
                "suspicious_low": 0.3,
                "suspicious_high": 0.7,
                "synthetic_threshold": 0.7
            },
            "note": "Default thresholds - calibrate with real dataset for production"
        }

        print("\nDefault Configuration:")
        print(f"Real Threshold: {report['recommended_config']['real_threshold']}")
        print(f"Suspicious Range: {report['recommended_config']['suspicious_low']} - {report['recommended_config']['suspicious_high']}")
        print(f"Synthetic Threshold: {report['recommended_config']['synthetic_threshold']}")
    else:
        # Calibrate thresholds
        calibrator = ThresholdCalibrator(validation_scores)
        report = calibrator.generate_calibration_report()

        # Print report
        print("\nCalibration Report:")
        print(f"EER Threshold: {report['eer_threshold']:.3f}")
        print(f"EER: {report['eer']:.3f}")
        print(f"High Recall Threshold: {report['high_recall_threshold']:.3f}")
        print(f"High Precision Threshold: {report['high_precision_threshold']:.3f}")

        print("\nRecommended Configuration:")
        print(json.dumps(report['recommended_config'], indent=2))

    # Save report
    with open("threshold_calibration_report.json", "w") as f:
        json.dump(report, f, indent=2)

    print("\nCalibration report saved to threshold_calibration_report.json")


if __name__ == "__main__":
    main()
