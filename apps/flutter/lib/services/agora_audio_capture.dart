import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// AgoraAudioCaptureService — Captures REMOTE caller audio from Agora calls
///
/// This service hooks into Agora's audio frame observer to capture
/// real-time audio for STT and scam detection.
/// CRITICAL: We capture ONLY remote caller audio (scammer's voice), not local audio.
/// Method: onPlaybackAudioFrameBeforeMixing captures audio BEFORE mixing with local microphone.
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
        // SKIP local audio recording (our microphone)
        onRecordAudioFrame: (String channelId, AudioFrame frame) {
          // Local microphone - DO NOT CAPTURE
        },
        // SKIP playback audio (what we hear - mixed with local)
        onPlaybackAudioFrame: (String channelId, AudioFrame frame) {
          // Mixed audio - DO NOT CAPTURE
        },
        // SKIP mixed audio (combined local + remote)
        onMixedAudioFrame: (String channelId, AudioFrame frame) {
          // Mixed audio - DO NOT CAPTURE
        },
        // SKIP ear monitoring
        onEarMonitoringAudioFrame: (AudioFrame frame) {},
        // CRITICAL: Capture ONLY remote caller audio BEFORE mixing
        // This is the scammer's voice WITHOUT our local audio
        onPlaybackAudioFrameBeforeMixing: (String channelId, int uid, AudioFrame frame) {
          if (_isCapturing) {
            debugPrint('[AgoraAudioCapture] 🎤 REMOTE UID=$uid | Samples=${frame.samplesPerChannel} | Bytes=${frame.buffer?.length ?? 0}');
            _processAudioFrame(frame);
          } else {
            debugPrint('[AgoraAudioCapture] ⚠️ Remote audio available but capture not started');
          }
        },
      ),
    );
    
    debugPrint('[AgoraAudioCapture] Audio capture initialized - REMOTE caller audio only');
  }

  /// Start capturing audio
  void startCapture() {
    _isCapturing = true;
    debugPrint('[AgoraAudioCapture] REMOTE caller audio capture started');
  }

  /// Stop capturing audio
  void stopCapture() {
    _isCapturing = false;
    debugPrint('[AgoraAudioCapture] REMOTE caller audio capture stopped');
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


