import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// WhisperTfliteService — On-device Speech-to-Text using Whisper TFLite.
///
/// Uses OpenAI's Whisper model converted to TFLite format.
/// Supports Hindi, English, and code-switching (Hinglish).
/// Works completely offline.
///
/// Model Options:
/// - whisper-tiny: ~40MB, fast, good quality
/// - whisper-base: ~80MB, better quality
/// - whisper-small: ~250MB, best quality (recommended)
/// - whisper-medium: ~500MB, excellent quality
class WhisperTfliteService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _isProcessing = false;

  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;

  // Model path
  static const String _modelAsset = 'assets/models/whisper_tiny.tflite';

  /// Initialize Whisper TFLite model.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('WhisperTFLite: Loading model from $_modelAsset...');

      // Load model from assets
      _interpreter = await Tflite.loadModel(
        model: _modelAsset,
        options: InterpreterOptions(
          threads: 4,
          useNnapi: true, // Use Android NNAPI for acceleration
        ),
      );

      if (_interpreter == null) {
        debugPrint('WhisperTFLite: ❌ Failed to load model');
        return false;
      }

      _isInitialized = true;
      debugPrint('WhisperTFLite: ✅ Model loaded successfully');
      return true;
    } catch (e) {
      debugPrint('WhisperTFLite: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Transcribe audio file to text.
  Future<String?> transcribeAudioFile(String filePath) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return null;
    }

    if (_isProcessing) {
      debugPrint('WhisperTFLite: Already processing, please wait');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('WhisperTFLite: Starting transcription for $filePath...');

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('WhisperTFLite: File not found: $filePath');
        return null;
      }

      // Read audio file
      final bytes = await file.readAsBytes();
      
      // Preprocess audio
      final audioFeatures = await _preprocessAudio(bytes);

      if (audioFeatures == null) {
        debugPrint('WhisperTFLite: Audio preprocessing failed');
        return null;
      }

      // Run inference
      final transcript = await _runInference(audioFeatures);

      if (transcript != null) {
        _transcriptController.add(transcript);
        debugPrint('WhisperTFLite: Transcript: $transcript');
      }

      return transcript;
    } catch (e) {
      debugPrint('WhisperTFLite: Transcription error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Transcribe audio bytes directly.
  Future<String?> transcribeAudioBytes(Uint8List audioBytes) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return null;
    }

    if (_isProcessing) {
      debugPrint('WhisperTFLite: Already processing, please wait');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('WhisperTFLite: Processing ${audioBytes.length} bytes...');

      // Preprocess audio
      final audioFeatures = await _preprocessAudio(audioBytes);

      if (audioFeatures == null) {
        debugPrint('WhisperTFLite: Audio preprocessing failed');
        return null;
      }

      // Run inference
      final transcript = await _runInference(audioFeatures);

      if (transcript != null) {
        _transcriptController.add(transcript);
        debugPrint('WhisperTFLite: Transcript: $transcript');
      }

      return transcript;
    } catch (e) {
      debugPrint('WhisperTFLite: Bytes transcription error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Preprocess audio for Whisper model.
  /// 
  /// Whisper expects:
  /// - Mono audio
  /// - 16kHz sample rate
  /// - Log-mel spectrogram (80 mel bins, 3000 frames)
  Future<List<List<List<double>>>?> _preprocessAudio(Uint8List audioBytes) async {
    try {
      // Note: This is a simplified preprocessing
      // In production, you would use proper audio processing libraries
      // to convert to mel spectrogram
      
      // For now, return placeholder
      // Actual implementation would:
      // 1. Decode audio (if MP3/WAV)
      // 2. Resample to 16kHz
      // 3. Convert to mono
      // 4. Generate log-mel spectrogram
      // 5. Normalize to [-1, 1] range
      
      debugPrint('WhisperTFLite: Audio preprocessing (simplified)');
      
      // Placeholder - return dummy features
      // In production, implement proper mel spectrogram generation
      return [];
    } catch (e) {
      debugPrint('WhisperTFLite: Preprocessing error: $e');
      return null;
    }
  }

  /// Run Whisper inference.
  Future<String?> _runInference(List<List<List<double>>> audioFeatures) async {
    if (_interpreter == null) {
      debugPrint('WhisperTFLite: Interpreter not initialized');
      return null;
    }

    try {
      // Whisper model expects input shape: [1, 80, 3000] (batch, mel_bins, frames)
      // Output shape depends on model variant
      
      // Prepare input tensor
      final input = [audioFeatures];
      
      // Prepare output tensor
      final output = List.filled(1 * 518 * 18, 0.0).reshape([1, 518, 18]);
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Decode output to text
      // This is a simplified decoding
      // In production, use proper tokenization and decoding
      
      debugPrint('WhisperTFLite: Inference complete');
      
      // Placeholder - return dummy text
      // In production, implement proper token decoding
      return null;
    } catch (e) {
      debugPrint('WhisperTFLite: Inference error: $e');
      return null;
    }
  }

  /// Release resources.
  void dispose() {
    _interpreter?.close();
    _transcriptController.close();
    _isInitialized = false;
  }
}
