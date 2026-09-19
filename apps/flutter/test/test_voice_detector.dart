import 'dart:typed_data';
import 'dart:math';
import '../lib/services/voice_deepfake_detector.dart';

void main() {
  final detector = VoiceDeepfakeDetector(sampleRate: 16000);
  
  // 1. Generate Synthetic-like Audio (Pure Sine Wave, very smooth phase, no tremors)
  // This simulates a highly synthetic signal
  Int16List syntheticAudio = Int16List(16000); // 1 second
  for (int i = 0; i < 16000; i++) {
    // 400 Hz sine wave
    double sample = sin(2 * pi * 400 * i / 16000) * 32767;
    syntheticAudio[i] = sample.toInt();
  }
  
  // 2. Generate Human-like Audio (Noisy, jittery, with low frequency tremors)
  Int16List humanAudio = Int16List(16000);
  final rand = Random();
  for (int i = 0; i < 16000; i++) {
    // Base 400 Hz sine wave
    double base = sin(2 * pi * 400 * i / 16000);
    // Add 10 Hz tremor (amplitude modulation)
    double tremor = 1.0 + 0.5 * sin(2 * pi * 10 * i / 16000);
    // Add high frequency random phase noise
    double noise = (rand.nextDouble() * 2 - 1) * 0.5;
    
    double sample = (base * tremor + noise) * 16000;
    humanAudio[i] = sample.toInt();
  }

  print('=== TEST 1: SYNTHETIC AUDIO (Smooth Sine Wave) ===');
  // Feed it a few times to fill the history buffers
  Map<String, dynamic> res1 = {};
  for(int i=0; i<10; i++) {
    res1 = detector.analyzeAudioBuffer(syntheticAudio);
  }
  print(res1);
  
  print('\n=== TEST 2: HUMAN AUDIO (Noisy + 10Hz Tremor) ===');
  Map<String, dynamic> res2 = {};
  for(int i=0; i<10; i++) {
    res2 = detector.analyzeAudioBuffer(humanAudio);
  }
  print(res2);
}
