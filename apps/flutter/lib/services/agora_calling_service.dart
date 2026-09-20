import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _isSpeakerEnabled = false;
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

  // 100ms audio frame accumulator: 16000 Hz * 0.1s * 2 bytes = 3200 bytes
  static const int targetChunkBytes = 3200;
  final List<int> _audioAccumulator = [];

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

      // Configure raw playback audio frame parameters for 16kHz mono 16-bit PCM
      // This allows audio capture WITHOUT speakerphone being ON
      try {
        await _engine!.setPlaybackAudioFrameParameters(
          sampleRate: 16000,
          channel: 1,
          mode: RawAudioFrameOpModeType.rawAudioFrameOpModeReadOnly,
          samplesPerCall: 320,
        );

        // Register raw audio frame observer on MediaEngine
        final mediaEngine = _engine!.getMediaEngine();
        mediaEngine.registerAudioFrameObserver(
          AudioFrameObserver(
            // This captures REMOTE caller's audio BEFORE mixing (dusre phone ki awaaz)
            onPlaybackAudioFrameBeforeMixing: (String channelId, int uid, AudioFrame frame) {
              debugPrint('🎤 Remote audio frame from user $uid (${frame.buffer?.length ?? 0} bytes)');
              _handleIncomingAudioFrame(frame);
            },
            // Fallback: captures mixed playback audio if before mixing not available
            onPlaybackAudioFrame: (String channelId, AudioFrame frame) {
              debugPrint('🎤 Playback audio frame (mixed) (${frame.buffer?.length ?? 0} bytes)');
              _handleIncomingAudioFrame(frame);
            },
          ),
        );
        debugPrint('✅ Agora AudioFrameObserver registered - capturing REMOTE caller audio at 16kHz mono');
      } catch (e) {
        debugPrint('⚠️ AudioFrameObserver setup failed: $e');
      }

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
          onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid, RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
            _onRemoteAudioStateChanged(connection, remoteUid, state, reason, elapsed);
          },
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
    // AudioFrameObserver automatically starts capturing REMOTE caller's audio
    debugPrint('👤 Remote user joined: $remoteUid - starting REMOTE audio capture');
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
    RemoteAudioStateReason reason,
    int elapsed,
  ) {
    debugPrint('🎤 Remote audio state: $state for user $remoteUid');
    if (state == RemoteAudioState.remoteAudioStateDecoding) {
      _startAudioCapture();
    }
  }

  void _handleIncomingAudioFrame(AudioFrame frame) {
    final buffer = frame.buffer;
    if (buffer == null || buffer.isEmpty) {
      debugPrint('⚠️ Empty audio frame received');
      return;
    }

    final startTime = DateTime.now();

    _audioAccumulator.addAll(buffer);

    // Flush in 100ms chunks (3200 bytes) for REAL-TIME streaming
    // 100ms chunks = 10 chunks per second = optimal for real-time
    while (_audioAccumulator.length >= targetChunkBytes) {
      final chunkStartTime = DateTime.now();
      final chunk = Uint8List.fromList(_audioAccumulator.sublist(0, targetChunkBytes));
      _audioAccumulator.removeRange(0, targetChunkBytes);
      _audioCaptureService.addAudioChunk(chunk);

      final chunkTime = DateTime.now().difference(chunkStartTime).inMilliseconds;
      debugPrint('📤 Audio chunk: ${chunk.length} bytes (${chunkTime}ms, REAL-TIME 100ms chunks)');
    }

    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    if (totalTime > 10) {
      debugPrint('⚠️ Audio frame processing slow: ${totalTime}ms (target: <10ms)');
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
    _isSpeakerEnabled = false;
    _isCameraMuted = false;
    _isVideoCall = false;
    _stopAudioCapture();
  }

  // ── Audio Capture for Scam Detection ─────────────────────────────────────

  // Callback for processing audio chunks (provided by SessionController)
  Function(Uint8List)? _audioChunkCallback;

  void setAudioChunkCallback(Function(Uint8List) callback) {
    _audioChunkCallback = callback;
    debugPrint('🎤 Audio chunk callback set for REMOTE caller audio processing');
  }

  void _startAudioCapture() async {
    if (_audioCaptureService.isCapturing) return;

    // AudioFrameObserver is already feeding data into the stream
    // Subscribe to the stream for dual processing (local + websocket)
    _audioStreamSubscription = _audioCaptureService.audioStream.listen(
      (audioData) {
        // Process audio chunk via callback (local ML + websocket streaming)
        if (_audioChunkCallback != null) {
          _audioChunkCallback!(audioData);
        }
        debugPrint('🎤 REMOTE caller audio chunk received: ${audioData.length} bytes');
      },
      onError: (error) {
        debugPrint('❌ Audio stream error: $error');
      },
    );
    debugPrint('🎤 REMOTE caller audio capture stream subscribed (via AudioFrameObserver)');
  }

  void _stopAudioCapture() async {
    await _audioStreamSubscription?.cancel();
    _audioCaptureService.stopCapture();
    _audioAccumulator.clear();
    debugPrint('🎤 Audio capture stopped');
  }

  // ── Scambaiter Audio Injection ───────────────────────────────────────────

  int _effectIdCounter = 1;

  Uint8List _addWavHeader(Uint8List pcmBytes) {
    int channels = 1;
    int sampleRate = 16000;
    int byteRate = sampleRate * channels * 2; // 16-bit

    var header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); // 'RIFF'
    header.setUint32(4, 36 + pcmBytes.length, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); // 'WAVE'
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x66); header.setUint8(15, 0x20); // 'fmt '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61); // 'data'
    header.setUint32(40, pcmBytes.length, Endian.little);

    final wavBytes = Uint8List(44 + pcmBytes.length);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, 44 + pcmBytes.length, pcmBytes);
    return wavBytes;
  }

  /// Inject the AI scambaiter voice into the live call so the scammer hears it
  /// SCENARIO: We call victim → Scammer is on victim's phone (remote caller)
  /// This AI voice goes to the SCAMMER (who is on the remote end), not the victim
  /// publish: true sends audio to the remote caller (scammer)
  /// REAL-TIME: Optimized for minimal latency (<500ms total)
  Future<void> playScambaiterAudio(Uint8List pcmBytes) async {
    if (_engine == null || pcmBytes.isEmpty) return;

    final startTime = DateTime.now();

    try {
      // Step 1: Convert PCM to WAV (fast operation)
      final convertStart = DateTime.now();
      final wavBytes = _addWavHeader(pcmBytes);
      final convertTime = DateTime.now().difference(convertStart).inMilliseconds;

      // Step 2: Write to temp file (fast on modern devices)
      final writeStart = DateTime.now();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/scam_audio_$_effectIdCounter.wav');
      await file.writeAsBytes(wavBytes);
      final writeTime = DateTime.now().difference(writeStart).inMilliseconds;

      // Step 3: Play via Agora (network latency depends on connection)
      final playStart = DateTime.now();
      await _engine!.playEffect(
        soundId: _effectIdCounter,
        filePath: file.path,
        loopCount: 1,
        pitch: 1.0,
        pan: 0.0,
        gain: 100,
        publish: true, // This sends AI voice to the scammer (remote caller)
      );
      final playTime = DateTime.now().difference(playStart).inMilliseconds;

      _effectIdCounter++;
      if (_effectIdCounter > 50) _effectIdCounter = 1;

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('🔊 AI scambaiter to SCAMMER: convert=${convertTime}ms, write=${writeTime}ms, play=${playTime}ms, total=${totalTime}ms (REAL-TIME target: <500ms)');

      // Cleanup old files to prevent storage bloat
      _cleanupOldAudioFiles(tempDir);

    } catch (e) {
      debugPrint('❌ Scambaiter audio play error: $e');
    }
  }

  void _cleanupOldAudioFiles(Directory tempDir) {
    // Keep only recent audio files to prevent storage issues
    try {
      final files = tempDir.listSync().where((f) => f.path.contains('scam_audio_')).toList();
      if (files.length > 10) {
        files.sort((a, b) => a.path.compareTo(b.path));
        for (var i = 0; i < files.length - 10; i++) {
          if (files[i] is File) {
            (files[i] as File).deleteSync();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Cleanup error: $e');
    }
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
