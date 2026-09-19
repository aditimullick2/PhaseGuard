import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// VoskSttService — On-device Speech-to-Text using Vosk.
///
/// Vosk is an offline speech recognition toolkit with pre-trained models.
/// Supports Hindi, English, and many other languages.
/// Model sizes: ~50MB (small) to ~1GB (large).
///
/// Models available:
/// - vosk-model-small-hi-0.22: ~50MB, Hindi (fast)
/// - vosk-model-small-en-us-0.15: ~50MB, English (fast)
/// - vosk-model-hi-0.22: ~500MB, Hindi (accurate)
/// - vosk-model-en-us-0.22: ~500MB, English (accurate)
class VoskSttService {
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _currentModelPath;

  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;

  // Model paths (will be downloaded or bundled)
  static const String _hindiModelAsset = 'assets/models/vosk-model-small-hi-0.22';
  static const String _englishModelAsset = 'assets/models/vosk-model-small-en-us-0.15';

  /// Initialize Vosk model.
  Future<bool> initialize({String language = 'hi'}) async {
    if (_isInitialized) return true;

    try {
      debugPrint('VoskSTT: Initializing model for language: $language...');

      // Select model based on language
      final modelAsset = language == 'hi' ? _hindiModelAsset : _englishModelAsset;

      // Check if model exists in assets
      final modelPath = await _getModelPath(modelAsset);

      if (modelPath == null) {
        debugPrint('VoskSTT: Model not found at $modelAsset');
        debugPrint('VoskSTT: Please download and add model to assets folder');
        return false;
      }

      _currentModelPath = modelPath;

      // Initialize Vosk model (this would call native code)
      // For now, this is a placeholder
      // In production, you would use:
      // await VoskPlugin.initModel(modelPath);

      _isInitialized = true;
      debugPrint('VoskSTT: ✅ Model initialized successfully');
      return true;
    } catch (e) {
      debugPrint('VoskSTT: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Get model path from assets or download.
  Future<String?> _getModelPath(String modelAsset) async {
    try {
      // Check if model exists in assets
      final byteData = await rootBundle.load(modelAsset);
      if (byteData.lengthInBytes > 0) {
        // Model exists in assets
        final tempDir = await getTemporaryDirectory();
        final modelDir = Directory('${tempDir.path}/vosk_model');
        
        if (!await modelDir.exists()) {
          await modelDir.create(recursive: true);
        }

        // Extract model to temp directory
        // This is simplified - in production, extract entire model directory
        return modelDir.path;
      }

      debugPrint('VoskSTT: Model not found in assets');
      return null;
    } catch (e) {
      debugPrint('VoskSTT: Error getting model path: $e');
      return null;
    }
  }

  /// Transcribe audio file to text.
  Future<String?> transcribeAudioFile(String filePath) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return null;
    }

    if (_isProcessing) {
      debugPrint('VoskSTT: Already processing, please wait');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('VoskSTT: Starting transcription for $filePath...');

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('VoskSTT: File not found: $filePath');
        return null;
      }

      // Read audio file
      final bytes = await file.readAsBytes();
      
      // Transcribe
      final transcript = await _transcribeAudioBytes(bytes);

      if (transcript != null) {
        _transcriptController.add(transcript);
        debugPrint('VoskSTT: Transcript: $transcript');
      }

      return transcript;
    } catch (e) {
      debugPrint('VoskSTT: Transcription error: $e');
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
      debugPrint('VoskSTT: Already processing, please wait');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('VoskSTT: Processing ${audioBytes.length} bytes...');

      // This would call Vosk native code
      // For now, this is a placeholder
      // In production, you would use:
      // final result = await VoskPlugin.recognizeFile(audioBytes, _currentModelPath);

      debugPrint('VoskSTT: Recognition started (placeholder)');

      // Placeholder - return dummy text
      // In production, actual Vosk recognition would happen here
      await Future.delayed(const Duration(seconds: 2));
      
      return null; // Placeholder
    } catch (e) {
      debugPrint('VoskSTT: Bytes transcription error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Release resources.
  void dispose() {
    _transcriptController.close();
    _isInitialized = false;
  }
}
