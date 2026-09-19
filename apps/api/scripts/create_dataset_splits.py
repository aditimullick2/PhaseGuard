"""
Speaker-Disjoint Dataset Split Engine
Creates train/calibration/test splits with speaker-disjoint separation
"""
import json
import os
import sys
import random
from typing import Dict, List, Set
from collections import defaultdict

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class DatasetSplitter:
    """Creates speaker-disjoint dataset splits."""

    def __init__(self, manifest_path: str = "data/dataset_manifest.json",
                 random_seed: int = 42):
        """
        Initialize dataset splitter.

        Args:
            manifest_path: Path to dataset manifest
            random_seed: Random seed for reproducibility
        """
        self.manifest_path = manifest_path
        self.random_seed = random_seed
        random.seed(random_seed)

        # Load manifest
        with open(manifest_path, 'r') as f:
            self.manifest = json.load(f)

        # Split distribution
        self.train_ratio = 0.60
        self.calibration_ratio = 0.20
        self.test_ratio = 0.20

    def create_speaker_disjoint_splits(self) -> Dict:
        """
        Create speaker-disjoint splits.

        Returns:
            Split information dictionary
        """
        samples = self.manifest.get('samples', [])

        # Group samples by speaker
        speaker_samples = defaultdict(list)
        for sample in samples:
            speaker_id = sample.get('speaker_id')
            if speaker_id:
                speaker_samples[speaker_id].append(sample)

        # Shuffle speakers for random split
        speaker_ids = list(speaker_samples.keys())
        random.shuffle(speaker_ids)

        # Calculate split boundaries
        total_speakers = len(speaker_ids)
        train_end = int(total_speakers * self.train_ratio)
        calibration_end = train_end + int(total_speakers * self.calibration_ratio)

        # Assign speakers to splits
        train_speakers = set(speaker_ids[:train_end])
        calibration_speakers = set(speaker_ids[train_end:calibration_end])
        test_speakers = set(speaker_ids[calibration_end:])

        # Verify no speaker overlap
        overlap_train_calibration = train_speakers & calibration_speakers
        overlap_train_test = train_speakers & test_speakers
        overlap_calibration_test = calibration_speakers & test_speakers

        if overlap_train_calibration or overlap_train_test or overlap_calibration_test:
            raise ValueError("Speaker overlap detected in splits!")

        # Assign samples to splits based on speaker
        splits = {
            'train': [],
            'calibration': [],
            'test': []
        }

        for sample in samples:
            speaker_id = sample.get('speaker_id')
            if speaker_id in train_speakers:
                sample['split'] = 'train'
                splits['train'].append(sample)
            elif speaker_id in calibration_speakers:
                sample['split'] = 'calibration'
                splits['calibration'].append(sample)
            elif speaker_id in test_speakers:
                sample['split'] = 'test'
                splits['test'].append(sample)
            else:
                # Speaker ID missing, assign to test
                sample['split'] = 'test'
                splits['test'].append(sample)

        # Update manifest with split information
        self.manifest['splits'] = {
            'train': {
                'speaker_ids': list(train_speakers),
                'sample_count': len(splits['train']),
                'percentage': len(splits['train']) / len(samples) * 100
            },
            'calibration': {
                'speaker_ids': list(calibration_speakers),
                'sample_count': len(splits['calibration']),
                'percentage': len(splits['calibration']) / len(samples) * 100
            },
            'test': {
                'speaker_ids': list(test_speakers),
                'sample_count': len(splits['test']),
                'percentage': len(splits['test']) / len(samples) * 100
            }
        }

        # Update reproducibility info
        self.manifest['reproducibility'] = {
            'random_seed': self.random_seed,
            'split_algorithm': 'speaker_disjoint',
            'split_distribution': {
                'train': self.train_ratio,
                'calibration': self.calibration_ratio,
                'test': self.test_ratio
            }
        }

        return {
            'train': splits['train'],
            'calibration': splits['calibration'],
            'test': splits['test'],
            'speaker_counts': {
                'train': len(train_speakers),
                'calibration': len(calibration_speakers),
                'test': len(test_speakers)
            }
        }

    def save_splits(self, output_path: str = None):
        """
        Save updated manifest with splits.

        Args:
            output_path: Output path for updated manifest
        """
        if output_path is None:
            output_path = self.manifest_path

        with open(output_path, 'w') as f:
            json.dump(self.manifest, f, indent=2)

        print(f"Saved updated manifest to {output_path}")

    def get_split_statistics(self) -> Dict:
        """
        Get statistics about the splits.

        Returns:
            Statistics dictionary
        """
        samples = self.manifest.get('samples', [])

        real_by_split = defaultdict(int)
        synthetic_by_split = defaultdict(int)
        language_by_split = defaultdict(lambda: defaultdict(int))
        condition_by_split = defaultdict(lambda: defaultdict(int))

        for sample in samples:
            split = sample.get('split', 'unknown')
            label = sample.get('label')
            language = sample.get('language', 'unknown')
            condition = sample.get('condition', 'unknown')

            if label == 'real':
                real_by_split[split] += 1
            elif label == 'synthetic':
                synthetic_by_split[split] += 1

            language_by_split[split][language] += 1
            condition_by_split[split][condition] += 1

        return {
            'real_distribution': dict(real_by_split),
            'synthetic_distribution': dict(synthetic_by_split),
            'language_distribution': {k: dict(v) for k, v in language_by_split.items()},
            'condition_distribution': {k: dict(v) for k, v in condition_by_split.items()}
        }

    def validate_split_balance(self) -> Dict:
        """
        Validate that splits have both real and synthetic samples.

        Returns:
            Validation results dictionary
        """
        stats = self.get_split_statistics()
        validation_results = {
            'train_has_both': False,
            'calibration_has_both': False,
            'test_has_both': False,
            'all_splits_valid': False,
            'issues': []
        }

        for split in ['train', 'calibration', 'test']:
            real_count = stats['real_distribution'].get(split, 0)
            synthetic_count = stats['synthetic_distribution'].get(split, 0)

            has_both = real_count > 0 and synthetic_count > 0

            if split == 'train':
                validation_results['train_has_both'] = has_both
            elif split == 'calibration':
                validation_results['calibration_has_both'] = has_both
            elif split == 'test':
                validation_results['test_has_both'] = has_both

            if not has_both:
                validation_results['issues'].append(
                    f"{split} split missing both classes: real={real_count}, synthetic={synthetic_count}"
                )

        validation_results['all_splits_valid'] = (
            validation_results['train_has_both'] and
            validation_results['calibration_has_both'] and
            validation_results['test_has_both']
        )

        return validation_results


