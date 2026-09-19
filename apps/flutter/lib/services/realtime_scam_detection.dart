import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import '../models/protocol.dart';

/// Real-time scam detection service
/// 
/// Connects to PhaseGuard backend WebSocket for live scam analysis
/// Uses accessibility + speakerphone audio capture
class RealtimeScamDetection {
  final ApiClient _apiClient;
  
  WebSocketChannel? _wsChannel;
  String? _callId;
  String? _token;
  bool _isConnected = false;
  bool _isRecording = false;

  final LocalSttService _localStt = LocalSttService();
  StreamSubscription<String>? _sttSubscription;
  
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _transcriptController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _alertController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<Map<String, dynamic>> get alertController => _alertController.stream;
  
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  String? get callId => _callId;
  
  RealtimeScamDetection({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
  
  /// Initialize call session and get WebSocket connection
  Future<CallInitResult> initCall({
    String? callerNumber,
    String ingestionMode = 'browser_mic',
  }) async {
    try {
      // Call backend to initialize session using existing ApiClient
      final initResult = await _apiClient.initCall();
      
      _callId = initResult.callId;
      _token = initResult.token;
      
      // Convert wsUrl to proper WebSocket URL
      final wsUrl = _apiClient.websocketUrl(initResult);
      
      // Connect to WebSocket (for raw audio streaming to backend Deepfake/L3 models)
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for WebSocket messages
      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      // Hook up Local STT (replaces backend transcript dependency)
      _sttSubscription = _localStt.transcriptStream.listen((text) {
        if (text.isNotEmpty) {
          _transcriptController.add(text);
          // Accumulate transcript and run 3-layer local detection
          _accumulatedText += ' $text';
          _runLocalDetection(_accumulatedText.trim());
        }
      });
      
      // Start listening to mic locally for STT
      await _localStt.startListening();
      
      _isConnected = true;
      
      _eventController.add({
        'type': 'connected',
        'call_id': _callId,
        'ts': DateTime.now().toIso8601String(),
      });
      
      return initResult;
    } catch (e) {
      _eventController.add({
        'type': 'error',
        'message': 'Failed to initialize call: $e',
        'ts': DateTime.now().toIso8601String(),
      });
      rethrow;
    }
  }
  
  /// Handle WebSocket messages from backend
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      switch (type) {
        case 'connected':
          _eventController.add(data);
          break;
          
        case 'transcript_update':
          final text = data['text'] ?? '';
          _transcriptController.add(text);
          _eventController.add(data);
          break;
          
        case 'factcheck_update':
          final status = data['status'] ?? '';
          final message = data['message'] ?? '';
          
          // Check for scam alert
          if (status == 'CRITICAL') {
            _alertController.add({
              'type': 'scam_alert',
              'message': message,
              'evidence_urls': data['evidence_urls'] ?? [],
              'call_id': _callId,
              'ts': data['ts'],
            });
          }
          
          _eventController.add(data);
          break;
          
        case 'pdi_update':
        case 'tremor_update':
        case 'ensemble_update':
        case 'video_frame_captured':
          _eventController.add(data);
          break;
          
        case 'error':
          _eventController.add(data);
          break;
          
        default:
          _eventController.add(data);
      }
    } catch (e) {
      _eventController.add({
        'type': 'error',
        'message': 'Failed to parse WebSocket message: $e',
        'ts': DateTime.now().toIso8601String(),
      });
    }
  }
  
  /// Send audio chunk to backend via WebSocket
  void sendAudioChunk(Uint8List audioData) {
    if (_wsChannel != null && _isConnected) {
      try {
        _wsChannel!.sink.add(audioData);
      } catch (e) {
        _eventController.add({
          'type': 'error',
          'message': 'Failed to send audio chunk: $e',
          'ts': DateTime.now().toIso8601String(),
        });
      }
    }
  }
  
  /// Activate scambaiter mode
  Future<void> activateScambaiter() async {
    if (_callId == null || _token == null) {
      throw Exception('Call not initialized');
    }
    
    try {
      await _apiClient.activateScambaiter(
        callId: _callId!,
        token: _token!,
      );
      
      _eventController.add({
        'type': 'scambaiter_activated',
        'call_id': _callId,
        'ts': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _eventController.add({
        'type': 'error',
        'message': 'Failed to activate scambaiter: $e',
        'ts': DateTime.now().toIso8601String(),
      });
      rethrow;
    }
  }
  
  /// Disconnect from WebSocket
  void disconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _isRecording = false;
    
    _eventController.add({
      'type': 'disconnected',
      'call_id': _callId,
      'ts': DateTime.now().toIso8601String(),
    });
  }
  
  void _handleError(dynamic error) {
    _eventController.add({
      'type': 'error',
      'message': 'WebSocket error: $error',
      'ts': DateTime.now().toIso8601String(),
    });
  }
  
  void _handleDisconnect() {
    _localStt.stopListening();
    _sttSubscription?.cancel();
    _isConnected = false;
    _isRecording = false;
    
    _eventController.add({
      'type': 'disconnected',
      'call_id': _callId,
      'ts': DateTime.now().toIso8601String(),
    });
  }
  
  void dispose() {
    _localStt.dispose();
    _sttSubscription?.cancel();
    _wsChannel?.sink.close();
    _eventController.close();
    _transcriptController.close();
    _alertController.close();
  }
}
