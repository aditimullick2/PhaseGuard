import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// AgoraAudioCaptureService — Captures audio from Agora calls
///
/// This service hooks into Agora's audio frame observer to capture
/// real-time audio for STT and scam detection.
class AgoraAudioCaptureService {
  RtcEngine? _engine;
  bool _isCapturing = false;
  
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isCapturing => _isCapturing;

  /// Initialize audio capture for Agora engine
  void initialize(RtcEngine engine) {
    _engine = engine;
    
    // Register audio frame observer
    _engine!.registerAudioFrameObserver(
      AudioFrameObserver(
        onAudioFrame: (AudioFrame frame) {
          if (_isCapturing) {
            _processAudioFrame(frame);
          }
        },
      ),
    );
    
    debugPrint('[AgoraAudioCapture] Audio capture initialized');
  }

  /// Start capturing audio
  void startCapture() {
    _isCapturing = true;
    debugPrint('[AgoraAudioCapture] Audio capture started');
  }

  /// Stop capturing audio
  void stopCapture() {
    _isCapturing = false;
    debugPrint('[AgoraAudioCapture] Audio capture stopped');
  }

  /// Process audio frame from Agora
  void _processAudioFrame(AudioFrame frame) {
    try {
      // Convert audio frame to bytes
      // Agora provides PCM audio data
      final samples = frame.samples;
      final bytesPerSample = frame.bytesPerSample;
      final channels = frame.channels;
      
      // Calculate total bytes
      final totalBytes = samples.length * bytesPerSample;
      final audioBytes = Uint8List(totalBytes);
      
      // Convert samples to bytes
      for (int i = 0; i < samples.length; i++) {
        final sample = samples[i];
        // Int16 to bytes (little-endian)
        if (bytesPerSample == 2) {
          audioBytes[i * 2] = sample & 0xFF;
          audioBytes[i * 2 + 1] = (sample >> 8) & 0xFF;
        }
      }
      
      // Add to stream
      _audioStreamController.add(audioBytes);
    } catch (e) {
      debugPrint('[AgoraAudioCapture] Error processing frame: $e');
    }
  }

  void dispose() {
    _isCapturing = false;
    _audioStreamController.close();
  }
}

/// AudioFrameObserver — Agora audio frame observer interface
class AudioFrameObserver {
  final Function(AudioFrame frame) onAudioFrame;

  AudioFrameObserver({required this.onAudioFrame});
}

/// AudioFrame — Represents a single audio frame from Agora
class AudioFrame {
  final Int16List samples;
  final int sampleRate;
  final int channels;
  final int samplesPerChannel;
  final int bytesPerSample;
  final int type;

  AudioFrame({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.samplesPerChannel,
    required this.bytesPerSample,
    required this.type,
  });
}
