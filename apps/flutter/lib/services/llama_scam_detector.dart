import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// LlamaScamDetector — Real on-device LLM inference using llama_cpp_dart.
///
/// Model: SmolLM2-135M-Instruct Q4_K_M (~100 MB) — bundled in APK assets.
/// Strategy:
///   1. First launch → copy model from APK assets to device storage (one-time, fast).
///   2. Subsequent launches → load directly from device storage path.
///   3. If anything fails → rule-based fallback (always works).
class LlamaScamDetector {
  static const String _assetPath = 'assets/models/scam_detector.gguf';
  static const String _storedFileName = 'scam_detector.gguf';

  // Compact system prompt for 135M model — keep it short!
  static const String _systemPrompt =
      'You are a scam detector. Reply ONLY with JSON: '
      '{"is_scam":true/false,"category":"SCAM|NORMAL","confidence":0.0-1.0,'
      '"reasoning":"short reason"}';

  LlamaParent? _llama;
  bool _isLoaded = false;

  // Copy-from-assets progress (0.0 → 1.0)
  bool _isCopying = false;
  double _copyProgress = 0.0;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<double> get copyProgress => _progressController.stream;
  bool get isLoaded => _isLoaded;
  bool get isCopying => _isCopying;
  double get copyProgressValue => _copyProgress;

