import 'dart:async';

import 'package:flutter/services.dart';

/// Accessibility Service Capture
/// 
/// Uses Android AccessibilityService to detect call state and attempt audio capture.
/// 
/// IMPORTANT NOTES:
/// - AccessibilityService primarily provides UI/event access, NOT direct telephony audio
/// - This service can detect call state (ringing, active, ended)
/// - Audio capture is device-dependent and may not work on all devices
/// - Does NOT guarantee cellular call audio access
/// - Users must manually enable Accessibility Service in system settings
class AccessibilityCapture {
  static const MethodChannel _channel = MethodChannel('phaseguard/accessibility_service');
  
  bool _isEnabled = false;
  int _callState = 0; // 0 = idle, 1 = ringing, 2 = offhook
  String? _phoneNumber;
  bool _isCapturing = false;
  
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<int>> _audioController = StreamController<List<int>>.broadcast();
  
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<List<int>> get audioStream => _audioController.stream;
  
  bool get isEnabled => _isEnabled;
  bool get isCapturing => _isCapturing;
  String? get phoneNumber => _phoneNumber;
  String get callStateLabel {
    switch (_callState) {
      case 1:
        return 'ringing';
      case 2:
        return 'active';
      default:
        return 'idle';
    }
  }
  
  /// Check if Accessibility Service is enabled
  Future<bool> isServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityServiceEnabled');
      _isEnabled = result == true;
      return _isEnabled;
    } catch (e) {
      return false;
    }
  }
  
  /// Open system settings to enable Accessibility Service
  Future<bool> enableService() async {
    try {
      final result = await _channel.invokeMethod('enableAccessibilityService');
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get current Accessibility Service state
  Future<Map<String, dynamic>> getServiceState() async {
    try {
      final result = await _channel.invokeMethod('getAccessibilityServiceState');
      if (result != null) {
        _isEnabled = result['enabled'] == true;
        _callState = result['callState'] ?? 0;
        _phoneNumber = result['phoneNumber'];
        _isCapturing = result['isCapturing'] == true;
      }
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {
        'enabled': false,
        'callState': 0,
        'phoneNumber': null,
        'isCapturing': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Start listening to Accessibility Service events
  void startListening() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Stop listening to Accessibility Service events
  void stopListening() {
    _channel.setMethodCallHandler(null);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'callRinging':
        _phoneNumber = call.arguments['phoneNumber'];
        _callState = 1;
        _eventController.add({
          'type': 'callRinging',
          'phoneNumber': _phoneNumber,
        });
        break;
      case 'callStarted':
        _phoneNumber = call.arguments['phoneNumber'];
        _callState = 2;
        _eventController.add({
          'type': 'callStarted',
          'phoneNumber': _phoneNumber,
        });
        break;
      case 'callEnded':
        _callState = 0;
        _phoneNumber = null;
        _eventController.add({
          'type': 'callEnded',
        });
        break;
      case 'audioCaptureStarted':
        _isCapturing = true;
        _eventController.add({
          'type': 'audioCaptureStarted',
          'sampleRate': call.arguments['sampleRate'],
        });
        break;
      case 'audioCaptureStopped':
        _isCapturing = false;
        _eventController.add({
          'type': 'audioCaptureStopped',
        });
        break;
      case 'audioCaptureFailed':
        _isCapturing = false;
        _eventController.add({
          'type': 'audioCaptureFailed',
          'error': call.arguments['error'],
        });
        break;
      case 'onAudioData':
        final List<int> audioData = List<int>.from(call.arguments['data']);
        _audioController.add(audioData);
        break;
    }
  }
  
  void dispose() {
    _eventController.close();
    _audioController.close();
    stopListening();
  }
}