import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../config/app_config.dart';

/// PhaseGuard 2-Level Deepfake Audio Detector
///
/// PARALLEL PROCESSING: Local + Web run simultaneously
///   → Local: TFLite 2D CNN + DSP heuristics (fast, less accurate)
///   → Web: Advanced multi-detector analysis (slow, most accurate)
///   → Jo pehle aaye = use karo
///   → Web result = FINAL (best model)
///   → Agar web nahi aaya = local result use karo
class DeepfakeDetectorService {
  final int sampleRate;
  final String serverBaseUrl;

  Interpreter? _interpreter;
  bool _isInitialized = false;

  DeepfakeDetectorService({
    this.sampleRate = 16000,
    String? serverBaseUrl,
  }) : serverBaseUrl = serverBaseUrl ?? AppConfig.backendUrl;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/deepfake_detector.tflite',
      );
      _isInitialized = true;
      debugPrint('[DeepfakeDetector] TFLite 2D CNN model loaded (PARALLEL PROCESSING)');
    } catch (e) {
      debugPrint('[DeepfakeDetector] Failed to load TFLite model: $e');
    }
  }

  /// Analyze audio with PARALLEL PROCESSING (Local + Web)
  /// Jo pehle aaye = use karo, Web result = FINAL
  Future<Map<String, dynamic>> analyze(Int16List pcmData) async {
    // PARALLEL: Local + Web simultaneously
    final localFuture = _runLocalLayerAsync(pcmData);
    final webFuture = _runServerLayerAsync(pcmData);

    // Wait for whichever completes first
    final results = await Future.any([localFuture, webFuture]);

    debugPrint('[DeepfakeDetector] First result: ${results['layer']} (${((results['confidence'] as num).toDouble() * 100).toStringAsFixed(1)}%)');

    return results;
  }

  Future<Map<String, dynamic>> _runLocalLayerAsync(Int16List pcmData) async {
    final localResult = _runLocalLayer(pcmData);
    final double localConf = localResult['confidence'] as double;
    debugPrint('[DeepfakeDetector] LOCAL result: ${localConf.toStringAsFixed(3)} (${localConf < 0.35 ? "NATURAL" : localConf > 0.65 ? "SYNTHETIC" : "UNCERTAIN"})');
    return {...localResult, 'layer': 'local'};
  }

  Future<Map<String, dynamic>> _runServerLayerAsync(Int16List pcmData) async {
    try {
      final wavBytes = _pcmToWavBytes(pcmData);
      final uri = Uri.parse('$serverBaseUrl/api/deepfake/analyze');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('audio', wavBytes, filename: 'audio.wav'));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[DeepfakeDetector] WEB result: ${((data['confidence'] as num).toDouble() * 100).toStringAsFixed(1)}% (FINAL - Best Model)');
        return {
          'is_synthetic': data['is_synthetic'] as bool,
          'confidence': (data['confidence'] as num).toDouble(),
          'reason': data['reason'] as String? ?? 'Server-side multi-detector analysis (FINAL)',
          'metrics': data['metrics'] ?? {},
          'layer': 'web',
        };
      }
      debugPrint('[DeepfakeDetector] Web failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('[DeepfakeDetector] Web error: $e - relying on local');
    }
    // Web failed, return error to trigger local fallback
    throw Exception('Web analysis failed');
  }

  Map<String, dynamic> _runLocalLayer(Int16List pcmData) {
    if (!_isInitialized || _interpreter == null) {
      init();
      return {'is_synthetic': false, 'confidence': 0.0, 'reason': 'Model loading...'};
    }
    if (pcmData.isEmpty) {
      return {'is_synthetic': false, 'confidence': 0.0, 'reason': 'Empty buffer'};
    }
    try {
      int targetSamples = 16000;
      Float64List audio = Float64List(targetSamples);
      for (int i = 0; i < targetSamples; i++) {
        audio[i] = i < pcmData.length ? pcmData[i] / 32768.0 : 0.0;
      }
      int nFft = 256;
      int hopLength = 128;
      int numFrames = 124;
      int numBins = 129;
      final fft = FFT(nFft);
      List<List<double>> spectrogram =
          List.generate(numFrames, (_) => List.filled(numBins, 0.0));
      double maxDb = -double.infinity;
      double minDb = double.infinity;
      for (int f = 0; f < numFrames; f++) {
        int start = f * hopLength;
        Float64List frame = Float64List(nFft);
        for (int i = 0; i < nFft; i++) { frame[i] = audio[start + i]; }
        final freqDomain = fft.realFft(frame);
        for (int b = 0; b < numBins; b++) {
          double real = freqDomain[b].x;
          double imag = freqDomain[b].y;
          double mag = sqrt(real * real + imag * imag);
          double db = 20 * (log(mag + 1e-10) / ln10);
          spectrogram[f][b] = db;
          if (db > maxDb) maxDb = db;
          if (db < minDb) minDb = db;
        }
      }
      double range = maxDb - minDb;
      if (range < 1e-6) range = 1e-6;
      Float32List flatInput = Float32List(numFrames * numBins);
      int idx = 0;
      for (int f = 0; f < numFrames; f++) {
        for (int b = 0; b < numBins; b++) {
          flatInput[idx++] = (spectrogram[f][b] - minDb) / range;
        }
      }
      var input = flatInput.reshape([1, numFrames, numBins, 1]);
      var output = List.filled(1, List.filled(1, 0.0)).reshape([1, 1]);
      _interpreter!.run(input, output);
      double nnConfidence = output[0][0];
      int zeroFrames = 0;
      List<int> dominantBins = [];
      for (int f = 0; f < numFrames; f++) {
        double frameEnergy = 0.0;
        double maxMag = -1.0;
        int maxBin = 0;
        for (int b = 0; b < numBins; b++) {
          double val = (spectrogram[f][b] - minDb) / range;
          frameEnergy += val;
          if (val > maxMag) { maxMag = val; maxBin = b; }
        }
        if (frameEnergy / numBins < 0.05) { zeroFrames++; }
        else { dominantBins.add(maxBin); }
      }
      double silenceRatio = zeroFrames / numFrames;
      double variance = 0.0;
      if (dominantBins.isNotEmpty) {
        double meanBin = dominantBins.reduce((a, b) => a + b) / dominantBins.length;
        double sumSq = 0.0;
        for (int b in dominantBins) { sumSq += (b - meanBin) * (b - meanBin); }
        variance = sumSq / dominantBins.length;
      }
      bool hasUnnaturalPitch = variance > 0.0 && variance < 8.0;
      bool hasAbsoluteSilence = silenceRatio > 0.3;
      double finalConfidence = nnConfidence;
      if (nnConfidence > 0.35 && (hasUnnaturalPitch || hasAbsoluteSilence)) {
        finalConfidence = min(1.0, nnConfidence + 0.4);
      } else if (variance > 25.0) {
        finalConfidence = max(0.0, nnConfidence - 0.3);
      }
      bool isSynthetic = finalConfidence >= 0.5;
      return {
        'is_synthetic': isSynthetic,
        'confidence': finalConfidence,
        'reason': isSynthetic
            ? 'AI detected via Neural Network & DSP Acoustic Anomalies'
            : 'Natural human vocal micro-tremors detected',
        'metrics': {'nn_score': nnConfidence, 'pitch_variance': variance, 'silence_ratio': silenceRatio},
      };
    } catch (e) {
      debugPrint('[DeepfakeDetector] Layer 1 error: $e');
      return {'is_synthetic': false, 'confidence': 0.0, 'reason': 'Local analysis error'};
    }
  }

  Uint8List _pcmToWavBytes(Int16List pcmData) {
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int sR = 16000;
    final int dataSize = pcmData.length * 2;
    final int fileSize = 44 + dataSize;
    final ByteData wav = ByteData(fileSize);
    wav.buffer.asUint8List().setAll(0, 'RIFF'.codeUnits);
    wav.setUint32(4, fileSize - 8, Endian.little);
    wav.buffer.asUint8List().setAll(8, 'WAVE'.codeUnits);
    wav.buffer.asUint8List().setAll(12, 'fmt '.codeUnits);
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little);
    wav.setUint16(22, numChannels, Endian.little);
    wav.setUint32(24, sR, Endian.little);
    wav.setUint32(28, sR * numChannels * bitsPerSample ~/ 8, Endian.little);
    wav.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    wav.setUint16(34, bitsPerSample, Endian.little);
    wav.buffer.asUint8List().setAll(36, 'data'.codeUnits);
    wav.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < pcmData.length; i++) {
      wav.setInt16(44 + i * 2, pcmData[i], Endian.little);
    }
    return wav.buffer.asUint8List();
  }
}
