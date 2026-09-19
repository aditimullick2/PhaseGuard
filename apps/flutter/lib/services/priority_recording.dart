import 'dart:async';
import 'package:flutter/services.dart';

/// Recording method enum (matches Android RecordingMethod)
enum RecordingMethod {
  none,
  cally,          // Primary - Shizuku + WrappedShellContext
  voip,           // First Fallback - Vapi/Plivo APIs
  accessibility,  // Second Fallback - Accessibility + Speakerphone
  bluetooth,      // Third Fallback - Bluetooth SCO
  hardware,       // Last Resort - Hardware device recommendation
}

/// Recording result data class
class RecordingResult {
  final bool success;
  final RecordingMethod method;
  final String message;
  final String? health;
  final bool speakerphoneEnabled;
  final bool hardwareRecommended;
  final List<String>? hardwareOptions;

  RecordingResult({
    required this.success,
    required this.method,
    required this.message,
    this.health,
    this.speakerphoneEnabled = false,
    this.hardwareRecommended = false,
    this.hardwareOptions,
  });

  factory RecordingResult.fromMap(Map<String, dynamic> map) {
    return RecordingResult(
      success: map['success'] ?? false,
      method: RecordingMethod.values.firstWhere(
        (e) => e.name == map['method'],
        orElse: () => RecordingMethod.none,
      ),
      message: map['message'] ?? 'Unknown',
      health: map['health'],
      speakerphoneEnabled: map['speakerphoneEnabled'] ?? false,
      hardwareRecommended: map['hardwareRecommended'] ?? false,
      hardwareOptions: map['hardwareOptions'] != null
          ? List<String>.from(map['hardwareOptions'])
          : null,
    );
  }
}

/// Priority-based recording service for PhaseGuard
///
/// Priority Order:
/// 1. Cally (Shizuku + WrappedShellContext) - Primary
/// 2. VoIP APIs (Vapi, Plivo) - First Fallback
/// 3. Accessibility + Speakerphone - Second Fallback
/// 4. Bluetooth SCO - Third Fallback
/// 5. Hardware Device - Last Resort
class PriorityRecording {
  static const MethodChannel _channel = MethodChannel('phaseguard/priority_recording');
  
  RecordingMethod _currentMethod = RecordingMethod.none;
  int _currentPriority = 0;
  bool _isRecording = false;
  
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RecordingResult> _resultController = StreamController<RecordingResult>.broadcast();
  
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<RecordingResult> get resultStream => _resultController.stream;
  
  RecordingMethod get currentMethod => _currentMethod;
  int get currentPriority => _currentPriority;
  bool get isRecording => _isRecording;
  
  /// Start recording with automatic priority selection
  Future<RecordingResult> startRecording({int sampleRate = 16000}) async {
    try {
      final result = await _channel.invokeMethod('startPriorityRecording', {
        'sampleRate': sampleRate,
      });
      
      final recordingResult = RecordingResult.fromMap(Map<String, dynamic>.from(result));
      
      if (recordingResult.success) {
        _isRecording = true;
        _currentMethod = recordingResult.method;
        _currentPriority = _getPriorityForMethod(recordingResult.method);
        
        _eventController.add({
          'type': 'recordingStarted',
          'method': recordingResult.method.name,
          'priority': _currentPriority,
          'message': recordingResult.message,
        });
        
        _resultController.add(recordingResult);
      }
      
      return recordingResult;
    } catch (e) {
      return RecordingResult(
        success: false,
        method: RecordingMethod.none,
        message: 'Error: $e',
      );
    }
  }
  
  /// Stop current recording
  Future<RecordingResult> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stopPriorityRecording');
      
      final recordingResult = RecordingResult.fromMap(Map<String, dynamic>.from(result));
      
      _isRecording = false;
      _currentMethod = RecordingMethod.none;
      _currentPriority = 0;
      
      _eventController.add({
        'type': 'recordingStopped',
        'method': recordingResult.method.name,
        'message': recordingResult.message,
      });
      
      _resultController.add(recordingResult);
      
      return recordingResult;
    } catch (e) {
      return RecordingResult(
        success: false,
        method: RecordingMethod.none,
        message: 'Error: $e',
      );
    }
  }
  
  /// Get current recording status
  Future<Map<String, dynamic>> getRecordingStatus() async {
    try {
      final result = await _channel.invokeMethod('getRecordingStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {
        'error': e.toString(),
        'currentMethod': RecordingMethod.none.name,
        'currentPriority': 0,
        'isRecording': false,
      };
    }
  }
  
  /// Get priority level for recording method
  int _getPriorityForMethod(RecordingMethod method) {
    switch (method) {
      case RecordingMethod.cally:
        return 1;
      case RecordingMethod.voip:
        return 2;
      case RecordingMethod.accessibility:
        return 3;
      case RecordingMethod.bluetooth:
        return 4;
      case RecordingMethod.hardware:
        return 5;
      case RecordingMethod.none:
        return 0;
    }
  }
  
  /// Get method name for priority level
  RecordingMethod getMethodForPriority(int priority) {
    switch (priority) {
      case 1:
        return RecordingMethod.cally;
      case 2:
        return RecordingMethod.voip;
      case 3:
        return RecordingMethod.accessibility;
      case 4:
        return RecordingMethod.bluetooth;
      case 5:
        return RecordingMethod.hardware;
      default:
        return RecordingMethod.none;
    }
  }
  
  /// Get user-friendly method name
  String getMethodDisplayName(RecordingMethod method) {
    switch (method) {
      case RecordingMethod.cally:
        return 'Cally (Shizuku)';
      case RecordingMethod.voip:
        return 'VoIP API';
      case RecordingMethod.accessibility:
        return 'Accessibility + Speakerphone';
      case RecordingMethod.bluetooth:
        return 'Bluetooth SCO';
      case RecordingMethod.hardware:
        return 'Hardware Device';
      case RecordingMethod.none:
        return 'None';
    }
  }
  
  /// Get method description
  String getMethodDescription(RecordingMethod method) {
    switch (method) {
      case RecordingMethod.cally:
        return 'Primary method using Shizuku shell UID with WrappedShellContext technique';
      case RecordingMethod.voip:
        return 'First fallback using Vapi/Plivo APIs for VoIP calls';
      case RecordingMethod.accessibility:
        return 'Second fallback using accessibility service with automatic speakerphone';
      case RecordingMethod.bluetooth:
        return 'Third fallback using Bluetooth SCO when headset connected';
      case RecordingMethod.hardware:
        return 'Last resort - hardware device recommendation for perfect recording';
      case RecordingMethod.none:
        return 'No recording method active';
    }
  }
  
  void dispose() {
    _eventController.close();
    _resultController.close();
  }
}
