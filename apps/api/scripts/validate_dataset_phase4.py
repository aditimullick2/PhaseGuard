"""
Phase 4 Dataset Validation Pipeline
Validates dataset integrity, detects duplicates, checks leakage, and prepares for scientific validation
"""
import json
import os
import sys
import hashlib
from typing import Dict, List, Set
from collections import defaultdict
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class Phase4DatasetValidator:
    """Enhanced dataset validator for Phase 4 scientific validation."""

    def __init__(self, manifest_path: str = "data/manifests/master_manifest.json",
                 min_real: int = 100, min_synthetic: int = 100,
                 min_test_per_class: int = 10, min_calibration_per_class: int = 10):
        """
        Initialize Phase 4 dataset validator.

        Args:
            manifest_path: Path to dataset manifest
            min_real: Minimum real samples for scientific validation
            min_synthetic: Minimum synthetic samples for scientific validation
            min_test_per_class: Minimum samples per class in test set
            min_calibration_per_class: Minimum samples per class in calibration set
        """
        self.manifest_path = manifest_path
        self.issues = []
        self.warnings = []
        self.manifest = None
        self.samples = []
        self.min_real = min_real
        self.min_synthetic = min_synthetic
        self.min_test_per_class = min_test_per_class
        self.min_calibration_per_class = min_calibration_per_class

    def load_manifest(self) -> bool:
        """Load dataset manifest."""
        try:
            if not os.path.exists(self.manifest_path):
                self.issues.append(f"Manifest file not found: {self.manifest_path}")
                return False

            with open(self.manifest_path, 'r') as f:
                self.manifest = json.load(f)

            self.samples = self.manifest.get('samples', [])
            return True
        except Exception as e:
            self.issues.append(f"Failed to load manifest: {e}")
            return False

    def validate(self) -> Dict:
        """
        Run all validation checks.

        Returns:
            Validation results dictionary
        """
        print("=" * 70)
        print("PHASE 4 DATASET VALIDATION")
        print("=" * 70)

        if not self.load_manifest():
            return self._create_results("BLOCKED", "Manifest loading failed")

        # Run validation checks
        self._check_missing_files()
        self._check_duplicate_hashes()
        self._check_duplicate_samples()
        self._check_invalid_labels()
        self._check_missing_metadata()
        self._check_sample_rates()
        self._check_durations()
        self._check_speaker_leakage()
        self._check_generator_leakage()
        self._check_class_balance()
        self._check_minimum_samples()

        return self._create_results()

    def _check_missing_files(self):
        """Check for missing audio files."""
        missing = []
        for sample in self.samples:
            file_path = sample.get('file_path')
            if not file_path:
                missing.append(f"{sample.get('sample_id', 'unknown')}: no file_path")
                continue

            full_path = os.path.join(os.path.dirname(self.manifest_path), file_path)
            if not os.path.exists(full_path):
                missing.append(f"{sample.get('sample_id', 'unknown')}: {file_path}")

        if missing:
            self.issues.append(f"Missing files: {len(missing)}")
            for m in missing[:10]:  # Show first 10
                self.issues.append(f"  - {m}")
            if len(missing) > 10:
                self.issues.append(f"  - ... and {len(missing) - 10} more")

    def _check_duplicate_hashes(self):
        """Check for duplicate file hashes."""
        hash_map = defaultdict(list)
        for sample in self.samples:
            file_path = sample.get('file_path')
            if not file_path:
                continue

            full_path = os.path.join(os.path.dirname(self.manifest_path), file_path)
            if not os.path.exists(full_path):
                continue

            try:
                with open(full_path, 'rb') as f:
                    file_hash = hashlib.sha256(f.read()).hexdigest()
                hash_map[file_hash].append(sample.get('sample_id'))
            except Exception as e:
                self.warnings.append(f"Failed to hash {file_path}: {e}")

        duplicates = {h: ids for h, ids in hash_map.items() if len(ids) > 1}
        if duplicates:
            self.issues.append(f"Duplicate file hashes: {len(duplicates)}")
            for h, ids in list(duplicates.items())[:5]:
                self.issues.append(f"  - Hash {h[:16]}...: {', '.join(ids)}")

    def _check_duplicate_samples(self):
        """Check for duplicate sample IDs."""
        sample_ids = [s.get('sample_id') for s in self.samples]
        seen = set()
        duplicates = []

        for sid in sample_ids:
            if sid in seen:
                duplicates.append(sid)
            seen.add(sid)

        if duplicates:
            self.issues.append(f"Duplicate sample IDs: {len(duplicates)}")
            for d in duplicates[:10]:
                self.issues.append(f"  - {d}")

    def _check_invalid_labels(self):
        """Check for invalid labels."""
        valid_labels = {'real', 'synthetic'}
        invalid = []

        for sample in self.samples:
            label = sample.get('label')
            if label not in valid_labels:
                invalid.append(f"{sample.get('sample_id', 'unknown')}: {label}")

        if invalid:
            self.issues.append(f"Invalid labels: {len(invalid)}")
            for i in invalid[:10]:
                self.issues.append(f"  - {i}")

    def _check_missing_metadata(self):
        """Check for missing required metadata fields."""
        required_fields = ['sample_id', 'file_path', 'label', 'speaker_id']
        missing_metadata = []

        for sample in self.samples:
            sample_id = sample.get('sample_id', 'unknown')
            for field in required_fields:
                if field not in sample or not sample[field]:
                    missing_metadata.append(f"{sample_id}: missing {field}")

        if missing_metadata:
            self.issues.append(f"Missing metadata fields: {len(missing_metadata)}")
            for m in missing_metadata[:10]:
                self.issues.append(f"  - {m}")

    def _check_sample_rates(self):
        """Check for invalid sample rates."""
        valid_rates = {16000, 44100, 48000}
        invalid_rates = []

        for sample in self.samples:
            sample_rate = sample.get('sample_rate')
            if sample_rate and sample_rate not in valid_rates:
                invalid_rates.append(f"{sample.get('sample_id', 'unknown')}: {sample_rate}Hz")

        if invalid_rates:
            self.warnings.append(f"Non-standard sample rates: {len(invalid_rates)}")
            for r in invalid_rates[:10]:
                self.warnings.append(f"  - {r}")

    def _check_durations(self):
        """Check for invalid durations."""
        too_short = []
        too_long = []

        for sample in self.samples:
            duration = sample.get('duration_seconds')
            if duration is None:
                continue
            if duration < 1.0:
                too_short.append(f"{sample.get('sample_id', 'unknown')}: {duration}s")
            elif duration > 30.0:
                too_long.append(f"{sample.get('sample_id', 'unknown')}: {duration}s")

        if too_short:
            self.warnings.append(f"Very short samples (<1s): {len(too_short)}")
            for t in too_short[:5]:
                self.warnings.append(f"  - {t}")

        if too_long:
            self.warnings.append(f"Very long samples (>30s): {len(too_long)}")
            for t in too_long[:5]:
                self.warnings.append(f"  - {t}")

    def _check_speaker_leakage(self):
        """Check for speaker leakage across splits (if split info exists)."""
        if 'split' not in self.samples[0] if self.samples else False:
            self.warnings.append("No split information available, cannot check speaker leakage")
            return

        speaker_splits = defaultdict(set)
        for sample in self.samples:
            speaker_id = sample.get('speaker_id')
            split = sample.get('split')
            if speaker_id and split:
                speaker_splits[speaker_id].add(split)

        leaked_speakers = {s: splits for s, splits in speaker_splits.items() if len(splits) > 1}
        if leaked_speakers:
            self.issues.append(f"Speaker leakage detected: {len(leaked_speakers)} speakers in multiple splits")
            for speaker, splits in list(leaked_speakers.items())[:5]:
                self.issues.append(f"  - Speaker {speaker}: {', '.join(sorted(splits))}")

    def _check_generator_leakage(self):
        """Check for generator leakage across splits (if available)."""
        if 'split' not in self.samples[0] if self.samples else False:
            self.warnings.append("No split information available, cannot check generator leakage")
            return

        generator_splits = defaultdict(set)
        for sample in self.samples:
            generator = sample.get('generator')
            split = sample.get('split')
            if generator and split:
                generator_splits[generator].add(split)

        leaked_generators = {g: splits for g, splits in generator_splits.items() if len(splits) > 1}
        if leaked_generators:
            self.warnings.append(f"Generator leakage detected: {len(leaked_generators)} generators in multiple splits")
            for generator, splits in list(leaked_generators.items())[:5]:
                self.warnings.append(f"  - Generator {generator}: {', '.join(sorted(splits))}")

    def _check_class_balance(self):
        """Check class balance."""
        labels = [s.get('label') for s in self.samples]
        real_count = labels.count('real')
        synthetic_count = labels.count('synthetic')

        if real_count == 0:
            self.issues.append("No real samples in dataset")
        elif synthetic_count == 0:
            self.issues.append("No synthetic samples in dataset")
        else:
            ratio = max(real_count, synthetic_count) / min(real_count, synthetic_count)
            if ratio > 10:
                self.warnings.append(f"Class imbalance >10x (real: {real_count}, synthetic: {synthetic_count})")

    def _check_minimum_samples(self):
        """Check minimum sample requirements."""
        total = len(self.samples)
        labels = [s.get('label') for s in self.samples]
        real_count = labels.count('real')
        synthetic_count = labels.count('synthetic')
        speakers = set(s.get('speaker_id') for s in self.samples if s.get('speaker_id'))

        # Phase 4 targets
        if total < 200:
            self.warnings.append(f"Dataset below Phase 4 target: {total}/200 samples")
        if real_count < 100:
            self.warnings.append(f"Real samples below Phase 4 target: {real_count}/100")
        if synthetic_count < 100:
            self.warnings.append(f"Synthetic samples below Phase 4 target: {synthetic_count}/100")
        if len(speakers) < 30:
            self.warnings.append(f"Speakers below Phase 4 target: {len(speakers)}/30")

    def classify_dataset_readiness(self) -> str:
        """
        Classify dataset readiness for scientific validation.

        Returns:
            READY_FOR_SCIENTIFIC_VALIDATION, REGRESSION_ONLY, or BLOCKED
        """
        labels = [s.get('label') for s in self.samples]
        real_count = labels.count('real')
        synthetic_count = labels.count('synthetic')
        total = len(self.samples)

        # Check minimum sample requirements
        if real_count < self.min_real or synthetic_count < self.min_synthetic:
            return "REGRESSION_ONLY"

        # Check for critical issues
        if self.issues:
            return "BLOCKED"

        # Check splits if available
        if 'split' in self.samples[0] if self.samples else False:
            calibration_real = sum(1 for s in self.samples if s.get('split') == 'calibration' and s.get('label') == 'real')
            calibration_synthetic = sum(1 for s in self.samples if s.get('split') == 'calibration' and s.get('label') == 'synthetic')
            test_real = sum(1 for s in self.samples if s.get('split') == 'test' and s.get('label') == 'real')
            test_synthetic = sum(1 for s in self.samples if s.get('split') == 'test' and s.get('label') == 'synthetic')

            # Both classes must be present in calibration and test
            if calibration_real < self.min_calibration_per_class or calibration_synthetic < self.min_calibration_per_class:
                return "REGRESSION_ONLY"
            if test_real < self.min_test_per_class or test_synthetic < self.min_test_per_class:
                return "REGRESSION_ONLY"

        return "READY_FOR_SCIENTIFIC_VALIDATION"

    def _create_results(self, status: str = None, message: str = None) -> Dict:
        """Create validation results dictionary."""
        if status is None:
            if self.issues:
                status = "BLOCKED" if len(self.issues) > 10 else "PARTIAL"
            elif self.warnings:
                status = "PARTIAL"
            else:
                status = "PASS"

        labels = [s.get('label') for s in self.samples] if self.samples else []
        real_count = labels.count('real')
        synthetic_count = labels.count('synthetic')
        speakers = set(s.get('speaker_id') for s in self.samples if s.get('speaker_id'))

        readiness = self.classify_dataset_readiness()

        return {
            "status": status,
            "message": message or "",
            "readiness": readiness,
            "total_samples": len(self.samples),
            "real_samples": real_count,
            "synthetic_samples": synthetic_count,
            "unique_speakers": len(speakers),
            "issues": self.issues,
            "warnings": self.warnings,
            "issue_count": len(self.issues),
            "warning_count": len(self.warnings)
        }


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Phase 4 Dataset Validation")
    parser.add_argument("--manifest", default="data/manifests/master_manifest.json",
                       help="Path to dataset manifest")
    parser.add_argument("--min-real", type=int, default=100,
                       help="Minimum real samples for scientific validation")
    parser.add_argument("--min-synthetic", type=int, default=100,
                       help="Minimum synthetic samples for scientific validation")
    parser.add_argument("--min-test-per-class", type=int, default=10,
                       help="Minimum samples per class in test set")
    parser.add_argument("--min-calibration-per-class", type=int, default=10,
                       help="Minimum samples per class in calibration set")
    args = parser.parse_args()

    validator = Phase4DatasetValidator(
        args.manifest,
        min_real=args.min_real,
        min_synthetic=args.min_synthetic,
        min_test_per_class=args.min_test_per_class,
        min_calibration_per_class=args.min_calibration_per_class
    )
    results = validator.validate()

    print("\n" + "=" * 70)
    print("VALIDATION RESULTS")
    print("=" * 70)
    print(f"Status: {results['status']}")
    print(f"Readiness: {results['readiness']}")
    print(f"Total Samples: {results['total_samples']}")
    print(f"Real: {results['real_samples']}")
    print(f"Synthetic: {results['synthetic_samples']}")
    print(f"Unique Speakers: {results['unique_speakers']}")
    print(f"Issues: {results['issue_count']}")
    print(f"Warnings: {results['warning_count']}")

    if results['issues']:
        print("\nIssues:")
        for issue in results['issues']:
            print(f"  - {issue}")

    if results['warnings']:
        print("\nWarnings:")
        for warning in results['warnings']:
            print(f"  - {warning}")

    print("\n" + "=" * 70)

    # Exit with error if blocked
    if results['status'] == "BLOCKED":
        sys.exit(1)
    elif results['status'] == "PARTIAL":
        sys.exit(2)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
