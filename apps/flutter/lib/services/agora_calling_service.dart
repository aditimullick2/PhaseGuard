import 'dart:async';
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'agora_audio_capture_service.dart';

/// PhaseGuard In-App Calling Service
/// Integrates Agora RTC for high-quality audio/video calling
/// with real-time scam detection during active calls
class AgoraCallingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RtcEngine? _engine;
  String? _currentCallId;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerEnabled = true;
  bool _isCameraMuted = false;
  bool _isVideoCall = false;
  bool _isJoined = false;
  bool _isConnected = false;
  int? _remoteUid;
  Timer? _callDurationTimer;
  int _callDuration = 0;
  String _connectionState = 'Disconnected';
  int _networkQuality = 0;
  bool _isEndingCall = false;

  // Audio capture for scam detection
  final AgoraAudioCaptureService _audioCaptureService = AgoraAudioCaptureService();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Getters
  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isCameraMuted => _isCameraMuted;
  bool get isVideoCall => _isVideoCall;
  bool get isJoined => _isJoined;
  bool get isConnected => _isConnected;
  int? get remoteUid => _remoteUid;
  int get callDuration => _callDuration;
  String get connectionState => _connectionState;
  int get networkQuality => _networkQuality;
  String? get currentCallId => _currentCallId;
  Stream<Uint8List> get remoteAudioStream => _audioCaptureService.audioStream;

  /// Initialize Agora RTC Engine (Testing Mode: App ID only, no certificate needed)
  Future<void> initialize({
    required String appId,
    String appCert = '', // ignored in testing mode
  }) async {
    if (_isInitialized) return;

    // Testing mode: App ID only, no certificate needed

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: _onJoinChannelSuccess,
          onUserJoined: _onUserJoined,
          onUserOffline: _onUserOffline,
          onLeaveChannel: _onLeaveChannel,
          onConnectionStateChanged: _onConnectionStateChanged,
          onNetworkQuality: _onNetworkQuality,
          onError: (ErrorCodeType err, String msg) {
            _onError(err, msg);
          },
          onRemoteAudioStateChanged: _onRemoteAudioStateChanged,
        ),
      );

      _isInitialized = true;
      debugPrint('✅ Agora RTC Engine initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Agora initialization failed: $e');
      rethrow;
    }
  }

  /// Start audio call
  Future<void> startAudioCall({
    required String callId,
    required String channelName,
    required int userId,
    required String token,
    required String remoteUserName,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora engine not initialized');
    }

    try {
      _currentCallId = callId;
      _isVideoCall = false;

      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: userId,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );

      // Store call to Firestore
      await _firestore.collection('calls').doc(callId).set({
        'type': 'audio',
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'remoteUserName': remoteUserName,
      }, SetOptions(merge: true));

      debugPrint('📞 Audio call started: $channelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to start audio call: $e');
      rethrow;
    }
  }

  /// Start video call
  Future<void> startVideoCall({
    required String callId,
    required String channelName,
    required int userId,
    required String token,
    required String remoteUserName,
  }) async {
    if (!_isInitialized) {
      throw Exception('Agora engine not initialized');
    }

    try {
      _currentCallId = callId;
      _isVideoCall = true;

      await _engine!.enableAudio();
      await _engine!.enableVideo();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: userId,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Store call to Firestore
      await _firestore.collection('calls').doc(callId).set({
        'type': 'video',
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'remoteUserName': remoteUserName,
      }, SetOptions(merge: true));

      debugPrint('📹 Video call started: $channelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to start video call: $e');
      rethrow;
    }
  }

  /// Toggle audio (mute/unmute)
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _engine!.muteLocalAudioStream(_isMuted);
      debugPrint('🔇 Audio ${_isMuted ? 'muted' : 'unmuted'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle mute: $e');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerEnabled = !_isSpeakerEnabled;
      await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
      debugPrint('📢 Speaker ${_isSpeakerEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle speaker: $e');
    }
  }

  /// Toggle camera (for video calls)
  Future<void> toggleCamera() async {
    if (!_isVideoCall) return;
    try {
      _isCameraMuted = !_isCameraMuted;
      await _engine!.muteLocalVideoStream(_isCameraMuted);
      debugPrint('📹 Camera ${_isCameraMuted ? 'disabled' : 'enabled'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to toggle camera: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (!_isVideoCall) return;
    try {
      await _engine!.switchCamera();
      debugPrint('🔄 Camera switched');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
    }
  }

  /// End call
  Future<void> endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      _callDurationTimer?.cancel();

      if (_isJoined && _engine != null) {
        await _engine!.leaveChannel();
      }

      // Update call record
      if (_currentCallId != null) {
        await _firestore.collection('calls').doc(_currentCallId).set({
          'status': 'ended',
          'endTime': FieldValue.serverTimestamp(),
          'duration': _callDuration,
        }, SetOptions(merge: true));
      }

      _resetCallState();
      debugPrint('📞 Call ended');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to end call: $e');
    } finally {
      _isEndingCall = false;
    }
  }

  // ── Event Handlers ────────────────────────────────────────────────────────

  void _onJoinChannelSuccess(RtcConnection connection, int elapsed) {
    _isJoined = true;
    debugPrint('✅ Joined channel successfully');
    notifyListeners();
  }

  void _onUserJoined(RtcConnection connection, int remoteUid, int elapsed) {
    _remoteUid = remoteUid;
    _isConnected = true;
    _startDurationTimer();
    _startAudioCapture();
    debugPrint('👤 Remote user joined: $remoteUid');
    notifyListeners();
  }

  void _onUserOffline(RtcConnection connection, int uid, UserOfflineReasonType reason) {
    _remoteUid = null;
    _isConnected = false;
    debugPrint('👤 Remote user offline: $uid');
    notifyListeners();
    unawaited(endCall());
  }

  void _onLeaveChannel(RtcConnection connection, RtcStats stats) {
    _isJoined = false;
    _remoteUid = null;
    _isConnected = false;
    _callDurationTimer?.cancel();
    debugPrint('🚪 Left channel');
    notifyListeners();
  }

  void _onConnectionStateChanged(
    RtcConnection connection,
    ConnectionStateType state,
    ConnectionChangedReasonType reason,
  ) {
    switch (state) {
      case ConnectionStateType.connectionStateConnecting:
      case ConnectionStateType.connectionStateReconnecting:
        _connectionState = 'Reconnecting...';
        break;
      case ConnectionStateType.connectionStateDisconnected:
        _connectionState = 'Disconnected';
        break;
      case ConnectionStateType.connectionStateFailed:
        _connectionState = 'Connection Failed';
        unawaited(endCall());
        break;
      case ConnectionStateType.connectionStateConnected:
        _connectionState = 'Connected';
        break;
    }
    debugPrint('🔗 Connection state: $_connectionState');
    notifyListeners();
  }

  void _onNetworkQuality(RtcConnection connection, int uid, QualityType txQuality, QualityType rxQuality) {
    _networkQuality = (txQuality.index + rxQuality.index) ~/ 2;
    notifyListeners();
  }

  void _onError(ErrorCodeType err, String msg) {
    debugPrint('❌ Agora error: $err - $msg');
  }

  void _onRemoteAudioStateChanged(
    RtcConnection connection,
    int remoteUid,
    RemoteAudioState state,
    int reason,
    int elapsed,
  ) {
    debugPrint('🎤 Remote audio state: $state for user $remoteUid');
    if (state == RemoteAudioState.remoteAudioStatePlaying) {
      _startAudioCapture();
    }
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  void _startDurationTimer() {
    _callDurationTimer?.cancel();
    _callDuration = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notifyListeners();
    });
  }

  void _resetCallState() {
    _currentCallId = null;
    _isJoined = false;
    _isConnected = false;
    _remoteUid = null;
    _callDuration = 0;
    _connectionState = 'Disconnected';
    _isMuted = false;
    _isSpeakerEnabled = true;
    _isCameraMuted = false;
    _isVideoCall = false;
    _stopAudioCapture();
  }

  // ── Audio Capture for Scam Detection ─────────────────────────────────────

  void _startAudioCapture() async {
    if (_audioCaptureService.isCapturing) return;

    try {
      final started = await _audioCaptureService.startCapture();
      if (started) {
        _audioStreamSubscription = _audioCaptureService.audioStream.listen(
          (audioData) {
            // Audio data available for STT and scam detection
            debugPrint('🎤 Audio chunk received: ${audioData.length} bytes');
          },
          onError: (error) {
            debugPrint('❌ Audio stream error: $error');
          },
        );
        debugPrint('🎤 Audio capture started for scam detection');
      }
    } catch (e) {
      debugPrint('❌ Failed to start audio capture: $e');
    }
  }

  void _stopAudioCapture() async {
    await _audioStreamSubscription?.cancel();
    await _audioCaptureService.stopCapture();
    debugPrint('🎤 Audio capture stopped');
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _audioCaptureService.dispose();
    _engine?.release();
    super.dispose();
  }
}
