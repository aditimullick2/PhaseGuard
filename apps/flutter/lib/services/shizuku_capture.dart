import 'dart:async';

import 'package:flutter/services.dart';

/// UI State Machine for Shizuku
enum ShizukuState {
  notInstalled,
  notRunning,
  permissionNeeded,
  granted,
  active,
  captureFailing,
}

/// Shizuku Audio Capture - Cally-like Implementation
///
/// This uses the Cally approach to capture voice call audio via Shizuku's UserService:
/// 1. Shizuku spawns a RecorderService in app_process (UID 2000 = shell)
/// 2. WrappedShellContext patches ActivityThread to pretend to be com.android.shell
/// 3. AudioRecord with VOICE_* sources works because AudioFlinger sees shell identity
/// 4. 5-step fallback ladder: VOICE_UPLINK → VOICE_DOWNLINK → VOICE_CALL → MEDIA → MIC
///
/// This is the most promising approach for single-device call audio capture without root.
///
/// UI State Machine:
/// - NOT_INSTALLED: Shizuku not installed on device
/// - NOT_RUNNING: Shizuku installed but not running
/// - PERMISSION_NEEDED: Shizuku running but permission not granted
/// - GRANTED: All permissions granted, ready to capture
/// - ACTIVE: Capture is running
/// - CAPTURE_FAILING: Capture running but producing silent buffers
class ShizukuCapture {
  static const MethodChannel _channel = MethodChannel('phaseguard/shizuku_audio');
  
  ShizukuState _currentState = ShizukuState.notInstalled;
  bool _isCapturing = false;
  int _sampleRate = 16000;
  
  // Device info
  String _manufacturer = '';
  String _model = '';
  String _androidVersion = '';
  int _sdkVersion = 0;
  
  // Audio stats for real test verification
  int _totalBytes = 0;
  int _nonZeroBytes = 0;
  double _nonZeroPercentage = 0.0;
  
  // Cally-specific metrics
  String _bypassHealth = 'Failed';
  int _fallbackStep = 0;
  bool _isDualRecording = false;
  
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<int>> _audioController = StreamController<List<int>>.broadcast();
  
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<List<int>> get audioStream => _audioController.stream;
  
  ShizukuState get currentState => _currentState;
  bool get isCapturing => _isCapturing;
  int get sampleRate => _sampleRate;
  String get manufacturer => _manufacturer;
  String get model => _model;
  String get androidVersion => _androidVersion;
  int get sdkVersion => _sdkVersion;
  int get totalBytes => _totalBytes;
  int get nonZeroBytes => _nonZeroBytes;
  double get nonZeroPercentage => _nonZeroPercentage;
  String get bypassHealth => _bypassHealth;
  int get fallbackStep => _fallbackStep;
  bool get isDualRecording => _isDualRecording;
  
  /// Get current Shizuku state
  Future<Map<String, dynamic>> getShizukuState() async {
    try {
      final result = await _channel.invokeMethod('getShizukuState');
      _updateStateFromResult(result);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'state': ShizukuState.notInstalled.name,
        'installed': false,
        'running': false,
        'permissionGranted': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Request Shizuku permission
  Future<Map<String, dynamic>> requestPermission() async {
    try {
      final result = await _channel.invokeMethod('requestShizukuPermission');
      _updateStateFromResult(result);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'granted': false,
        'state': ShizukuState.permissionNeeded.name,
        'message': 'Error: $e',
      };
    }
  }
  
  /// Start elevated capture attempt using Cally-like approach
  /// No longer requires MediaProjection - uses Shizuku UserService directly
  Future<Map<String, dynamic>> startElevatedCapture({
    int sampleRate = 16000,
  }) async {
    try {
      _sampleRate = sampleRate;
      _totalBytes = 0;
      _nonZeroBytes = 0;
      _nonZeroPercentage = 0.0;
      _fallbackStep = 0;
      _isDualRecording = false;
      
      final result = await _channel.invokeMethod('startElevatedCapture', {
        'sampleRate': sampleRate,
      });
      
      if (result['success'] == true) {
        _isCapturing = true;
        _currentState = ShizukuState.active;
        _bypassHealth = result['health'] ?? 'Failed';
        _fallbackStep = result['fallbackStep'] ?? 0;
        _isDualRecording = result['isDual'] ?? false;
        startListening();
      }
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  /// Stop elevated capture
  Future<Map<String, dynamic>> stopElevatedCapture() async {
    try {
      final result = await _channel.invokeMethod('stopElevatedCapture');
      _isCapturing = false;
      stopListening();
      
      // Update stats from result
      if (result['totalBytes'] != null) {
        _totalBytes = result['totalBytes'];
        _nonZeroBytes = result['nonZeroBytes'];
        _nonZeroPercentage = result['nonZeroPercentage'] ?? 0.0;
        
        if (_nonZeroPercentage < 1.0) {
          _currentState = ShizukuState.captureFailing;
        } else {
          _currentState = ShizukuState.granted;
        }
      }
      
      _isDualRecording = false;
      _fallbackStep = 0;
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  
  /// Run self-test to classify device capability
  Future<Map<String, dynamic>> runSelfTest() async {
    try {
      final result = await _channel.invokeMethod('runSelfTest');
      
      // Update bypass health from result
      if (result['health'] != null) {
        _bypassHealth = result['health'];
      }
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'classification': 'CALLY_FAILED',
        'message': 'Error: $e',
        'health': 'Failed',
      };
    }
  }
  
  /// Start listening to Shizuku events
  void startListening() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Stop listening to Shizuku events
  void stopListening() {
    _channel.setMethodCallHandler(null);
  }
  
  void _updateStateFromResult(Map<String, dynamic> result) {
    final stateName = result['state'] as String?;
    if (stateName != null) {
      _currentState = ShizukuState.values.firstWhere(
        (e) => e.name == stateName,
        orElse: () => ShizukuState.notInstalled,
      );
    }
    
    _manufacturer = result['manufacturer'] ?? '';
    _model = result['model'] ?? '';
    _androidVersion = result['androidVersion'] ?? '';
    _sdkVersion = result['sdkVersion'] ?? 0;
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onShizukuAudioData':
        final List<int> audioData = List<int>.from(call.arguments['data']);
        final String? stream = call.arguments['stream'] as String?;
        
        // Add stream information to event
        _eventController.add({
          'type': 'audioData',
          'stream': stream ?? 'unknown',
          'data': audioData,
        });
        
        // Also add to audio stream for backward compatibility
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