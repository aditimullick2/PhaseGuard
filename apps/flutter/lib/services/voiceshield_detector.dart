import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class VoiceShieldDetector {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/deepfake/voiceshield_ast_v1.tflite');
      _isInitialized = true;
      print("VoiceShield TFLite model loaded successfully.");
    } catch (e) {
      print("Failed to load VoiceShield TFLite model: $e");
    }
  }

  /// Analyzes audio using VoiceShield AST model
  /// Expected input: Audio spectrogram with specific dimensions
  Map<String, dynamic> analyzeAudioBuffer(Int16List pcmData) {
    if (!_isInitialized || _interpreter == null) {
      init();
      return {
        'is_synthetic': false,
        'confidence': 0.0,
        'reason': 'Model loading...',
        'model': 'VoiceShield'
      };
    }

    if (pcmData.isEmpty) {
      return {
        'is_synthetic': false,
        'confidence': 0.0,
        'reason': 'Empty buffer',
        'model': 'VoiceShield'
      };
    }

    try {
      // VoiceShield expects audio converted to spectrogram
      // Typical input shape: [1, 128, 128, 1] or similar
      int targetSamples = 16000; // 1 second at 16kHz
      Float64List audio = Float64List(targetSamples);

      for (int i = 0; i < targetSamples; i++) {
        audio[i] = i < pcmData.length ? pcmData[i] / 32768.0 : 0.0;
      }

      // Generate Mel-spectrogram (VoiceShield uses spectrogram input)
      int nFft = 1024;
      int hopLength = 256;
      int nMels = 128;
      int numFrames = 128; // Fixed frames for model input

      // Simple mel-spectrogram approximation
      Float32List spectrogram = _generateMelSpectrogram(audio, nFft, hopLength, nMels, numFrames);

      // Reshape for TFLite input [1, 128, 128, 1]
      var input = spectrogram.reshape([1, numFrames, nMels, 1]);
      var output = List.filled(1, List.filled(2, 0.0)).reshape([1, 2]); // [real, fake]

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction (model outputs [real_probability, fake_probability])
      double realProb = output[0][0];
      double fakeProb = output[0][1];

      double confidence = fakeProb; // Probability of being fake

      // Adaptive threshold based on confidence level
      // If confidence is very high or very low, be more decisive
      double threshold = 0.45;
      if (confidence > 0.8 || confidence < 0.2) {
        threshold = 0.4; // More sensitive for extreme cases
      } else {
        threshold = 0.5; // More conservative for uncertain cases
      }

      bool isSynthetic = confidence >= threshold;

      String reason = isSynthetic
          ? "VoiceShield detected synthetic audio patterns"
          : "VoiceShield detected natural human voice";

      return {
        'is_synthetic': isSynthetic,
        'confidence': confidence,
        'reason': reason,
        'model': 'VoiceShield',
        'real_probability': realProb,
        'fake_probability': fakeProb
      };

    } catch (e) {
      print("Error in VoiceShield inference: $e");
      return {
        'is_synthetic': false,
        'confidence': 0.0,
        'reason': 'Error analyzing audio: $e',
        'model': 'VoiceShield'
      };
    }
  }

  /// Generate Mel-spectrogram from audio data (Optimized)
  Float32List _generateMelSpectrogram(Float64List audio, int nFft, int hopLength, int nMels, int numFrames) {
    // Improved mel-spectrogram generation for better accuracy
    Float32List melSpec = Float32List(numFrames * nMels);

    int samplesPerFrame = hopLength;
    for (int f = 0; f < numFrames; f++) {
      int start = f * samplesPerFrame;
      if (start + nFft > audio.length) break;

      // Calculate FFT magnitude for this frame
      List<double> fftResult = _computeFFT(audio, start, nFft);

      // Improved mel-scale conversion using linear spacing
      for (int m = 0; m < nMels; m++) {
        // Better bin mapping for mel-scale approximation
        double melLow = 0;
        double melHigh = 2595 * log10(1 + (nFft / 2) / 700);
        double melPoint = melLow + (melHigh - melLow) * m / (nMels - 1);
        double freqPoint = 700 * (pow(10, melPoint / 2595) - 1);
        int binIndex = (freqPoint * fftResult.length ~/ (nFft / 2)).clamp(0, fftResult.length - 1);

        double magnitude = fftResult[binIndex];

        // Improved log magnitude calculation
        double logMag = log((magnitude * magnitude) + 1e-10);
        melSpec[f * nMels + m] = logMag.abs();
      }
    }

    // Improved normalization using min-max
    double minVal = melSpec.reduce((a, b) => a < b ? a : b);
    double maxVal = melSpec.reduce((a, b) => a > b ? a : b);
    double range = maxVal - minVal;

    if (range > 1e-8) {
      for (int i = 0; i < melSpec.length; i++) {
        melSpec[i] = (melSpec[i] - minVal) / range;
      }
    }

    return melSpec;
  }

  /// Compute FFT magnitude (simplified)
  List<double> _computeFFT(Float64List audio, int start, int nFft) {
    int halfLength = nFft ~/ 2;
    List<double> magnitudes = List.filled(halfLength, 0.0);

    for (int i = 0; i < halfLength; i++) {
      double real = 0.0;
      double imag = 0.0;

      for (int k = 0; k < nFft; k++) {
        double angle = 2 * pi * i * k / nFft;
        real += audio[start + k] * cos(angle);
        imag += audio[start + k] * sin(angle);
      }

      magnitudes[i] = sqrt(real * real + imag * imag);
    }

    return magnitudes;
  }

  /// Release resources
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
