import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Agora Audio Capture Service
/// Captures REMOTE caller's audio from Agora calls for scam detection
/// This captures the OTHER person's voice (dusre phone ki awaaz), NOT local microphone
/// Uses Android native CallAudioCapture for system calls
/// Uses Agora audio frame observer for in-app calls
class AgoraAudioCaptureService {
  static const MethodChannel _methodChannel = MethodChannel('com.phaseguard/audio');
  static const EventChannel _eventChannel = EventChannel('com.phaseguard/call_audio');

  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;
  bool _isCapturing = false;

  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  bool get isCapturing => _isCapturing;

  /// Start audio capture
  Future<bool> startCapture() async {
    if (_isCapturing) return true;

    try {
      // Start native audio capture
      final result = await _methodChannel.invokeMethod<bool>('startCallCapture');
      if (result == true) {
        _isCapturing = true;
        _startAudioStream();
        debugPrint('✅ Audio capture started');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to start audio capture: $e');
      return false;
    }
  }

  /// Stop audio capture
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _methodChannel.invokeMethod('stopCallCapture');
      _isCapturing = false;
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      debugPrint('✅ Audio capture stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop audio capture: $e');
    }
  }

  /// Check if audio capture is active
  Future<bool> isCaptureActive() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isCallCaptureActive');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to check capture status: $e');
      return false;
    }
  }

  /// Set speakerphone (for audio routing)
  Future<bool> setSpeakerphone(bool on) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setSpeakerphone', {'on': on});
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Failed to set speakerphone: $e');
      return false;
    }
  }

  void _startAudioStream() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          try {
            final audioBytes = base64Decode(event);
            _audioStreamController.add(audioBytes);
          } catch (e) {
            debugPrint('❌ Failed to decode audio chunk: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Audio stream error: $error');
      },
      onDone: () {
        debugPrint('🎤 Audio stream ended');
      },
    );
  }

  /// Add audio chunk directly (from Agora AudioFrameObserver)
  /// This chunk contains REMOTE caller's audio (dusre phone ki awaaz)
  /// REAL-TIME: Chunks sent immediately as they arrive (100ms intervals)
  void addAudioChunk(Uint8List chunk) {
    if (!_isCapturing) {
      _isCapturing = true;
      debugPrint('✅ REMOTE caller audio capture started via AudioFrameObserver (REAL-TIME)');
    }
    _audioStreamController.add(chunk);
    debugPrint('🎤 REMOTE audio chunk: ${chunk.length} bytes (REAL-TIME stream)');
  }

  void dispose() {
    stopCapture();
    _audioStreamController.close();
  }
}
