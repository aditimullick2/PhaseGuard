import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ConnectCallSttService — STT for ConnectCall app
///
/// Uses backend STT (Groq Whisper) for transcription
/// Simpler architecture: Capture → Backend → Transcript
class ConnectCallSttService {
  static const String _baseUrl = 'http://localhost:8000';
  bool _isProcessing = false;
  
  final StreamController<String> _transcriptController =
      StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  bool get isProcessing => _isProcessing;

  /// Transcribe audio using backend STT
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    if (_isProcessing) {
      debugPrint('[ConnectCallSTT] Already processing, skipping...');
      return null;
    }

    try {
      _isProcessing = true;
      debugPrint('[ConnectCallSTT] Transcribing ${audioBytes.length} bytes...');

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(audioBytes);
      
      // Send to backend
      final uri = Uri.parse('$_baseUrl/api/stt/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', tempFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[ConnectCallSTT] Backend error: ${response.statusCode}');
        return null;
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final transcript = responseData['transcript'] as String?;

      if (transcript != null) {
        _transcriptController.add(transcript);
        debugPrint('[ConnectCallSTT] Transcript: $transcript');
      }

      // Cleanup
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return transcript;
    } catch (e) {
      debugPrint('[ConnectCallSTT] Error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Simple scam detection (keyword-based)
  Map<String, dynamic> detectScam(String transcript) {
    final scamKeywords = [
      'digital arrest',
      'bank freeze',
      'police',
      'cbi',
      'money',
      'paisa',
      'urgent',
      'emergency',
      'account',
      'otp',
      'verification',
    ];

    final transcriptLower = transcript.toLowerCase();
    int scamScore = 0;
    List<String> foundKeywords = [];

    for (final keyword in scamKeywords) {
      if (transcriptLower.contains(keyword)) {
        scamScore++;
        foundKeywords.add(keyword);
      }
    }

    final isScam = scamScore >= 2;

    return {
      'is_scam': isScam,
      'scam_score': scamScore,
      'found_keywords': foundKeywords,
      'confidence': (scamScore / scamKeywords.length).clamp(0.0, 1.0),
    };
  }

  void dispose() {
    _transcriptController.close();
  }
}
