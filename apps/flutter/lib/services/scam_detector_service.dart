import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'scam_detector.dart';

/// PhaseGuard 3-Layer Scam Text Detector
///
/// Layer 1 (Instant, Offline): Keyword pattern matching
///   → Returns in <1ms with no ML overhead.
///   → Catches obvious scams (OTP, block account, CBI, etc.)
///   → If CONFIRMED scam (score ≥ 3) or CONFIRMED clean (score = 0) → done.
///
/// Layer 2 (Local ML, Offline): TFLite 3-layer Dense NN (TF-IDF)
///   → Runs on-device in ~100ms.
///   → Catches nuanced, indirect, and "twisted" scam patterns.
///   → If confident (>0.70 or <0.30) → done.
///
/// Layer 3 (Server Fallback): PhaseGuard AI factcheck API
///   → Called only when both Layer 1 and 2 are uncertain.
///   → Uses full LLM/factcheck pipeline on server.
///   → Falls back to Layer 2 result if server unavailable.

class ScamDetectorService {
  final String serverBaseUrl;

  Interpreter? _interpreter;
  Map<String, dynamic>? _metadata;
  Map<String, int>? _vocab;
  List<double>? _idfWeights;
  bool _isModelReady = false;

  static const double _highConfidenceThreshold = 0.70;
  static const double _lowConfidenceThreshold = 0.30;
  static const int _keywordConfirmedScam = 3;

  ScamDetectorService({
    this.serverBaseUrl = 'http://10.0.2.2:8000',
  });

  Future<void> init() async {
    if (_isModelReady) return;
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/scam_detector.tflite',
      );

