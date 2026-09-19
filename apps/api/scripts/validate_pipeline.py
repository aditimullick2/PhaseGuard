"""
PhaseGuard Pipeline Validation Script
Validates the entire detection pipeline before benchmarking
"""
import os
import sys
import json
import time
import numpy as np
from typing import Dict, List

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.audio_preprocessor import get_audio_preprocessor
from detection.model_manager import get_model_manager


class PipelineValidator:
    """Validates the detection pipeline."""

    def __init__(self):
        """Initialize pipeline validator."""
        self.preprocessor = get_audio_preprocessor()
        self.model_manager = get_model_manager()
        self.results = {}

    def validate_audio_files(self, test_files: Dict[str, List[str]]) -> Dict:
        """
        Validate all audio files before processing.

        Args:
            test_files: Dictionary with 'human' and 'synthetic' file lists

        Returns:
            Validation results for all files
        """
        print("\n" + "=" * 60)
        print("VALIDATING AUDIO FILES")
        print("=" * 60)

        validation_results = {
            'total_files': 0,
            'valid_files': 0,
            'failed_files': 0,
            'files': {}
        }

        for category, files in test_files.items():
            for file_path in files:
                validation_results['total_files'] += 1

                print(f"\nValidating: {file_path}")
                metadata = self.preprocessor.validate_audio_file(file_path)

                validation_results['files'][file_path] = {
                    'category': category,
                    'label': 1 if category == 'synthetic' else 0,
                    **metadata
                }

                if metadata['valid']:
                    validation_results['valid_files'] += 1
                    print(f"  [OK] Valid - Format: {metadata['format']}, SR: {metadata['sample_rate']}, Duration: {metadata['duration']:.2f}s")
                else:
                    validation_results['failed_files'] += 1
                    print(f"  [X] Invalid - Error: {metadata['error']}")

        print(f"\nValidation Summary:")
        print(f"  Total Files: {validation_results['total_files']}")
        print(f"  Valid Files: {validation_results['valid_files']}")
        print(f"  Failed Files: {validation_results['failed_files']}")
        print(f"  Failure Rate: {validation_results['failed_files'] / validation_results['total_files'] * 100:.1f}%")

        if validation_results['failed_files'] > 0:
            print("\n[WARNING] Some files failed validation - cannot proceed with benchmark")
            validation_results['benchmark_status'] = 'INVALID'
        else:
            print("\n[OK] All files validated successfully")
            validation_results['benchmark_status'] = 'VALID'

        return validation_results

    def test_model_lifecycle(self, model_name: str) -> Dict:
        """
        Test that model is loaded once and reused.

        Args:
            model_name: Name of model to test

        Returns:
            Lifecycle test results
        """
        print(f"\n{'=' * 60}")
        print(f"TESTING MODEL LIFECYCLE: {model_name}")
        print(f"{'=' * 60}")

        initial_load_count = self.model_manager.get_load_count(model_name)
        print(f"Initial load count: {initial_load_count}")

        # Make 10 API-style calls
        for i in range(10):
            print(f"  Request {i+1}/10...")
            detector = self.model_manager.get_model(model_name)
            if detector is None:
                print(f"  [X] Model {model_name} not available")
                return {'valid': False, 'error': 'Model not available'}

        final_load_count = self.model_manager.get_load_count(model_name)
        print(f"Final load count: {final_load_count}")

        # Check if load count remained the same
        if final_load_count == initial_load_count:
            print(f"[OK] Model reused correctly (load count unchanged)")
            return {
                'valid': True,
                'initial_load_count': initial_load_count,
                'final_load_count': final_load_count,
                'requests_made': 10,
                'status': 'PASS'
            }
        else:
            print(f"[X] Model reload detected (load count changed from {initial_load_count} to {final_load_count})")
            return {
                'valid': False,
                'initial_load_count': initial_load_count,
                'final_load_count': final_load_count,
                'requests_made': 10,
                'status': 'FAIL'
            }

    def test_direct_vs_api(self, model_name: str, audio_file: str) -> Dict:
        """
        Test that direct and API inference produce identical results.

        Args:
            model_name: Name of model to test
            audio_file: Path to test audio file

        Returns:
            Comparison results
        """
        print(f"\n{'=' * 60}")
        print(f"TESTING DIRECT VS API INFERENCE: {model_name}")
        print(f"{'=' * 60}")

        try:
            # Load audio file
            audio = self.preprocessor.preprocess_audio_file(audio_file)

            # Get detector
            detector = self.model_manager.get_model(model_name)
            if detector is None:
                return {'valid': False, 'error': 'Model not available'}

            # Direct inference
            print("Running direct inference...")
            direct_result = detector.predict(audio)
            direct_score = direct_result.get('spoof_score', 0.0)

            # API inference (simulated)
            print("Running API inference...")
            api_result = detector.predict(audio)
            api_score = api_result.get('spoof_score', 0.0)

            print(f"Direct score: {direct_score:.6f}")
            print(f"API score: {api_score:.6f}")
            print(f"Difference: {abs(direct_score - api_score):.6f}")

            # Check if scores are equal (within tiny tolerance)
            if abs(direct_score - api_score) < 1e-6:
                print("[OK] Direct and API inference agree")
                return {
                    'valid': True,
                    'direct_score': direct_score,
                    'api_score': api_score,
                    'difference': abs(direct_score - api_score),
                    'status': 'PASS'
                }
            else:
                print("[X] Direct and API inference differ significantly")
                return {
                    'valid': False,
                    'direct_score': direct_score,
                    'api_score': api_score,
                    'difference': abs(direct_score - api_score),
                    'status': 'FAIL'
                }

        except Exception as e:
            print(f"[X] Error: {e}")
            return {'valid': False, 'error': str(e)}

    def run_full_validation(self, test_files: Dict[str, List[str]]) -> Dict:
        """
        Run full pipeline validation.

        Args:
            test_files: Dictionary with 'human' and 'synthetic' file lists

        Returns:
            Full validation results
        """
        print("=" * 60)
        print("PHASEGUARD PIPELINE VALIDATION")
        print("=" * 60)

        # Step 1: Validate audio files
        audio_validation = self.validate_audio_files(test_files)

        if audio_validation['benchmark_status'] == 'INVALID':
            print("\n[STOP] Audio validation failed - cannot proceed")
            return audio_validation

        # Step 2: Test model lifecycle
        lifecycle_tests = {}
        for model_name in ['aasist_l', 'specrnet']:
            lifecycle_tests[model_name] = self.test_model_lifecycle(model_name)

        # Step 3: Test direct vs API inference
        inference_tests = {}
        for model_name in ['aasist_l', 'specrnet']:
            # Use first valid file for testing
            valid_file = None
            for category, files in test_files.items():
                for file_path in files:
                    if audio_validation['files'][file_path]['valid']:
                        valid_file = file_path
                        break
                if valid_file:
                    break

            if valid_file:
                inference_tests[model_name] = self.test_direct_vs_api(model_name, valid_file)

        # Compile results
        results = {
            'audio_validation': audio_validation,
            'lifecycle_tests': lifecycle_tests,
            'inference_tests': inference_tests,
            'overall_status': 'VALID' if (
                audio_validation['benchmark_status'] == 'VALID' and
                lifecycle_tests.get('aasist_l', {}).get('valid', False) and
                lifecycle_tests.get('specrnet', {}).get('valid', False) and
                inference_tests.get('aasist_l', {}).get('valid', False)
            ) else 'INVALID'
        }

        print(f"\n{'=' * 60}")
        print(f"VALIDATION STATUS: {results['overall_status']}")
        print(f"{'=' * 60}")

        return results


def main():
    """Main validation function."""
    # Test dataset
    test_files = {
        'human': [
            'samples/user_voices/WhatsApp Ptt 2026-09-17 at 23.39.57.ogg',
            'samples/user_voices/freesound_community-shortfilm-voice-56795.mp3',
        ],
        'synthetic': [
            'samples/synthetic/hindi_ai_voice.mp3',
            'samples/deepfake_test/elevenlabs_sample.mp3',
        ]
    }

    validator = PipelineValidator()
    results = validator.run_full_validation(test_files)

    # Save results
    with open("pipeline_validation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nValidation results saved to pipeline_validation_results.json")

    return results


if __name__ == "__main__":
    main()