def main():
    """Main function to create dataset splits."""
    splitter = DatasetSplitter()

    print("Creating speaker-disjoint splits...")
    splits = splitter.create_speaker_disjoint_splits()

    print(f"\nSplit Statistics:")
    print(f"  Train: {len(splits['train'])} samples, {splits['speaker_counts']['train']} speakers")
    print(f"  Calibration: {len(splits['calibration'])} samples, {splits['speaker_counts']['calibration']} speakers")
    print(f"  Test: {len(splits['test'])} samples, {splits['speaker_counts']['test']} speakers")

    stats = splitter.get_split_statistics()
    print(f"\nReal/Synthetic Distribution:")
    for split in ['train', 'calibration', 'test']:
        print(f"  {split}:")
        print(f"    Real: {stats['real_distribution'].get(split, 0)}")
        print(f"    Synthetic: {stats['synthetic_distribution'].get(split, 0)}")

    # Validate split balance
    validation = splitter.validate_split_balance()
    print(f"\nSplit Balance Validation:")
    print(f"  Train has both classes: {validation['train_has_both']}")
    print(f"  Calibration has both classes: {validation['calibration_has_both']}")
    print(f"  Test has both classes: {validation['test_has_both']}")

    if validation['issues']:
        print(f"\n[WARNING] Split Balance Issues:")
        for issue in validation['issues']:
            print(f"  - {issue}")
        print(f"\n[WARNING] Dataset is too small for balanced splits.")
        print(f"[WARNING] Current dataset: {splitter.manifest['total_samples']} samples")
        print(f"[WARNING] Required: 100+ real, 100+ synthetic for balanced splits")
    else:
        print(f"\n[OK] All splits have both real and synthetic samples")

    splitter.save_splits()
    print(f"\n[OK] Splits created and saved to manifest")

    # Return validation status
    return validation['all_splits_valid']


if __name__ == "__main__":
    main()
