import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// SherpaSttService — On-device Speech-to-Text using Sherpa ONNX.
/// Processes raw PCM chunks (from Agora) locally.
class SherpaSttService {
  bool _isInitialized = false;
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;

  final StreamController<String> _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  bool get isInitialized => _isInitialized;

  /// Initialize Sherpa ONNX model.
  /// Ensure you have downloaded the sherpa-onnx-streaming model and placed it in assets/models/sherpa/
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('SherpaSTT: Initializing model...');

      // Update these paths to match your downloaded sherpa-onnx model files
      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: 'assets/models/sherpa/encoder-epoch-99-avg-1.int8.onnx',
            decoder: 'assets/models/sherpa/decoder-epoch-99-avg-1.int8.onnx',
            joiner: 'assets/models/sherpa/joiner-epoch-99-avg-1.int8.onnx',
          ),
          tokens: 'assets/models/sherpa/tokens.txt',
          numThreads: 1,
          debug: 0,
        ),
        featConfig: sherpa.FeatureConfig(
          sampleRate: 16000,
          featureDim: 80,
        ),
        enableEndpoint: 1,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 300,
      );

      _recognizer = sherpa.OnlineRecognizer(config: config);
      _stream = _recognizer!.createStream();

      _isInitialized = true;
      debugPrint('SherpaSTT: ✅ Model initialized successfully');
      return true;
    } catch (e) {
      debugPrint('SherpaSTT: Initialization error: $e. Did you forget to add the model files?');
      _isInitialized = false;
      return false;
    }
  }

  /// Feed raw PCM chunk (16kHz 16-bit mono) from Agora to the STT engine
  void processAudioChunk(Uint8List audioBytes) {
    if (!_isInitialized || _stream == null || _recognizer == null) return;

    try {
      // Convert 16-bit PCM bytes to float32 samples [-1.0, 1.0] for Sherpa
      final byteData = ByteData.sublistView(audioBytes);
      final samples = Float32List(audioBytes.length ~/ 2);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = byteData.getInt16(i * 2, Endian.little) / 32768.0;
      }

      // Accept waveform
      _stream!.acceptWaveform(sampleRate: 16000, samples: samples);

      // Decode
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
      }

      // Get Result
      final result = _recognizer!.getResult(_stream!);
      if (result.text.isNotEmpty) {
        _transcriptController.add(result.text);
      }

      // Reset stream if endpoint detected (e.g. silence)
      if (_recognizer!.isEndpoint(_stream!)) {
        _recognizer!.reset(_stream!);
      }
    } catch (e) {
      debugPrint('SherpaSTT: Error processing chunk: $e');
    }
  }

  void dispose() {
    _stream?.free();
    _recognizer?.free();
    _transcriptController.close();
    _isInitialized = false;
  }
}
