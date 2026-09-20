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
    _engine!.getMediaEngine().registerAudioFrameObserver(
      AudioFrameObserver(
        onRecordAudioFrame: (String channelId, AudioFrame frame) {
          if (_isCapturing) {
            _processAudioFrame(frame);
          }
        },
        onPlaybackAudioFrame: (String channelId, AudioFrame frame) {
          if (_isCapturing) {
            _processAudioFrame(frame);
          }
        },
        onMixedAudioFrame: (String channelId, AudioFrame frame) {
          if (_isCapturing) {
            _processAudioFrame(frame);
          }
        },
        onEarMonitoringAudioFrame: (AudioFrame frame) {},
        onPlaybackAudioFrameBeforeMixing: (String channelId, int uid, AudioFrame frame) {},
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
      final audioBytes = frame.buffer;
      if (audioBytes != null) {
        _audioStreamController.add(audioBytes);
      }
    } catch (e) {
      debugPrint('[AgoraAudioCapture] Error processing frame: $e');
    }
  }

  void dispose() {
    _isCapturing = false;
    _audioStreamController.close();
  }
}


