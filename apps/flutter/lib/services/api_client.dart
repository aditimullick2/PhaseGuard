import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/protocol.dart';
import '../config/app_config.dart';

/// Backend-only architecture - uses local backend URL from config
class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.backendUrl;

  final String baseUrl;

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Health check to keep the backend alive and check connectivity
  Future<bool> healthCheck() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<CallInitResult> initCall({String? callerNumber}) async {
    final body = <String, dynamic>{
      'ingestion_mode': 'browser_mic',
      if (callerNumber != null && callerNumber.isNotEmpty)
        'caller_number': callerNumber,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/call/init'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('Timeout', 408),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Call init failed (${res.statusCode})');
    }
    return CallInitResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> refreshToken({
    required String callId,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/refresh-token'),
      headers: _headers(token: token),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => http.Response('Timeout', 408),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Token refresh failed (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<EscalationDraft> draftEscalation({
    required String callId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/escalate/draft'),
      headers: _headers(token: token),
      body: jsonEncode({'format': 'webhook'}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Draft escalation failed');
    }
    return EscalationDraft.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> confirmEscalation({
    required String callId,
    required String token,
    required String draftId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/escalate/confirm'),
      headers: _headers(token: token),
      body: jsonEncode({'draft_id': draftId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Confirm escalation failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<CallStatus> getCallStatus({
    required String callId,
    required String token,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/call/$callId/status'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Status fetch failed');
    }
    return CallStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Rewrite init `ws_url` (often an internal host) onto the public WSS origin.
  String websocketUrl(CallInitResult init) {
    return '$baseUrl/ws/call/${init.callId}?token=${Uri.encodeQueryComponent(init.token)}'
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  /// Upload a video frame for forensic analysis
  Future<Map<String, dynamic>> uploadFrame({
    required String callId,
    required String token,
    required List<int> frameBytes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/frame'),
      headers: _headers(token: token),
      body: frameBytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Frame upload failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Activate AI scambaiter for the call
  Future<Map<String, dynamic>> activateScambaiter({
    required String callId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/scambait'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // The API returns 409 if already active or wrong state. Return it for handling.
      if (res.statusCode == 409) return jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(_detail(res) ?? 'Scambaiter activation failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Analyze scam text using the PhaseGuard backend (Layer 3 fallback)
  Future<Map<String, dynamic>> analyzeScamText(String text) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/scam/analyze'),
      headers: _headers(),
      body: jsonEncode({'text': text, 'include_reasoning': true}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Scam analysis failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Analyze deepfake audio using backend DSP layer
  Future<Map<String, dynamic>> analyzeDeepfake(List<int> audioBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/deepfake/analyze'));
    request.files.add(
      http.MultipartFile.fromBytes('audio', audioBytes, filename: 'audio_sample.wav'),
    );
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Deepfake analysis failed (${response.statusCode})');
    }
    final res = await http.Response.fromStream(response);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Inject speech text to trigger STT, fact-checker and scambaiter
  Future<Map<String, dynamic>> injectSpeech({
    required String callId,
    required String token,
    required String text,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/test_inject?text=${Uri.encodeQueryComponent(text)}'),
      headers: _headers(token: token),
      body: jsonEncode({}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Speech injection failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Generate AI voice using backend TTS service
  /// Returns audio bytes (MP3/WAV format) for Agora injection
  Future<Uint8List?> textToSpeech(String text) async {
    try {
      debugPrint('[ApiClient] Generating AI voice for: $text');
      
      // Try Fish first, then fallback to Sonex, Sarvam, and finally gTTS
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/voice/tts'),
        headers: _headers(),
        body: jsonEncode({
          'text': text,
          'voice_id': 'default', // Use default voice or user's voice ID
          'format': 'mp3', // MP3 format (gTTS fallback uses MP3)
          'provider': 'auto', // Auto-selects: Fish → Sonex → Sarvam → gTTS
        }),
      );

      if (res.statusCode == 200) {
        final audioBytes = res.bodyBytes;
        debugPrint('[ApiClient] AI voice generated: ${audioBytes.length} bytes');
        return audioBytes;
      } else {
        debugPrint('[ApiClient] TTS request failed: ${res.statusCode} - ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[ApiClient] Error generating AI voice: $e');
      return null;
    }
  }

  /// Download forensic PDF dossier for a call
  Future<List<int>> getDossier({
    required String callId,
    required String token,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/call/$callId/dossier'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Dossier download failed');
    }
    return res.bodyBytes;
  }

  /// Transcribe audio file using backend STT (Groq Whisper)
  Future<Map<String, dynamic>> transcribeAudio({
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/stt/transcribe');
      final request = http.MultipartRequest('POST', uri);
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException('Audio file not found: $filePath');
      }
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('STT transcription failed (${response.statusCode})');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException('STT transcription error: $e');
    }
  }

  /// Upload audio for backend analysis (deepfake detection, company verification)
  Future<Map<String, dynamic>> uploadAudioForAnalysis({
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/audio/upload');
      final request = http.MultipartRequest('POST', uri);
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException('Audio file not found: $filePath');
      }
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('Audio upload failed (${response.statusCode})');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException('Audio upload error: $e');
    }
  }

  /// Get call history with optional limit
  Future<List<Map<String, dynamic>>> getCallHistory({
    required String token,
    int limit = 50,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/calls/history?limit=$limit'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Call history fetch failed');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Continue monitoring a call
  Future<Map<String, dynamic>> continueMonitoring({
    required String callId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/$callId/monitor'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Continue monitoring failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Block and report a call (when endpoint is available)
  /// Currently not on API, but leaving stub for future use
  Future<Map<String, dynamic>> blockAndReport({
    required String callId,
    required String token,
    required String reason,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/$callId/block-report'),
      headers: _headers(token: token),
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Block and report failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Voice/TTS API Methods ─────────────────────────────────────────────────────

  /// Enroll a voice sample for cloning
  Future<Map<String, dynamic>> enrollVoice({
    required String displayName,
    required List<int> audioBytes,
    String fileName = 'voice_sample.wav',
    bool enhanceQuality = true,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/voice/enroll'));
    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: fileName,
    ));
    request.fields['display_name'] = displayName;
    request.fields['enhance_quality'] = enhanceQuality.toString();

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detailFromJson(body) ?? 'Voice enrollment failed');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Synthesize text to speech
  Future<List<int>> synthesize({
    required String text,
    String? voiceId,
    String format = 'mp3',
    String provider = 'auto',
  }) async {
    final body = <String, dynamic>{
      'text': text,
      'format': format,
      'provider': provider,
    };
    if (voiceId != null) {
      body['voice_id'] = voiceId;
    }

    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/voice/tts'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'TTS synthesis failed');
    }
    return res.bodyBytes;
  }

  /// Stream text to speech
  Future<http.StreamedResponse> streamVoice({
    required String text,
    String? voiceId,
    String format = 'mp3',
    String provider = 'auto',
  }) async {
    final body = <String, dynamic>{
      'text': text,
      'format': format,
      'provider': provider,
    };
    if (voiceId != null) {
      body['voice_id'] = voiceId;
    }

    final request = http.Request('POST', Uri.parse('$baseUrl/api/v1/voice/stream'))
      ..headers.addAll(_headers())
      ..body = jsonEncode(body);

    final res = await request.send();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Voice streaming failed: ${res.statusCode}');
    }
    return res;
  }

  /// List enrolled voice profiles
  Future<List<Map<String, dynamic>>> listVoices() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/voice/voices'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'List voices failed');
    }
    final body = jsonDecode(res.body) as List;
    return body.cast<Map<String, dynamic>>();
  }

  /// Delete a voice profile
  Future<Map<String, dynamic>> deleteVoice({
    required String voiceId,
  }) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/voice/voices/$voiceId'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Delete voice failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Check voice service health
  Future<Map<String, dynamic>> voiceHealthCheck() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/voice/health'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Voice health check failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Multi-Detector Fallback API Methods ───────────────────────────────────────

  /// Detect if audio is synthetic/real using multi-detector fallback
  /// Fallback chain: Vocalyx → final-voice-deepfake → VoiceGuard Pro → VoiceShield Local
  Future<Map<String, dynamic>> detectAudio({
    required List<int> audioBytes,
    String fileName = 'audio.wav',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/multi-detector/detect'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioBytes,
      filename: fileName,
    ));

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detailFromJson(body) ?? 'Multi-detector detection failed');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Detect if audio is synthetic/real from bytes directly
  Future<Map<String, dynamic>> detectAudioBytes({
    required List<int> audioBytes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/multi-detector/detect/bytes'),
      headers: _headers(),
      body: audioBytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Multi-detector detection from bytes failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Get availability status of all detectors
  Future<Map<String, dynamic>> getDetectorStatus() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/multi-detector/status'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Detector status check failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Get information about available detectors
  Future<Map<String, dynamic>> getDetectorInfo() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/multi-detector/info'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Detector info fetch failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Escalate directly to National Cyber Crime Portal (1930)
  Future<Map<String, dynamic>> escalateToCybercell({
    required String callId,
    required String token,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/call/$callId/escalate/cybercell'),
      headers: _headers(token: token),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(res) ?? 'Cybercell escalation failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String? _detail(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return null;
  }

  String? _detailFromJson(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['detail'] != null) {
        return json['detail'].toString();
      }
    } catch (_) {}
    return null;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
