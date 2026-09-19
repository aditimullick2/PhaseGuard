"""
Dataset Validation Script
Validates dataset integrity and detects common issues
"""
import json
import os
import sys
import hashlib
from typing import Dict, List, Set
from collections import defaultdict

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class DatasetValidator:
    """Validates dataset integrity and detects issues."""

    def __init__(self, manifest_path: str = "data/dataset_manifest.json"):
        """
        Initialize dataset validator.

        Args:
            manifest_path: Path to dataset manifest
        """
        self.manifest_path = manifest_path

        # Load manifest
        with open(manifest_path, 'r') as f:
            self.manifest = json.load(f)

        self.samples = self.manifest.get('samples', [])
        self.issues = []
        self.warnings = []

    def validate(self) -> Dict:
        """
        Run all validation checks.

        Returns:
            Validation results dictionary
        """
        print("=" * 60)
        print("PHASEGUARD DATASET VALIDATION")
        print("=" * 60)

        # Run all validation checks
        self._check_missing_files()
        self._check_duplicate_files()
        self._check_duplicate_hashes()
        self._check_invalid_labels()
        self._check_missing_speaker_ids()
        self._check_speaker_leakage()
        self._check_invalid_sample_rates()
        self._check_invalid_channel_count()
        self._check_corrupted_audio()
        self._check_extremely_short_audio()
        self._check_invalid_duration()
        self._check_unknown_generation_method()
        self._check_train_test_speaker_overlap()
        self._check_calibration_test_speaker_overlap()

        # Determine validation status
        is_valid = len(self.issues) == 0

        print("\n" + "=" * 60)
        if is_valid:
            print("[OK] DATASET VALID")
        else:
            print("[X] DATASET INVALID")
        print("=" * 60)

        if self.issues:
            print("\nCRITICAL ISSUES:")
            for issue in self.issues:
                print(f"  [X] {issue}")

        if self.warnings:
            print("\nWARNINGS:")
            for warning in self.warnings:
                print(f"  [!] {warning}")

        return {
            'valid': is_valid,
            'issues': self.issues,
            'warnings': self.warnings,
            'total_samples': len(self.samples),
            'valid_samples': len(self.samples) - len(self.issues)
        }

    def _check_missing_files(self):
        """Check for missing files."""
        missing_files = []
        for sample in self.samples:
            path = sample.get('path')
            if path and not os.path.exists(path):
                missing_files.append(path)

        if missing_files:
            self.issues.append(f"Missing files: {len(missing_files)}")
            for file in missing_files:
                self.issues.append(f"  Missing: {file}")

    def _check_duplicate_files(self):
        """Check for duplicate file paths."""
        file_paths = [sample.get('path') for sample in self.samples]
        duplicates = [f for f in file_paths if file_paths.count(f) > 1]

        if duplicates:
            self.issues.append(f"Duplicate file paths found: {len(set(duplicates))}")

    def _check_duplicate_hashes(self):
        """Check for duplicate file hashes."""
        hashes = {}
        for sample in self.samples:
            path = sample.get('path')
            if path and os.path.exists(path):
                try:
                    with open(path, 'rb') as f:
                        file_hash = hashlib.md5(f.read()).hexdigest()
                    if file_hash in hashes:
                        self.issues.append(f"Duplicate hash: {path} == {hashes[file_hash]}")
                    else:
                        hashes[file_hash] = path
                except Exception as e:
                    self.warnings.append(f"Could not hash {path}: {e}")

    def _check_invalid_labels(self):
        """Check for invalid labels."""
        valid_labels = {'real', 'synthetic'}
        invalid_labels = []

        for sample in self.samples:
            label = sample.get('label')
            if label not in valid_labels:
                invalid_labels.append(label)

        if invalid_labels:
            self.issues.append(f"Invalid labels found: {set(invalid_labels)}")

    def _check_missing_speaker_ids(self):
        """Check for missing speaker IDs."""
        missing_speaker_ids = []

        for sample in self.samples:
            speaker_id = sample.get('speaker_id')
            if not speaker_id:
                missing_speaker_ids.append(sample.get('id'))

        if missing_speaker_ids:
            self.warnings.append(f"Missing speaker IDs: {len(missing_speaker_ids)}")

    def _check_speaker_leakage(self):
        """Check for speaker leakage between splits."""
        split_speakers = defaultdict(set)

        for sample in self.samples:
            split = sample.get('split')
            speaker_id = sample.get('speaker_id')
            if split and speaker_id:
                split_speakers[split].add(speaker_id)

        # Check for overlaps
        if 'train' in split_speakers and 'calibration' in split_speakers:
            overlap = split_speakers['train'] & split_speakers['calibration']
            if overlap:
                self.issues.append(f"Speaker leakage: train/calibration overlap: {overlap}")

        if 'train' in split_speakers and 'test' in split_speakers:
            overlap = split_speakers['train'] & split_speakers['test']
            if overlap:
                self.issues.append(f"Speaker leakage: train/test overlap: {overlap}")

        if 'calibration' in split_speakers and 'test' in split_speakers:
            overlap = split_speakers['calibration'] & split_speakers['test']
            if overlap:
                self.issues.append(f"Speaker leakage: calibration/test overlap: {overlap}")

    def _check_invalid_sample_rates(self):
        """Check for invalid sample rates."""
        invalid_rates = []

        for sample in self.samples:
            sample_rate = sample.get('sample_rate')
            if sample_rate and (sample_rate <= 0 or sample_rate > 192000):
                invalid_rates.append(sample_rate)

        if invalid_rates:
            self.issues.append(f"Invalid sample rates: {set(invalid_rates)}")

    def _check_invalid_channel_count(self):
        """Check for invalid channel counts."""
        invalid_channels = []

        for sample in self.samples:
            channels = sample.get('channels')
            if channels and (channels <= 0 or channels > 2):
                invalid_channels.append(channels)

        if invalid_channels:
            self.issues.append(f"Invalid channel counts: {set(invalid_channels)}")

    def _check_corrupted_audio(self):
        """Check for corrupted audio files."""
        corrupted_files = []

        for sample in self.samples:
            path = sample.get('path')
            if path and os.path.exists(path):
                try:
                    import soundfile as sf
                    sf.info(path)
                except Exception as e:
                    corrupted_files.append(path)
                    self.issues.append(f"Corrupted audio: {path} - {e}")

    def _check_extremely_short_audio(self):
        """Check for extremely short audio files."""
        short_files = []

        for sample in self.samples:
            duration = sample.get('duration_seconds')
            if duration and duration < 0.5:
                short_files.append(sample.get('path'))

        if short_files:
            self.warnings.append(f"Extremely short audio files (<0.5s): {len(short_files)}")

    def _check_invalid_duration(self):
        """Check for invalid duration values."""
        invalid_durations = []

        for sample in self.samples:
            duration = sample.get('duration_seconds')
            if duration and (duration <= 0 or duration > 3600):
                invalid_durations.append(duration)

        if invalid_durations:
            self.issues.append(f"Invalid duration values: {set(invalid_durations)}")

    def _check_unknown_generation_method(self):
        """Check for unknown generation methods in synthetic samples."""
        unknown_methods = []

        for sample in self.samples:
            if sample.get('label') == 'synthetic':
                method = sample.get('generation_method')
                if not method or method == 'unknown':
                    unknown_methods.append(sample.get('id'))

        if unknown_methods:
            self.warnings.append(f"Unknown generation methods: {len(unknown_methods)}")

    def _check_train_test_speaker_overlap(self):
        """Check for train/test speaker overlap (already covered in speaker_leakage)."""
        # This is covered by _check_speaker_leakage
        pass

    def _check_calibration_test_speaker_overlap(self):
        """Check for calibration/test speaker overlap (already covered in speaker_leakage)."""
        # This is covered by _check_speaker_leakage
        pass


def main():
    """Main function to validate dataset."""
    validator = DatasetValidator()
    results = validator.validate()

    # Save validation results
    with open("dataset_validation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nValidation results saved to dataset_validation_results.json")

    return results


if __name__ == "__main__":
    main()
