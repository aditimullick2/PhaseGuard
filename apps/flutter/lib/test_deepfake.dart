import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:phaseguard/services/deepfake_detector_service.dart';

// Standalone test script to compare Local vs Web accuracy
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== DEEPFAKE DETECTOR ACCURACY TEST ===');
  
  final service = DeepfakeDetectorService();
  
  // Create 1 second of audio (16000 samples)
  // Let's generate a pure sine wave (Highly Synthetic/Artificial)
  print('\nGenerating synthetic audio (Pure 440Hz Sine Wave)...');
  final syntheticPcm = Int16List(16000);
  for (int i = 0; i < 16000; i++) {
    // 440 Hz sine wave
    double t = i / 16000.0;
    syntheticPcm[i] = (sin(2 * pi * 440 * t) * 32000).toInt();
  }
  
  print('\n1. Testing LOCAL Model (TFLite)...');
  try {
    // Note: We bypass analyze() to test the specific layer
    final localStream = service.analyze(syntheticPcm);
    await for (final result in localStream) {
       print('RESULT: \$result');
       break; // only need the first result
    }
  } catch (e) {
    print('Local test error: \$e');
  }
}
