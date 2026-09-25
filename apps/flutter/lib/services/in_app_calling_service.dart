import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

/// InAppCallingService manages Agora RTC Engine in Testing Mode (App ID only)
/// and hooks into MediaEngine to capture raw 16kHz 16-bit mono PCM remote audio,
/// batching it into 100ms chunks (3200 bytes) for PhaseGuard's scam detection pipeline.
class InAppCallingService extends ChangeNotifier {
  static String get configuredAppId => AppConfig.agoraAppId;

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerphoneOn = false;
  bool _isCameraOff = false;
  int? _remoteUid;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  int? _localUid; // Track local user ID to skip local audio

  // AI Scambaiter Audio Queue
  final Queue<Uint8List> _scambaiterAudioQueue = Queue<Uint8List>();
  bool _isPlayingScambaiter = false;
  int _effectIdCounter = 1;

  // 100ms audio frame accumulator: 16000 Hz * 0.1s * 2 bytes = 3200 bytes
  static const int targetChunkBytes = 3200;
  final List<int> _audioAccumulator = [];
  final StreamController<Uint8List> _remoteAudioController = StreamController<Uint8List>.broadcast();

  // Getters
  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isSpeakerphoneOn => _isSpeakerphoneOn;
  bool get isCameraOff => _isCameraOff;
  int? get remoteUid => _remoteUid;
  int get callDurationSeconds => _callDurationSeconds;
  Stream<Uint8List> get remoteAudioStream => _remoteAudioController.stream;

  Future<void> initialize({String? appId}) async {
    if (_isInitialized) return;

    final targetId = appId ?? configuredAppId;
    if (targetId.isEmpty) {
      debugPrint('[InAppCallingService] Warning: AGORA_APP_ID is empty. Check .env file or --dart-define');
      AppConfig.printConfig();
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: targetId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Configure raw playback audio frame parameters for 16kHz mono 16-bit PCM
    // 320 samples = 20ms frame at 16kHz
    try {
      await _engine!.setPlaybackAudioFrameParameters(
        sampleRate: 16000,
        channel: 1,
        mode: RawAudioFrameOpModeType.rawAudioFrameOpModeReadOnly,
        samplesPerCall: 320,
      );

      // CRITICAL FIX: Also set BeforeMixing parameters, otherwise onPlaybackAudioFrameBeforeMixing returns stereo!
      await _engine!.setPlaybackAudioFrameBeforeMixingParameters(
        sampleRate: 16000,
        channel: 1,
        samplesPerCall: 320,
      );

      // Register raw audio frame observer on MediaEngine
      final mediaEngine = _engine!.getMediaEngine();
      mediaEngine.registerAudioFrameObserver(
        AudioFrameObserver(
          // This captures REMOTE caller's audio BEFORE mixing (dusre phone ki awaaz)
          onPlaybackAudioFrameBeforeMixing: (String channelId, int uid, AudioFrame frame) {
            // ONLY capture REMOTE caller audio, skip local user's audio
            // The caller (who made the call) should NOT be analyzed
            // debugPrint('[InAppCallingService] 🎤 Audio frame from user $uid (LOCAL=$_localUid REMOTE=$_remoteUid)');
            if (uid == _localUid) {
              // debugPrint('[InAppCallingService] ⏭️ Skipping LOCAL user audio - only analyzing REMOTE caller');
              return;
            }
            // debugPrint('[InAppCallingService] 🎤 REMOTE audio frame from user $uid (${frame.buffer?.length ?? 0} bytes)');
            _handleIncomingAudioFrame(frame);
          },
          // Fallback: captures mixed playback audio if before mixing not available
          onPlaybackAudioFrame: (String channelId, AudioFrame frame) {
            // debugPrint('[InAppCallingService] 🎤 Playback audio frame (mixed) - SKIPPING to avoid local audio contamination');
            // Don't capture mixed audio as it contains local user's voice
          },
        ),
      );
      debugPrint('[InAppCallingService] AudioFrameObserver registered - capturing ONLY REMOTE caller audio at 16kHz mono');
    } catch (e) {
      debugPrint('[InAppCallingService] Error configuring raw audio observer: $e');
    }

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[InAppCallingService] Joined channel: ${connection.channelId}');
          _isJoined = true;
          _localUid = connection.localUid; // Capture local user's UID
          debugPrint('[InAppCallingService] Local user UID: $_localUid');
          _engine?.enableLocalAudio(true);
          _engine?.muteLocalAudioStream(false);
          _engine?.adjustRecordingSignalVolume(100);
          _engine?.adjustPlaybackSignalVolume(100);
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[InAppCallingService] Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          _isConnected = true;
          _startDurationTimer();
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[InAppCallingService] Remote user offline: $remoteUid ($reason)');
          _remoteUid = null;
          _isConnected = false;
          _stopDurationTimer();
          notifyListeners();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[InAppCallingService] Left channel');
          _isJoined = false;
          _isConnected = false;
          _remoteUid = null;
          _stopDurationTimer();
          notifyListeners();
        },
        onAudioEffectFinished: (int soundId) {
          if (soundId >= 1 && soundId <= 50) {
            _isPlayingScambaiter = false;
            _processScambaiterQueue();
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[InAppCallingService] Agora error $err: $msg');
        },
      ),
    );

