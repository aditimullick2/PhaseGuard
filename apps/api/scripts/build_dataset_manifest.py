"""
Dataset Manifest Builder for PhaseGuard Deepfake Detection
Creates structured dataset manifest for training and evaluation
"""
import os
import pandas as pd
from pathlib import Path
from typing import List, Dict
import json


class DatasetManifestBuilder:
    """Build dataset manifest for PhaseGuard training/evaluation."""

    def __init__(self, dataset_root: str = "data"):
        """
        Initialize dataset manifest builder.

        Args:
            dataset_root: Root directory for dataset
        """
        self.dataset_root = Path(dataset_root)
        self.manifest = []

    def scan_directory(self, directory: str, label: str, language: str = "unknown",
                      condition: str = "clean", source: str = "unknown") -> None:
        """
        Scan directory for audio files and add to manifest.

        Args:
            directory: Directory to scan
            label: Audio label (real/synthetic)
            language: Language (hindi/english/hinglish/other_indian)
            condition: Audio condition (clean/noisy/phone_quality)
            source: Audio source
        """
        dir_path = self.dataset_root / directory
        if not dir_path.exists():
            print(f"Directory not found: {dir_path}")
            return

        audio_extensions = ['.wav', '.mp3', '.ogg', '.flac', '.m4a']

        for file_path in dir_path.rglob('*'):
            if file_path.suffix.lower() in audio_extensions:
                # Get file info
                try:
                    import librosa
                    audio_info = librosa.get_duration(filename=str(file_path))
                    duration = audio_info

                    entry = {
                        "file": str(file_path.relative_to(self.dataset_root)),
                        "label": label,
                        "language": language,
                        "speaker_id": file_path.stem[:8],  # Use filename prefix as speaker ID
                        "source": source,
                        "generation_method": "unknown" if label == "real" else "tts",
                        "codec": file_path.suffix[1:],
                        "sample_rate": 16000,  # Assume 16kHz
                        "duration": duration,
                        "condition": condition
                    }
                    self.manifest.append(entry)

                except Exception as e:
                    print(f"Error processing {file_path}: {e}")

    def save_manifest(self, output_path: str = "data/dataset_manifest.csv") -> None:
        """
        Save dataset manifest to CSV.

        Args:
            output_path: Path to save manifest
        """
        df = pd.DataFrame(self.manifest)
        df.to_csv(output_path, index=False)
        print(f"Manifest saved to {output_path}")
        print(f"Total files: {len(self.manifest)}")

    def get_statistics(self) -> Dict:
        """Get dataset statistics."""
        if not self.manifest:
            return {"error": "No data in manifest"}

        df = pd.DataFrame(self.manifest)

        stats = {
            "total_files": len(df),
            "label_distribution": df['label'].value_counts().to_dict(),
            "language_distribution": df['language'].value_counts().to_dict(),
            "condition_distribution": df['condition'].value_counts().to_dict(),
            "avg_duration": df['duration'].mean(),
            "total_duration": df['duration'].sum()
        }

        return stats


def main():
    """Main function to build dataset manifest."""
    print("PhaseGuard Dataset Manifest Builder")
    print("=" * 50)

    builder = DatasetManifestBuilder("data")

    # Scan real audio
    builder.scan_directory("real/hindi", "real", "hindi", "clean", "recorded")
    builder.scan_directory("real/english", "real", "english", "clean", "recorded")
    builder.scan_directory("real/hinglish", "real", "hinglish", "clean", "recorded")
    builder.scan_directory("real/phone_quality", "real", "english", "phone_quality", "phone")

    # Scan synthetic audio
    builder.scan_directory("synthetic/hindi", "synthetic", "hindi", "clean", "tts")
    builder.scan_directory("synthetic/english", "synthetic", "english", "clean", "tts")
    builder.scan_directory("synthetic/hinglish", "synthetic", "hinglish", "clean", "tts")
    builder.scan_directory("synthetic/tts", "synthetic", "english", "clean", "tts")
    builder.scan_directory("synthetic/voice_clone", "synthetic", "english", "clean", "voice_clone")

    # Save manifest
    builder.save_manifest()

    # Print statistics
    stats = builder.get_statistics()
    print("\nDataset Statistics:")
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
