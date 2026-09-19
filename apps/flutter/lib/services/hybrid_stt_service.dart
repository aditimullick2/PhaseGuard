import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';

/// HybridSttService — Hybrid Speech-to-Text (Local + Backend).
///
/// Strategy:
/// 1. Save audio files locally from Shizuku/capture
/// 2. Try backend STT when WiFi available
/// 3. Cache transcripts locally
/// 4. Use simple keyword matching as fallback
class HybridSttService {
  final ApiClient _apiClient = ApiClient();
  bool _isProcessing = false;
  
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isProcessing => _isProcessing;

  /// Directory for storing audio files
  Future<Directory> get _audioDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/captured_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Directory for storing transcripts
  Future<Directory> get _transcriptDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final transcriptDir = Directory('${appDir.path}/transcripts');
    if (!await transcriptDir.exists()) {
      await transcriptDir.create(recursive: true);
    }
    return transcriptDir;
  }

  /// Save audio from capture (Shizuku, Bluetooth, etc.)
  Future<String?> saveAudioFile(Uint8List audioBytes, {String? filename}) async {
    try {
      final audioDir = await _audioDir;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = filename ?? 'audio_$timestamp.wav';
      final file = File('${audioDir.path}/$name');
      
      await file.writeAsBytes(audioBytes);
      debugPrint('HybridSTT: Audio saved to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('HybridSTT: Error saving audio: $e');
      return null;
    }
  }

  /// Transcribe audio file (hybrid approach).
  Future<String?> transcribeAudioFile(String filePath) async {
    if (_isProcessing) {
      debugPrint('HybridSTT: Already processing, please wait');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('HybridSTT: Starting transcription for $filePath...');

      // Check if transcript already cached
      final cachedTranscript = await _getCachedTranscript(filePath);
      if (cachedTranscript != null) {
        debugPrint('HybridSTT: Using cached transcript');
        _transcriptController.add(cachedTranscript);
        return cachedTranscript;
      }

      // Try backend STT
      final transcript = await _transcribeWithBackend(filePath);

      if (transcript != null) {
        // Cache the transcript
        await _cacheTranscript(filePath, transcript);
        _transcriptController.add(transcript);
        debugPrint('HybridSTT: Transcript: $transcript');
      }

      return transcript;
    } catch (e) {
      debugPrint('HybridSTT: Transcription error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Transcribe using backend API.
  Future<String?> _transcribeWithBackend(String filePath) async {
    try {
      debugPrint('HybridSTT: Sending audio to backend...');

      // Call backend STT endpoint
      final response = await _apiClient.transcribeAudio(filePath: filePath);

      if (response['success'] == true) {
        final transcript = response['transcript'] as String?;
        debugPrint('HybridSTT: Backend transcription successful');
        return transcript;
      } else {
        debugPrint('HybridSTT: Backend transcription failed: ${response['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('HybridSTT: Backend STT error: $e');
      return null;
    }
  }

  /// Get cached transcript.
  Future<String?> _getCachedTranscript(String audioPath) async {
    try {
      final transcriptDir = await _transcriptDir;
      final filename = audioPath.split('/').last;
      final transcriptFile = File('${transcriptDir.path}/$filename.txt');
      
      if (await transcriptFile.exists()) {
        return await transcriptFile.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('HybridSTT: Error reading cache: $e');
      return null;
    }
  }

  /// Cache transcript.
  Future<void> _cacheTranscript(String audioPath, String transcript) async {
    try {
      final transcriptDir = await _transcriptDir;
      final filename = audioPath.split('/').last;
      final transcriptFile = File('${transcriptDir.path}/$filename.txt');
      
      await transcriptFile.writeAsString(transcript);
      debugPrint('HybridSTT: Transcript cached');
    } catch (e) {
      debugPrint('HybridSTT: Error caching transcript: $e');
    }
  }

  /// Simple keyword detection (offline fallback).
  Map<String, dynamic> detectKeywords(String transcript) {
    final scamKeywords = [
      'digital arrest', 'arrest warrant', 'police', 'cbi', 'income tax',
      'aadhaar', 'pan card', 'bank account', 'freeze', 'suspend',
      'electricity', 'disconnection', 'immediately', 'urgent',
      'money transfer', 'pay now', 'bank account',
    ];

    final transcriptLower = transcript.toLowerCase();
    int score = 0;
    List<String> matchedKeywords = [];

    for (final keyword in scamKeywords) {
      if (transcriptLower.contains(keyword)) {
        score += 10;
        matchedKeywords.add(keyword);
      }
    }

    return {
      'isScam': score >= 20,
      'score': score,
      'matchedKeywords': matchedKeywords,
    };
  }

  void dispose() {
    _transcriptController.close();
  }
}
