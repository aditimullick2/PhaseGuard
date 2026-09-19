"""
SpecRNet Diagnostic Script
Investigates score collapse and preprocessing issues
"""
import numpy as np
import torch
import librosa
import io
import soundfile as sf
import json
import sys
import os
from typing import Dict, List
import time

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.specrnet_service import SpecRNetService


class SpecRNetDiagnostics:
    """Diagnostic investigation of SpecRNet pipeline."""

    def __init__(self):
        """Initialize diagnostics."""
        self.service = SpecRNetService(device="cpu")
        self.service.load_model()
        self.results = []

    def load_audio_file(self, file_path: str) -> np.ndarray:
        """Load audio file."""
        audio, sr = librosa.load(file_path, sr=16000, mono=True)
        return audio, sr

    def audio_to_bytes(self, audio: np.ndarray, sr: int = 16000) -> bytes:
        """Convert audio array to WAV bytes."""
        with io.BytesIO() as buffer:
            sf.write(buffer, audio, sr, format='WAV')
            return buffer.getvalue()

    def inspect_preprocessing(self, audio_bytes: bytes) -> Dict:
        """Inspect preprocessing pipeline."""
        # Load audio
        audio, sr = librosa.load(io.BytesIO(audio_bytes), sr=16000, mono=True)

        preprocessing_info = {
            'original_duration': len(audio) / sr,
            'original_samples': len(audio),
            'original_sr': sr,
            'audio_min': float(audio.min()),
            'audio_max': float(audio.max()),
            'audio_mean': float(audio.mean()),
            'audio_std': float(audio.std())
        }

        # Length handling
        target_samples = sr * 3
        if len(audio) > target_samples:
            audio = audio[:target_samples]
        elif len(audio) < target_samples:
            audio = np.pad(audio, (0, target_samples - len(audio)))

        preprocessing_info['target_duration'] = len(audio) / sr
        preprocessing_info['target_samples'] = len(audio)
        preprocessing_info['padded'] = len(audio) > target_samples
        preprocessing_info['truncated'] = len(audio) < target_samples

        # Mel-spectrogram
        mel_spec = librosa.feature.melspectrogram(
            y=audio,
            sr=sr,
            n_mels=80,
            n_fft=1024,
            hop_length=512,
            fmin=0,
            fmax=8000
        )

        preprocessing_info['mel_shape'] = mel_spec.shape
        preprocessing_info['mel_min'] = float(mel_spec.min())
        preprocessing_info['mel_max'] = float(mel_spec.max())
        preprocessing_info['mel_mean'] = float(mel_spec.mean())
        preprocessing_info['mel_std'] = float(mel_spec.std())

        # Log scale
        mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)

        preprocessing_info['mel_db_min'] = float(mel_spec_db.min())
        preprocessing_info['mel_db_max'] = float(mel_spec_db.max())
        preprocessing_info['mel_db_mean'] = float(mel_spec_db.mean())
        preprocessing_info['mel_db_std'] = float(mel_spec_db.std())

        # Standardization
        mean = mel_spec_db.mean()
        std = mel_spec_db.std()
        if std > 1e-8:
            mel_spec_normalized = (mel_spec_db - mean) / std
        else:
            mel_spec_normalized = mel_spec_db

        preprocessing_info['normalized_min'] = float(mel_spec_normalized.min())
        preprocessing_info['normalized_max'] = float(mel_spec_normalized.max())
        preprocessing_info['normalized_mean'] = float(mel_spec_normalized.mean())
        preprocessing_info['normalized_std'] = float(mel_spec_normalized.std())

        # Reshape
        mel_spec_reshaped = mel_spec_normalized[np.newaxis, np.newaxis, :, :]
        preprocessing_info['final_shape'] = mel_spec_reshaped.shape

        return preprocessing_info

    def inspect_model_output(self, audio_bytes: bytes) -> Dict:
        """Inspect model output."""
        # Preprocess
        input_tensor = self.service.preprocess_audio(audio_bytes)

        # Run inference
        with torch.no_grad():
            output = self.service.model(input_tensor)

        # Get raw logits
        raw_logits = output.cpu().numpy()

        # Get probability
        probability = torch.sigmoid(output).item()

        return {
            'raw_logits': raw_logits.tolist(),
            'logit_shape': list(raw_logits.shape),
            'probability': probability,
            'input_shape': list(input_tensor.shape),
            'input_min': float(input_tensor.min()),
            'input_max': float(input_tensor.max()),
            'input_mean': float(input_tensor.mean()),
            'input_std': float(input_tensor.std())
        }

    def diagnose_sample(self, file_path: str, label: str, sample_id: str) -> Dict:
        """Complete diagnosis of a single sample."""
        print(f"\n{'='*60}")
        print(f"Diagnosing: {sample_id}")
        print(f"Label: {label}")
        print(f"File: {file_path}")
        print(f"{'='*60}")

        if not os.path.exists(file_path):
            print(f"ERROR: File not found: {file_path}")
            return None

        # Load audio
        audio, sr = self.load_audio_file(file_path)
        audio_bytes = self.audio_to_bytes(audio, sr)

        # Inspect preprocessing
        preprocessing_info = self.inspect_preprocessing(audio_bytes)

        print(f"\nPreprocessing:")
        print(f"  Original Duration: {preprocessing_info['original_duration']:.3f}s")
        print(f"  Target Duration: {preprocessing_info['target_duration']:.3f}s")
        print(f"  Audio Range: [{preprocessing_info['audio_min']:.6f}, {preprocessing_info['audio_max']:.6f}]")
        print(f"  Mel Shape: {preprocessing_info['mel_shape']}")
        print(f"  Final Shape: {preprocessing_info['final_shape']}")

        # Inspect model output
        model_info = self.inspect_model_output(audio_bytes)

        print(f"\nModel Output:")
        print(f"  Raw Logits: {model_info['raw_logits']}")
        print(f"  Probability: {model_info['probability']:.6f}")
        print(f"  Input Shape: {model_info['input_shape']}")
        print(f"  Input Range: [{model_info['input_min']:.6f}, {model_info['input_max']:.6f}]")

        # Get detection result
        detection_result = self.service.detect_deepfake(audio_bytes)

        print(f"\nDetection Result:")
        print(f"  Is Synthetic: {detection_result['is_synthetic']}")
        print(f"  Confidence: {detection_result['confidence']:.6f}")
        print(f"  Inference Time: {detection_result['inference_time_ms']:.2f}ms")

        return {
            'sample_id': sample_id,
            'label': label,
            'file_path': file_path,
            'preprocessing': preprocessing_info,
            'model_output': model_info,
            'detection': detection_result
        }

    def analyze_score_distribution(self, results: List[Dict]) -> Dict:
        """Analyze score distribution across samples."""
        real_scores = []
        synthetic_scores = []

        for result in results:
            label = result['label']
            probability = result['model_output']['probability']

            if label == 'real':
                real_scores.append(probability)
            elif label == 'synthetic':
                synthetic_scores.append(probability)

        analysis = {
            'real_scores': real_scores,
            'synthetic_scores': synthetic_scores
        }

        if real_scores:
            real_scores_arr = np.array(real_scores)
            analysis['real_stats'] = {
                'count': len(real_scores),
                'min': float(real_scores_arr.min()),
                'max': float(real_scores_arr.max()),
                'mean': float(real_scores_arr.mean()),
                'median': float(np.median(real_scores_arr)),
                'std': float(real_scores_arr.std()),
                'p01': float(np.percentile(real_scores_arr, 1)),
                'p05': float(np.percentile(real_scores_arr, 5)),
                'p25': float(np.percentile(real_scores_arr, 25)),
                'p50': float(np.percentile(real_scores_arr, 50)),
                'p75': float(np.percentile(real_scores_arr, 75)),
                'p95': float(np.percentile(real_scores_arr, 95)),
                'p99': float(np.percentile(real_scores_arr, 99))
            }

        if synthetic_scores:
            synthetic_scores_arr = np.array(synthetic_scores)
            analysis['synthetic_stats'] = {
                'count': len(synthetic_scores),
                'min': float(synthetic_scores_arr.min()),
                'max': float(synthetic_scores_arr.max()),
                'mean': float(synthetic_scores_arr.mean()),
                'median': float(np.median(synthetic_scores_arr)),
                'std': float(synthetic_scores_arr.std()),
                'p01': float(np.percentile(synthetic_scores_arr, 1)),
                'p05': float(np.percentile(synthetic_scores_arr, 5)),
                'p25': float(np.percentile(synthetic_scores_arr, 25)),
                'p50': float(np.percentile(synthetic_scores_arr, 50)),
                'p75': float(np.percentile(synthetic_scores_arr, 75)),
                'p95': float(np.percentile(synthetic_scores_arr, 95)),
                'p99': float(np.percentile(synthetic_scores_arr, 99))
            }

        # Between-class analysis
        if real_scores and synthetic_scores:
            analysis['between_class'] = {
                'mean_difference': float(np.mean(synthetic_scores) - np.mean(real_scores)),
                'real_std': float(np.std(real_scores)),
                'synthetic_std': float(np.std(synthetic_scores)),
                'within_class_variance': (float(np.std(real_scores)) + float(np.std(synthetic_scores))) / 2
            }

        return analysis

    def test_determinism(self, file_path: str, num_runs: int = 10) -> Dict:
        """Test inference determinism."""
        print(f"\n{'='*60}")
        print(f"Testing Determinism: {num_runs} runs")
        print(f"{'='*60}")

        if not os.path.exists(file_path):
            print(f"ERROR: File not found: {file_path}")
            return None

        audio, sr = self.load_audio_file(file_path)
        audio_bytes = self.audio_to_bytes(audio, sr)

        results = []
        for i in range(num_runs):
            result = self.service.detect_deepfake(audio_bytes)
            results.append(result['confidence'])
            print(f"  Run {i+1}: {result['confidence']:.6f}")

        results_arr = np.array(results)
        determinism_analysis = {
            'num_runs': num_runs,
            'min': float(results_arr.min()),
            'max': float(results_arr.max()),
            'mean': float(results_arr.mean()),
            'std': float(results_arr.std()),
            'range': float(results_arr.max() - results_arr.min()),
            'is_deterministic': bool(results_arr.std() < 1e-6)
        }

        print(f"\nDeterminism Analysis:")
        print(f"  Range: {determinism_analysis['range']:.10f}")
        print(f"  Std: {determinism_analysis['std']:.10f}")
        print(f"  Deterministic: {determinism_analysis['is_deterministic']}")

        return determinism_analysis

    def test_length_handling(self, durations: List[float]) -> Dict:
        """Test different audio durations."""
        print(f"\n{'='*60}")
        print(f"Testing Length Handling")
        print(f"{'='*60}")

        results = {}
        for duration in durations:
            # Generate synthetic audio of specified duration
            num_samples = int(16000 * duration)
            audio = np.random.randn(num_samples).astype(np.float32)
            audio_bytes = self.audio_to_bytes(audio, 16000)

            # Run inference
            result = self.service.detect_deepfake(audio_bytes)

            results[duration] = {
                'confidence': result['confidence'],
                'inference_time_ms': result['inference_time_ms']
            }

            print(f"  {duration}s: confidence={result['confidence']:.6f}, time={result['inference_time_ms']:.2f}ms")

        return results


