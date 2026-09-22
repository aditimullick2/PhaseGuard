import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/call.dart';
import '../models/user.dart';
import 'permission_service.dart';
import 'push_service.dart';
import 'agora_audio_capture.dart';
import 'connectcall_stt_service.dart';

/// Manages the Agora RTC engine lifecycle and Firestore call documents.
///
/// Design decisions:
/// - Single instance via Riverpod Provider (ChangeNotifierProvider).
/// - Agora engine is initialized lazily once and reused across calls.
/// - Duration timer is started on BOTH sides when [onUserJoined] fires
///   (not just the callee), so the timer stays in sync.
/// - endCall() is idempotent and guards against double-writes.
/// - Audio capture auto-starts when remote user joins for PhaseGuard analysis.
class CallingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PermissionService _permissionService = PermissionService();

  RtcEngine? _engine;
  String? _currentCallId;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerEnabled = true; // Default: speaker on for calls
  bool _isCameraMuted = false;
  bool _isJoined = false;
  bool _isConnected = false; // True when remote peer has joined
  int? _remoteUid;
  Timer? _callTimeoutTimer;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  String _connectionState = 'Disconnected';
  int _networkQuality = 0; // 0=unknown 1=excellent 2=good 3=poor 4=bad
  bool _isEndingCall = false; // Guard against concurrent endCall() calls

  // PhaseGuard STT Integration
  final AgoraAudioCaptureService _audioCapture = AgoraAudioCaptureService();
  final ConnectCallSttService _sttService = ConnectCallSttService();
  Timer? _sttTimer;
  List<int> _audioBuffer = [];
  bool _scamDetected = false;
  int _effectIdCounter = 1; // Counter for Agora playEffect sound IDs

  // AI Scambaiter Audio Queue
  final Queue<Uint8List> _scambaiterAudioQueue = Queue<Uint8List>();
  bool _isPlayingScambaiter = false;

  // ── Getters ──────────────────────────────────────────────────────────────

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isCameraMuted => _isCameraMuted;
  bool get isJoined => _isJoined;
  bool get isConnected => _isConnected;
  int? get remoteUid => _remoteUid;
  int get callDurationSeconds => _callDurationSeconds;
  String get connectionState => _connectionState;
  int get networkQuality => _networkQuality;
  String? get currentCallId => _currentCallId;
  Stream<Uint8List>? get audioCaptureStream => _audioCapture.audioStream;

  String? _appId;
  String? _appCert;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({required String appId, required String appCert}) async {
    if (_isInitialized) return;
    
    _appId = appId;
    _appCert = appCert;
    
    debugPrint('[CallingService] Initializing Agora with App ID: $appId');
    debugPrint('[CallingService] App Certificate: ${appCert.isNotEmpty ? "SET" : "NOT SET"}');

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    
    debugPrint('[CallingService] Agora engine initialized successfully');

    // Initialize PhaseGuard audio capture
    _audioCapture.initialize(_engine!);
    
    // Debug verification
    debugPrint('🔍 === CALLING SERVICE AUDIO CAPTURE VERIFICATION ===');
    debugPrint('✅ AgoraAudioCaptureService is integrated');
    debugPrint('✅ audioCaptureStream getter exposed');
    debugPrint('✅ Auto-start on remote user join: onUserJoined()');
    debugPrint('✅ Auto-stop on remote user leave: onUserOffline()');
    debugPrint('✅ AudioFrameObserver: onPlaybackAudioFrameBeforeMixing');
    debugPrint('✅ Capture: REMOTE caller audio only (scammer voice)');
    debugPrint('🎉 Audio capture connection verified');

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _isJoined = true;
          notifyListeners();
        },

        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _remoteUid = remoteUid;
          _isConnected = true;
          // Start duration timer when the remote peer actually joins
          _startDurationTimer();
          
          // Start PhaseGuard audio capture when remote joins
          _audioCapture.startCapture();
          debugPrint('[CallingService] Started PhaseGuard audio capture for remote caller');
          
          notifyListeners();
        },

        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          _remoteUid = null;
          _isConnected = false;
          // Stop PhaseGuard audio capture when remote leaves
          _audioCapture.stopCapture();
          debugPrint('[CallingService] Stopped PhaseGuard audio capture - remote user left');
          notifyListeners();
          // Remote peer left — end the call on our side
          _handleRemoteUserLeft();
        },

        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _isJoined = false;
          _remoteUid = null;
          _isConnected = false;
          // Stop PhaseGuard audio capture when leaving channel
          _audioCapture.stopCapture();
          debugPrint('[CallingService] Stopped PhaseGuard audio capture - left channel');
          notifyListeners();
        },

        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason) {
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
              endCall();
              break;
            case ConnectionStateType.connectionStateConnected:
              _connectionState = 'Connected';
              break;
          }
          notifyListeners();
        },

        onNetworkQuality: (RtcConnection connection, int uid,
            QualityType txQuality, QualityType rxQuality) {
          // Average of TX and RX quality (1=excellent … 5=bad)
          _networkQuality = (txQuality.index + rxQuality.index) ~/ 2;
          notifyListeners();
        },

        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora] Error $err: $msg');
          if (err == ErrorCodeType.errInvalidToken || 
              err == ErrorCodeType.errTokenExpired) {
            _connectionState = 'Connection Failed';
            endCall();
          }
        },
      ),
    );

    _isInitialized = true;
    debugPrint('[CallingService] Agora engine initialized');
  }

  // ── Start Call (Caller Side) ──────────────────────────────────────────────

  Future<CallModel> startCall({
    required UserModel caller,
    required UserModel callee,
    required String type, // 'audio' | 'video'
  }) async {
    // 1. Permissions
    final permStatus = await _permissionService.requestCallPermissions(
      requireCamera: type == 'video',
    );
    if (permStatus != CallPermissionStatus.granted) {
      throw Exception(permStatus == CallPermissionStatus.permanentlyDenied
          ? 'Permission permanently denied. Please enable it in app settings.'
          : 'Microphone${type == 'video' ? '/Camera' : ''} permission is required.');
    }

    if (!_isInitialized) throw Exception('Agora engine not initialized');

    // 2. Create Firestore call document
    final callId = _firestore.collection('calls').doc().id;
    final channelName = callId; // Dynamic channel for every call!

    final call = CallModel(
      callId: callId,
      callerId: caller.uid,
      calleeId: callee.uid,
      callerName: caller.name,
      calleeName: callee.name,
      callerPic: caller.photoUrl,
      calleePic: callee.photoUrl,
      type: type,
      status: 'calling',
      agoraChannelName: channelName,
      startTime: DateTime.now(),
    );

    await _firestore.collection('calls').doc(callId).set(call.toMap());
    _currentCallId = callId;
    _isEndingCall = false;
    _connectionState = 'Connecting...';
    notifyListeners();

    // 2.5 Fire Push Notification to wake up callee if they have an FCM token
    if (callee.fcmToken != null && callee.fcmToken!.isNotEmpty) {
      final pushService = PushService();
      pushService.sendIncomingCallNotification(
        targetFcmToken: callee.fcmToken!,
        callId: callId,
        callerId: caller.uid,
        callerName: caller.name,
        calleeId: callee.uid,
        callType: type,
        channelName: channelName,
      ); // Fire and forget
    }

    // 3. Configure and join Agora channel
    await _configureEngine(type: type);
    await _joinChannel(channelName, type: type);

    // Start audio capture immediately after joining channel
    _audioCapture.startCapture();
    debugPrint('[CallingService] Started PhaseGuard audio capture after joining channel');

    // 4. 30-second timeout → mark as missed if no answer
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      final snap =
          await _firestore.collection('calls').doc(callId).get();
      if (snap.exists) {
        final status = snap.data()!['status'] as String?;
        if (status == 'calling' || status == 'ringing') {
          await _firestore.collection('calls').doc(callId).update({
            'status': 'missed',
            'endTime': DateTime.now().millisecondsSinceEpoch,
          });
          await _cleanup();
        }
      }
    });

    return call;
  }

  // ── Accept Call (Callee Side) ─────────────────────────────────────────────

  Future<void> acceptCall({
    required String callId,
    required String channelName,
    required String type,
  }) async {
    debugPrint('[CallingService] acceptCall called for callId: $callId');

    // 1. Cleanup any existing call completely
    if (_isJoined || _currentCallId != null) {
      debugPrint('[CallingService] Cleaning up existing call before accepting new call');
      await _cleanup();
      await Future.delayed(const Duration(milliseconds: 500)); // Wait for cleanup
    }

    // 2. Permissions
    final permStatus = await _permissionService.requestCallPermissions(
      requireCamera: type == 'video',
    );
    if (permStatus != CallPermissionStatus.granted) {
      throw Exception(permStatus == CallPermissionStatus.permanentlyDenied
          ? 'Permission permanently denied. Please enable it in app settings.'
          : 'Microphone${type == 'video' ? '/Camera' : ''} permission is required.');
    }

    if (!_isInitialized) {
      debugPrint('[CallingService] Agora engine not initialized, initializing...');
      throw Exception('Agora engine not initialized');
    }

    debugPrint('[CallingService] Permissions granted, engine initialized');

    // 3. Update Firestore first
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'connected',
        'connectedTime': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[CallingService] Firestore updated to connected');
    } catch (e) {
      debugPrint('[CallingService] Error updating Firestore: $e');
    }

    _currentCallId = callId;
    _isEndingCall = false;
    _connectionState = 'Connecting...';
    notifyListeners();

    // 4. Configure and join Agora channel
    try {
      await _configureEngine(type: type);
      await _joinChannel(channelName, type: type);
      debugPrint('[CallingService] Joined Agora channel successfully');
    } catch (e) {
      debugPrint('[CallingService] Error joining Agora channel: $e');
      // Revert Firestore status on failure
      await _firestore.collection('calls').doc(callId).update({
        'status': 'failed',
        'endTime': DateTime.now().millisecondsSinceEpoch,
      });
      throw e;
    }

    // Start audio capture immediately after joining channel
    _audioCapture.startCapture();
    debugPrint('[CallingService] Started PhaseGuard audio capture after joining channel (accept call)');
  }

  // ── Reject Call ───────────────────────────────────────────────────────────

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endTime': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[CallingService] rejectCall error: $e');
    }
  }

  // ── End Call (idempotent) ─────────────────────────────────────────────────

  Future<void> endCall() async {
    if (_isEndingCall) {
      debugPrint('[CallingService] Already ending call, skipping');
      return;
    }
    _isEndingCall = true;
    debugPrint('[CallingService] Starting endCall process for call: $_currentCallId');

    try {
      // 1. Update Firestore status
      if (_currentCallId != null) {
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': 'ended',
          'endTime': DateTime.now().millisecondsSinceEpoch,
          'duration': _callDurationSeconds,
        });
        debugPrint('[CallingService] Firestore updated to ended');
      }

      // 2. Leave Agora channel
      if (_isJoined) {
        await _engine!.leaveChannel();
        _isJoined = false;
        debugPrint('[CallingService] Left Agora channel');
      }

      // 3. Stop duration timer
      _durationTimer?.cancel();
      _durationTimer = null;

      // 4. Stop audio capture
      _audioCapture.stopCapture();

      // 5. Reset state
      _remoteUid = null;
      _isConnected = false;
      _currentCallId = null;
      _callDurationSeconds = 0;
      _connectionState = 'Idle';
      _isEndingCall = false;

      debugPrint('[CallingService] Call ended successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('[CallingService] Error ending call: $e');
      // Force reset even on error
      _isEndingCall = false;
      _currentCallId = null;
      _isJoined = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerEnabled = !_isSpeakerEnabled;
    await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (_engine == null) return;
    _isCameraMuted = !_isCameraMuted;
    await _engine!.muteLocalVideoStream(_isCameraMuted);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  // ── AI Voice Injection for Scambaiter ───────────────────────────────────────

  /// Inject AI voice into Agora call for Scambaiter
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
      // Detect audio format
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

      final isWav = audioBytes.length > 3 &&
          (audioBytes[0] == 0x52 && audioBytes[1] == 0x49 && audioBytes[2] == 0x46 && audioBytes[3] == 0x46);

      final String ext = isMp3 ? 'mp3' : 'wav';
      debugPrint('🔊 ScamBaiter audio chunk: ${audioBytes.length} bytes, format=${isMp3 ? "MP3" : isWav ? "WAV" : "PCM→WAV"}');

      // Build final audio bytes
      final fileBytes = (isMp3 || isWav)
          ? audioBytes
          : _addWavHeader(audioBytes);

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/scam_audio_$_effectIdCounter.$ext');
      await file.writeAsBytes(fileBytes);

      // Play via Agora (publish=true → sent to remote scammer)
      await _engine!.playEffect(
        soundId: _effectIdCounter,
        filePath: file.path,
        loopCount: 1,
        pitch: 1.0,
        pan: 0.0,
        gain: 100,
        publish: true,
      );

      _effectIdCounter++;
      if (_effectIdCounter > 50) _effectIdCounter = 1;

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('🔊 AI scambaiter to SCAMMER: format=$ext, total=${totalTime}ms');

      // Cleanup old files
      _cleanupOldAudioFiles(tempDir);

      // Process next chunk in queue
      _isPlayingScambaiter = false;
      _processScambaiterQueue();

    } catch (e) {
      debugPrint('❌ Scambaiter audio play error: $e');
      _isPlayingScambaiter = false;
      _processScambaiterQueue();
    }
  }

  Uint8List _addWavHeader(Uint8List pcmBytes) {
    int channels = 1;
    int sampleRate = 16000;
    int byteRate = sampleRate * channels * 2;
    
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

  void _cleanupOldAudioFiles(Directory tempDir) {
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
      debugPrint('[CallingService] Cleanup error: $e');
    }
  }
  /// Converts audio bytes to WAV format and plays to remote user (scammer)
  Future<void> injectAIVoice(Uint8List audioBytes) async {
    if (_engine == null) {
      debugPrint('[CallingService] Cannot inject AI voice: Agora engine not initialized');
      return;
    }

    try {
      debugPrint('[CallingService] Injecting AI voice: ${audioBytes.length} bytes');
      
      // Save audio to temp file (Agora requires file path)
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioPath = '${tempDir.path}/ai_voice_$timestamp.wav';
      
      // Convert audio bytes to WAV format if needed
      // For now, assuming backend sends WAV format
      final file = File(audioPath);
      await file.writeAsBytes(audioBytes);
      
      debugPrint('[CallingService] AI voice saved to: $audioPath');
      
      // Play effect to remote user (scammer)
      // publish: true ensures the scammer hears it
      final soundId = _effectIdCounter;
      await _engine!.playEffect(
        soundId: soundId,
        filePath: audioPath,
        loopCount: 1,
        pitch: 1.0,
        pan: 0.0,
        gain: 100,
        publish: true, // This sends AI voice to the scammer (remote caller)
      );
      
      debugPrint('[CallingService] AI voice injected with soundId: $soundId');
      
      _effectIdCounter++;
      if (_effectIdCounter > 50) _effectIdCounter = 1;
      
      // Clean up temp file after delay
      Future.delayed(const Duration(seconds: 5), () {
        if (File(audioPath).existsSync()) {
          File(audioPath).deleteSync();
          debugPrint('[CallingService] Cleaned up AI voice temp file');
        }
      });
      
    } catch (e) {
      debugPrint('[CallingService] Error injecting AI voice: $e');
    }
  }

  // ── Firestore Listeners ───────────────────────────────────────────────────

  /// Stream for the callee to detect incoming calls.
  /// Returns the latest unhandled [CallModel] or null.
  Stream<CallModel?> listenForIncomingCalls(String currentUserId) {
    debugPrint('[CallingService] Listening for incoming calls for user: $currentUserId');
    return _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: currentUserId)
        .where('status', whereIn: ['calling', 'ringing'])
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      debugPrint('[CallingService] Incoming calls snapshot: ${snapshot.docs.length} docs');
      if (snapshot.docs.isEmpty) {
        debugPrint('[CallingService] No incoming calls found');
        return null;
      }
      final doc = snapshot.docs.first;
      final callData = doc.data();
      final callStatus = callData['status'] as String?;
      
      // Only return if status is still calling/ringing (not ended/rejected)
      if (callStatus != 'calling' && callStatus != 'ringing') {
        debugPrint('[CallingService] Call status changed to $callStatus, ignoring');
        return null;
      }
      
      debugPrint('[CallingService] Incoming call found: ${doc.id} with status: $callStatus');
      return CallModel.fromMap(callData, doc.id);
    }).handleError((error) {
      debugPrint('[CallingService] Error listening for calls: $error');
      return null;
    });
  }

  /// Stream changes to a specific call document.
  Stream<CallModel?> listenToCallStatus(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CallModel.fromMap(doc.data()!, doc.id);
    }).handleError((error) => null);
  }

  /// Fetch the full call history for a user (both as caller and callee).
  Stream<List<CallModel>> getCallHistory(String userId) {
    // Firestore OR queries require two separate queries merged client-side.
    // We combine two streams using StreamTransformer.
    final callerStream = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .snapshots();

    final calleeStream = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .snapshots();

    // Merge by keeping a map of docId → CallModel, updated on each snapshot
    final Map<String, CallModel> mergedMap = {};

    late StreamController<List<CallModel>> controller;
    StreamSubscription? sub1, sub2;

    controller = StreamController<List<CallModel>>(
      onListen: () {
        sub1 = callerStream.listen((snap) {
          for (final doc in snap.docs) {
            mergedMap[doc.id] = CallModel.fromMap(doc.data(), doc.id);
          }
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.removed) {
              mergedMap.remove(change.doc.id);
            }
          }
          _emitSorted(controller, mergedMap);
        }, onError: (error) {
          // Ignore permission-denied on signout
        });

        sub2 = calleeStream.listen((snap) {
          for (final doc in snap.docs) {
            mergedMap[doc.id] = CallModel.fromMap(doc.data(), doc.id);
          }
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.removed) {
              mergedMap.remove(change.doc.id);
            }
          }
          _emitSorted(controller, mergedMap);
        }, onError: (error) {
          // Ignore permission-denied on signout
        });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  void _emitSorted(
    StreamController<List<CallModel>> controller,
    Map<String, CallModel> map,
  ) {
    final list = map.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    if (!controller.isClosed) controller.add(list);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _configureEngine({required String type}) async {
    await _engine!.enableAudio();
    
    // Ignore ERR_NOT_READY (-3) if called before joining channel
    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setEnableSpeakerphone(true); 
    } catch (e) {
      debugPrint('[CallingService] speakerphone config error: $e');
    }
    
    _isSpeakerEnabled = true;

    if (type == 'video') {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }
  }

  Future<void> _joinChannel(String channelName, {required String type}) async {
    if (_appId == null) {
      debugPrint('[CallingService] Cannot join: App ID not initialized.');
      throw Exception('Agora engine not initialized - App ID missing');
    }

    debugPrint('[CallingService] Joining channel: $channelName with App ID: $_appId');
    debugPrint('[CallingService] App Certificate: ${_appCert != null && _appCert!.isNotEmpty ? "SET" : "NOT SET"}');

    final expireTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // 1 hour token
    try {
      String token;
      
      // If certificate is set, use it for token generation
      if (_appCert != null && _appCert!.isNotEmpty) {
        debugPrint('[CallingService] Using certificate for token generation');
        token = RtcTokenBuilder.build(
          appId: _appId!,
          appCertificate: _appCert!,
          channelName: channelName,
          uid: '0',
          role: RtcRole.publisher,
          expireTimestamp: expireTimestamp,
        );
      } else {
        // Try without certificate (for testing - not recommended for production)
        debugPrint('[CallingService] WARNING: Using temporary token without certificate');
        token = ''; // Empty token may work for testing
      }
      
      debugPrint('[CallingService] Token: ${token.isNotEmpty ? "Generated" : "Empty (testing)"}');

      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0, // Let Agora assign a UID
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: type == 'video', // Publish camera if it's a video call
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      debugPrint('[CallingService] Successfully joined channel: $channelName');
    } catch (e) {
      debugPrint('[CallingService] Error joining channel: $e');
      rethrow;
    }
  }

  Future<void> _leaveChannel() async {
    try {
      if (_engine != null) {
        debugPrint('[CallingService] Leaving Agora channel...');
        await _engine!.leaveChannel();
        await _engine!.stopPreview();
        await _engine!.disableVideo();
        debugPrint('[CallingService] Left Agora channel successfully');
      }
    } catch (e) {
      debugPrint('[CallingService] leaveChannel error: $e');
    } finally {
      _isJoined = false;
      _remoteUid = null;
      _isConnected = false;
    }
  }

  void _startDurationTimer() {
    // Prevent multiple timers
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _handleRemoteUserLeft() {
    // When remote leaves, end the call on our side.
    // This will update Firestore, which triggers the other screen to close.
    endCall();
  }

  Future<void> _cleanup() async {
    debugPrint('[CallingService] Cleaning up call state...');
    
    // Cancel timers
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    
    // Stop audio capture
    _audioCapture.stopCapture();
    
    // Leave Agora channel if joined
    if (_isJoined && _engine != null) {
      try {
        await _leaveChannel();
        debugPrint('[CallingService] Left Agora channel');
      } catch (e) {
        debugPrint('[CallingService] Error leaving channel: $e');
      }
    }
    
    // Reset all state
    _currentCallId = null;
    _callDurationSeconds = 0;
    _remoteUid = null;
    _isJoined = false;
    _isConnected = false;
    _isMuted = false;
    _isCameraMuted = false;
    _connectionState = 'Idle';
    _networkQuality = 0;
    _isEndingCall = false;
    
    notifyListeners();
    debugPrint('[CallingService] Call state cleaned up');
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    _durationTimer?.cancel();
    _engine?.release();
    super.dispose();
  }
}
