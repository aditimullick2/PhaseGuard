import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Voice Detection Result Model
class VoiceDetectionResult {
  final String status; // success, error, timeout, unavailable
  final String riskLevel; // SAFE, SUSPICIOUS, HIGH_RISK, UNKNOWN
  final double confidence;
  final bool isSynthetic;
  final String provider; // cloud, local, hybrid
  final int processingTimeMs;
  final String? errorMessage;

  VoiceDetectionResult({
    required this.status,
    required this.riskLevel,
    required this.confidence,
    required this.isSynthetic,
    required this.provider,
    required this.processingTimeMs,
    this.errorMessage,
  });

  factory VoiceDetectionResult.fromJson(Map<String, dynamic> json) {
    return VoiceDetectionResult(
      status: json['status'] as String? ?? 'unknown',
      riskLevel: json['riskLevel'] as String? ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isSynthetic: json['isSynthetic'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'unknown',
      processingTimeMs: json['processingTimeMs'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'riskLevel': riskLevel,
      'confidence': confidence,
      'isSynthetic': isSynthetic,
      'provider': provider,
      'processingTimeMs': processingTimeMs,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

/// Abstract Voice Detection Service Interface
/// This abstraction allows future local/hybrid providers without changing UI
abstract class VoiceDetectionService {
  Future<VoiceDetectionResult> analyzeAudio({
    required String callId,
    required String userId,
    required List<int> audioData,
    required int sampleRate,
    required int channels,
  });
  
  Future<VoiceDetectionResult> analyzeScamText({
    required String text,
  });
}

/// Backend-Only Voice Detection Service Implementation
/// All AI processing happens on the server, no local models
class BackendVoiceDetectionService implements VoiceDetectionService {
  final ApiClient _apiClient;
  
  BackendVoiceDetectionService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<VoiceDetectionResult> analyzeAudio({
    required String callId,
    required String userId,
    required List<int> audioData,
    required int sampleRate,
    required int channels,
  }) async {
    final startTime = DateTime.now();
    
    try {
      debugPrint('[BackendVoiceDetection] Analyzing audio: ${audioData.length} bytes, ${sampleRate}Hz, ${channels} channels');
      
      // Send audio to backend for analysis
      final result = await _apiClient.detectAudioBytes(audioBytes: audioData);
      
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      
      debugPrint('[BackendVoiceDetection] Analysis complete: ${result['status']}, ${processingTime}ms');
      
      return VoiceDetectionResult(
        status: result['status'] as String? ?? 'success',
        riskLevel: _mapRiskLevel(result),
        confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
        isSynthetic: result['is_spoof'] as bool? ?? false,
        provider: 'cloud',
        processingTimeMs: processingTime,
      );
    } catch (e) {
      debugPrint('[BackendVoiceDetection] Error: $e');
      return VoiceDetectionResult(
        status: 'error',
        riskLevel: 'UNKNOWN',
        confidence: 0.0,
        isSynthetic: false,
        provider: 'cloud',
        processingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<VoiceDetectionResult> analyzeScamText({
    required String text,
  }) async {
    final startTime = DateTime.now();
    
    try {
      debugPrint('[BackendVoiceDetection] Analyzing scam text: ${text.substring(0, 50)}...');
      
      // Send text to backend for analysis
      final result = await _apiClient.analyzeScamText(text);
      
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      
      debugPrint('[BackendVoiceDetection] Scam analysis complete: ${result['is_scam']}, ${processingTime}ms');
      
      return VoiceDetectionResult(
        status: 'success',
        riskLevel: result['is_scam'] == true ? 'HIGH_RISK' : 'SAFE',
        confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
        isSynthetic: false,
        provider: 'cloud',
        processingTimeMs: processingTime,
      );
    } catch (e) {
      debugPrint('[BackendVoiceDetection] Scam analysis error: $e');
      return VoiceDetectionResult(
        status: 'error',
        riskLevel: 'UNKNOWN',
        confidence: 0.0,
        isSynthetic: false,
        provider: 'cloud',
        processingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }
  
  String _mapRiskLevel(Map<String, dynamic> result) {
    final isSpoof = result['is_spoof'] as bool? ?? false;
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    
    if (isSpoof && confidence >= 0.7) {
      return 'HIGH_RISK';
    } else if (isSpoof && confidence >= 0.4) {
      return 'SUSPICIOUS';
    } else if (!isSpoof && confidence <= 0.3) {
      return 'SAFE';
    } else {
      return 'UNKNOWN';
    }
  }
}