import 'dart:async';
import 'package:flutter/services.dart';
import 'realtime_scam_detection.dart';
import 'voice_deepfake_detector.dart';

/// Audio streaming service
/// 
/// Captures audio using native AudioRecord with MIC/VOICE_RECOGNITION source
/// Requires speakerphone to be enabled to capture both sides of the call
/// Streams audio chunks to backend for scam detection
class AudioStreaming {
  final RealtimeScamDetection _scamDetection;
  final VoiceDeepfakeDetector _voiceDetector = VoiceDeepfakeDetector(sampleRate: 16000);
  
  // Stream to broadcast local DSP results to UI
  final StreamController<Map<String, dynamic>> _localDspController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get localDspStream => _localDspController.stream;

  static const MethodChannel _audioMethodChannel = MethodChannel('phaseguard/audio_capture');
  static const EventChannel _audioEventChannel = EventChannel('phaseguard/audio_capture_events');
  
  bool _isStreaming = false;
  bool _isSpeakerphoneOn = false;
  StreamSubscription? _audioEventSubscription;
  StreamSubscription? _speakerphoneCheckTimer;
  
  // Current audio source: "MIC" or "VOICE_RECOGNITION"
  String _currentAudioSource = "MIC";
  
  AudioStreaming({required RealtimeScamDetection scamDetection})
      : _scamDetection = scamDetection;
  
  bool get isStreaming => _isStreaming;
  bool get isSpeakerphoneOn => _isSpeakerphoneOn;
  String get currentAudioSource => _currentAudioSource;
  
  /// Check if RECORD_AUDIO permission is granted
  Future<bool> checkPermission() async {
    try {
      final result = await _audioMethodChannel.invokeMethod('checkPermission');
      return result == true;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }
  
  /// Check if speakerphone is enabled
  Future<bool> checkSpeakerphone() async {
    try {
      final result = await _audioMethodChannel.invokeMethod('isSpeakerphoneOn');
      _isSpeakerphoneOn = result == true;
      return _isSpeakerphoneOn;
    } catch (e) {
      print('Error checking speakerphone: $e');
      return false;
    }
  }
  
  /// Start audio capture
  Future<bool> startCapture({String? source}) async {
    if (_isStreaming) return true;
    
    // Check permission first
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      print('RECORD_AUDIO permission not granted');
      return false;
    }
    
    // Check speakerphone
    final speakerphoneOn = await checkSpeakerphone();
    if (!speakerphoneOn) {
      print('Speakerphone is not enabled - audio capture may not capture both sides');
    }
    
    try {
      await _audioMethodChannel.invokeMethod('startCapture', {
        'source': source ?? _currentAudioSource,
      });
      
      _isStreaming = true;
      _currentAudioSource = source ?? _currentAudioSource;
      
      // Start listening to audio events
      _audioEventSubscription = _audioEventChannel.receiveBroadcastStream().listen(
        _handleAudioEvent,
        onError: (error) {
          print('Audio event error: $error');
        },
      );
      
      // Start periodic speakerphone checks
      _startSpeakerphoneMonitoring();
      
      print('Audio capture started with source: $_currentAudioSource');
      return true;
    } catch (e) {
      print('Error starting capture: $e');
      return false;
    }
  }
  
  /// Stop audio capture
  Future<bool> stopCapture() async {
    if (!_isStreaming) return true;
    
    try {
      await _audioMethodChannel.invokeMethod('stopCapture');
      
      _isStreaming = false;
      _audioEventSubscription?.cancel();
      _speakerphoneCheckTimer?.cancel();
      
      print('Audio capture stopped');
      return true;
    } catch (e) {
      print('Error stopping capture: $e');
      return false;
    }
  }
  
  /// Handle audio events from native module
  void _handleAudioEvent(dynamic event) {
    if (event is List<int>) {
      // 1. Process Locally First
      final audioChunk = Uint8List.fromList(event);
      final int16List = audioChunk.buffer.asInt16List();
      final dspResult = _voiceDetector.analyzeAudioBuffer(int16List);
      _localDspController.add(dspResult);
      
      // 2. Send to Backend
      _scamDetection.sendAudioChunk(audioChunk);
    } else if (event is Map) {
      // Event (like speakerphone state change)
      final type = event['type'];
      if (type == 'speakerphone_state') {
        _isSpeakerphoneOn = event['isOn'] == true;
        print('Speakerphone state changed: $_isSpeakerphoneOn');
      }
    }
  }
  
  /// Start periodic speakerphone monitoring
  void _startSpeakerphoneMonitoring() {
    _speakerphoneCheckTimer = Stream.periodic(
      const Duration(seconds: 2),
      (_) async {
        final speakerphoneOn = await checkSpeakerphone();
        if (speakerphoneOn != _isSpeakerphoneOn) {
          _isSpeakerphoneOn = speakerphoneOn;
          print('Speakerphone state updated: $_isSpeakerphoneOn');
        }
      },
    ).listen((_) {});
  }
  
  /// Get audio statistics (for debugging)
  Future<Map<String, dynamic>> getAudioStats() async {
    try {
      final result = await _audioMethodChannel.invokeMethod('getAudioStats');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error getting audio stats: $e');
      return {
        'error': e.toString(),
      };
    }
  }
  
  /// Switch audio source (for testing which works better)
  Future<void> switchAudioSource(String source) async {
    if (_isStreaming) {
      await stopCapture();
      _currentAudioSource = source;
      await startCapture(source: source);
    } else {
      _currentAudioSource = source;
    }
  }
  
  void dispose() {
    stopCapture();
  }
}