      // Load vocabulary + IDF from metadata JSON
      final metaStr = await rootBundle.loadString(
        'assets/models/tflite_metadata.json',
      );
      _metadata = jsonDecode(metaStr) as Map<String, dynamic>;
      _vocab = Map<String, int>.from(
        (_metadata!['vocabulary'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
      _idfWeights = List<double>.from(
        (_metadata!['idf_weights'] as List).map((e) => (e as num).toDouble()),
      );

      _isModelReady = true;
      print('[ScamDetector] TFLite model + vocabulary loaded ✅ (${_vocab!.length} tokens)');
    } catch (e) {
      print('[ScamDetector] Failed to load model: $e');
    }
  }

  // ─── PUBLIC ENTRY POINT ────────────────────────────────────────────────────

  /// Analyze text using 3-layer pipeline.
  Future<ScamAnalysisResult> analyze(String text) async {
    if (!_isModelReady) await init();

    final normalizedText = _normalize(text);

    // ── LAYER 1: Keyword Matching ──────────────────────────────────────────
    final keywordResult = _runKeywordLayer(normalizedText);
    print('[ScamDetector] L1 keyword score: ${keywordResult.keywordScore}');

    // Hard confirmed: ≥ 3 STRONG scam keywords → immediate alert
    if (keywordResult.keywordScore >= _keywordConfirmedScam) {
      return ScamAnalysisResult(
        isScam: true,
        confidence: 1.0,
        layer: 'keyword',
        category: keywordResult.category,
        reasoning: keywordResult.reasoning,
        keywordScore: keywordResult.keywordScore,
      );
    }

    // Hard confirmed clean: 0 keywords AND legitimateScore ≥ 2 → safe
    if (keywordResult.keywordScore == 0 && keywordResult.legitimateScore >= 2) {
      return ScamAnalysisResult(
        isScam: false,
        confidence: 0.0,
        layer: 'keyword',
        category: 'SAFE',
        reasoning: 'No scam keywords detected. Legitimate indicators present.',
        keywordScore: 0,
      );
    }

    // ── LAYER 2: TFLite Model ──────────────────────────────────────────────
    final mlResult = _runModelLayer(normalizedText);
    print('[ScamDetector] L2 model confidence: ${mlResult.toStringAsFixed(3)}');

    // Confident scam
    if (mlResult > _highConfidenceThreshold) {
      return ScamAnalysisResult(
        isScam: true,
        confidence: mlResult,
        layer: 'tflite',
        category: 'SCAM_DETECTED',
        reasoning: 'TFLite neural network flagged this as a scam (${(mlResult * 100).toStringAsFixed(1)}% confidence)',
        keywordScore: keywordResult.keywordScore,
      );
    }

    // Confident clean
    if (mlResult < _lowConfidenceThreshold) {
      return ScamAnalysisResult(
        isScam: false,
        confidence: mlResult,
        layer: 'tflite',
        category: 'SAFE',
        reasoning: 'TFLite model: Clean conversation (${((1 - mlResult) * 100).toStringAsFixed(1)}% safe confidence)',
        keywordScore: keywordResult.keywordScore,
      );
    }

    // ── LAYER 3: Server Fallback (uncertain zone) ──────────────────────────
    print('[ScamDetector] L2 uncertain (${mlResult.toStringAsFixed(2)}) → escalating to server Layer 3...');
    try {
      final serverResult = await _runServerLayer(text);
      if (serverResult != null) {
        return ScamAnalysisResult(
          isScam: serverResult['is_scam'] as bool,
          confidence: (serverResult['confidence'] as num).toDouble(),
          layer: 'server',
          category: serverResult['category'] as String? ?? 'UNKNOWN',
          reasoning: serverResult['reasoning'] as String? ?? 'Server AI analysis',
          keywordScore: keywordResult.keywordScore,
        );
      }
    } catch (e) {
      print('[ScamDetector] Server fallback failed: $e → using L2 result');
    }

    // Server unavailable → return L2 result with honest uncertainty
    return ScamAnalysisResult(
      isScam: mlResult >= 0.50,
      confidence: mlResult,
      layer: 'tflite_fallback',
      category: mlResult >= 0.50 ? 'POSSIBLE_SCAM' : 'LIKELY_SAFE',
      reasoning: 'Uncertain: TFLite score=${mlResult.toStringAsFixed(2)}. '
          'Keyword hits=${keywordResult.keywordScore}. Server offline.',
      keywordScore: keywordResult.keywordScore,
    );
  }

  // ─── LAYER 1: KEYWORD ──────────────────────────────────────────────────────

  _KeywordLayerResult _runKeywordLayer(String text) {
    final result = ScamDetector.detectScam(text);
    return _KeywordLayerResult(
      keywordScore: result.scamScore,
      legitimateScore: result.legitimateScore,
      category: result.category,
      reasoning: result.reasoning,
    );
  }

  // ─── LAYER 2: TFLITE ───────────────────────────────────────────────────────

  double _runModelLayer(String text) {
    if (!_isModelReady || _interpreter == null || _vocab == null || _idfWeights == null) {
      return 0.5; // Unknown → trigger server fallback
    }

    try {
      // TF-IDF vectorization (mirrors Python training pipeline)
      final tokens = text.split(RegExp(r'\s+'));
      final tf = <String, double>{};
      for (final token in tokens) {
        if (_vocab!.containsKey(token)) {
          tf[token] = (tf[token] ?? 0.0) + 1.0;
        }
      }

      // Bigrams
      for (int i = 0; i < tokens.length - 1; i++) {
        final bigram = '${tokens[i]} ${tokens[i + 1]}';
        if (_vocab!.containsKey(bigram)) {
          tf[bigram] = (tf[bigram] ?? 0.0) + 1.0;
        }
      }

      // Normalize TF + apply IDF → build input vector
      final int vocabSize = _vocab!.length;
      final Float32List tfidfVector = Float32List(vocabSize);
      final double totalTokens = tokens.length.toDouble();

      tf.forEach((token, count) {
        final int? idx = _vocab![token];
        if (idx != null && idx < vocabSize) {
          final double tfScore = count / totalTokens;
          final double idf = _idfWeights![idx];
          tfidfVector[idx] = tfScore * idf;
        }
      });

      // L2 normalize
      double norm = 0.0;
      for (int i = 0; i < vocabSize; i++) { norm += tfidfVector[i] * tfidfVector[i]; }
      norm = norm > 0 ? norm : 1.0;
      for (int i = 0; i < vocabSize; i++) { tfidfVector[i] /= norm; }

      var input = tfidfVector.reshape([1, vocabSize]);
      var output = List.filled(1, List.filled(1, 0.0)).reshape([1, 1]);
      _interpreter!.run(input, output);

      return (output[0][0] as double).clamp(0.0, 1.0);
    } catch (e) {
      print('[ScamDetector] Layer 2 error: $e');
      return 0.5;
    }
  }

  // ─── LAYER 3: SERVER ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _runServerLayer(String text) async {
    final uri = Uri.parse('$serverBaseUrl/api/scam/analyze');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    print('[ScamDetector] Server returned ${response.statusCode}');
    return null;
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// ─── Internal models ───────────────────────────────────────────────────────────

class _KeywordLayerResult {
  final int keywordScore;
  final int legitimateScore;
  final String category;
  final String reasoning;
  _KeywordLayerResult({
    required this.keywordScore,
    required this.legitimateScore,
    required this.category,
    required this.reasoning,
  });
}

/// Result from ScamDetectorService.analyze()
class ScamAnalysisResult {
  final bool isScam;
  final double confidence;
  final String layer;      // 'keyword' | 'tflite' | 'server' | 'tflite_fallback'
  final String category;
  final String reasoning;
  final int keywordScore;

  ScamAnalysisResult({
    required this.isScam,
    required this.confidence,
    required this.layer,
    required this.category,
    required this.reasoning,
    required this.keywordScore,
  });

  Map<String, dynamic> toJson() => {
    'is_scam': isScam,
    'confidence': confidence,
    'layer': layer,
    'category': category,
    'reasoning': reasoning,
    'keyword_score': keywordScore,
  };

  @override
  String toString() =>
      'ScamAnalysisResult(isScam=$isScam, conf=${confidence.toStringAsFixed(2)}, layer=$layer)';
}
