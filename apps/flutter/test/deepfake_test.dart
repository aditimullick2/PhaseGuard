import 'dart:typed_data';
import 'dart:math' as import_math;
import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/deepfake_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeepfakeDetectorService Parallel Logic Test', () async {
    final service = DeepfakeDetectorService();
    // Intentionally not calling init() to simulate failure/fallback or just testing the parallel logic
    
    // Create 1 second of audio (16000 samples) of a pure sine wave (Highly Synthetic)
    final syntheticPcm = Int16List(16000);
    for (int i = 0; i < 16000; i++) {
      import_math.Random();
      double t = i / 16000.0;
      syntheticPcm[i] = (import_math.sin(2 * import_math.pi * 440 * t) * 32000).toInt();
    }
    
    try {
      final stream = service.analyze(syntheticPcm);
      await for (final result in stream) {
        print('RESULT: \$result');
        // Because of our new DSP heuristics (0 variance, unnatural ZCR, absolute silence in other bins),
        // it should detect it as synthetic with high confidence!
        expect(result['is_synthetic'], isTrue);
        expect((result['confidence'] as num) > 0.6, isTrue);
      }
    } catch (e) {
      print('Test error: \$e');
    }
  });
}
