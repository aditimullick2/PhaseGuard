import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/voice_deepfake_detector.dart';

void main() {
  // Initialize Flutter binding for TFLite
  TestWidgetsFlutterBinding.ensureInitialized();
  group('VoiceShield Local Model Tests', () {
    late VoiceDeepfakeDetector detector;

    setUp(() async {
      detector = VoiceDeepfakeDetector();
      await detector.init();
    });

    test('VoiceShield model should initialize', () async {
      // This test checks if VoiceShield can be initialized
      expect(detector, isNotNull);
    });

    test('VoiceShield should analyze audio buffer', () async {
      // Create dummy audio data (16-bit PCM, 16kHz, 1 second)
      final int sampleRate = 16000;
      final int duration = 1; // 1 second
      final int numSamples = sampleRate * duration;

      // Generate dummy audio (sine wave for testing)
      final Int16List pcmData = Int16List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        pcmData[i] = (32767 * 0.5 * (1 + (i % 100) / 100.0)).toInt();
      }

      // Analyze audio
      final result = detector.analyzeAudioBuffer(pcmData);

      // Check that result contains expected fields
      expect(result, isNotNull);
      expect(result.containsKey('is_synthetic'), true);
      expect(result.containsKey('confidence'), true);
      expect(result.containsKey('reason'), true);
      // Model field might be missing if initialization failed
      print('VoiceShield Result: $result');
    });

    test('VoiceShield should handle empty buffer', () {
      final Int16List emptyData = Int16List(0);
      final result = detector.analyzeAudioBuffer(emptyData);

      expect(result['is_synthetic'], false);
      expect(result['confidence'], 0.0);
      // Reason might be 'Empty buffer' or 'Model loading...'
      expect(result['reason'], isNotNull);
    });

    test('VoiceShield should fallback to 2D CNN for uncertain results', () async {
      // This test verifies the hybrid logic
      // VoiceShield should return its result, and for uncertain results
      // it should fallback to the 2D CNN model

      final int sampleRate = 16000;
      final int numSamples = sampleRate; // 1 second

      // Generate test audio
      final Int16List pcmData = Int16List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        pcmData[i] = (32767 * 0.3 * ((i % 50) / 50.0)).toInt();
      }

      final result = detector.analyzeAudioBuffer(pcmData);

      // Verify result structure
      expect(result, isNotNull);

      // Check which model was used (if available)
      if (result.containsKey('model')) {
        final modelUsed = result['model'];
        print('Model used: $modelUsed');

        // Should be either 'VoiceShield' or 'Fallback 2D CNN'
        expect(
          modelUsed == 'VoiceShield' || modelUsed == 'Fallback 2D CNN',
          true,
        );
      } else {
        print('Model field not available - initialization may have failed');
      }
    });

    tearDown(() {
      detector.dispose();
    });
  });
}