  /// Returns device storage path for the model file.
  Future<String> get _modelStoragePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_storedFileName';
  }

  /// Load model — copies from assets on first run, then loads from storage.
  Future<void> loadModel() async {
    try {
      final storagePath = await _modelStoragePath;
      final storageFile = File(storagePath);

      if (!storageFile.existsSync()) {
        debugPrint('LlamaScamDetector: Copying model from assets to storage...');
        final copied = await _copyAssetToStorage(storagePath);
        if (!copied) {
          debugPrint('LlamaScamDetector: Asset copy failed — using rule-based');
          _isLoaded = false;
          return;
        }
      } else {
        final sizeMb = storageFile.lengthSync() / 1024 / 1024;
        debugPrint(
            'LlamaScamDetector: Model already in storage (${sizeMb.toStringAsFixed(0)} MB)');
      }

      // Build llama_cpp_dart params — conservative for small mobile model
      final modelParams = ModelParams()
        ..nGpuLayers = 0; // CPU-only — no GPU assumed on Android

      final contextParams = ContextParams()
        ..nCtx = 256 // 135M model — smaller context is fine
        ..nThreads = 4
        ..nBatch = 64;

      final samplerParams = SamplerParams()
        ..temp = 0.1 // Low temp for deterministic JSON
        ..topK = 5;

      final loadCommand = LlamaLoad(
        path: storagePath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplerParams,
      );

      _llama = LlamaParent(loadCommand, ChatMLFormat());
      await _llama!.init();

      _isLoaded = true;
      debugPrint('LlamaScamDetector: ✅ Model loaded! Ready for inference.');
    } catch (e) {
      debugPrint('LlamaScamDetector: Error loading model: $e');
      _llama = null;
      _isLoaded = false;
    }
  }

  /// Copy bundled asset to device writable storage.
  /// Reports progress via [copyProgress] stream.
  Future<bool> _copyAssetToStorage(String destPath) async {
    _isCopying = true;
    _copyProgress = 0.0;
    _progressController.add(0.0);

    try {
      // Load asset as bytes
      _progressController.add(0.1);
      final data = await rootBundle.load(_assetPath);
      _progressController.add(0.5);

      // Write to device storage
      final bytes = data.buffer.asUint8List();
      final file = File(destPath);
      await file.writeAsBytes(bytes, flush: true);

      _copyProgress = 1.0;
      _progressController.add(1.0);
      _isCopying = false;

      final sizeMb = bytes.length / 1024 / 1024;
      debugPrint(
          'LlamaScamDetector: Copied ${sizeMb.toStringAsFixed(0)} MB to $destPath');
      return true;
    } catch (e) {
      debugPrint('LlamaScamDetector: Asset copy error: $e');
      _isCopying = false;
      // Clean up partial file
      try {
        final f = File(destPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      return false;
    }
  }

  /// Detect scam using local LLM, falls back to rule-based if model not ready.
  Future<Map<String, dynamic>> detectScam(String transcript) async {
    if (!_isLoaded || _llama == null) {
      await loadModel();
    }

    if (_isLoaded && _llama != null) {
      try {
        return await _runInference(transcript);
      } catch (e) {
        debugPrint('LlamaScamDetector: Inference error: $e — using rule-based');
      }
    }

    return _ruleBasedFallback(transcript);
  }

  /// Run LLM inference — sendPrompt returns Future<String> directly.
  Future<Map<String, dynamic>> _runInference(String transcript) async {
    // ChatML format for SmolLM2
    final prompt =
        '<|im_start|>system\n$_systemPrompt<|im_end|>\n'
        '<|im_start|>user\nCall transcript: "$transcript"<|im_end|>\n'
        '<|im_start|>assistant\n';

    final raw = await _llama!.sendPrompt(prompt).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('LlamaScamDetector: Inference timeout');
        return '';
      },
    );

    debugPrint('LlamaScamDetector raw: $raw');

    final jsonStr = _extractJson(raw);
    if (jsonStr == null || jsonStr.isEmpty) {
      throw Exception('No JSON in output: $raw');
    }

    final isScam = jsonStr.contains('"is_scam":true') ||
        jsonStr.contains('"is_scam": true');
    final category = _extractStr(jsonStr, 'category') ?? 'UNKNOWN';
    final reasoning = _extractStr(jsonStr, 'reasoning') ?? 'LLM analysis';
    final confidence =
        _extractDouble(jsonStr, 'confidence') ?? (isScam ? 0.85 : 0.15);

    return {
      'is_scam': isScam,
      'category': category,
      'reasoning': reasoning,
      'confidence': confidence,
      'source': 'local_llm',
    };
  }

  // ── JSON helpers ────────────────────────────────────────────────────────────

  String? _extractJson(String text) {
    final s = text.indexOf('{');
    final e = text.lastIndexOf('}');
    if (s == -1 || e <= s) return null;
    return text.substring(s, e + 1);
  }

  String? _extractStr(String json, String key) =>
      RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(json)?.group(1);

  double? _extractDouble(String json, String key) {
    final m = RegExp('"$key"\\s*:\\s*([0-9.]+)').firstMatch(json);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  // ── Model management ────────────────────────────────────────────────────────

  Future<bool> isModelReady() async {
    final path = await _modelStoragePath;
    return File(path).existsSync();
  }

  Future<double> getModelSizeMB() async {
    final path = await _modelStoragePath;
    final f = File(path);
    return f.existsSync() ? f.lengthSync() / 1024 / 1024 : 0;
  }

  /// Delete cached model from storage (will re-copy from assets on next load).
  Future<void> resetModel() async {
    final path = await _modelStoragePath;
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    _isLoaded = false;
    _llama?.dispose();
    _llama = null;
    debugPrint('LlamaScamDetector: Model cache cleared');
  }

  void dispose() {
    _llama?.dispose();
    _llama = null;
    _isLoaded = false;
    _progressController.close();
  }

  // ── Rule-based fallback ─────────────────────────────────────────────────────

  Map<String, dynamic> _ruleBasedFallback(String transcript) {
    final lower = transcript.toLowerCase();

    final patterns = <String, int>{
      'digital arrest': 10, 'arrest warrant': 10, 'cbi': 9, 'fir': 9,
      'enforcement directorate': 9, 'non-bailable warrant': 10,
      'immediately transfer': 8, 'secure account': 7, 'otp share': 9,
      'illegal transactions': 8, 'pay immediately': 7, 'remote access': 8,
      'microsoft support': 7, 'guaranteed returns': 6, 'won lottery': 8,
      'video leak': 10, 'video kar liya': 10, 'hospital emergency': 9,
      'accident': 8, 'surgery': 8, 'urgent paisa': 9, 'bijli kategi': 8,
      'customs clearance': 7, 'parcel seized': 7, 'kyc incomplete': 9,
      'upi pin': 9, 'accept this collect': 9, 'narcotics': 9,
      'money laundering': 8, 'account freeze': 7,
    };

    int score = 0, max = 0;
    patterns.forEach((p, w) {
      if (lower.contains(p)) score += w;
      max += w;
    });

    final conf = max > 0 ? score / max : 0.0;
    final isScam = conf > 0.08;

    String cat = 'NORMAL';
    String reason = 'No scam patterns detected';

    if (isScam) {
      if (lower.contains('cbi') || lower.contains('digital arrest') || lower.contains('enforcement')) {
        cat = 'DIGITAL_ARREST'; reason = 'Law enforcement impersonation';
      } else if (lower.contains('video') && lower.contains('leak')) {
        cat = 'SEXTORTION'; reason = 'Sextortion patterns';
      } else if (lower.contains('hospital') || lower.contains('accident')) {
        cat = 'FAMILY_EMERGENCY'; reason = 'Family emergency scam';
      } else if (lower.contains('bijli') || lower.contains('disconnection')) {
        cat = 'ELECTRICITY_THREAT'; reason = 'Electricity threat scam';
      } else if (lower.contains('guaranteed') || lower.contains('returns')) {
        cat = 'INVESTMENT_FRAUD'; reason = 'Investment fraud';
      } else if (lower.contains('customs') || lower.contains('parcel')) {
        cat = 'COURIER_CUSTOMS'; reason = 'Courier scam';
      } else if (lower.contains('kyc') || lower.contains('upi')) {
        cat = 'KYC_SCAM'; reason = 'KYC/UPI scam';
      } else {
        cat = 'SCAM_DETECTED'; reason = 'Multiple scam indicators';
      }
    }

    return {
      'is_scam': isScam,
      'category': cat,
      'reasoning': reason,
      'confidence': conf,
      'source': 'rule_based_fallback',
    };
  }
}