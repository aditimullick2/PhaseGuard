import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'hybrid_scam_detector.dart';
import 'hybrid_stt_service.dart';

/// UnifiedAudioProcessor — Complete audio processing pipeline.
///
/// Flow:
/// 1. Shizuku/Bluetooth/Accessibility captures audio
/// 2. Send to backend for deepfake detection
/// 3. Get transcript from backend STT
/// 4. Run local scam detection (3-layer)
/// 5. Return complete analysis
class UnifiedAudioProcessor {
  final ApiClient _apiClient = ApiClient();
  final HybridSttService _sttService = HybridSttService();
  final HybridScamDetector _scamDetector = HybridScamDetector();
  
  bool _isProcessing = false;
  
  final StreamController<Map<String, dynamic>> _resultController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get resultStream => _resultController.stream;
  bool get isProcessing => _isProcessing;

  /// Process audio file through complete pipeline.
  Future<Map<String, dynamic>> processAudioFile(String filePath) async {
    if (_isProcessing) {
      debugPrint('UnifiedProcessor: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('UnifiedProcessor: Starting pipeline for $filePath...');

      // Step 1: Upload to backend for deepfake detection
      debugPrint('UnifiedProcessor: Step 1 - Deepfake detection...');
      final deepfakeResult = await _apiClient.uploadAudioForAnalysis(filePath: filePath);
      
      if (!deepfakeResult['success']) {
        debugPrint('UnifiedProcessor: Deepfake detection failed');
        return {
          'success': false,
          'error': 'Deepfake detection failed',
          'deepfake': deepfakeResult,
        };
      }

      // Step 2: Get transcript from backend STT
      debugPrint('UnifiedProcessor: Step 2 - STT transcription...');
      final sttResult = await _apiClient.transcribeAudio(filePath: filePath);
      
      if (!sttResult['success']) {
        debugPrint('UnifiedProcessor: STT failed');
        return {
          'success': false,
          'error': 'STT failed',
          'deepfake': deepfakeResult,
        };
      }

      final transcript = sttResult['transcript'] as String;
      debugPrint('UnifiedProcessor: Transcript: $transcript');

      // Step 3: Run local scam detection (3-layer)
      debugPrint('UnifiedProcessor: Step 3 - Local scam detection...');
      await HybridScamDetector.prewarm();
      final scamResult = await _scamDetector.detectScam(transcript);
      
      debugPrint('UnifiedProcessor: Scam detection: ${scamResult['is_scam']}');

      // Step 4: Compile complete result
      final completeResult = {
        'success': true,
        'transcript': transcript,
        'language': sttResult['language'],
        'deepfake': deepfakeResult['deepfake_detection'],
        'scam': scamResult,
        'processing_time': DateTime.now().toIso8601String(),
      };

      _resultController.add(completeResult);
      debugPrint('UnifiedProcessor: Pipeline complete ✅');
      
      return completeResult;
    } catch (e) {
      debugPrint('UnifiedProcessor: Pipeline error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      _isProcessing = false;
    }
  }

  /// Process audio bytes directly (from Shizuku real-time).
  Future<Map<String, dynamic>> processAudioBytes(
    List<int> audioBytes, {
    String? filename,
  }) async {
    if (_isProcessing) {
      debugPrint('UnifiedProcessor: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('UnifiedProcessor: Processing ${audioBytes.length} bytes...');

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final name = filename ?? 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final tempFile = File('${tempDir.path}/$name');
      await tempFile.writeAsBytes(audioBytes);
      
      debugPrint('UnifiedProcessor: Saved to ${tempFile.path}');

      // Process through pipeline
      final result = await processAudioFile(tempFile.path);
      
      // Cleanup temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result;
    } catch (e) {
      debugPrint('UnifiedProcessor: Bytes processing error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _resultController.close();
  }
}
