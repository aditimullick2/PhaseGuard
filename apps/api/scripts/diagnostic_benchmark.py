"""
PhaseGuard Diagnostic Benchmark
Deep analysis of raw scores, thresholds, and model semantics
"""
import os
import sys
import json
import numpy as np
from typing import Dict, List, Tuple
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, roc_curve, confusion_matrix
)

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.audio_preprocessor import get_audio_preprocessor
from detection.model_manager import get_model_manager


class DiagnosticBenchmark:
    """Diagnostic benchmark for deepfake detection models."""

    def __init__(self):
        """Initialize diagnostic benchmark."""
        self.preprocessor = get_audio_preprocessor()
        self.model_manager = get_model_manager()
        self.test_files = self._load_test_dataset()

    def _load_test_dataset(self) -> Dict[str, List[str]]:
        """Load test dataset with proper labels."""
        test_files = {
            'real': [
                'samples/user_voices/WhatsApp Ptt 2026-09-17 at 23.39.57.ogg',
                'samples/user_voices/freesound_community-shortfilm-voice-56795.mp3',
                'samples/user_voices/universfield-female-voice-good-morning-242169.mp3',
                'samples/user_voices/universfield-are-you-home-voice-clip-323554.mp3',
                'samples/user_voices/originalvo-medieval-gamer-voice-darkness-hunts-us-what-youx27ve-learned-stay-226596.mp3',
                'samples/user_voices/sdking79-man-talking-unintelligibly-1-546038.mp3',
            ],
            'synthetic': [
                'samples/synthetic/ElevenLabs_2026-09-01T15_58_06_Kanika - Warm, Expressive and Natural_pvc_sp100_s50_sb75_se0_m2.mp3',
                'samples/synthetic/hindi_ai_voice.mp3',
                'samples/synthetic/myvoice.mp3.ogg',
                'samples/synthetic/new_ai_voice.mp3',
                'samples/deepfake_test/elevenlabs_sample.mp3',
                'samples/deepfake_test/gtts_sample.mp3',
            ]
        }
        return test_files

    def print_raw_scores(self, model_name: str) -> Dict:
        """Print raw scores for all samples."""
        print(f"\n{'=' * 60}")
        print(f"RAW SCORES: {model_name}")
        print(f"{'=' * 60}")

        detector = self.model_manager.get_model(model_name)
        if detector is None:
            print(f"[X] Model {model_name} not available")
            return {}

        results = {
            'real': [],
            'synthetic': []
        }

        for category, files in self.test_files.items():
            label = 1 if category == 'synthetic' else 0
            print(f"\n{category.upper()} samples:")

            for file_path in files:
                if not os.path.exists(file_path):
                    print(f"  [X] {file_path} - File not found")
                    continue

                try:
                    # Load and preprocess audio
                    audio = self.preprocessor.preprocess_audio_file(file_path)

                    # Get raw prediction
                    result = detector.predict(audio)

                    spoof_score = result.get('spoof_score', 0.5)
                    bonafide_score = result.get('bonafide_score', 0.5)
                    decision = result.get('decision', 'UNKNOWN')

                    # Store result
                    results[category].append({
                        'file': file_path,
                        'label': label,
                        'spoof_score': spoof_score,
                        'bonafide_score': bonafide_score,
                        'decision': decision
                    })

                    print(f"  {os.path.basename(file_path)}:")
                    print(f"    Label: {category} ({label})")
                    print(f"    Spoof Score: {spoof_score:.6f}")
                    print(f"    Bonafide Score: {bonafide_score:.6f}")
                    print(f"    Decision: {decision}")

                except Exception as e:
                    print(f"  [X] {file_path} - Error: {e}")

        return results

    def analyze_score_distributions(self, raw_results: Dict) -> Dict:
        """Analyze score distributions for real vs synthetic."""
        print(f"\n{'=' * 60}")
        print("SCORE DISTRIBUTION ANALYSIS")
        print(f"{'=' * 60}")

        analysis = {}

        for category in ['real', 'synthetic']:
            scores = [r['spoof_score'] for r in raw_results[category]]

            if len(scores) == 0:
                print(f"\n{category.upper()}: No samples")
                continue

            analysis[category] = {
                'count': len(scores),
                'mean': float(np.mean(scores)),
                'median': float(np.median(scores)),
                'std': float(np.std(scores)),
                'min': float(np.min(scores)),
                'max': float(np.max(scores)),
                'range': float(np.max(scores) - np.min(scores))
            }

            print(f"\n{category.upper()} scores (n={len(scores)}):")
            print(f"  Mean: {analysis[category]['mean']:.6f}")
            print(f"  Median: {analysis[category]['median']:.6f}")
            print(f"  Std: {analysis[category]['std']:.6f}")
            print(f"  Min: {analysis[category]['min']:.6f}")
            print(f"  Max: {analysis[category]['max']:.6f}")
            print(f"  Range: {analysis[category]['range']:.6f}")

        return analysis

    def test_score_orientations(self, raw_results: Dict) -> Dict:
        """Test both score orientations (score and 1-score)."""
        print(f"\n{'=' * 60}")
        print("SCORE ORIENTATION TEST")
        print(f"{'=' * 60}")

        # Prepare data
        all_results = raw_results['real'] + raw_results['synthetic']
        labels = [r['label'] for r in all_results]
        scores = [r['spoof_score'] for r in all_results]

        orientation_tests = {}

        # Test orientation 1: higher = more synthetic
        try:
            roc_auc_1 = float(roc_auc_score(labels, scores))
            print(f"\nOrientation 1 (higher = more synthetic):")
            print(f"  ROC-AUC: {roc_auc_1:.6f}")
            orientation_tests['orientation_1'] = {
                'description': 'higher = more synthetic',
                'roc_auc': roc_auc_1
            }
        except Exception as e:
            print(f"  [X] Error: {e}")
            orientation_tests['orientation_1'] = {'error': str(e)}

        # Test orientation 2: higher = more real (1 - score)
        try:
            inverted_scores = [1 - s for s in scores]
            roc_auc_2 = float(roc_auc_score(labels, inverted_scores))
            print(f"\nOrientation 2 (higher = more real):")
            print(f"  ROC-AUC: {roc_auc_2:.6f}")
            orientation_tests['orientation_2'] = {
                'description': 'higher = more real',
                'roc_auc': roc_auc_2
            }
        except Exception as e:
            print(f"  [X] Error: {e}")
            orientation_tests['orientation_2'] = {'error': str(e)}

        # Best orientation
        if 'roc_auc' in orientation_tests['orientation_1'] and 'roc_auc' in orientation_tests['orientation_2']:
            if orientation_tests['orientation_1']['roc_auc'] > orientation_tests['orientation_2']['roc_auc']:
                best = 'orientation_1'
            else:
                best = 'orientation_2'
            print(f"\nBest orientation: {best}")
            orientation_tests['best'] = best

        return orientation_tests

    def threshold_sweep(self, raw_results: Dict) -> Dict:
        """Perform threshold sweep from 0.05 to 0.95."""
        print(f"\n{'=' * 60}")
        print("THRESHOLD SWEEP")
        print(f"{'=' * 60}")

        # Prepare data
        all_results = raw_results['real'] + raw_results['synthetic']
        labels = [r['label'] for r in all_results]
        scores = [r['spoof_score'] for r in all_results]

        sweep_results = []

        for threshold in np.arange(0.05, 0.96, 0.01):
            predictions = [1 if score >= threshold else 0 for score in scores]

            try:
                accuracy = float(accuracy_score(labels, predictions))
                precision = float(precision_score(labels, predictions, zero_division=0))
                recall = float(recall_score(labels, predictions, zero_division=0))
                f1 = float(f1_score(labels, predictions, zero_division=0))

                # Calculate FAR and FRR
                tn, fp, fn, tp = confusion_matrix(labels, predictions).ravel()
                far = float(fp / (fp + tn)) if (fp + tn) > 0 else 0.0
                frr = float(fn / (fn + tp)) if (fn + tp) > 0 else 0.0

                sweep_results.append({
                    'threshold': round(threshold, 2),
                    'accuracy': accuracy,
                    'precision': precision,
                    'recall': recall,
                    'f1': f1,
                    'far': far,
                    'frr': frr,
                    'tp': int(tp),
                    'tn': int(tn),
                    'fp': int(fp),
                    'fn': int(fn)
                })

            except Exception as e:
                continue

        # Find best thresholds
        if sweep_results:
            best_f1 = max(sweep_results, key=lambda x: x['f1'])
            best_recall = max(sweep_results, key=lambda x: x['recall'])
            best_precision = max(sweep_results, key=lambda x: x['precision'])

            print(f"\nBest F1 threshold: {best_f1['threshold']:.2f} (F1={best_f1['f1']:.3f})")
            print(f"Best Recall threshold: {best_recall['threshold']:.2f} (Recall={best_recall['recall']:.3f})")
            print(f"Best Precision threshold: {best_precision['threshold']:.2f} (Precision={best_precision['precision']:.3f})")

        return {
            'sweep_results': sweep_results,
            'best_f1': best_f1 if sweep_results else None,
            'best_recall': best_recall if sweep_results else None,
            'best_precision': best_precision if sweep_results else None
        }

    def verify_labels(self) -> Dict:
        """Verify label mapping."""
        print(f"\n{'=' * 60}")
        print("LABEL VERIFICATION")
        print(f"{'=' * 60}")

        print("\nCurrent label mapping:")
        print("  0 = real")
        print("  1 = synthetic")

        print("\nDataset:")
        print(f"  Real samples: {len(self.test_files['real'])}")
        print(f"  Synthetic samples: {len(self.test_files['synthetic'])}")

        return {
            'label_mapping': {
                '0': 'real',
                '1': 'synthetic'
            },
            'real_count': len(self.test_files['real']),
            'synthetic_count': len(self.test_files['synthetic'])
        }

    def run_diagnostic(self, model_name: str) -> Dict:
        """Run complete diagnostic for a model."""
        print("=" * 60)
        print(f"PHASEGUARD DIAGNOSTIC BENCHMARK: {model_name}")
        print("=" * 60)

        diagnostic_results = {
            'model': model_name,
            'timestamp': None,
            'raw_scores': {},
            'score_distributions': {},
            'orientation_tests': {},
            'threshold_sweep': {},
            'label_verification': {}
        }

        # Step 1: Print raw scores
        raw_results = self.print_raw_scores(model_name)
        diagnostic_results['raw_scores'] = raw_results

        if not raw_results:
            print(f"\n[X] No valid results for {model_name}")
            return diagnostic_results

        # Step 2: Analyze score distributions
        score_analysis = self.analyze_score_distributions(raw_results)
        diagnostic_results['score_distributions'] = score_analysis

        # Step 3: Test score orientations
        orientation_tests = self.test_score_orientations(raw_results)
        diagnostic_results['orientation_tests'] = orientation_tests

        # Step 4: Threshold sweep
        threshold_results = self.threshold_sweep(raw_results)
        diagnostic_results['threshold_sweep'] = threshold_results

        # Step 5: Verify labels
        label_verification = self.verify_labels()
        diagnostic_results['label_verification'] = label_verification

        # Summary
        print(f"\n{'=' * 60}")
        print(f"DIAGNOSTIC SUMMARY: {model_name}")
        print(f"{'=' * 60}")

        if 'best' in orientation_tests:
            print(f"Best score orientation: {orientation_tests['best']}")
            print(f"  ROC-AUC: {orientation_tests[orientation_tests['best']]['roc_auc']:.6f}")

        if threshold_results['best_f1']:
            print(f"Best F1 threshold: {threshold_results['best_f1']['threshold']:.2f}")
            print(f"  F1: {threshold_results['best_f1']['f1']:.3f}")
            print(f"  Recall: {threshold_results['best_f1']['recall']:.3f}")
            print(f"  Precision: {threshold_results['best_f1']['precision']:.3f}")

        return diagnostic_results


def main():
    """Main diagnostic function."""
    diagnostic = DiagnosticBenchmark()

    # Run diagnostics for both models
    results = {}
    for model_name in ['aasist_l', 'specrnet']:
        try:
            results[model_name] = diagnostic.run_diagnostic(model_name)
        except Exception as e:
            print(f"Error running diagnostic for {model_name}: {e}")
            results[model_name] = {'error': str(e)}

    # Save results
    with open("diagnostic_benchmark_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n{'=' * 60}")
    print("Diagnostic results saved to diagnostic_benchmark_results.json")
    print(f"{'=' * 60}")

    return results


if __name__ == "__main__":
    main()
