import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'scam_detector.dart';

/// PhaseGuard 3-Level Scam Text Detector
///
/// LOCAL ONLY (SEQUENTIAL): Keyword + TFLite ML model
///   → Runs on-device, no internet needed.
///   → Catches obvious scams (OTP, block account, CBI, etc.)
///   → Catches nuanced, indirect, and "twisted" scam patterns.
///   → Returns local result with confidence score.
class ScamDetectorService {
  Interpreter? _interpreter;
  Map<String, dynamic>? _metadata;
  Map<String, int>? _vocab;
  List<double>? _idfWeights;
  bool _isModelReady = false;

  static const double _highConfidenceThreshold = 0.70;
  static const double _lowConfidenceThreshold = 0.30;
  static const int _keywordConfirmedScam = 3;

  ScamDetectorService();

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
      debugPrint('[ScamDetector] TFLite model + vocabulary loaded ✅ (${_vocab!.length} tokens)');
    } catch (e) {
      debugPrint('[ScamDetector] Failed to load model: $e');
    }
  }

  // ─── PUBLIC ENTRY POINT ────────────────────────────────────────────────────

  /// Analyze text using local keyword + TFLite ML pipeline.
  /// Returns local result only - works completely offline.
  Future<ScamAnalysisResult> analyze(String text) async {
    if (!_isModelReady) await init();

    final normalizedText = _normalize(text);

    // ── LAYER 1: Keyword Matching ──────────────────────────────────────────
    final keywordResult = _runKeywordLayer(normalizedText);
    debugPrint('[ScamDetector] L1 keyword score: ${keywordResult.keywordScore}');

    // Hard confirmed: ≥ 3 STRONG scam keywords → immediate alert
    if (keywordResult.keywordScore >= _keywordConfirmedScam) {
      return ScamAnalysisResult(
        isScam: true,
        confidence: 1.0,
        layer: 'keyword',
        category: keywordResult.category,
        reasoning: keywordResult.reasoning,
        keywordScore: keywordResult.keywordScore,
        needsWebEscalation: false, // Confident result, no web needed
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
        needsWebEscalation: false, // Confident result, no web needed
      );
    }

    // ── LAYER 2: TFLite Model ──────────────────────────────────────────────
    final mlResult = _runModelLayer(normalizedText);
    final status = mlResult < 0.30 ? 'SAFE' : mlResult > 0.70 ? 'SCAM' : 'UNCERTAIN';
    debugPrint('[ScamDetector] L2 model confidence: ${mlResult.toStringAsFixed(3)} ($status)');

    // Confident scam
    if (mlResult > _highConfidenceThreshold) {
      return ScamAnalysisResult(
        isScam: true,
        confidence: mlResult,
        layer: 'tflite',
        category: 'SCAM_DETECTED',
        reasoning: 'TFLite neural network flagged this as a scam (${(mlResult * 100).toStringAsFixed(1)}% confidence)',
        keywordScore: keywordResult.keywordScore,
        needsWebEscalation: false, // Confident result, no web needed
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
        needsWebEscalation: false, // Confident result, no web needed
      );
    }

    // Uncertain → return with honest uncertainty and flag for web escalation
    return ScamAnalysisResult(
      isScam: mlResult >= 0.50,
      confidence: mlResult,
      layer: 'tflite',
      category: mlResult >= 0.50 ? 'POSSIBLE_SCAM' : 'LIKELY_SAFE',
      reasoning: 'Uncertain: TFLite score=${mlResult.toStringAsFixed(2)}. Keyword hits=${keywordResult.keywordScore}. Web escalation recommended.',
      keywordScore: keywordResult.keywordScore,
      needsWebEscalation: true, // Flag for web escalation
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
      debugPrint('[ScamDetector] Layer 2 error: $e');
      return 0.5;
    }
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
  final bool needsWebEscalation; // Flag for web escalation when uncertain

  ScamAnalysisResult({
    required this.isScam,
    required this.confidence,
    required this.layer,
    required this.category,
    required this.reasoning,
    required this.keywordScore,
    this.needsWebEscalation = false,
  });

  Map<String, dynamic> toJson() => {
    'is_scam': isScam,
    'confidence': confidence,
    'layer': layer,
    'category': category,
    'reasoning': reasoning,
    'keyword_score': keywordScore,
    'needs_web_escalation': needsWebEscalation,
  };

  @override
  String toString() =>
      'ScamAnalysisResult(isScam=$isScam, conf=${confidence.toStringAsFixed(2)}, layer=$layer)';
}
