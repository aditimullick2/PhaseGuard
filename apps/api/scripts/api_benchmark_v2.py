"""
PhaseGuard Detection Benchmark v2 - API Version
Comprehensive benchmark using API endpoints for reliable testing
"""
import time
import psutil
import os
import json
import requests
import numpy as np
from typing import Dict, List, Tuple
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, roc_curve, confusion_matrix
)


class APIBenchmark:
    """Benchmark using API endpoints for reliable testing."""

    def __init__(self):
        """Initialize API benchmark."""
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
        """Test a model via API endpoint."""
        try:
            url = f"{self.base_url}/api/v1/detection/audio?model={model_name}"
            with open(file_path, 'rb') as f:
                files = {'audio': f}
                response = requests.post(url, files=files, timeout=30)

            if response.status_code == 200:
                return response.json()
            else:
                return {'error': f"HTTP {response.status_code}"}
        except Exception as e:
            return {'error': str(e)}

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

        print("  [OK] API available")

        # Cold latency (first inference)
        print("Measuring cold latency...")
        cold_latencies = []
        for file_path in self.test_files['human'][:2]:
            if os.path.exists(file_path):
                start_time = time.time()
                result = self.test_model_via_api(model_name, file_path)
                if 'error' not in result:
                    cold_latency = (time.time() - start_time) * 1000
                    cold_latencies.append(cold_latency)

        avg_cold_latency = np.mean(cold_latencies) if cold_latencies else 0

        # Warm latency (multiple inferences)
        print("Measuring warm latency on real audio files...")
        warm_latencies = []
        memory_usage = []

        all_predictions = []
        all_labels = []
        all_scores = []

        for category, files in self.test_files.items():
            label = 1 if category == 'synthetic' else 0

            for file_path in files:
                if not os.path.exists(file_path):
                    continue

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

                        if 'error' not in result:
                            warm_latencies.append(latency_ms)
                            memory_usage.append(mem_after - mem_before)

                            # Collect prediction data
                            spoof_score = result.get('spoof_score', 0.5)
                            is_synthetic = result.get('decision') == 'SYNTHETIC'

                            all_predictions.append(1 if is_synthetic else 0)
                            all_labels.append(label)
                            all_scores.append(spoof_score)

                except Exception as e:
                    print(f"  Error processing {file_path}: {e}")
                    continue

        # Calculate metrics
        if len(all_predictions) > 0:
            metrics = self._calculate_metrics(all_labels, all_predictions, all_scores)
        else:
            metrics = self._empty_metrics()

        # Latency statistics
        latencies = np.array(warm_latencies)
        metrics['cold_latency_ms'] = float(avg_cold_latency)
        metrics['warm_avg_latency_ms'] = float(np.mean(latencies)) if len(latencies) > 0 else 0.0
        metrics['warm_p50_latency_ms'] = float(np.percentile(latencies, 50)) if len(latencies) > 0 else 0.0
        metrics['warm_p95_latency_ms'] = float(np.percentile(latencies, 95)) if len(latencies) > 0 else 0.0
        metrics['memory_mb'] = float(np.mean(memory_usage)) if memory_usage else 0.0

        return metrics

    def _calculate_metrics(self, labels: List[int], predictions: List[int], scores: List[float]) -> Dict:
        """Calculate comprehensive metrics."""
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
            'memory_mb': 0.0
        }

    def rank_models(self) -> List[Tuple[str, float]]:
        """Rank models based on multiple criteria."""
        rankings = []

        for model_name, metrics in self.results.items():
            # Calculate composite score
            synthetic_recall = metrics.get('synthetic_recall', 0.0)
            fnr = metrics.get('false_negative_rate', 1.0)
            eer = metrics.get('eer', 1.0)
            latency = metrics.get('warm_avg_latency_ms', 1000) / 1000

            # Composite score (higher is better)
            composite_score = (
                synthetic_recall * 0.4 +
                (1 - fnr) * 0.3 +
                (1 - eer) * 0.2 +
                (1 / (1 + latency)) * 0.1
            )

            rankings.append((model_name, composite_score))

        rankings.sort(key=lambda x: x[1], reverse=True)
        return rankings

    def run_benchmark(self):
        """Run comprehensive benchmark for all models."""
        print("=" * 60)
        print("PHASEGUARD DETECTION BENCHMARK V2 - API VERSION")
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

        # Rank models
        rankings = self.rank_models()

        # Print summary
        print(f"\n{'=' * 60}")
        print("BENCHMARK SUMMARY")
        print(f"{'=' * 60}")

        print("\nModel Rankings (based on composite score):")
        for rank, (model_name, score) in enumerate(rankings, 1):
            print(f"{rank}. {model_name}: {score:.3f}")

        print(f"\nDetailed Results:")
        for model_name, metrics in self.results.items():
            print(f"\n{model_name}:")
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
            print(f"  Memory: {metrics['memory_mb']:.2f}MB")

        # Save results
        output = {
            'rankings': [(name, float(score)) for name, score in rankings],
            'detailed_results': self.results,
            'methodology': {
                'preprocessing': '16kHz mono float32',
                'test_files': len(self.test_files['human']) + len(self.test_files['synthetic']),
                'human_files': len(self.test_files['human']),
                'synthetic_files': len(self.test_files['synthetic']),
                'ranking_criteria': ['synthetic_recall', 'false_negative_rate', 'eer', 'latency', 'memory'],
                'api_version': 'v2'
            }
        }

        with open("api_benchmark_v2_results.json", "w") as f:
            json.dump(output, f, indent=2)

        print(f"\n{'=' * 60}")
        print("Results saved to api_benchmark_v2_results.json")
        print(f"{'=' * 60}")

        return output


def main():
    """Main benchmark function."""
    benchmark = APIBenchmark()
    results = benchmark.run_benchmark()
    return results


if __name__ == "__main__":
    main()