def main():
    """Main diagnostic function."""
    # Change to API directory
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    diagnostics = SpecRNetDiagnostics()

    # Test samples from current dataset
    real_samples = [
        ("samples/user_voices/WhatsApp Ptt 2026-09-17 at 23.39.57.ogg", "real", "real_001"),
        ("samples/user_voices/freesound_community-shortfilm-voice-56795.mp3", "real", "real_002")
    ]

    synthetic_samples = [
        ("samples/synthetic/ElevenLabs_2026-09-01T15_58_06_Kanika - Warm, Expressive and Natural_pvc_sp100_s50_sb75_se0_m2.mp3", "synthetic", "synthetic_001"),
        ("samples/synthetic/hindi_ai_voice.mp3", "synthetic", "synthetic_002")
    ]

    all_samples = real_samples + synthetic_samples

    print(f"\n{'='*60}")
    print(f"PHASEGUARD SPECRNET DIAGNOSTICS")
    print(f"{'='*60}")
    print(f"Dataset Status: LEGACY_BASELINE (12 samples)")
    print(f"Suitable For: Pipeline debugging, NOT performance claims")
    print(f"{'='*60}")

    # Diagnose each sample
    results = []
    for file_path, label, sample_id in all_samples:
        result = diagnostics.diagnose_sample(file_path, label, sample_id)
        if result:
            results.append(result)

    # Analyze score distribution
    print(f"\n{'='*60}")
    print(f"SCORE DISTRIBUTION ANALYSIS")
    print(f"{'='*60}")

    distribution_analysis = diagnostics.analyze_score_distribution(results)

    if 'real_stats' in distribution_analysis:
        print(f"\nReal Scores ({distribution_analysis['real_stats']['count']} samples):")
        print(f"  Mean: {distribution_analysis['real_stats']['mean']:.6f}")
        print(f"  Std: {distribution_analysis['real_stats']['std']:.6f}")
        print(f"  Range: [{distribution_analysis['real_stats']['min']:.6f}, {distribution_analysis['real_stats']['max']:.6f}]")
        print(f"  P50: {distribution_analysis['real_stats']['p50']:.6f}")

    if 'synthetic_stats' in distribution_analysis:
        print(f"\nSynthetic Scores ({distribution_analysis['synthetic_stats']['count']} samples):")
        print(f"  Mean: {distribution_analysis['synthetic_stats']['mean']:.6f}")
        print(f"  Std: {distribution_analysis['synthetic_stats']['std']:.6f}")
        print(f"  Range: [{distribution_analysis['synthetic_stats']['min']:.6f}, {distribution_analysis['synthetic_stats']['max']:.6f}]")
        print(f"  P50: {distribution_analysis['synthetic_stats']['p50']:.6f}")

    if 'between_class' in distribution_analysis:
        print(f"\nBetween-Class Analysis:")
        print(f"  Mean Difference: {distribution_analysis['between_class']['mean_difference']:.6f}")
        print(f"  Real Std: {distribution_analysis['between_class']['real_std']:.6f}")
        print(f"  Synthetic Std: {distribution_analysis['between_class']['synthetic_std']:.6f}")
        print(f"  Within-Class Variance: {distribution_analysis['between_class']['within_class_variance']:.6f}")

    # Test determinism
    if real_samples:
        determinism_result = diagnostics.test_determinism(real_samples[0][0], num_runs=10)

    # Test length handling
    length_results = diagnostics.test_length_handling([2.0, 3.0, 4.0, 5.0, 6.0])

    # Save results
    output = {
        'dataset_status': 'LEGACY_BASELINE',
        'dataset_warning': 'NOT suitable for performance claims',
        'sample_results': results,
        'distribution_analysis': distribution_analysis,
        'determinism': determinism_result if 'determinism_result' in locals() else None,
        'length_handling': length_results
    }

    output_path = "specrnet_diagnostics.json"
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Results saved to: {output_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
