"""
AASIST-L Score Semantics Validation
Verify exact score semantics by tracing through the model
"""
import numpy as np
import onnxruntime as ort
import soundfile as sf
import librosa
import json
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.canonical_audio import load_canonical_audio


class AASISTLSemanticsValidator:
    """Validates AASIST-L score semantics."""

    def __init__(self, model_path: str = "models/aasist_l/aasist-l.onnx"):
        """
        Initialize validator.

        Args:
            model_path: Path to AASIST-L ONNX model
        """
        self.model_path = model_path
        self.session = ort.InferenceSession(model_path)

        # Get model input/output info
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name

        self.input_shape = self.session.get_inputs()[0].shape
        self.output_shape = self.session.get_outputs()[0].shape

        print(f"Model: {model_path}")
        print(f"Input: {self.input_name}, shape: {self.input_shape}")
        print(f"Output: {self.output_name}, shape: {self.output_shape}")

    def preprocess_audio(self, audio_path: str) -> np.ndarray:
        """
        Preprocess audio for AASIST-L.

        Args:
            audio_path: Path to audio file

        Returns:
            Preprocessed waveform
        """
        # Load audio
        waveform, sr = librosa.load(audio_path, sr=16000, mono=True)

        # AASIST-L expects 64600 samples (~4.04 seconds at 16 kHz)
        target_length = 64600

        if len(waveform) < target_length:
            # Pad with zeros
            padding = target_length - len(waveform)
            waveform = np.pad(waveform, (0, padding), mode='constant')
        elif len(waveform) > target_length:
            # Truncate
            waveform = waveform[:target_length]

        # Add batch dimension
        waveform = waveform.reshape(1, -1)

        return waveform.astype(np.float32)

    def run_inference(self, audio_path: str) -> dict:
        """
        Run inference and capture all intermediate values.

        Args:
            audio_path: Path to audio file

        Returns:
            Dictionary with all inference details
        """
        # Preprocess
        waveform = self.preprocess_audio(audio_path)

        print(f"\n{'='*60}")
        print(f"Processing: {audio_path}")
        print(f"{'='*60}")

        # Print input details
        print(f"\nInput Details:")
        print(f"  Shape: {waveform.shape}")
        print(f"  Dtype: {waveform.dtype}")
        print(f"  Min: {waveform.min():.6f}")
        print(f"  Max: {waveform.max():.6f}")
        print(f"  Mean: {waveform.mean():.6f}")
        print(f"  Std: {waveform.std():.6f}")

        # Run inference
        outputs = self.session.run([self.output_name], {self.input_name: waveform})
        logits = outputs[0]

        print(f"\nRaw Output (Logits):")
        print(f"  Shape: {logits.shape}")
        print(f"  Values: {logits}")

        # Apply softmax
        exp_logits = np.exp(logits - np.max(logits, axis=1, keepdims=True))
        softmax_probs = exp_logits / np.sum(exp_logits, axis=1, keepdims=True)

        print(f"\nSoftmax Probabilities:")
        print(f"  Shape: {softmax_probs.shape}")
        print(f"  Class 0: {softmax_probs[0, 0]:.6f}")
        print(f"  Class 1: {softmax_probs[0, 1]:.6f}")

        # Determine class
        predicted_class = np.argmax(softmax_probs, axis=1)[0]

        print(f"\nPredicted Class: {predicted_class}")

        return {
            'input_shape': waveform.shape,
            'input_stats': {
                'min': float(waveform.min()),
                'max': float(waveform.max()),
                'mean': float(waveform.mean()),
                'std': float(waveform.std())
            },
            'raw_logits': logits.tolist(),
            'softmax_probs': softmax_probs.tolist(),
            'predicted_class': int(predicted_class)
        }

    def test_known_samples(self):
        """Test with known real and synthetic samples."""
        results = {
            'real_samples': [],
            'synthetic_samples': []
        }

        # Real samples (from dataset manifest)
        real_samples = [
            "samples/user_voices/WhatsApp Ptt 2026-09-17 at 23.39.57.ogg",
            "samples/user_voices/freesound_community-shortfilm-voice-56795.mp3"
        ]

        # Synthetic samples (from dataset manifest)
        synthetic_samples = [
            "samples/synthetic/ElevenLabs_2026-09-01T15_58_06_Kanika - Warm, Expressive and Natural_pvc_sp100_s50_sb75_se0_m2.mp3",
            "samples/synthetic/hindi_ai_voice.mp3"
        ]

        print(f"\n{'='*60}")
        print(f"Testing REAL Samples")
        print(f"{'='*60}")

        for sample_path in real_samples:
            if os.path.exists(sample_path):
                try:
                    result = self.run_inference(sample_path)
                    results['real_samples'].append({
                        'path': sample_path,
                        'result': result
                    })
                except Exception as e:
                    print(f"Error processing {sample_path}: {e}")
            else:
                print(f"File not found: {sample_path}")

        print(f"\n{'='*60}")
        print(f"Testing SYNTHETIC Samples")
        print(f"{'='*60}")

        for sample_path in synthetic_samples:
            if os.path.exists(sample_path):
                try:
                    result = self.run_inference(sample_path)
                    results['synthetic_samples'].append({
                        'path': sample_path,
                        'result': result
                    })
                except Exception as e:
                    print(f"Error processing {sample_path}: {e}")
            else:
                print(f"File not found: {sample_path}")

        return results

    def analyze_score_semantics(self, results: dict):
        """
        Analyze results to determine score semantics.

        Args:
            results: Dictionary with test results
        """
        print(f"\n{'='*60}")
        print(f"Score Semantics Analysis")
        print(f"{'='*60}")

        real_scores = []
        synthetic_scores = []

        for sample in results['real_samples']:
            probs = sample['result']['softmax_probs'][0]
            real_scores.append(probs)

        for sample in results['synthetic_samples']:
            probs = sample['result']['softmax_probs'][0]
            synthetic_scores.append(probs)

        print(f"\nReal Sample Probabilities:")
        for i, probs in enumerate(real_scores):
            print(f"  Sample {i+1}: Class 0 = {probs[0]:.6f}, Class 1 = {probs[1]:.6f}")

        print(f"\nSynthetic Sample Probabilities:")
        for i, probs in enumerate(synthetic_scores):
            print(f"  Sample {i+1}: Class 0 = {probs[0]:.6f}, Class 1 = {probs[1]:.6f}")

        # Analyze patterns
        print(f"\nPattern Analysis:")

        if real_scores and synthetic_scores:
            # Calculate average probabilities
            avg_real_class0 = np.mean([p[0] for p in real_scores])
            avg_real_class1 = np.mean([p[1] for p in real_scores])
            avg_synth_class0 = np.mean([p[0] for p in synthetic_scores])
            avg_synth_class1 = np.mean([p[1] for p in synthetic_scores])

            print(f"\nAverage Real Probabilities:")
            print(f"  Class 0: {avg_real_class0:.6f}")
            print(f"  Class 1: {avg_real_class1:.6f}")

            print(f"\nAverage Synthetic Probabilities:")
            print(f"  Class 0: {avg_synth_class0:.6f}")
            print(f"  Class 1: {avg_synth_class1:.6f}")

            # Determine semantics
            print(f"\nSemantics Determination:")

            if avg_real_class0 > avg_real_class1 and avg_synth_class1 > avg_synth_class0:
                print(f"  Class 0 = Bona Fide (Real)")
                print(f"  Class 1 = Spoof (Synthetic)")
                print(f"  Higher Class 1 score = More Synthetic")
            elif avg_real_class1 > avg_real_class0 and avg_synth_class0 > avg_synth_class1:
                print(f"  Class 0 = Spoof (Synthetic)")
                print(f"  Class 1 = Bona Fide (Real)")
                print(f"  Higher Class 0 score = More Synthetic")
            else:
                print(f"  WARNING: Cannot determine clear semantics")
                print(f"  Data may be insufficient or model may not be performing well")

        return results


def main():
    """Main function."""
    # Change to API directory
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    validator = AASISTLSemanticsValidator()
    results = validator.test_known_samples()
    validator.analyze_score_semantics(results)

    # Save results
    output_path = "aasist_l_semantics_validation.json"
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Results saved to: {output_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
