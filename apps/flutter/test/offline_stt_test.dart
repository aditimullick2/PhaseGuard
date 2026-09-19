import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phaseguard/services/offline_stt_service.dart';

void main() {
  // Initialize Flutter binding for TFLite
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline STT Tests', () {
    late OfflineSttService offlineStt;

    setUp(() {
      offlineStt = OfflineSttService();
    });

    test('Initialize Whisper TFLite model', () async {
      print('Testing Whisper TFLite model initialization...');
      
      final initialized = await offlineStt.initialize();
      
      expect(initialized, isTrue, reason: 'Model should initialize successfully');
      expect(offlineStt.isInitialized, isTrue, reason: 'isInitialized should be true');
      
      print('✅ Model initialized successfully');
    });

    test('Check if model file exists', () async {
      print('Checking if Whisper TFLite model file exists...');
      
      final modelPath = 'assets/models/whisper_tiny_quant.tflite';
      final file = File(modelPath);
      
      final exists = await file.exists();
      
      print('Model file exists: $exists');
      if (exists) {
        final size = await file.length();
        print('Model file size: ${size / (1024 * 1024)} MB');
      }
      
      expect(exists, isTrue, reason: 'Model file should exist');
    });

    test('Transcribe dummy audio (mock test)', () async {
      print('Testing audio transcription with dummy data...');
      
      // First initialize
      await offlineStt.initialize();
      
      // Create dummy audio bytes (for testing only)
      final dummyAudio = Uint8List(16000); // 1 second of silence
      
      // This will fail because it's dummy data, but we test the flow
      final result = await offlineStt.transcribeAudioBytes(dummyAudio);
      
      print('Transcription result: $result');
      
      // For now, we expect null because dummy audio won't produce valid transcript
      // But the important thing is that the process doesn't crash
      print('✅ Transcription flow completed without crashing');
    });

    tearDown(() {
      offlineStt.dispose();
    });
  });
}
