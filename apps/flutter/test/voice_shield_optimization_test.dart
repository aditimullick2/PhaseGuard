import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/voiceshield_detector.dart';

void main() {
  // Initialize Flutter binding for TFLite
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceShield Optimization Tests', () {
    late VoiceShieldDetector detector;

    setUp(() async {
      detector = VoiceShieldDetector();
      await detector.init();
    });

    test('Test human voice detection', () async {
      // Test with a real human voice file
      final file = File('samples/user_voices/WhatsApp Ptt 2026-09-17 at 23.39.57.ogg');
      if (!file.existsSync()) {
        print("Human voice file not found, skipping test");
        return;
      }

      final bytes = await file.readAsBytes();
      // Convert to Int16List (assuming 16-bit PCM)
      final pcmData = Int16List.fromList(
        List.generate(bytes.length ~/ 2, (i) =>
          (bytes[i * 2] | (bytes[i * 2 + 1] << 8))
        )
      );

      final result = detector.analyzeAudioBuffer(pcmData);
      print('Human Voice Result: $result');

      // Expected: is_synthetic should be false
      expect(result['is_synthetic'], false, reason: 'Human voice should not be detected as synthetic');
    });

    test('Test synthetic voice detection', () async {
      // Test with synthetic voice file
      final file = File('samples/synthetic/ElevenLabs_2026-09-01T15_58_06_Kanika - Warm, Expressive and Natural_pvc_sp100_s50_sb75_se0_m2.mp3');
      if (!file.existsSync()) {
        print("Synthetic voice file not found, skipping test");
        return;
      }

      final bytes = await file.readAsBytes();
      // Convert to Int16List (assuming 16-bit PCM)
      final pcmData = Int16List.fromList(
        List.generate(bytes.length ~/ 2, (i) =>
          (bytes[i * 2] | (bytes[i * 2 + 1] << 8))
        )
      );

      final result = detector.analyzeAudioBuffer(pcmData);
      print('Synthetic Voice Result: $result');

      // Expected: is_synthetic should be true
      expect(result['is_synthetic'], true, reason: 'Synthetic voice should be detected as synthetic');
    });

    test('Test confidence range', () async {
      // Test that confidence is always between 0 and 1
      final int sampleRate = 16000;
      final int numSamples = sampleRate; // 1 second

      // Generate test audio
      final Int16List pcmData = Int16List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        pcmData[i] = (32767 * 0.3 * ((i % 50) / 50.0)).toInt();
      }

      final result = detector.analyzeAudioBuffer(pcmData);

      if (result['confidence'] != null) {
        expect(result['confidence'], greaterThanOrEqualTo(0.0));
        expect(result['confidence'], lessThanOrEqualTo(1.0));
      }
    });

    tearDown(() {
      detector.dispose();
    });
  });
}
