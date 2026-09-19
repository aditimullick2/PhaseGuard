import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'offline_stt_service.dart';
import 'voiceshield_detector.dart';
import 'hybrid_scam_detector.dart';

/// OfflineFirstProcessor — Complete offline-first architecture.
///
/// Parallel Processing:
/// - Local processing runs immediately (always available)
/// - Web processing runs in parallel (when available)
/// - Merge results: Use web if available, otherwise use local
///
/// Offline-First Guarantee:
/// - If web unavailable → Use local results
/// - Local never fails → Always returns something
class OfflineFirstProcessor {
  final ApiClient _apiClient = ApiClient();
  final OfflineSttService _localStt = OfflineSttService();
  final VoiceShieldDetector _localDeepfake = VoiceShieldDetector();
  final HybridScamDetector _scamDetector = HybridScamDetector();
  
  bool _isProcessing = false;
  
  final StreamController<Map<String, dynamic>> _resultController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get resultStream => _resultController.stream;
  bool get isProcessing => _isProcessing;

  /// Initialize all local services.
  Future<void> initialize() async {
    debugPrint('OfflineFirstProcessor: Initializing local services...');
    
    // Initialize local STT
    await _localStt.initialize();
    
    // Initialize local deepfake
    await _localDeepfake.init();
    
    // Pre-warm scam detector
    await HybridScamDetector.prewarm();
    
    debugPrint('OfflineFirstProcessor: ✅ All local services initialized');
  }

  /// Process audio file with parallel local + web processing.
  Future<Map<String, dynamic>> processAudioFile(String filePath) async {
    if (_isProcessing) {
      debugPrint('OfflineFirstProcessor: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('OfflineFirstProcessor: Starting parallel processing for $filePath...');

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('OfflineFirstProcessor: File not found: $filePath');
        return {'error': 'File not found'};
      }

      // Read audio bytes
      final audioBytes = await file.readAsBytes();
      
      // Parallel processing: Local + Web
      final results = await Future.wait([
        _processLocal(audioBytes, filePath),
        _processWeb(filePath),
      ], eagerError: false);

      final localResult = results[0] as Map<String, dynamic>;
      final webResult = results[1] as Map<String, dynamic>?;

      // Merge results: Use web if available, otherwise use local
      final finalResult = _mergeResults(localResult, webResult);

      _resultController.add(finalResult);
      debugPrint('OfflineFirstProcessor: Processing complete ✅');
      
      return finalResult;
    } catch (e) {
      debugPrint('OfflineFirstProcessor: Processing error: $e');
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
      debugPrint('OfflineFirstProcessor: Already processing, please wait');
      return {'error': 'Already processing'};
    }

    try {
      _isProcessing = true;
      debugPrint('OfflineFirstProcessor: Processing ${audioBytes.length} bytes...');

      // Save to temp file for web processing
      final tempDir = Directory.systemTemp;
      final name = filename ?? 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final tempFile = File('${tempDir.path}/$name');
      await tempFile.writeAsBytes(audioBytes);
      
      debugPrint('OfflineFirstProcessor: Saved to ${tempFile.path}');

      // Parallel processing: Local + Web
      final results = await Future.wait([
        _processLocal(audioBytes, tempFile.path),
        _processWeb(tempFile.path),
      ], eagerError: false);

      final localResult = results[0] as Map<String, dynamic>;
      final webResult = results[1] as Map<String, dynamic>?;

      // Merge results: Use web if available, otherwise use local
      final finalResult = _mergeResults(localResult, webResult);
      
      // Cleanup temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return finalResult;
    } catch (e) {
      debugPrint('OfflineFirstProcessor: Bytes processing error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      _isProcessing = false;
    }
  }

  /// Local processing (always available).
  Future<Map<String, dynamic>> _processLocal(
    List<int> audioBytes,
    String filePath,
  ) async {
    try {
      debugPrint('OfflineFirstProcessor: Running local processing...');
      
      // Step 1: Local STT
      final transcript = await _localStt.transcribeAudioBytes(audioBytes);
      
      // Step 2: Local Deepfake Detection
      // Convert bytes to Int16List for VoiceShield
      final int16List = Int16List(audioBytes.length ~/ 2);
      for (int i = 0; i < int16List.length; i++) {
        int16List[i] = (audioBytes[i * 2] & 0xFF) | ((audioBytes[i * 2 + 1] & 0xFF) << 8);
      }
      
      final deepfakeResult = _localDeepfake.analyzeAudioBuffer(int16List);
      
      // Step 3: Local Scam Detection (if transcript available)
      Map<String, dynamic>? scamResult;
      if (transcript != null && transcript.isNotEmpty) {
        scamResult = await _scamDetector.detectScam(transcript);
      }
      
      return {
        'success': true,
        'source': 'local',
        'transcript': transcript,
        'deepfake': deepfakeResult,
        'scam': scamResult,
        'processing_time': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('OfflineFirstProcessor: Local processing error: $e');
      return {
        'success': false,
        'source': 'local',
        'error': e.toString(),
      };
    }
  }

  /// Web processing (when available).
  Future<Map<String, dynamic>?> _processWeb(String filePath) async {
    try {
      debugPrint('OfflineFirstProcessor: Running web processing...');
      
      // Step 1: Upload to backend for deepfake detection
      final deepfakeResult = await _apiClient.uploadAudioForAnalysis(filePath: filePath);
      
      if (!deepfakeResult['success']) {
        debugPrint('OfflineFirstProcessor: Web deepfake failed');
        return null;
      }
      
      // Step 2: Get transcript from backend STT
      final sttResult = await _apiClient.transcribeAudio(filePath: filePath);
      
      if (!sttResult['success']) {
        debugPrint('OfflineFirstProcessor: Web STT failed');
        return {
          'success': true,
          'source': 'web',
          'deepfake': deepfakeResult['deepfake_detection'],
          'transcript': null,
          'scam': null,
        };
      }
      
      // Step 3: Scam detection (local or web)
      final transcript = sttResult['transcript'] as String;
      final scamResult = await _scamDetector.detectScam(transcript);
      
      return {
        'success': true,
        'source': 'web',
        'transcript': transcript,
        'language': sttResult['language'],
        'deepfake': deepfakeResult['deepfake_detection'],
        'scam': scamResult,
        'processing_time': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('OfflineFirstProcessor: Web processing error: $e');
      return null; // Web unavailable is not an error
    }
  }

  /// Merge local and web results.
  /// Prefer web if available, otherwise use local.
  Map<String, dynamic> _mergeResults(
    Map<String, dynamic> localResult,
    Map<String, dynamic>? webResult,
  ) {
    if (webResult != null && webResult['success'] == true) {
      debugPrint('OfflineFirstProcessor: Using web result (preferred)');
      return {
        ...webResult,
        'fallback_used': false,
        'reason': 'Web processing successful',
      };
    } else {
      debugPrint('OfflineFirstProcessor: Using local result (web unavailable)');
      return {
        ...localResult,
        'fallback_used': true,
        'reason': webResult == null 
          ? 'Web unavailable' 
          : 'Web processing failed',
      };
    }
  }

  void dispose() {
    _resultController.close();
    _localStt.dispose();
    _localDeepfake.dispose();
  }
}
