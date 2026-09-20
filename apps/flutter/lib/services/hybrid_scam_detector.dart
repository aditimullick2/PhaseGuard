import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'scam_detector.dart';
import 'scam_detector_service.dart';
import '../config/app_config.dart';

/// PhaseGuard 3-Layer Scam Detection Engine
///
/// Layer 1 (Instant, <1ms, Offline): Keyword + rule-based matching via [ScamDetector]
///   → If keywordScore ≥ 3 (obvious scam) or score == 0 with strong legit signal → done.
///
/// Layer 2 (Local ML, ~100ms, Offline): TFLite dense-NN via [ScamDetectorService]
///   → Catches nuanced/indirect scam patterns missed by keywords.
///   → If model score > 0.70 (scam) or < 0.30 (safe) → done (confident).
///
/// Layer 3 (Web API, ~1–4s, Online): PhaseGuard backend factcheck API
///   → Only called when L1 + L2 are both uncertain (0.30–0.70 zone).
///   → Most powerful — uses Groq LLM + web search.
///   → Skipped entirely when offline or server unavailable.
///
/// Fallback guarantee: If ANY layer fails, the next layer takes over.
/// If ALL layers fail, returns the best available local result.
class HybridScamDetector {
  static String get _baseUrl => AppConfig.backendUrl;
  static const Duration _webTimeout = Duration(seconds: 6);

  // Singleton TFLite service — shared, pre-warmed
  static final ScamDetectorService _tfliteService = ScamDetectorService(
    serverBaseUrl: _baseUrl,
  );
  static bool _tfliteInitialized = false;

  /// Pre-warm the TFLite model (call once at app start / session start).
  static Future<void> prewarm() async {
    if (!_tfliteInitialized) {
      await _tfliteService.init();
      _tfliteInitialized = true;
      debugPrint('[HybridScamDetector] TFLite model pre-warmed ✅');
    }
  }

  /// Main 3-layer detection pipeline.
  /// Returns a unified result map with 'source', 'layer', 'is_scam', 'confidence', 'reasoning'.
  Future<Map<String, dynamic>> detectScam(String transcript) async {
    // ═══════════════════════════════════════════════════════
    // LAYER 1: Keyword-based (instant, always runs)
    // ═══════════════════════════════════════════════════════
    final keywordResult = ScamDetector.detectScam(transcript);
    debugPrint(
        '[L1-Keywords] scamScore=${keywordResult.scamScore} legitScore=${keywordResult.legitimateScore}');

    // Strong scam signal (≥3 keyword hits) → instant kill, no L2/L3 needed
    if (keywordResult.scamScore >= 3) {
      debugPrint('[L1-Keywords] ✅ Confident SCAM — skipping L2/L3');
      return {
        'is_scam': true,
        'category': keywordResult.category,
        'confidence': 0.95,
        'reasoning': '🔑 ${keywordResult.reasoning}',
        'source': 'keywords',
        'layer': 1,
      };
    }

    // Strong safe signal (0 keywords + legit indicators) → instant safe, no L2/L3
    if (keywordResult.scamScore == 0 && keywordResult.legitimateScore >= 2) {
      debugPrint('[L1-Keywords] ✅ Confident SAFE — skipping L2/L3');
      return {
        'is_scam': false,
        'category': 'NORMAL',
        'confidence': 0.05,
        'reasoning': '🔑 ${keywordResult.reasoning}',
        'source': 'keywords',
        'layer': 1,
      };
    }

    // ═══════════════════════════════════════════════════════
    // LAYER 2: TFLite Model (local ML, offline capable)
    // ═══════════════════════════════════════════════════════
    try {
      if (!_tfliteInitialized) await prewarm();

      final tfliteResult = await _tfliteService.analyze(transcript);
      debugPrint(
          '[L2-TFLite] layer=${tfliteResult.layer} conf=${tfliteResult.confidence.toStringAsFixed(3)}');

      // Only act on confident TFLite predictions (outside uncertain zone)
      if (tfliteResult.layer == 'tflite' || tfliteResult.layer == 'keyword') {
        debugPrint('[L2-TFLite] ✅ Confident result — skipping L3');
        return {
          'is_scam': tfliteResult.isScam,
          'category': tfliteResult.category,
          'confidence': tfliteResult.confidence,
          'reasoning': '🤖 ${tfliteResult.reasoning}',
          'source': 'tflite',
          'layer': 2,
        };
      }

      // TFLite is uncertain — fall through to L3 but keep L2 result as fallback
      debugPrint(
          '[L2-TFLite] ⚠️ Uncertain (conf=${tfliteResult.confidence.toStringAsFixed(2)}) — escalating to L3...');

      // ═════════════════════════════════════════════════════
      // LAYER 3: Web / Server API (most powerful, online only)
      // ═════════════════════════════════════════════════════
      final webResult = await _tryWebApi(transcript);
      if (webResult != null) {
        debugPrint('[L3-Web] ✅ Server verdict received');
        return {
          ...webResult,
          'source': 'web',
          'layer': 3,
        };
      }

      // L3 unavailable → use L2 result (honest uncertainty)
      debugPrint('[L3-Web] ❌ Server unavailable — using L2 fallback');
      return {
        'is_scam': tfliteResult.isScam,
        'category': tfliteResult.isScam ? 'POSSIBLE_SCAM' : 'LIKELY_SAFE',
        'confidence': tfliteResult.confidence,
        'reasoning':
            '🤖 ${tfliteResult.reasoning} (server offline — unverified)',
        'source': 'tflite_fallback',
        'layer': 2,
      };
    } catch (e) {
      debugPrint('[L2-TFLite] ❌ Error: $e — trying L3 directly...');

      // L2 failed → try L3 directly
      try {
        final webResult = await _tryWebApi(transcript);
        if (webResult != null) {
          debugPrint('[L3-Web] ✅ Server verdict (L2 bypassed due to error)');
          return {
            ...webResult,
            'source': 'web',
            'layer': 3,
          };
        }
      } catch (_) {}

      // All layers failed → L1 keyword result as last resort
      debugPrint('[HybridScamDetector] ⚠️ All layers failed — L1 fallback');
      return {
        'is_scam': keywordResult.isScam,
        'category': keywordResult.category,
        'confidence': keywordResult.isScam ? 0.6 : 0.4,
        'reasoning':
            '🔑 ${keywordResult.reasoning} (L2/L3 unavailable)',
        'source': 'keyword_fallback',
        'layer': 1,
      };
    }
  }

  /// Call the PhaseGuard backend `/api/scam/analyze` endpoint.
  Future<Map<String, dynamic>?> _tryWebApi(String transcript) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/scam/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': transcript}),
          )
          .timeout(_webTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'is_scam': data['is_scam'] as bool? ?? false,
          'category': data['category'] as String? ?? 'UNKNOWN',
          'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.5,
          'reasoning':
              '🌐 ${data['reasoning'] as String? ?? 'Server AI analysis'}',
        };
      }
      debugPrint('[L3-Web] Server responded ${response.statusCode}');
    } catch (e) {
      debugPrint('[L3-Web] Request failed: $e');
    }
    return null;
  }
}