"""
Telephone Condition Generation Pipeline
Creates telephone-band and degraded audio conditions for evaluation
"""
import numpy as np
import librosa
import soundfile as sf
import json
import os
import sys
from typing import Dict, List
import random

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class TelephoneConditionGenerator:
    """Generates telephone-band and degraded audio conditions."""

    def __init__(self, target_sr: int = 8000, random_seed: int = 42):
        """
        Initialize telephone condition generator.

        Args:
            target_sr: Target sample rate for telephone (default 8kHz)
            random_seed: Random seed for reproducibility
        """
        self.target_sr = target_sr
        self.random_seed = random_seed
        random.seed(random_seed)

    def apply_telephone_band(self, audio: np.ndarray, original_sr: int) -> np.ndarray:
        """
        Apply telephone band filtering (300-3400 Hz).

        Args:
            audio: Audio array
            original_sr: Original sample rate

        Returns:
            Band-limited audio
        """
        # Resample to target sample rate first
        if original_sr != self.target_sr:
            audio = librosa.resample(audio, orig_sr=original_sr, target_sr=self.target_sr)

        # Apply bandpass filter (300-3400 Hz)
        # This is a simplified version - real telephone filtering is more complex
        from scipy import signal

        lowcut = 300.0
        highcut = 3400.0
        nyquist = 0.5 * self.target_sr
        low = lowcut / nyquist
        high = highcut / nyquist

        b, a = signal.butter(4, [low, high], btype='band')
        filtered_audio = signal.filtfilt(b, a, audio)

        return filtered_audio

    def add_telephone_noise(self, audio: np.ndarray, snr_db: float = 30) -> np.ndarray:
        """
        Add telephone-quality noise.

        Args:
            audio: Audio array
            snr_db: Signal-to-noise ratio in dB

        Returns:
            Noisy audio
        """
        signal_power = np.mean(audio ** 2)
        noise_power = signal_power / (10 ** (snr_db / 10))
        noise = np.random.normal(0, np.sqrt(noise_power), len(audio))
        noisy_audio = audio + noise

        return noisy_audio

    def apply_codec_degradation(self, audio: np.ndarray, target_sr: int) -> np.ndarray:
        """
        Simulate codec degradation.

        Args:
            audio: Audio array
            target_sr: Target sample rate

        Returns:
            Codec-degraded audio
        """
        # This is a simplified simulation
        # Real codec degradation would use actual codec encoding/decoding

        # Quantization noise simulation
        bits = 8
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio_normalized = audio / max_val
            quantized = np.round(audio_normalized * (2**bits - 1)) / (2**bits - 1)
            degraded = quantized * max_val
        else:
            degraded = audio

        return degraded

    def generate_condition(self, input_path: str, output_path: str,
                         condition: str, parent_sample_id: str,
                         transformation_config: Dict) -> Dict:
        """
        Generate a specific audio condition.

        Args:
            input_path: Input audio file path
            output_path: Output audio file path
            condition: Condition type (telephone, noisy_telephone, etc.)
            parent_sample_id: Parent sample ID
            transformation_config: Transformation configuration

        Returns:
            Generation metadata
        """
        # Load audio
        audio, sr = librosa.load(input_path, sr=None, mono=True)

        metadata = {
            'parent_sample_id': parent_sample_id,
            'condition': condition,
            'transformation_config': transformation_config,
            'random_seed': self.random_seed,
            'original_sr': sr,
            'target_sr': self.target_sr,
            'input_path': input_path,
            'output_path': output_path
        }

        # Apply transformations based on condition
        if condition == 'telephone':
            audio = self.apply_telephone_band(audio, sr)
            metadata['transformations'] = ['telephone_band']
        elif condition == 'noisy_telephone':
            audio = self.apply_telephone_band(audio, sr)
            audio = self.add_telephone_noise(audio)
            metadata['transformations'] = ['telephone_band', 'noise']
        elif condition == 'codec_degraded':
            audio = self.apply_codec_degradation(audio, self.target_sr)
            metadata['transformations'] = ['codec_degradation']
        else:
            raise ValueError(f"Unknown condition: {condition}")

        # Save output
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        sf.write(output_path, audio, self.target_sr)

        metadata['duration_seconds'] = len(audio) / self.target_sr
        metadata['channels'] = 1
        metadata['codec'] = 'WAV'

        return metadata


def main():
    """Main function to generate telephone conditions."""
    # Example usage
    generator = TelephoneConditionGenerator()

    # This would be used with actual dataset
    print("Telephone condition generation infrastructure ready")
    print("Use with: python generate_phone_conditions.py --input <file> --condition <type>")


if __name__ == "__main__":
    main()
