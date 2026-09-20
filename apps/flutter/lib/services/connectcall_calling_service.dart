import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/connectcall_call.dart';
import '../models/connectcall_user.dart';
import 'connectcall_permission_service.dart';
import 'connectcall_push_service.dart';
import 'connectcall_agora_audio_capture.dart';
import 'connectcall_stt_service.dart';

/// Manages the Agora RTC engine lifecycle and Firestore call documents.
///
/// Design decisions:
/// - Single instance via Riverpod Provider (ChangeNotifierProvider).
/// - Agora engine is initialized lazily once and reused across calls.
/// - Duration timer is started on BOTH sides when [onUserJoined] fires
///   (not just the callee), so the timer stays in sync.
/// - endCall() is idempotent and guards against double-writes.
class ConnectCallCallingService extends ChangeNotifier {
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
  int _callDuration = 0;
  String _connectionState = 'Disconnected';
  int _networkQuality = 0; // 0=unknown 1=excellent 2=good 3=poor 4=bad
  bool _isEndingCall = false; // Guard against concurrent endCall() calls

  // PhaseGuard STT Integration
  final AgoraAudioCaptureService _audioCapture = AgoraAudioCaptureService();
  final ConnectCallSttService _sttService = ConnectCallSttService();
  Timer? _sttTimer;
  List<int> _audioBuffer = [];
  bool _scamDetected = false;

  // ── Getters ──────────────────────────────────────────────────────────────

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isCameraMuted => _isCameraMuted;
  bool get isJoined => _isJoined;
  bool get isConnected => _isConnected;
  int? get remoteUid => _remoteUid;
  int get callDuration => _callDuration;
  String get connectionState => _connectionState;
  int get networkQuality => _networkQuality;
  String? get currentCallId => _currentCallId;

  String? _appId;
  String? _appCert;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({required String appId, required String appCert}) async {
    if (_isInitialized) return;
    
    _appId = appId;
    _appCert = appCert;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Initialize PhaseGuard audio capture
    _audioCapture.initialize(_engine!);

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
          
          // Start PhaseGuard audio capture and STT
          _startPhaseGuardDetection();
          
          notifyListeners();
        },

        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          _remoteUid = null;
          _isConnected = false;
          notifyListeners();
          // Remote peer left — end the call on our side
          _handleRemoteUserLeft();
        },

        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _isJoined = false;
          _remoteUid = null;
          _isConnected = false;
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

    // 2. Update Firestore
    await _firestore.collection('calls').doc(callId).update({
      'status': 'connected',
      'connectedTime': DateTime.now().millisecondsSinceEpoch,
    });

    _currentCallId = callId;
    _isEndingCall = false;
    _connectionState = 'Connecting...';
    notifyListeners();

    // 3. Configure and join Agora channel
    await _configureEngine(type: type);
    await _joinChannel(channelName, type: type);
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
    if (_isEndingCall) return;
    _isEndingCall = true;

    // Cancel timers first
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    // Leave Agora channel
    await _leaveChannel();

    // Update Firestore call document (only if not already ended)
    if (_currentCallId != null) {
      try {
        final snap =
            await _firestore.collection('calls').doc(_currentCallId).get();
        if (snap.exists) {
          final data = snap.data()!;
          final status = data['status'] as String?;
          // Only write if call isn't already in a terminal state
          if (status == null ||
              status == 'connected' ||
              status == 'calling' ||
              status == 'ringing') {
            final connectedTime = data['connectedTime'] as int?;
            final now = DateTime.now().millisecondsSinceEpoch;
            await _firestore
                .collection('calls')
                .doc(_currentCallId)
                .update({
              'status': 'ended',
              'endTime': now,
              'duration': connectedTime != null
                  ? ((now - connectedTime) / 1000).round()
                  : 0,
            });
          }
        }
      } catch (e) {
        debugPrint('[CallingService] endCall Firestore error: $e');
      }
    }

    await _cleanup();
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

  // ── Firestore Listeners ───────────────────────────────────────────────────

  /// Stream for the callee to detect incoming calls.
  /// Returns the latest unhandled [CallModel] or null.
  Stream<CallModel?> listenForIncomingCalls(String currentUserId) {
    return _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: currentUserId)
        .where('status', whereIn: ['calling', 'ringing'])
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return CallModel.fromMap(doc.data(), doc.id);
    }).handleError((error) => null);
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
        .orderBy('startTime', descending: true)
        .snapshots();

    final calleeStream = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
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
    if (_appId == null || _appCert == null) {
      debugPrint('[CallingService] Cannot join: App ID or Cert not initialized.');
      return;
    }

    final expireTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // 1 hour token
    final token = RtcTokenBuilder.build(
      appId: _appId!,
      appCertificate: _appCert!,
      channelName: channelName,
      uid: '0',
      role: RtcRole.publisher,
      expireTimestamp: expireTimestamp,
    );

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
  }

  Future<void> _leaveChannel() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.stopPreview();
        await _engine!.disableVideo();
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
    _callDuration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notifyListeners();
    });
  }

  void _handleRemoteUserLeft() {
    // When remote leaves, end the call on our side.
    // This will update Firestore, which triggers the other screen to close.
    endCall();
  }

  Future<void> _cleanup() async {
    _currentCallId = null;
    _callDuration = 0;
    _remoteUid = null;
    _isJoined = false;
    _isConnected = false;
    _isMuted = false;
    _isCameraMuted = false;
    _connectionState = 'Disconnected';
    _networkQuality = 0;
    _isEndingCall = false;
    notifyListeners();
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
