import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'voice_deepfake_detector.dart';

class ParallelDeepfakeDetector {
  final VoiceDeepfakeDetector _localDetector;
  final String _webApiUrl;

  ParallelDeepfakeDetector({this._webApiUrl = 'http://localhost:8000/api/deepfake/analyze-specrnet'})
      : _localDetector = VoiceDeepfakeDetector();

  Future<void> init() async {
    await _localDetector.init();
  }

  /// Analyze audio in parallel on both mobile and web
  /// Returns whichever result comes first (race condition)
  Future<Map<String, dynamic>> analyzeParallel(Int16List pcmData) async {
    // Start both analyses in parallel
    final localFuture = _localDetector.analyzeAudioBuffer(pcmData);
    final webFuture = _analyzeOnWeb(pcmData);

    // Wait for first result
    final results = await Future.any([localFuture, webFuture]);

    print("Result source: ${results['source']}");
    return results;
  }

  /// Analyze on web (SpecRNet)
  Future<Map<String, dynamic>> _analyzeOnWeb(Int16List pcmData) async {
    try {
      // Convert Int16List to bytes
      final bytes = _pcmToBytes(pcmData);

      // Send to web API
      final request = http.MultipartRequest('POST', Uri.parse(_webApiUrl));
      request.files.add(http.MultipartFile.fromBytes('audio', bytes));

      final response = await request.send().timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final result = jsonDecode(responseBody) as Map<String, dynamic>;
        result['source'] = 'web';
        return result;
      } else {
        throw Exception('Web API failed: ${response.statusCode}');
      }
    } catch (e) {
      print("Web analysis failed: $e");
      // Return error result
      return {
        'is_synthetic': false,
        'confidence': 0.0,
        'error': str(e),
        'source': 'web_error'
      };
    }
  }

  /// Convert Int16List PCM data to bytes
  List<int> _pcmToBytes(Int16List pcmData) {
    final bytes = <int>[];
    for (int i = 0; i < pcmData.length; i++) {
      // Convert Int16 to bytes (little-endian)
      final value = pcmData[i];
      bytes.add(value & 0xFF);
      bytes.add((value >> 8) & 0xFF);
    }
    return bytes;
  }

  void dispose() {
    _localDetector.dispose();
  }
}
