import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'screen_audio_capture.dart';

typedef JsonHandler = void Function(Map<String, dynamic> json);
typedef BytesHandler = void Function(List<int> bytes);

class CallSocket {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _keepaliveTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnect = 5;
  static const _reconnectDelay = Duration(seconds: 2);
  static const _keepaliveInterval = Duration(minutes: 5); // Send ping every 5 minutes to prevent Render spindown
  
  // Screen audio capture
  final ScreenAudioCapture _audioCapture = ScreenAudioCapture();
  StreamSubscription<List<int>>? _audioSubscription;
  bool _useScreenAudio = false;

  bool get isConnected => _channel != null;
  bool get isCapturingAudio => _audioCapture.isCapturing;

  Future<void> connect({
    required String url,
    required JsonHandler onJson,
    BytesHandler? onBytes,
    void Function(String message)? onError,
    void Function()? onClose,
  }) async {
    await disconnect();
    final uri = Uri.parse(url);
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    _reconnectAttempts = 0;

    // Start keepalive timer to prevent Render spindown
    _startKeepalive();

    _sub = _channel!.stream.listen(
      (event) {
        if (event is String) {
          try {
            final decoded = jsonDecode(event);
            if (decoded is Map<String, dynamic>) {
              onJson(decoded);
            }
          } catch (_) {}
        } else if (event is List<int>) {
          onBytes?.call(event);
        }
      },
      onError: (Object err) {
        onError?.call(err.toString());
      },
      onDone: () {
        _stopKeepalive();
        onClose?.call();
        _attemptReconnect(
          url: url,
          onJson: onJson,
          onBytes: onBytes,
          onError: onError,
          onClose: onClose,
        );
      },
    );
  }

  void _startKeepalive() {
    _stopKeepalive(); // Clear any existing timer
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (timer) {
      if (_channel != null) {
        try {
          // Send a ping message to keep the connection alive
          _channel!.sink.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()}));
        } catch (e) {
          // If sending fails, the connection might be dead
          timer.cancel();
        }
      }
    });
  }

  void _stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  void _attemptReconnect({
    required String url,
    required JsonHandler onJson,
    BytesHandler? onBytes,
    void Function(String message)? onError,
    void Function()? onClose,
  }) {
    if (_reconnectAttempts >= _maxReconnect) return;
    _reconnectAttempts++;
    Future<void>.delayed(_reconnectDelay, () {
      connect(
        url: url,
        onJson: onJson,
        onBytes: onBytes,
        onError: onError,
        onClose: onClose,
      ).catchError((Object err) {
        onError?.call(err.toString());
      });
    });
  }

  void sendBytes(List<int> bytes) {
    if (_channel != null) {
      try {
        _channel!.sink.add(bytes);
      } catch (e) {
        // Socket sink error
      }
    }
  }

  void sendJson(Map<String, dynamic> json) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(json));
      } catch (e) {
        // Socket sink error
      }
    }
  }

  Future<void> disconnect() async {
    _stopKeepalive();
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    
    // Stop audio capture
    await stopScreenAudioCapture();
  }
  
  /// Enable screen audio capture
  Future<bool> enableScreenAudioCapture({int sampleRate = 16000}) async {
    try {
      final available = await _audioCapture.isAvailable();
      if (!available) {
        return false;
      }
      
      final success = await _audioCapture.requestPermissionAndStart(sampleRate: sampleRate);
      if (success) {
        _useScreenAudio = true;
        
        // Subscribe to audio stream and send to WebSocket
        _audioSubscription = _audioCapture.audioStream.listen((audioData) {
          _sendAudioData(audioData);
        });
        
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Disable screen audio capture
  Future<void> stopScreenAudioCapture() async {
    if (_useScreenAudio) {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _audioCapture.stop();
      _useScreenAudio = false;
    }
  }
  
  /// Send audio data to WebSocket
  void _sendAudioData(List<int> audioData) {
    if (_channel != null && isConnected) {
      try {
        _channel!.sink.add(audioData);
      } catch (e) {
        // Silently handle send errors
      }
    }
  }
  
  /// Get screen audio capture status
  bool get screenAudioEnabled => _useScreenAudio;
  
  /// Get screen audio capture device info
  Future<Map<String, dynamic>> getScreenAudioDeviceInfo() async {
    return await _audioCapture.getDeviceInfo();
  }
}
