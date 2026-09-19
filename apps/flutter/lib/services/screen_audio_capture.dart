import 'dart:async';
import 'package:flutter/services.dart';

/// Screen Audio Capture Service
/// Uses MediaProjection API to capture screen and system audio
/// This should capture call audio on most Android devices
class ScreenAudioCapture {
  static const MethodChannel _channel = MethodChannel('phaseguard/screen_audio');
  
  bool _isCapturing = false;
  StreamController<List<int>>? _audioController;
  int _sampleRate = 16000; // 16kHz for better quality
  
  bool get isCapturing => _isCapturing;
  int get sampleRate => _sampleRate;
  
  /// Request screen capture permission and start audio capture
  /// Returns true if permission granted and capture started
  Future<bool> requestPermissionAndStart({
    int sampleRate = 16000,
  }) async {
    if (_isCapturing) {
      return true; // Already capturing
    }
    
    try {
      _sampleRate = sampleRate;
      final result = await _channel.invokeMethod('requestPermissionAndStart', {
        'sampleRate': _sampleRate,
      });
      
      if (result == true) {
        _isCapturing = true;
        _audioController ??= StreamController<List<int>>();
        _channel.setMethodCallHandler(_handleMethodCall);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Stop audio capture
  Future<void> stop() async {
    if (!_isCapturing) {
      return;
    }
    
    try {
      await _channel.invokeMethod('stopCapture');
      _isCapturing = false;
      await _audioController?.close();
      _audioController = null;
      _channel.setMethodCallHandler(null);
    } catch (e) {
      // Silently handle stop errors
    }
  }
  
  /// Get audio stream
  Stream<List<int>> get audioStream {
    _audioController ??= StreamController<List<int>>();
    return _audioController!.stream;
  }
  
  /// Handle method calls from native platform
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioData':
        final List<int> audioData = List<int>.from(call.arguments['data']);
        _audioController?.add(audioData);
        break;
      case 'onCaptureError':
        _isCapturing = false;
        break;
      case 'onCaptureStopped':
        _isCapturing = false;
        break;
    }
  }
  
  /// Check if screen audio capture is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod('isAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get device compatibility info
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
      };
    }
  }
}