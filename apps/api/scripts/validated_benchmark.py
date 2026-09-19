"""
PhaseGuard Validated Benchmark Script
Follows strict validation requirements - no scoring of failed inferences
"""
import os
import sys
import time
import psutil
import json
import numpy as np
from typing import Dict, List, Tuple
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, roc_curve, confusion_matrix
)
import requests

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class ValidatedBenchmark:
    """Benchmark with strict validation and error handling."""

    def __init__(self):
        """Initialize validated benchmark."""
        self.base_url = "http://localhost:8000"
        self.test_files = self._load_test_dataset()
        self.results = {}

    def _load_test_dataset(self) -> Dict[str, List[str]]:
        """Load test dataset with speaker-disjoint splits."""
        test_files = {
            'human': [
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

    def test_model_via_api(self, model_name: str, file_path: str) -> Dict:
        """Test a model via API endpoint with error handling."""
        try:
            url = f"{self.base_url}/api/v1/detection/audio?model={model_name}"
            with open(file_path, 'rb') as f:
                files = {'audio': f}
                response = requests.post(url, files=files, timeout=30)

            if response.status_code == 200:
                return {
                    'status': 'success',
                    'data': response.json()
                }
            else:
                return {
                    'status': 'error',
                    'error': f"HTTP {response.status_code}",
                    'response': response.text
                }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }

    def run_model_benchmark(self, model_name: str) -> Dict:
        """Run comprehensive benchmark for a single model via API."""
        print(f"\n{'=' * 60}")
        print(f"Benchmarking {model_name} via API")
        print(f"{'=' * 60}")

        # Check model availability
        try:
            health_response = requests.get(f"{self.base_url}/api/v1/detection/health", timeout=10)
            if health_response.status_code != 200:
                print(f"  [X] Health check failed")
                return self._empty_metrics()
        except Exception as e:
            print(f"  [X] Cannot connect to API: {e}")
            return self._empty_metrics()

        health_data = health_response.json()
        print(f"  [OK] API available")
        print(f"  Available models: {health_data.get('available_models', [])}")
        print(f"  Model load counts: {health_data.get('models', {})}")

        # Validate audio files first
        print("\nValidating audio files...")
        from detection.audio_preprocessor import get_audio_preprocessor
        preprocessor = get_audio_preprocessor()

        valid_files = []
        for category, files in self.test_files.items():
            for file_path in files:
                if os.path.exists(file_path):
                    metadata = preprocessor.validate_audio_file(file_path)
                    if metadata['valid']:
                        valid_files.append((file_path, category))
                        print(f"  [OK] {file_path} - Valid")
                    else:
                        print(f"  [X] {file_path} - Invalid: {metadata['error']}")
                else:
                    print(f"  [X] {file_path} - File not found")

        if len(valid_files) == 0:
            print("\n[STOP] No valid audio files - cannot benchmark")
            return self._empty_metrics()

        print(f"\nValid files: {len(valid_files)}/{len(self.test_files['human']) + len(self.test_files['synthetic'])}")

        # Cold latency (first inference)
        print("\nMeasuring cold latency...")
        cold_latencies = []
        for file_path, category in valid_files[:2]:
            start_time = time.time()
            result = self.test_model_via_api(model_name, file_path)
            if result['status'] == 'success':
                cold_latency = (time.time() - start_time) * 1000
                cold_latencies.append(cold_latency)
                print(f"  Cold request: {cold_latency:.2f}ms")

        avg_cold_latency = np.mean(cold_latencies) if cold_latencies else 0

        # Warm latency (multiple inferences)
        print("\nMeasuring warm latency on valid audio files...")
        warm_latencies = []
        memory_usage = []

        all_predictions = []
        all_labels = []
        all_scores = []
        failed_samples = []

        for file_path, category in valid_files:
            label = 1 if category == 'synthetic' else 0

            try:
                # Warm up
                for _ in range(3):
                    self.test_model_via_api(model_name, file_path)

                # Measured runs
                for _ in range(5):
                    start_time = time.time()

                    # Measure memory before
                    process = psutil.Process(os.getpid())
                    mem_before = process.memory_info().rss / (1024 * 1024)

                    # API call
                    result = self.test_model_via_api(model_name, file_path)

                    # Measure memory after
                    mem_after = process.memory_info().rss / (1024 * 1024)
                    latency_ms = (time.time() - start_time) * 1000

                    if result['status'] == 'success':
                        warm_latencies.append(latency_ms)
                        memory_usage.append(mem_after - mem_before)

                        # Collect prediction data
                        data = result['data']
                        spoof_score = data.get('spoof_score', 0.5)
                        is_synthetic = data.get('decision') == 'SYNTHETIC'

                        all_predictions.append(1 if is_synthetic else 0)
                        all_labels.append(label)
                        all_scores.append(spoof_score)
                    else:
                        print(f"  [X] Failed inference: {result['error']}")
                        failed_samples.append({
                            'file': file_path,
                            'label': category,
                            'error': result['error']
                        })

            except Exception as e:
                print(f"  [X] Error processing {file_path}: {e}")
                failed_samples.append({
                    'file': file_path,
                    'label': category,
                    'error': str(e)
                })
                continue

        # Calculate metrics only on successful predictions
        if len(all_predictions) > 0:
            metrics = self._calculate_metrics(all_labels, all_predictions, all_scores)
        else:
            metrics = self._empty_metrics()
            metrics['benchmark_status'] = 'INVALID'

        # Latency statistics
        latencies = np.array(warm_latencies)
        metrics['cold_latency_ms'] = float(avg_cold_latency)
        metrics['warm_avg_latency_ms'] = float(np.mean(latencies)) if len(latencies) > 0 else 0.0
        metrics['warm_p50_latency_ms'] = float(np.percentile(latencies, 50)) if len(latencies) > 0 else 0.0
        metrics['warm_p95_latency_ms'] = float(np.percentile(latencies, 95)) if len(latencies) > 0 else 0.0
        metrics['memory_mb'] = float(np.mean(memory_usage)) if memory_usage else 0.0

        # Add validation statistics
        metrics['total_files'] = len(valid_files)
        metrics['total_inferences'] = len(all_predictions)
        metrics['successful_inferences'] = len(all_predictions)
        metrics['failed_inferences'] = len(failed_samples)
        metrics['failure_rate'] = len(failed_samples) / (len(all_predictions) + len(failed_samples)) if (len(all_predictions) + len(failed_samples)) > 0 else 0.0
        metrics['failed_inference_details'] = failed_samples

        # Determine benchmark validity
        if metrics['failure_rate'] > 0:
            metrics['benchmark_status'] = 'INVALID'
            print(f"\n[WARNING] Benchmark invalid - {len(failed_samples)} samples failed")
        else:
            metrics['benchmark_status'] = 'VALID'
            print(f"\n[OK] Benchmark valid - all samples processed successfully")

        return metrics

    def _calculate_metrics(self, labels: List[int], predictions: List[int], scores: List[float]) -> Dict:
        """Calculate comprehensive metrics with verification."""
        metrics = {}

        try:
            # Basic metrics
            metrics['accuracy'] = float(accuracy_score(labels, predictions))
            metrics['precision'] = float(precision_score(labels, predictions, zero_division=0))
            metrics['recall'] = float(recall_score(labels, predictions, zero_division=0))
            metrics['f1'] = float(f1_score(labels, predictions, zero_division=0))

            # ROC-AUC
            try:
                metrics['roc_auc'] = float(roc_auc_score(labels, scores))
            except:
                metrics['roc_auc'] = 0.5

            # EER
            try:
                fpr, tpr, thresholds = roc_curve(labels, scores)
                eer_idx = np.nanargmin(np.absolute(fpr - (1 - tpr)))
                metrics['eer'] = float(fpr[eer_idx])
                metrics['eer_threshold'] = float(thresholds[eer_idx])
            except:
                metrics['eer'] = 0.5
                metrics['eer_threshold'] = 0.5

            # FAR and FRR
            tn, fp, fn, tp = confusion_matrix(labels, predictions).ravel()
            metrics['far'] = float(fp / (fp + tn)) if (fp + tn) > 0 else 0.0
            metrics['frr'] = float(fn / (fn + tp)) if (fn + tp) > 0 else 0.0

            # Synthetic-specific metrics
            synthetic_recall = metrics['recall']  # Recall for synthetic class
            false_negative_rate = metrics['frr']
            metrics['synthetic_recall'] = synthetic_recall
            metrics['false_negative_rate'] = false_negative_rate

            # Confusion matrix details
            metrics['confusion_matrix'] = {
                'tp': int(tp),
                'tn': int(tn),
                'fp': int(fp),
                'fn': int(fn)
            }

        except Exception as e:
            print(f"Error calculating metrics: {e}")
            return self._empty_metrics()

        return metrics

    def _empty_metrics(self) -> Dict:
        """Return empty metrics when no data available."""
        return {
            'accuracy': 0.0,
            'precision': 0.0,
            'recall': 0.0,
            'f1': 0.0,
            'roc_auc': 0.5,
            'eer': 0.5,
            'eer_threshold': 0.5,
            'far': 0.0,
            'frr': 0.0,
            'synthetic_recall': 0.0,
            'false_negative_rate': 0.0,
            'cold_latency_ms': 0.0,
            'warm_avg_latency_ms': 0.0,
            'warm_p50_latency_ms': 0.0,
            'warm_p95_latency_ms': 0.0,
            'memory_mb': 0.0,
            'total_files': 0,
            'total_inferences': 0,
            'successful_inferences': 0,
            'failed_inferences': 0,
            'failure_rate': 0.0,
            'benchmark_status': 'INVALID',
            'failed_inference_details': []
        }

    def run_benchmark(self):
        """Run comprehensive benchmark for all models."""
        print("=" * 60)
        print("PHASEGUARD VALIDATED BENCHMARK")
        print("=" * 60)

        # Available models via API
        models_to_test = ['specrnet', 'aasist_l']

        # Benchmark each model
        for model_name in models_to_test:
            try:
                self.results[model_name.upper()] = self.run_model_benchmark(model_name)
            except Exception as e:
                print(f"Error benchmarking {model_name}: {e}")
                self.results[model_name.upper()] = self._empty_metrics()

        # Print summary
        print(f"\n{'=' * 60}")
        print("BENCHMARK SUMMARY")
        print(f"{'=' * 60}")

        for model_name, metrics in self.results.items():
            print(f"\n{model_name}:")
            print(f"  Benchmark Status: {metrics['benchmark_status']}")
            print(f"  Total Files: {metrics['total_files']}")
            print(f"  Total Inferences: {metrics['total_inferences']}")
            print(f"  Successful Inferences: {metrics['successful_inferences']}")
            print(f"  Failed Inferences: {metrics['failed_inferences']}")
            print(f"  Failure Rate: {metrics['failure_rate']:.2%}")

            if metrics['benchmark_status'] == 'VALID':
                print(f"  Accuracy: {metrics['accuracy']:.3f}")
                print(f"  Precision: {metrics['precision']:.3f}")
                print(f"  Recall: {metrics['recall']:.3f}")
                print(f"  F1: {metrics['f1']:.3f}")
                print(f"  ROC-AUC: {metrics['roc_auc']:.3f}")
                print(f"  EER: {metrics['eer']:.3f}")
                print(f"  FAR: {metrics['far']:.3f}")
                print(f"  FRR: {metrics['frr']:.3f}")
                print(f"  Synthetic Recall: {metrics['synthetic_recall']:.3f}")
                print(f"  Cold Latency: {metrics['cold_latency_ms']:.2f}ms")
                print(f"  Warm Avg Latency: {metrics['warm_avg_latency_ms']:.2f}ms")
                print(f"  Warm P50 Latency: {metrics['warm_p50_latency_ms']:.2f}ms")
                print(f"  Warm P95 Latency: {metrics['warm_p95_latency_ms']:.2f}ms")
            else:
                print(f"  [INVALID] Cannot report metrics due to failed inferences")

        # Save results
        output = {
            'detailed_results': self.results,
            'methodology': {
                'preprocessing': '16kHz mono float32',
                'validation': 'Strict - failed samples excluded from metrics',
                'scoring': 'Only successful inferences scored',
                'api_version': 'validated'
            }
        }

        with open("validated_benchmark_results.json", "w") as f:
            json.dump(output, f, indent=2)

        print(f"\n{'=' * 60}")
        print("Results saved to validated_benchmark_results.json")
        print(f"{'=' * 60}")

        return output


def main():
    """Main benchmark function."""
    benchmark = ValidatedBenchmark()
    results = benchmark.run_benchmark()
    return results


if __name__ == "__main__":
    main()