    _isInitialized = true;
    notifyListeners();
  }

  void _handleIncomingAudioFrame(AudioFrame frame) {
    final buffer = frame.buffer;
    if (buffer == null || buffer.isEmpty) {
      debugPrint('[InAppCallingService] ⚠️ Empty audio frame received');
      return;
    }

    final startTime = DateTime.now();

    _audioAccumulator.addAll(buffer);

    // Flush in 100ms chunks (3200 bytes) for REAL-TIME streaming
    // 100ms chunks = 10 chunks per second = optimal for real-time speech
    while (_audioAccumulator.length >= targetChunkBytes) {
      final chunk = Uint8List.fromList(_audioAccumulator.sublist(0, targetChunkBytes));
      _audioAccumulator.removeRange(0, targetChunkBytes);
      _remoteAudioController.add(chunk);
    }

    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    if (totalTime > 10) {
      debugPrint('[InAppCallingService] ⚠️ Audio frame processing slow: ${totalTime}ms (target: <10ms)');
    }
  }

  Future<void> joinCall({
    required String channelName,
    required String callType, // 'audio' or 'video'
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Request permissions
    final micPerm = await Permission.microphone.request();
    debugPrint('[InAppCallingService] Microphone permission status: $micPerm');
    if (callType == 'video') {
      await Permission.camera.request();
    }

    await _engine!.enableAudio();
    await _engine!.enableLocalAudio(true);
    await _engine!.muteLocalAudioStream(false);
    await _engine!.adjustRecordingSignalVolume(100);
    await _engine!.adjustPlaybackSignalVolume(100);

    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(false);
      await _engine!.setEnableSpeakerphone(false);
      _isSpeakerphoneOn = false;
    } catch (_) {}

    if (callType == 'video') {
      await _engine!.enableVideo();
      await _engine!.startPreview();
      _isCameraOff = false;
    } else {
      await _engine!.disableVideo();
      _isCameraOff = true;
    }

    _isMuted = false;
    _audioAccumulator.clear();

    // In Agora Testing Mode (App ID only), token is empty string ""
    await _engine!.joinChannel(
      token: '',
      channelId: channelName,
      uid: 0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: callType == 'video',
        autoSubscribeAudio: true,
        autoSubscribeVideo: callType == 'video',
      ),
    );
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerphoneOn = !_isSpeakerphoneOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerphoneOn);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (_engine == null) return;
    _isCameraOff = !_isCameraOff;
    await _engine!.muteLocalVideoStream(_isCameraOff);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  Future<void> leaveCall() async {
    _stopDurationTimer();
    _audioAccumulator.clear();
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.stopPreview();
        await _engine!.disableVideo();
      }
    } catch (e) {
      debugPrint('[InAppCallingService] Error leaving channel: $e');
    } finally {
      _isJoined = false;
      _isConnected = false;
      _remoteUid = null;
      _callDurationSeconds = 0;
      notifyListeners();
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  // ==== SCAMBAITER AUDIO INJECTION ====

  Uint8List _addWavHeader(Uint8List pcmBytes) {
    int channels = 1;
    int sampleRate = 16000;
    int byteRate = sampleRate * channels * 2; // 16-bit
    
    var header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); // 'RIFF'
    header.setUint32(4, 36 + pcmBytes.length, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); // 'WAVE'
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20); // 'fmt '
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
    if (pcmBytes.isEmpty) return;
    _scambaiterAudioQueue.add(pcmBytes);
    _processScambaiterQueue();
  }

  Future<void> _processScambaiterQueue() async {
    if (_isPlayingScambaiter || _scambaiterAudioQueue.isEmpty || _engine == null) return;

    _isPlayingScambaiter = true;
    final audioBytes = _scambaiterAudioQueue.removeFirst();
    final startTime = DateTime.now();

    try {
      // ── Step 1: Detect audio format ───────────────────────────────────────
      // MP3 magic bytes: MPEG sync word starts with 0xFF 0xEx/0xFx
      // ID3 tag (common MP3 header): 0x49 0x44 0x33 ("ID3")
      bool isMp3 = false;
      for (int i = 0; i < audioBytes.length - 2 && i < 100; i++) {
        if (audioBytes[i] == 0x49 && audioBytes[i+1] == 0x44 && audioBytes[i+2] == 0x33) {
          isMp3 = true;
          break;
        }
        if (audioBytes[i] == 0xFF && (audioBytes[i+1] & 0xE0) == 0xE0) {
          isMp3 = true;
          break;
        }
      }

      // WAV magic bytes: RIFF (0x52 0x49 0x46 0x46)
      final isWav = audioBytes.length > 3 &&
          (audioBytes[0] == 0x52 && audioBytes[1] == 0x49 && audioBytes[2] == 0x46 && audioBytes[3] == 0x46);

      final String ext = isMp3 ? 'mp3' : 'wav';
      debugPrint('🔊 ScamBaiter audio chunk: ${audioBytes.length} bytes, format=${isMp3 ? "MP3" : isWav ? "WAV" : "PCM→WAV"}');

      // ── Step 2: Build final audio bytes ────────────────────────────────
      final convertStart = DateTime.now();
      final Uint8List fileBytes = (isMp3 || isWav)
          ? audioBytes                  // MP3 or already WAV: use directly, no header needed
          : _addWavHeader(audioBytes);  // Raw PCM: wrap with RIFF/WAV header
      final convertTime = DateTime.now().difference(convertStart).inMilliseconds;

      // ── Step 3: Write to temp file ────────────────────────────────────────
      final writeStart = DateTime.now();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/scam_audio_$_effectIdCounter.$ext');
      await file.writeAsBytes(fileBytes);
      final writeTime = DateTime.now().difference(writeStart).inMilliseconds;

      // ── Step 4: Play via Agora (publish=true → sent to remote scammer) ────
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
      debugPrint('🔊 AI scambaiter to SCAMMER: format=$ext, convert=${convertTime}ms, write=${writeTime}ms, play=${playTime}ms, total=${totalTime}ms');

      // Cleanup old files to prevent storage bloat
      _cleanupOldAudioFiles(tempDir);

    } catch (e) {
      debugPrint('❌ Scambaiter audio play error: $e');
      _isPlayingScambaiter = false;
      _processScambaiterQueue();
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
      debugPrint('[InAppCallingService] Cleanup error: $e');
    }
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _remoteAudioController.close();
    _engine?.release();
    super.dispose();
  }
}
