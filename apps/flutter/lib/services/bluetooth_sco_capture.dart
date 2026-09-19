import 'dart:async';

import 'package:flutter/services.dart';

/// Bluetooth SCO Audio Capture
/// 
/// Captures audio from Bluetooth SCO (Synchronous Connection-Oriented) channel.
/// This is used for telephone-quality audio during calls when using a Bluetooth headset.
/// 
/// IMPORTANT NOTES:
/// - Requires Bluetooth headset to be connected
/// - Audio quality is limited to telephone range (8-16 kHz)
/// - Works best during active calls
/// - Some devices may not support SCO audio capture
class BluetoothScoCapture {
  static const MethodChannel _channel = MethodChannel('phaseguard/bluetooth_sco');
  
  bool _isCapturing = false;
  bool _headsetConnected = false;
  bool _scoAvailable = false;
  String? _deviceName;
  int _sampleRate = 16000;
  
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<int>> _audioController = StreamController<List<int>>.broadcast();
  
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<List<int>> get audioStream => _audioController.stream;
  
  bool get isCapturing => _isCapturing;
  bool get headsetConnected => _headsetConnected;
  bool get scoAvailable => _scoAvailable;
  String? get deviceName => _deviceName;
  int get sampleRate => _sampleRate;
  
  /// Check if Bluetooth headset is connected
  Future<bool> isHeadsetConnected() async {
    try {
      final result = await _channel.invokeMethod('getScoDeviceInfo');
      _headsetConnected = result['headsetConnected'] == true;
      _scoAvailable = result['scoAvailable'] == true;
      _deviceName = result['deviceName'];
      return _headsetConnected;
    } catch (e) {
      return false;
    }
  }
  
  /// Get SCO device info
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod('getScoDeviceInfo');
      _headsetConnected = result['headsetConnected'] == true;
      _scoAvailable = result['scoAvailable'] == true;
      _deviceName = result['deviceName'];
      _sampleRate = result['sampleRate'] ?? 16000;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'headsetConnected': false,
        'scoAvailable': false,
        'scoOn': false,
        'deviceName': null,
        'sampleRate': 16000,
        'error': e.toString(),
      };
    }
  }
  
  /// Start SCO audio capture
  Future<bool> startCapture({int sampleRate = 16000}) async {
    try {
      _sampleRate = sampleRate;
      final result = await _channel.invokeMethod('startScoCapture', {
        'sampleRate': sampleRate,
      });
      
      if (result == true) {
        _isCapturing = true;
        startListening();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Stop SCO audio capture
  Future<bool> stopCapture() async {
    try {
      final result = await _channel.invokeMethod('stopScoCapture');
      _isCapturing = false;
      stopListening();
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Start listening to SCO events
  void startListening() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Stop listening to SCO events
  void stopListening() {
    _channel.setMethodCallHandler(null);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'headsetConnected':
        _headsetConnected = true;
        _deviceName = call.arguments['deviceName'];
        _eventController.add({
          'type': 'headsetConnected',
          'deviceName': _deviceName,
        });
        break;
      case 'headsetDisconnected':
        _headsetConnected = false;
        _deviceName = null;
        _eventController.add({
          'type': 'headsetDisconnected',
        });
        break;
      case 'scoCaptureStarted':
        _isCapturing = true;
        _sampleRate = call.arguments['sampleRate'] ?? 16000;
        _eventController.add({
          'type': 'scoCaptureStarted',
          'sampleRate': _sampleRate,
        });
        break;
      case 'scoCaptureStopped':
        _isCapturing = false;
        _eventController.add({
          'type': 'scoCaptureStopped',
        });
        break;
      case 'scoCaptureFailed':
        _isCapturing = false;
        _eventController.add({
          'type': 'scoCaptureFailed',
          'error': call.arguments['error'],
        });
        break;
      case 'onScoAudioData':
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