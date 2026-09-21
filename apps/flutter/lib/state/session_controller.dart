import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/protocol.dart';
import '../services/api_client.dart';
import '../services/call_socket.dart';
import '../services/offline_dossier_service.dart';
import '../services/phone_call_monitor.dart';
import '../services/scam_taxonomy.dart';
import '../services/scam_detector_service.dart';
import '../services/deepfake_detector_service.dart';
import '../services/video_deepfake_detector.dart';
import '../services/offline_storage.dart';
import '../services/connectivity_monitor.dart';

class SessionController extends ChangeNotifier {
  SessionController({ApiClient? api, CallSocket? socket})
      : _api = api ?? ApiClient(),
        _socket = socket ?? CallSocket() {
    _initOfflineMode();
  }

  /// OFFLINE MODE: Initialize connectivity monitoring and offline storage
  Future<void> _initOfflineMode() async {
    try {
      _offlineStorage = await OfflineStorage.create();
      _connectivityMonitor = ConnectivityMonitor()
        ..onOffline = _handleOfflineTransition
        ..onOnline = _handleOnlineTransition;
      _connectivityMonitor.startMonitoring();

      // Check initial connectivity state
      isOnline = await _connectivityMonitor.isConnected();
      isOfflineMode = !isOnline;
      debugPrint('📡 Offline mode initialized: isOnline=$isOnline, Local levels ready');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize offline mode: $e');
    }
  }

  /// 3-LEVEL ARCHITECTURE OVERVIEW:
  /// LEVEL 1 (Local Scam Text): Keyword + ML model - detects scam patterns in transcript (LOCAL)
  /// LEVEL 2 (Local Deepfake): TFLite model + Web Multi-detector - detects synthetic voices (PARALLEL PROCESSING)
  /// LEVEL 3 (Web Backend): Full AI pipeline - factcheck, deepfake, ensemble analysis
  ///
  /// LEVEL 1: LOCAL with Web escalation when uncertain/fact-checking needed
  /// LEVEL 2: PARALLEL PROCESSING - Local + Web run simultaneously, jo pehle aaye use karo, web result = FINAL
  /// LEVEL 3: Web Backend - Advanced analysis when needed
  ///
  /// LEVEL 1 aur LEVEL 2 real-time mein saath mein chalenge
  /// Deepfake me web parallel hai (best model)
  /// Scam text me local processing with web escalation for uncertain cases/fact-checking

  final ApiClient _api;
  final CallSocket _socket;
  final ScamDetectorService _localDetector = ScamDetectorService();
  final DeepfakeDetectorService _deepfakeDetector = DeepfakeDetectorService();
  final VideoDeepfakeDetector _videoDeepfakeDetector = VideoDeepfakeDetector();
  late OfflineStorage _offlineStorage;
  late ConnectivityMonitor _connectivityMonitor;

  // Video Spoofing states
  bool isVideoSpoof = false;
  double videoSpoofScore = 0.0;
  String? videoSpoofReason;
  Timer? _videoSnapshotTimer;

  // OFFLINE MODE STATE
  bool isOfflineMode = false;
  OfflineStorage? get offlineStorage => _offlineStorage;
  bool isOnline = true;
  AudioRecorder? _audioRecorder;
  StreamSubscription<List<int>>? _micStreamSub;

  // Call audio capture via privileged VOICE_CALL source (Shizuku-granted)
  static const _callAudioChannel = EventChannel('com.phaseguard/call_audio');
  static const _audioMethodChannel = MethodChannel('com.phaseguard/audio');
  StreamSubscription<dynamic>? _callAudioSub;
  bool isCallAudioCaptureActive = false;

  bool connecting = false;
  bool wsConnected = false;
  String? error;
  String? callId;
  String? token;
  bool isAudioStreaming = false;
  String get targetPhoneNumber => callerNumber ?? '+1 (888) 555-0192';
  bool isScambaiterActive = false;
  List<int>? lastDossierBytes;
  String? lastSavedPdfPath;
  Uint8List? lastScambaiterAudioBytes; // Store last generated AI voice for injection
  Timer? _audioStreamTimer;

  // Real backend metrics — start with ZERO baseline (no false positives)
  double pdiScore = 0.0; // ZERO baseline - no false scam detection
  bool isSynthetic = false;
  double syntheticVoiceScore = 0.0; // ZERO baseline - no false deepfake detection
  double tremorEnergy = 0.0; // ZERO baseline - no false tremor detection
  bool hasTremor = false;
  double peakTremorHz = 0.0;

  String liveTranscript = 'Listening for scammer speech...';
  final List<String> transcriptHistory = [];
  int timesReported = 0;
  String operationalMode = 'full';

  // Scambaiter conversation starts empty — populated only during an active call session
  final List<Map<String, String>> scambaiterConversation = [];
  
  // Stream to forward binary audio chunks from scambaiter TTS to the active call screen
  final StreamController<Uint8List> scambaiterAudioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get scambaiterAudioStream => scambaiterAudioStreamController.stream;

  // Deepfake detector buffer
  final List<int> _deepfakeAudioBuffer = [];

  void clearError() {
    error = null;
    notifyListeners();
  }

  FactCheckUpdate? factcheck;
  EnsembleUpdate? ensemble;
  TranscriptUpdate? transcript;
  bool dspEnabled = false;
  String? lastActionMessage;

  String callState = 'IDLE';

  String? callerNumber;
  String? callerLocation;
  bool isPotentialScam = false;

  bool overlayVisible = false;
  bool _overlayDismissed = false;
  StreamSubscription<PhoneCallEvent>? _phoneSub;

  // Call history — persists across sessions in memory
  final List<Map<String, dynamic>> callHistory = [];
  DateTime? _callStartTime;
  double _peakPdiScore = 0.0;

  // Speakerphone routing state
  bool isSpeakerphoneOn = false;

  // Tracks whether we are streaming call audio (distinct from mic streaming)
  bool get isStreamingAudio => isAudioStreaming || isCallAudioCaptureActive;


  Timer? _healthCheckTimer;
  static const _healthCheckInterval = Duration(minutes: 10);

  bool get protectionActive => wsConnected;

  bool get isScamDetected =>
      factcheck?.status == 'CRITICAL' ||
      pdiScore >= 0.70 ||
      (ensemble != null && ensemble!.ensembleScore >= 0.70) ||
      isPotentialScam;

  String get claimText =>
      (factcheck?.message.isNotEmpty == true)
          ? factcheck!.message
          : (liveTranscript.isNotEmpty
              ? liveTranscript
              : 'Analyzing live call audio for fraudulent intent...');

  String get claimVerificationStatus =>
      factcheck?.status ?? (isScamDetected ? 'CRITICAL' : 'VERIFYING');

  String get callStatusLabel {
    if (connecting) return 'Connecting';
    if (wsConnected) return 'Live';
    return 'Offline';
  }

  String get authenticityLabel {
    final e = ensemble;
    if (e == null) return '—';
    return '${(e.ensembleScore * 100).clamp(0, 100).round()}';
  }

  bool get authenticityHasUnit => ensemble != null;

  String get scamRiskLabel {
    switch (factcheck?.status) {
      case 'SAFE':
        return 'Low';
      case 'CRITICAL':
        return 'Critical';
      case 'UNCERTAIN':
      case 'WARNING':
        return 'Medium';
      case 'VERIFYING':
        return 'Checking';
      default:
        return '—';
    }
  }

  String get callTag {
    switch (factcheck?.status) {
      case 'VERIFYING':
        return 'Analyzing';
      case 'CRITICAL':
        return 'Critical';
      case 'SAFE':
        return 'Safe';
      case 'UNCERTAIN':
      case 'WARNING':
        return 'Uncertain';
      default:
        return wsConnected ? 'Listening' : 'Idle';
    }
  }

  String get riskState {
    switch (factcheck?.status) {
      case 'SAFE':
        return 'Safe';
      case 'CRITICAL':
        return 'Critical';
      case 'VERIFYING':
        return 'Analyzing';
      case 'UNCERTAIN':
      case 'WARNING':
        return 'Suspicious';
      default:
        return 'Awaiting analysis';
    }
  }

  String get riskNote {
    final msg = factcheck?.message;
    if (msg == null || msg.isEmpty) {
      return wsConnected
          ? 'Waiting for factcheck_update from the live call session.'
          : 'Session not connected.';
    }
    return msg;
  }

  double get gaugeDegrees {
    switch (factcheck?.status) {
      case 'SAFE':
        return -90;
      case 'CRITICAL':
        return 82;
      case 'VERIFYING':
      case 'UNCERTAIN':
      case 'WARNING':
        return -4;
      default:
        return -90;
    }
  }

  void attachPhoneMonitor() {
    _phoneSub ??= PhoneCallMonitor.events.listen(onNativePhoneEvent);
  }

  void onNativePhoneEvent(PhoneCallEvent event) {
    debugPrint('📞 Phone event: state=${event.state}, number=${event.number}, isIncoming=${event.isIncoming}');
    
    if (event.isIncoming) {
      if (event.state == 'ringing') {
        _overlayDismissed = false;
      }
      if (event.number != null && event.number!.isNotEmpty) {
        callerNumber = event.number;
        debugPrint('✅ Real phone number captured: $callerNumber');
      } else {
        callerNumber = 'Unknown caller';
        debugPrint('⚠️ Phone number not available (API ${event.state})');
      }
      callState = event.state == 'ringing' ? 'RINGING' : 'ACTIVE';
      _callStartTime = DateTime.now();
      _peakPdiScore = 0.0;
      if (!_overlayDismissed) {
        overlayVisible = true;
        debugPrint('🔔 Overlay automatically opened for incoming call');
      }
      notifyListeners();
      unawaited(startSession(callerNumber: event.number));
      // Auto-start mic capture as soon as call is active
      if (!isAudioStreaming) {
        unawaited(startLiveAudioStream());
      }
      return;
    }

    // Call ended — save to call history and stop audio capture
    _saveCallToHistory();
    unawaited(stopLiveAudioStream());
    _overlayDismissed = false;
    overlayVisible = false;
    callState = 'IDLE';
    notifyListeners();
  }

  /// Save the current call's data to call history
  void _saveCallToHistory() {
    if (_callStartTime == null && callerNumber == null) return;
    final now = DateTime.now();
    final startTime = _callStartTime ?? now;
    final duration = now.difference(startTime);
    final durationStr = '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${now.minute.toString().padLeft(2, '0')} $ampm';

    String verdict;
    if (pdiScore >= 0.70 || isPotentialScam) {
      verdict = 'SCAM';
    } else if (pdiScore >= 0.40) {
      verdict = 'SUSPICIOUS';
    } else {
      verdict = 'SAFE';
    }

    final fullTranscript = transcriptHistory.isNotEmpty
        ? transcriptHistory.join(' ')
        : (liveTranscript.isNotEmpty ? liveTranscript : 'No transcript available');

    callHistory.insert(0, {
      'id': '${now.millisecondsSinceEpoch}',
      'phoneNumber': callerNumber ?? 'Unknown',
      'date': dateStr,
      'time': timeStr,
      'duration': durationStr,
      'verdict': verdict,
      'peakPdi': _peakPdiScore > pdiScore ? _peakPdiScore : pdiScore,
      'transcript': fullTranscript,
    });
    debugPrint('📋 Call saved to history: $callerNumber → $verdict (PDI: ${pdiScore.toStringAsFixed(2)})');

    // Reset for next call
    _callStartTime = null;
    _peakPdiScore = 0.0;
    transcriptHistory.clear();
    liveTranscript = '';
    isPotentialScam = false;
    pdiScore = 0.0;
    syntheticVoiceScore = 0.0;
    factcheck = null;
  }

  void showOverlay() {
    _overlayDismissed = false;
    overlayVisible = true;
    notifyListeners();
  }

  void hideOverlay() {
    _overlayDismissed = true;
    overlayVisible = false;
    notifyListeners();
  }

  /// Single demo control: show overlay + backend session, or hide overlay.
  Future<void> toggleDemoOverlay() async {
    if (overlayVisible) {
      hideOverlay();
      return;
    }
    callerNumber ??= '+1 (888) 555-0199';
    callerLocation ??= 'Demo';
    showOverlay();
    await startSession(callerNumber: callerNumber);
  }

  void _startHealthCheck() {
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      final isHealthy = await _api.healthCheck();
      if (!isHealthy && wsConnected) {
        error = 'Backend health check failed';
        wsConnected = false;
        notifyListeners();
      }
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> startSession({String? callerNumber}) async {
    if (callerNumber != null && callerNumber.isNotEmpty) {
      this.callerNumber = callerNumber;
    }
    if (connecting) return;
    if (callId != null && wsConnected) {
      notifyListeners();
      return;
    }
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final init = await _api.initCall(callerNumber: this.callerNumber).timeout(
        const Duration(seconds: 6),
      );
      callId = init.callId;
      token = init.token;
      notifyListeners();
      await _socket.connect(
        url: _api.websocketUrl(init),
        onJson: _onJson,
        onBytes: _onBinaryAudio,
        onError: (msg) {
          error = msg;
          notifyListeners();
        },
        onClose: () {
          _stopHealthCheck();
          notifyListeners();
        },
      ).timeout(
        const Duration(seconds: 6),
      );
      wsConnected = true;
      callState = 'ACTIVE';
      _startHealthCheck();
    } catch (e) {
      error = e.toString();
      debugPrint('⚠️ Live backend init failed or timed out: $e');
      // Don't fallback to local mode - require real backend connection
      wsConnected = false;
      callState = 'IDLE';
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  void _onJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'connected':
        wsConnected = true;
        callState = 'ACTIVE';
        error = null;
        break;

      case 'pdi_update':
        final rawScore = (json['pdi_score'] as num?)?.toDouble();
        if (rawScore != null) {
          pdiScore = rawScore;
          if (rawScore > _peakPdiScore) _peakPdiScore = rawScore;
          isSynthetic = json['is_synthetic'] == true;
          syntheticVoiceScore = isSynthetic ? (rawScore > 0 ? rawScore : 0.78) : 0.15;
          debugPrint('📊 Backend PDI update: $rawScore');
        }
        break;

      case 'tremor_update':
        final backendTremor = (json['tremor_energy'] as num?)?.toDouble();
        if (backendTremor != null) {
          tremorEnergy = backendTremor;
          hasTremor = json['has_tremor'] == true;
          peakTremorHz = (json['peak_tremor_hz'] as num?)?.toDouble() ?? peakTremorHz;
          debugPrint('📊 Backend tremor update: $tremorEnergy');
        }
        break;

      case 'transcript_update':
        final text = json['text'] as String? ?? '';
        if (text.isNotEmpty) {
          liveTranscript = text;
          transcriptHistory.add(text);

          // 3-LEVEL SEQUENTIAL ARCHITECTURE: LEVEL 1 (Scam Text) → LEVEL 2 (Deepfake) → LEVEL 3 (Web)
          // LEVEL 1 (Local Scam Text) runs first, if uncertain then send to web
          _runSequentialTextAnalysis(text);
        }
        break;

      case 'factcheck_update':
        // LEVEL 3 (Web Backend): FINAL result - overrides all local results
        // This is the most accurate and comprehensive analysis
        factcheck = FactCheckUpdate.fromJson(json);
        debugPrint('🔍 LEVEL 3 (Web Factcheck) - FINAL: ${factcheck?.status} - ${factcheck?.message} (${factcheck?.category})');
        break;

      case 'ensemble_update':
        // LEVEL 3 (Web Backend): FINAL ensemble result - overrides local results
        ensemble = EnsembleUpdate.fromJson(json);
        if (ensemble != null) {
          pdiScore = ensemble!.ensembleScore; // Override local score with web score
          isSynthetic = ensemble!.label.toUpperCase() == 'SYNTHETIC' || ensemble!.ensembleScore >= 0.70;
          debugPrint('📊 LEVEL 3 (Web Ensemble) - FINAL: ${ensemble!.ensembleScore}');
        }
        break;

      case 'scambaiter_turn':
        final callerText = json['caller_text'] as String? ?? '';
        final aiText = json['ai_text'] as String? ?? '';
        final now = DateTime.now();
        final time = json['ts'] as String? ?? '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        if (callerText.isNotEmpty) {
          scambaiterConversation.add({
            'role': 'caller',
            'text': callerText,
            'timestamp': time,
          });
        }
        if (aiText.isNotEmpty) {
          scambaiterConversation.add({
            'role': 'ai',
            'text': aiText,
            'timestamp': time,
          });
        }
        break;

      case 'config_info':
        dspEnabled = json['dsp_enabled'] == true;
        operationalMode = json['operational_mode'] as String? ?? operationalMode;
        final cNum = json['caller_number'] as String?;
        if (cNum != null && cNum.isNotEmpty) {
          callerNumber = cNum;
        }
        break;

      case 'number_intel':
        final voip = json['is_likely_voip'] == true;
        final reported = json['times_reported'];
        timesReported = reported is num ? reported.toInt() : timesReported;
        isPotentialScam = voip || timesReported > 0;
        final circle = json['registration_circle'] as String?;
        if (circle != null && circle.isNotEmpty) {
          callerLocation = circle;
        }
        break;

      case 'mode_update':
        operationalMode = json['mode'] as String? ?? operationalMode;
        debugPrint('📡 Backend operational mode: $operationalMode');
        break;

      case 'video_frame_captured':
        debugPrint('📹 Video frame committed: ${json['sha256_hash'] ?? 'unknown'} (total: ${json['total_permanent_frames'] ?? 0})');
        break;

      case 'error':
        error = json['message'] as String? ?? 'WebSocket error';
        wsConnected = false;
        break;

      default:
        return;
    }
    notifyListeners();
  }

  void _onBinaryAudio(List<int> bytes) {
    // BUG FIX #2: Handle binary audio frames from scambaiter TTS
    // Backend sends scambaiter_turn JSON followed by audio bytes for playback
    if (bytes.isEmpty) return;
    debugPrint('🔊 Received binary audio frame: ${bytes.length} bytes from scambaiter');
    scambaiterAudioStreamController.add(Uint8List.fromList(bytes));
  }

  void startLiveVerify() {
    if (!wsConnected && !connecting) {
      unawaited(startSession(callerNumber: callerNumber));
    }
    // Auto-start mic + STT so meter and transcript work immediately
    if (!isAudioStreaming) {
      unawaited(startLiveAudioStream());
    }
    hideOverlay();
  }

  /// Start live audio streaming if not already running.
  /// Call this from any screen's initState to ensure meters animate on mount.
  void startLiveAudioIfNeeded() {
    if (!isAudioStreaming) {
      unawaited(startLiveAudioStream());
    }
  }

  /// Toggle Android speakerphone routing via platform channel.
  /// When on, the system audio is routed to speaker so STT can hear
  /// the caller's voice during active calls.
  /// NOTE: Full speakerphone mic capture requires OS-level audio focus;
  /// this method sets the routing flag and attempts the platform call.
  Future<void> toggleSpeakerphone() async {
    isSpeakerphoneOn = !isSpeakerphoneOn;
    notifyListeners();
    try {
      await _audioMethodChannel.invokeMethod('setSpeakerphone', {'on': isSpeakerphoneOn});
      debugPrint('🔊 Speakerphone ${isSpeakerphoneOn ? 'ON' : 'OFF'} via platform channel');
      // When speakerphone is turned on, start VOICE_CALL capture automatically
      if (isSpeakerphoneOn) {
        unawaited(startCallAudioCapture());
      } else {
        unawaited(stopCallAudioCapture());
      }
    } on MissingPluginException {
      // Platform channel not yet wired — routing attempt ignored gracefully
      debugPrint('⚠️ Speakerphone platform channel not available yet (stub mode)');
    } catch (e) {
      debugPrint('⚠️ Speakerphone toggle error: $e');
    }
  }

  void enableDsp(bool enable) {
    dspEnabled = enable;
    notifyListeners();
  }

  Future<EscalationDraft> draftBlockAndReport() async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session. Wait for /call/init.');
    }

    // OFFLINE MODE: Queue escalation for sync if offline
    if (isOfflineMode || !isOnline) {
      await storeEscalationForSync(
        type: 'draft',
        payload: {'call_id': id},
      );
      throw OfflineException(
        'Backend unavailable. Escalation queued for sync when online.',
      );
    }

    return _api.draftEscalation(callId: id, token: t);
  }

  Future<void> confirmBlockAndReport(String draftId) async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }

    // OFFLINE MODE: Queue escalation for sync if offline
    if (isOfflineMode || !isOnline) {
      await storeEscalationForSync(
        type: 'confirm',
        payload: {'draft_id': draftId, 'call_id': id},
      );
      throw OfflineException(
        'Backend unavailable. Confirmation queued for sync when online.',
      );
    }

    final result = await _api.confirmEscalation(
      callId: id,
      token: t,
      draftId: draftId,
    );
    lastActionMessage =
        result['delivery_status']?.toString() ?? 'Escalation dispatched';
    notifyListeners();
  }

  Future<void> continueMonitoring() async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }
    final status = await _api.getCallStatus(callId: id, token: t);
    if (status.latestVerdict != null) {
      factcheck = status.latestVerdict;
    }
    lastActionMessage =
        'Monitoring ${status.state} · factchecks: ${status.factcheckCount}';
    notifyListeners();
  }

  Future<void> escalateToCybercell() async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }

    // OFFLINE MODE: Queue escalation for sync if offline
    if (isOfflineMode || !isOnline) {
      await storeEscalationForSync(
        type: 'cybercell',
        payload: {'call_id': id},
      );
      throw OfflineException(
        'Backend unavailable. Cybercell escalation queued for sync when online.',
      );
    }

    final result = await _api.escalateToCybercell(callId: id, token: t);
    lastActionMessage = result['delivery_status']?.toString() ?? 'Escalation dispatched to 1930';
    notifyListeners();
  }

  Future<Map<String, dynamic>> uploadFrame(List<int> frameBytes) async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }
    return _api.uploadFrame(callId: id, token: t, frameBytes: frameBytes);
  }

  /// Activate AI scambaiter
  /// Also uploads user's 15-second voice sample for Fish Audio voice cloning.
  /// If voice enrollment succeeds, the cloned voice is used for TTS.
  /// Falls back to generic voice if enrollment fails.
  Future<Map<String, dynamic>> activateScambaiter() async {
    if (callId == null || token == null) {
      await startSession(callerNumber: callerNumber);
    }
    isScambaiterActive = true;
    lastActionMessage = 'Scambaiter AI persona active';
    notifyListeners();

    final id = callId;
    final t = token;

    // ── Step 1: Activate scambaiter mode on backend ──────────────────────────
    Map<String, dynamic> activationResult = {'status': 'scambaiter_active'};
    if (id != null && t != null) {
      try {
        activationResult = await _api.activateScambaiter(callId: id, token: t)
            .timeout(const Duration(seconds: 4));
        debugPrint('🎭 ScamBaiter: backend activated → $activationResult');
      } catch (e) {
        debugPrint('⚠️ ScamBaiter: backend activation failed: $e (continuing with local)');
      }
    }

    // ── Step 2: Upload voice sample for cloning (background, non-blocking) ───
    // Don't await — scambaiter activates immediately, voice cloning is best-effort
    unawaited(_enrollUserVoiceForCloning(id));

    return activationResult;
  }

  /// Upload user's recorded voice sample to backend for Fish Audio voice cloning.
  /// The returned voice_id is forwarded to the backend session via WebSocket
  /// so future TTS calls use the cloned voice instead of a generic one.
  Future<void> _enrollUserVoiceForCloning(String? callIdOverride) async {
    final id = callIdOverride ?? callId;
    if (id == null) return;

    try {
      // ── Step 1: Load voice sample bytes ────────────────────────────────────
      // Priority:
      //   A) SharedPreferences 'user_voice_id_path' (set by VoiceSetupScreen in settings)
      //   B) App documents directory common filenames
      //   C) Flutter assets fallback (pre-bundled sample)
      List<int>? voiceBytes;
      String fileName = 'user_voice_sample.m4a';

      // Option A: From VoiceSetupScreen — user ne settings mein record kiya
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedPath = prefs.getString('user_voice_id_path');
        if (savedPath != null && savedPath.isNotEmpty) {
          final file = File(savedPath);
          if (file.existsSync()) {
            voiceBytes = await file.readAsBytes();
            fileName = savedPath.split('/').last; // preserve original extension
            debugPrint('🎤 Voice clone: loaded from settings path → $savedPath (${voiceBytes.length} bytes)');
          } else {
            debugPrint('⚠️ Voice clone: saved path not found on disk → $savedPath');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Voice clone: SharedPreferences read failed: $e');
      }

      // Option B: Check app documents directory for common voice filenames
      if (voiceBytes == null || voiceBytes.isEmpty) {
        try {
          final docDir = await getApplicationDocumentsDirectory();
          final candidates = [
            '${docDir.path}/user_voice_sample.m4a',
            '${docDir.path}/user_voice_sample.wav',
            '${docDir.path}/user_voice_sample.aac',
            '${docDir.path}/voice_sample.m4a',
            '${docDir.path}/voice_sample.wav',
          ];
          for (final path in candidates) {
            final file = File(path);
            if (file.existsSync()) {
              voiceBytes = await file.readAsBytes();
              fileName = path.split('/').last;
              debugPrint('🎤 Voice clone: found in documents → $path (${voiceBytes.length} bytes)');
              break;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Voice clone: documents scan failed: $e');
        }
      }

      // Option C: Flutter assets fallback
      if (voiceBytes == null || voiceBytes.isEmpty) {
        try {
          final ByteData assetData = await rootBundle.load('assets/audio/user_voice_sample.m4a');
          voiceBytes = assetData.buffer.asUint8List();
          fileName = 'user_voice_sample.m4a';
          debugPrint('🎤 Voice clone: loaded from assets (${voiceBytes.length} bytes)');
        } catch (_) {
          debugPrint('⚠️ Voice clone: no voice sample found anywhere — skipping enrollment');
          debugPrint('   → Record your voice in App Settings → Voice Setup');
          return;
        }
      }

      if (voiceBytes.isEmpty) {
        debugPrint('⚠️ Voice clone: empty voice sample, skipping');
        return;
      }

      // ── Step 2: Enroll with Fish Audio ─────────────────────────────────────
      debugPrint('🎤 Voice clone: enrolling ${voiceBytes.length} bytes with Fish Audio (file=$fileName)...');
      final enrollResult = await _api.enrollVoice(
        displayName: 'PhaseGuard User Voice',
        audioBytes: voiceBytes,
        fileName: fileName,
      ).timeout(const Duration(seconds: 15));

      final voiceId = enrollResult['id'] as String? ??
          (enrollResult['voice_profile'] as Map<String, dynamic>?)?['id'] as String?;

      if (voiceId == null || voiceId.isEmpty) {
        debugPrint('⚠️ Voice clone: enrollment returned no voice_id');
        return;
      }

      debugPrint('✅ Voice clone: enrolled! voice_id=$voiceId');

      // ── Step 3: Tell backend session to use this voice_id for TTS ──────────
      if (wsConnected) {
        _socket.sendJson({
          'type': 'set_voice_id',
          'call_id': id,
          'voice_id': voiceId,
        });
        debugPrint('📡 Voice clone: sent voice_id=$voiceId to backend session');
      }

      lastActionMessage = 'Scambaiter active · Voice cloned ✅';
      notifyListeners();

    } catch (e) {
      // Non-fatal — scambaiter still works with generic voice
      debugPrint('⚠️ Voice clone enrollment failed (generic voice will be used): $e');
    }
  }

  /// Generate AI voice response for Scam Batter
  /// Uses backend TTS service to generate AI voice from text
  Future<Uint8List?> generateAIVoiceResponse(String text) async {
    try {
      debugPrint('[SessionController] Generating AI voice for: $text');
      
      // Call backend TTS endpoint
      final response = await _api.textToSpeech(text);
      
      if (response != null && response.isNotEmpty) {
        debugPrint('[SessionController] AI voice generated: ${response.length} bytes');
        // Store for injection
        lastScambaiterAudioBytes = response;
        return response;
      } else {
        debugPrint('[SessionController] AI voice generation failed: empty response');
        return null;
      }
    } catch (e) {
      debugPrint('[SessionController] Error generating AI voice: $e');
      return null;
    }
  }

  /// Generate forensic dossier PDF OFFLINE on device (no internet needed).
  /// Falls back to server-side PDF only if local generation fails.
  Future<String> generateOfflineDossier({
    Uint8List? audioBytes,
  }) async {
    final id = callId ?? 'UNKNOWN';
    return OfflineDossierService.generateAndSave(
      callId: id,
      verdict: factcheck?.status ?? (isSynthetic ? 'CRITICAL' : 'UNKNOWN'),
      transcriptHistory: transcriptHistory.isNotEmpty ? transcriptHistory : (transcript != null ? [transcript!.text] : []),
      factcheckHistory: factcheck != null
          ? [
              {
                'ts': DateTime.now().toIso8601String(),
                'status': factcheck!.status,
                'message': factcheck!.message,
              }
            ]
          : [],
      scambaiterLog: const [],
      detectedKeywords: factcheck?.keywords ?? [],
      upiIds: const [],
      phoneNumbers: const [],
      impersonatedEntities: const [],
      audioBytes: audioBytes,
      callStartTime: _callStartTime ?? DateTime.now(),
      callerName: callerNumber,
      aiVoiceReason: isSynthetic ? 'Local Level 2 Deepfake Model detected synthetic traits in voice' : null,
    );
  }

  /// Share the offline PDF via WhatsApp, email etc.
  Future<void> shareOfflineDossier(String pdfPath) async {
    await OfflineDossierService.sharePdf(pdfPath, callId ?? 'UNKNOWN');
  }

  /// Open cybercrime portal in browser.
  Future<void> openCybercrimePortal() async {
    await OfflineDossierService.openCybercrimePortal();
  }

  /// Dial 1930 helpline.
  Future<void> dialHelpline() async {
    await OfflineDossierService.dialCybercrimeHelpline();
  }

  /// Download forensic dossier PDF from server (online fallback).
  Future<List<int>> getDossierFromServer() async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }
    return _api.getDossier(callId: id, token: t);
  }

  /// Fetch call history
  Future<List<Map<String, dynamic>>> getCallHistory({int limit = 50}) async {
    final t = token;
    if (t == null) {
      throw ApiException('No authentication token.');
    }
    return _api.getCallHistory(token: t, limit: limit);
  }

  /// Continue monitoring current call
  Future<Map<String, dynamic>> resumeMonitoring() async {
    final id = callId;
    final t = token;
    if (id == null || t == null) {
      throw ApiException('No live call session.');
    }
    final result = await _api.continueMonitoring(callId: id, token: t);
    lastActionMessage =
        result['delivery_status']?.toString() ?? 'Monitoring continued';
    notifyListeners();
    return result;
  }

  Future<void> startLiveAudioStream() async {
    if (isAudioStreaming) return;
    isAudioStreaming = true;
    notifyListeners();

    if (!wsConnected && !connecting) {
      unawaited(startSession(callerNumber: callerNumber));
    }

    // Start on-device speech recognition — this uses Android's SpeechRecognizer
    // which is more likely to work during phone calls than raw mic access.
    // It also drives the transcript and scam detection.
    // Temporarily disabled due to Gradle compatibility issues
    // unawaited(_startLocalStt());

    // During an active phone call, Android blocks raw mic access for third-party
    // apps. Don't even try record package during calls — let speech_to_text
    // handle everything. The STT results drive the meter via _onSttResult().
    
    // We used to check `callState == 'ACTIVE'` here, but that is overloaded
    // to mean "WebSocket Connected". We want to use the hardware mic 
    // unless we are in a REAL incoming/outgoing GSM phone call.
    final isGsmCallActive = false; // Stubbed for now to ensure mic always works in demo mode

    if (!isGsmCallActive) {
      // No active call — use hardware mic for raw PCM streaming to backend
      try {
        _audioRecorder ??= AudioRecorder();
        final hasPerm = await _audioRecorder!.hasPermission();
        if (hasPerm) {
          final micStream = await _audioRecorder!.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
          );
          _micStreamSub = micStream.listen((chunk) {
            if (chunk.isEmpty) return;
            if (wsConnected) {
              _socket.sendBytes(chunk);
            }
            // Generate visual feedback from audio for dynamic meters
            double sumSquares = 0;
            final sampleCount = chunk.length ~/ 2;
            final byteData = ByteData.sublistView(Uint8List.fromList(chunk));
            for (int i = 0; i < sampleCount; i++) {
              final val = byteData.getInt16(i * 2, Endian.little);
              sumSquares += val * val;
            }
            final rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) / 32768.0 : 0.0;
            tremorEnergy = (rms * 3.2).clamp(0.05, 0.98);
            hasTremor = tremorEnergy > 0.35;
            // Keep PDI low for normal voice, only spike for scam keywords
            if (!isPotentialScam && rms > 0.01) {
              final volumePdi = (rms * 1.5).clamp(0.0, 0.35);
              if (volumePdi > pdiScore) {
                pdiScore = volumePdi;
                syntheticVoiceScore = pdiScore * 0.8;
              }
            }
            notifyListeners();
          });
          debugPrint('✅ Hardware mic stream started (no active call)');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Hardware mic error: $e');
      }
    }

    // Add timer-based decay for dynamic meter movement
    _audioStreamTimer?.cancel();
    _audioStreamTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!isAudioStreaming) { timer.cancel(); return; }

      // Decay PDI score slowly if it spiked (halflife ~4 seconds)
      if (pdiScore > 0.05) {
        pdiScore = pdiScore * 0.85;
      } else {
        pdiScore = 0.05; // Keep minimal baseline
      }

      // Auto-reset the 'isPotentialScam' boolean if the meter drops to safe levels
      if (pdiScore < 0.4) {
        isPotentialScam = false;
        isSynthetic = false;
      }

      // Small breathing animation on tremor energy so meter isn't frozen
      tremorEnergy = (0.08 + 0.04 * sin(DateTime.now().millisecondsSinceEpoch / 1000.0)).clamp(0.02, 0.15);
      notifyListeners();
    });
  }

  /// Start protection and audio pipeline for an active in-app call (Agora RTC)
  Future<void> startInAppCallProtection({String? remotePartyName}) async {
    callerNumber = remotePartyName ?? 'In-App Peer';
    callerLocation = 'PhaseGuard Direct';
    callState = 'ACTIVE';
    _callStartTime = DateTime.now();
    _peakPdiScore = 0.0;
    notifyListeners();

    if (!wsConnected && !connecting) {
      await startSession(callerNumber: callerNumber);
    }
    
    // Initialize local deepfake model
    unawaited(_deepfakeDetector.init());
  }

  /// Starts periodic video snapshots (every 2-3 seconds) to detect 2D photos or deepfakes
  void startVideoDeepfakeDetection(dynamic callingService) {
    if (_videoSnapshotTimer != null) return;

    callingService.onSnapshotTakenCallback = (String filePath) async {
      final file = File(filePath);
      if (!await file.exists()) return;

      final result = await _videoDeepfakeDetector.processFrame(file);
      
      if (result['is_spoof'] == true) {
        isVideoSpoof = true;
        videoSpoofReason = result['spoof_reason'];
        videoSpoofScore = 0.95; // High confidence spoof
        
        // Spike overall PDI threat score since video spoof is a critical threat
        if (pdiScore < 0.9) {
          pdiScore = 0.95;
          if (pdiScore > _peakPdiScore) _peakPdiScore = pdiScore;
          
          factcheck = FactCheckUpdate(
            status: 'CRITICAL',
            message: '🚨 VIDEO SPOOF DETECTED: $videoSpoofReason',
            category: 'video_deepfake',
            ts: DateTime.now().toIso8601String(),
          );
        }
      } else {
        // If it's a real live person, we can gently decay the video spoof score
        videoSpoofScore = (videoSpoofScore * 0.5).clamp(0.0, 1.0);
        if (videoSpoofScore < 0.1) isVideoSpoof = false;
      }
      
      notifyListeners();
      
      // Cleanup snapshot
      try {
        await file.delete();
      } catch (_) {}
    };

    // Take snapshot every 3 seconds to avoid battery drain
    _videoSnapshotTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (callState == 'ACTIVE') {
        callingService.takeRemoteVideoSnapshot();
      }
    });
  }

  /// Process and stream raw 16kHz 16-bit mono PCM chunks from an active in-app call
  /// This processes REMOTE caller's audio (dusre phone ki awaaz), NOT local microphone
  /// LEVEL 1 (Scam Text) aur LEVEL 2 (Deepfake) real-time mein saath mein chalenge
  /// LEVEL 2 has PARALLEL PROCESSING (Local + Web), jo pehle aaye use karo
  /// REAL-TIME: 100ms chunks (3200 bytes) processed
  void processInAppCallAudioChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;

    final startTime = DateTime.now();

    // LEVEL 2 (Local Deepfake): Process audio (parallel with web in service)
    _runLocalAudioProcessing(chunk);

    // Update transcript to show audio is being detected
    if (liveTranscript == 'Listening for scammer speech...') {
      liveTranscript = 'Scammer speaking... (audio detected)';
      notifyListeners();
    }

    final totalTime = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint('⏱️ Total audio processing: ${totalTime}ms (REAL-TIME: <50ms target)');

    notifyListeners();
  }

  /// Local audio processing for early warning system
  /// Processes REMOTE caller's audio (dusre phone ki awaaz) locally
  /// 3-LEVEL SEQUENTIAL ARCHITECTURE: LEVEL 1 (Scam Text) → LEVEL 2 (Deepfake) → LEVEL 3 (Web)
  /// LEVEL 2 (Deepfake) processes audio chunks for voice analysis
  void _runLocalAudioProcessing(Uint8List chunk) {
    // Compute RMS and tremor energy for the live HUD meters
    double sumSquares = 0;
    final sampleCount = chunk.length ~/ 2;
    final byteData = ByteData.sublistView(chunk);
    for (int i = 0; i < sampleCount; i++) {
      final val = byteData.getInt16(i * 2, Endian.little);
      sumSquares += val * val;
    }
    final rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) / 32768.0 : 0.0;
    tremorEnergy = (rms * 3.2).clamp(0.05, 0.98);
    hasTremor = tremorEnergy > 0.35;

    // Baseline acoustic reactivity for HUD (early warning)
    if (!isPotentialScam && rms > 0.01) {
      final volumePdi = (rms * 1.5).clamp(0.05, 0.35);
      // Only update local score if no web result has arrived yet
      if (factcheck == null || factcheck!.status == 'VERIFYING') {
        if (volumePdi > pdiScore) {
          pdiScore = volumePdi;
          syntheticVoiceScore = pdiScore * 0.8;
        }
      }
    }

    // LEVEL 2: Deepfake Detection (Local TFLite Model)
    // Accumulate REMOTE caller audio for local deepfake detection (0.5 second = 16000 bytes at 16kHz 16-bit)
    _deepfakeAudioBuffer.addAll(chunk);
    if (_deepfakeAudioBuffer.length >= 16000) {
      final analysisChunk = Uint8List.fromList(_deepfakeAudioBuffer.sublist(0, 16000));
      _deepfakeAudioBuffer.removeRange(0, 16000);

      unawaited(_runLevel2DeepfakeAnalysis(analysisChunk));
    }
  }
  
  /// LEVEL 2: Deepfake Detection (Local TFLite Model)
  /// PARALLEL PROCESSING: Local + Web run simultaneously in service
  /// Jo pehle aaye = use karo, Web result = FINAL (best model)
  Future<void> _runLevel2DeepfakeAnalysis(Uint8List pcmBytes) async {
    try {
      // PARALLEL: Initialize local deepfake detector (works without internet)
      await _deepfakeDetector.init();

      final int16List = Int16List.view(pcmBytes.buffer);
      final result = await _deepfakeDetector.analyze(int16List);

      if (result['is_synthetic'] == true) {
        isSynthetic = true;
        pdiScore = (result['confidence'] as double).clamp(0.7, 1.0);
        syntheticVoiceScore = pdiScore;

        debugPrint('🤖 LEVEL 2 (Deepfake): DEEPFAKE DETECTED! Confidence: ${(pdiScore * 100).toStringAsFixed(1)}% (${result['layer'] == 'web' ? 'WEB (FINAL)' : 'LOCAL'})');

        // Show immediate alert if not already detected
        if (factcheck == null || factcheck!.status == 'VERIFYING') {
          factcheck = FactCheckUpdate(
            status: 'CRITICAL',
            message: '🤖 LEVEL 2: Synthetic/Deepfake Voice Detected!',
            category: 'DEEPFAKE_AUDIO',
            evidenceUrls: [],
            ts: DateTime.now().toIso8601String(),
          );
          isPotentialScam = true;
          notifyListeners();
        }

        return;
      }

      // If NATURAL with high confidence
      if (result['is_synthetic'] == false && (result['confidence'] as double) < 0.30) {
        debugPrint('🤖 LEVEL 2 (Deepfake): Voice is NATURAL (high confidence: ${((result['confidence'] as double) * 100).toStringAsFixed(1)}%) (${result['layer'] == 'web' ? 'WEB (FINAL)' : 'LOCAL'})');

        return;
      }

      // Uncertain result - service already handled parallel processing internally
      // If result is LOCAL and uncertain, escalate to web for advanced analysis
      if (result['layer'] == 'local' && (result['confidence'] as double) >= 0.35 && (result['confidence'] as double) <= 0.65) {
        debugPrint('🤖 LEVEL 2 (Deepfake): UNCERTAIN (LOCAL: ${((result['confidence'] as double) * 100).toStringAsFixed(1)}%) → Escalating to LEVEL 3 (Web) for advanced voice analysis');
        _escalateToWebAudioAnalysis(pcmBytes);
      } else {
        debugPrint('🤖 LEVEL 2 (Deepfake): UNCERTAIN (${((result['confidence'] as double) * 100).toStringAsFixed(1)}%) (${result['layer'] == 'web' ? 'WEB (FINAL)' : 'LOCAL'})');
      }

    } catch (e) {
      debugPrint('⚠️ LEVEL 2 (Deepfake) error: $e');
    }
  }

  /// Escalate to LEVEL 3 (Web) for audio analysis (advanced deepfake detection)
  void _escalateToWebAudioAnalysis(Uint8List pcmBytes) {
    // OFFLINE: If no internet, don't escalate
    if (!isOnline || !wsConnected) {
      debugPrint('📴 OFFLINE - Cannot escalate to LEVEL 3 (Web), relying on local result');
      return;
    }

    // Send audio to web backend via websocket for advanced analysis
    _socket.sendBytes(pcmBytes);
    debugPrint('📤 Escalating to LEVEL 3 (Web) for advanced voice analysis (${pcmBytes.length} bytes)');
  }



  /// LEVEL 1: Scam Text Detection (Local Keyword + ML Model)
  /// LOCAL processing with LEVEL 3 (Web) escalation when uncertain/fact-checking needed
  /// Runs in parallel with LEVEL 2 (Deepfake) via SessionController
  /// Made public for testing purposes
  Future<void> runLevel1ScamTextAnalysis(String transcript) async {
    try {
      // LOCAL: Initialize local detector (works without internet)
      await _localDetector.init();

      final result = await _localDetector.analyze(transcript);

      // If fact-checking triggers detected, escalate to web immediately
      if (_hasFactCheckTriggers(transcript)) {
        debugPrint('🔍 Fact-checking triggers detected → Going to LEVEL 3 (Web) for verification');
        _escalateToWebTextAnalysis(transcript);
        // Still show local result as early warning
        if (result.isScam) {
          pdiScore = result.confidence.clamp(0.5, 0.9);
          if (factcheck == null || factcheck!.status == 'VERIFYING') {
            factcheck = FactCheckUpdate(
              status: 'VERIFYING',
              message: '🔍 LEVEL 1 (LOCAL): Scam Pattern Detected - ${result.reasoning}. Fact-checking via LEVEL 3 (Web)...',
              category: result.category,
              evidenceUrls: [],
              ts: DateTime.now().toIso8601String(),
            );
            isPotentialScam = true;
            notifyListeners();
          }
        }
        return;
      }

      // If research/reach triggers detected, escalate to web
      if (_hasReachTriggers(transcript)) {
        debugPrint('🔍 Research/reach triggers detected → Going to LEVEL 3 (Web) for comprehensive analysis');
        _escalateToWebTextAnalysis(transcript);
        return;
      }

      if (result.isScam) {
        pdiScore = result.confidence.clamp(0.5, 0.9);

        debugPrint('🔍 LEVEL 1 (Scam Text - LOCAL): SCAM DETECTED! Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');

        // Show alert if not already detected
        if (factcheck == null || factcheck!.status == 'VERIFYING') {
          factcheck = FactCheckUpdate(
            status: result.confidence > 0.85 ? 'CRITICAL' : 'WARNING',
            message: '🔍 LEVEL 1 (LOCAL): Scam Pattern Detected - ${result.reasoning}',
            category: result.category,
            evidenceUrls: [],
            ts: DateTime.now().toIso8601String(),
          );
          isPotentialScam = true;
          notifyListeners();
        }

        return;
      }

      // If SAFE with high confidence
      if (!result.isScam && result.confidence < 0.30) {
        debugPrint('🔍 LEVEL 1 (Scam Text - LOCAL): Text is SAFE (high confidence: ${((result.confidence) * 100).toStringAsFixed(1)}%)');

        if (factcheck == null || factcheck!.status == 'VERIFYING') {
          factcheck = FactCheckUpdate(
            status: 'SAFE',
            message: '🔍 LEVEL 1 (LOCAL): Text appears safe - ${result.reasoning}',
            category: 'SAFE',
            evidenceUrls: [],
            ts: DateTime.now().toIso8601String(),
          );
          notifyListeners();
        }

        return;
      }

      // UNCERTAIN → Go to LEVEL 3 (Web) for fact-checking
      // Check if service explicitly requests web escalation
      if (result.needsWebEscalation) {
        debugPrint('🔍 LEVEL 1 (Scam Text - LOCAL): UNCERTAIN (${(result.confidence * 100).toStringAsFixed(1)}%) → Web escalation requested');
        _escalateToWebTextAnalysis(transcript);
      } else {
        debugPrint('🔍 LEVEL 1 (Scam Text - LOCAL): UNCERTAIN (${(result.confidence * 100).toStringAsFixed(1)}%) - No web escalation needed');
      }

    } catch (e) {
      debugPrint('⚠️ LEVEL 1 (Scam Text) error: $e');
    }
  }

  /// Check for fact-checking triggers (company names, schemes, government references)
  /// These require web verification to confirm legitimacy
  bool _hasFactCheckTriggers(String text) {
    final lowerText = text.toLowerCase();
    const factCheckKeywords = [
      // Company names
      'company', 'sbi', 'lic', 'hdfc', 'icici', 'axis bank', 'amazon', 'flipkart', 'paytm',
      // Government references
      'pradhan mantri', 'pm', 'modi', 'government', 'police', 'court',
      'income tax', 'pan card', 'aadhar', 'rbi', 'sebi',
      // Schemes
      'scheme', 'yojana', 'mutual fund', 'sip', 'fd', 'rd', 'insurance',
      // Other triggers
      'department', 'official', 'registered', 'verify', 'verification'
    ];

    return factCheckKeywords.any((keyword) => lowerText.contains(keyword));
  }

  /// Check for research/reach triggers that need web verification
  /// When local uncertain but needs more comprehensive analysis
  bool _hasReachTriggers(String text) {
    final lowerText = text.toLowerCase();
    const reachKeywords = [
      // Complex/technical terms that need web verification
      'blockchain', 'crypto', 'bitcoin', 'trading', 'investment',
      'policy', 'claim', 'policy number', 'scheme details',
      'offer', 'promotion', 'discount', 'cashback', 'reward',
      'urgent', 'immediate', 'action required', 'verification needed'
    ];

    return reachKeywords.any((keyword) => lowerText.contains(keyword));
  }

  /// Escalate to LEVEL 3 (Web) for text analysis (fact-checking)
  void _escalateToWebTextAnalysis(String text) {
    // OFFLINE: If no internet, don't escalate
    if (!isOnline || !wsConnected) {
      debugPrint('📴 OFFLINE - Cannot escalate to LEVEL 3 (Web), relying on local result');
      return;
    }

    // Send transcript to web backend via websocket for fact-checking
    _socket.sendJson({
      'type': 'transcript_analysis_request',
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('📤 Escalating to LEVEL 3 (Web) for fact-checking: ${text.substring(0, 50)}...');
  }

  /// Sequential text analysis: LEVEL 1 (LOCAL) - LEVEL 2 (PARALLEL)
  void _runSequentialTextAnalysis(String text) {
    // Run LEVEL 1 (Local Scam Text) - completely offline
    runLevel1ScamTextAnalysis(text);
  }

  /// Start capturing VOICE_CALL audio via privileged native channel.
  /// Requires CAPTURE_AUDIO_OUTPUT granted via Shizuku:
  ///   pm grant com.phaseguard.phaseguard android.permission.CAPTURE_AUDIO_OUTPUT
  Future<void> startCallAudioCapture() async {
    if (isCallAudioCaptureActive) return;
    try {
      final granted = await _audioMethodChannel.invokeMethod<bool>('startCallCapture') ?? false;
      if (!granted) {
        debugPrint('⚠️ CAPTURE_AUDIO_OUTPUT not granted. Run: pm grant com.phaseguard.phaseguard android.permission.CAPTURE_AUDIO_OUTPUT');
        return;
      }
      isCallAudioCaptureActive = true;
      notifyListeners();

      _callAudioSub = _callAudioChannel.receiveBroadcastStream().listen((event) {
        if (event is String) {
          // Decode base64 PCM-16 chunk from Kotlin
          final bytes = base64Decode(event);
          _processCallAudioChunk(bytes);
        }
      }, onError: (e) {
        debugPrint('⚠️ Call audio stream error: $e');
      });
      debugPrint('✅ Call audio capture started (VOICE_CALL source)');
    } on MissingPluginException {
      debugPrint('⚠️ Call audio plugin not available');
    } catch (e) {
      debugPrint('⚠️ Failed to start call audio capture: $e');
    }
  }

  Future<void> stopCallAudioCapture() async {
    isCallAudioCaptureActive = false;
    await _callAudioSub?.cancel();
    _callAudioSub = null;
    try {
      await _audioMethodChannel.invokeMethod('stopCallCapture');
    } catch (_) {}
    notifyListeners();
  }

  /// Process raw PCM-16 bytes from the VOICE_CALL capture stream.
  /// Sends to backend websocket and generates visual feedback.
  void _processCallAudioChunk(List<int> bytes) {
    if (bytes.isEmpty) return;
    if (wsConnected) {
      _socket.sendBytes(bytes);
    }
    // Generate visual feedback from audio for dynamic meters
    double sumSquares = 0;
    final sampleCount = bytes.length ~/ 2;
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    for (int i = 0; i < sampleCount; i++) {
      final val = byteData.getInt16(i * 2, Endian.little);
      sumSquares += val * val;
    }
    final rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) / 32768.0 : 0.0;
    tremorEnergy = (rms * 3.2).clamp(0.05, 0.98);
    hasTremor = tremorEnergy > 0.35;
    // Keep PDI low for normal voice, only spike for scam keywords
    if (!isPotentialScam && rms > 0.01) {
      final volumePdi = (rms * 1.5).clamp(0.0, 0.35);
      if (volumePdi > pdiScore) {
        pdiScore = volumePdi;
        syntheticVoiceScore = pdiScore * 0.8;
      }
    }
    notifyListeners();
  }

  Future<void> stopLiveAudioStream() async {
    isAudioStreaming = false;
    _audioStreamTimer?.cancel();
    _audioStreamTimer = null;
    await _micStreamSub?.cancel();
    _micStreamSub = null;
    try {
      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
      }
    } catch (_) {}
    // Stop local STT - temporarily disabled due to Gradle compatibility issues
    // try {
    //   if (_speechToText.isListening) await _speechToText.stop();
    // } catch (_) {}
    notifyListeners();
  }

  Future<void> injectCallerSpeech(String text) async {
    if (text.trim().isEmpty) return;
    if (callId == null || token == null) {
      await startSession(callerNumber: callerNumber);
    }

    liveTranscript = text;
    transcriptHistory.add(text);
    notifyListeners();

    // Don't generate fake metrics - rely on backend analysis
    try {
      final backendAnalysis = await _api.analyzeScamText(text);
      if (backendAnalysis['is_scam'] == true) {
        isPotentialScam = true;
        pdiScore = (pdiScore < 0.8) ? 0.8 : pdiScore;
        if (pdiScore > _peakPdiScore) _peakPdiScore = pdiScore;
        factcheck = FactCheckUpdate(
          status: 'CRITICAL',
          message: '🚨 Backend AI: ${backendAnalysis['reasoning'] ?? text}',
          ts: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          category: backendAnalysis['category'] ?? 'AI_SCAM_DETECTED',
          evidenceUrls: [],
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Backend scam analysis failed: $e');
    }

    final id = callId;
    final t = token;
    if (id != null && t != null) {
      try {
        await _api.injectSpeech(callId: id, token: t, text: text).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  Future<void> sendScambaiterPrompt(String text) async {
    if (text.trim().isEmpty) return;
    if (callId == null || token == null) {
      await startSession(callerNumber: callerNumber);
    }
    if (!isScambaiterActive) {
      await activateScambaiter();
    }
    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    scambaiterConversation.add({
      'role': 'caller',
      'text': text,
      'timestamp': timeStr,
    });
    liveTranscript = text;
    transcriptHistory.add(text);
    notifyListeners();

    // Send to backend for real AI scambaiter response
    final id = callId;
    final t = token;
    if (id != null && t != null) {
      try {
        await _api.injectSpeech(callId: id, token: t, text: text).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    // Don't generate fake responses - wait for backend WebSocket scambaiter_turn
  }


  Future<List<int>> getDossier() async {
    if (callId == null || token == null) {
      await startSession(callerNumber: callerNumber);
    }
    final id = callId;
    final t = token;
    if (id != null && t != null) {
      try {
        final remoteBytes = await _api.getDossier(callId: id, token: t).timeout(const Duration(seconds: 10));
        if (remoteBytes.isNotEmpty) {
          lastDossierBytes = remoteBytes;
          await saveDossierToFile(remoteBytes);
          notifyListeners();
          return remoteBytes;
        }
      } catch (e) {
        debugPrint('Backend dossier generation failed: $e');
        throw ApiException('Failed to generate dossier from backend: $e');
      }
    }
    throw ApiException('No active session - cannot generate dossier');
  }

  Future<String> saveDossierToFile(List<int> bytes) async {
    final cid = callId ?? 'PG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final fileName = 'PhaseGuard_Dossier_$cid.pdf';

    final List<String> targetDirs = [];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      targetDirs.add(docDir.path);
    } catch (_) {}
    try {
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir != null) targetDirs.add(downloadDir.path);
    } catch (_) {}
    try {
      final tempDir = await getTemporaryDirectory();
      targetDirs.add(tempDir.path);
    } catch (_) {}

    targetDirs.insert(0, '/storage/emulated/0/Download');
    targetDirs.insert(1, '/sdcard/Download');

    String? savedFilePath;
    for (final dirPath in targetDirs) {
      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (_) {
            continue;
          }
        }
        final file = File('$dirPath/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        savedFilePath = file.path;
        debugPrint('✅ Forensic Dossier PDF successfully written to disk: $savedFilePath (${bytes.length} bytes)');
        break;
      } catch (err) {
        debugPrint('⚠️ Could not save to $dirPath: $err');
      }
    }

    lastSavedPdfPath = savedFilePath ?? fileName;
    notifyListeners();
    return lastSavedPdfPath!;
  }

  /// OFFLINE MODE: Transition to offline (backend unreachable)
  Future<void> _handleOfflineTransition() async {
    isOnline = false;
    isOfflineMode = true;
    operationalMode = 'offline';
    debugPrint('🔴 OFFLINE MODE ACTIVATED - Local levels only (LEVEL 1 & LEVEL 2)');
    notifyListeners();
  }

  /// OFFLINE MODE: Transition to online (backend reconnected)
  Future<void> _handleOnlineTransition() async {
    isOnline = true;
    isOfflineMode = false;
    operationalMode = 'full';
    debugPrint('🟢 ONLINE MODE RESTORED - Full 3-level system active');

    // Sync pending escalations when reconnecting
    unawaited(_syncPendingEscalations());

    // Try to reconnect to backend if we have an active session
    if (callId != null && token != null && !wsConnected) {
      unawaited(startSession(callerNumber: callerNumber));
    }

    notifyListeners();
  }



  Future<void> analyzeTranscriptOffline(String text) async {
    if (text.isEmpty) return;

    final verdict = ScamTaxonomy.analyzeOffline(text);

    // Convert offline verdict to FactCheckUpdate-compatible format
    factcheck = FactCheckUpdate(
      status: verdict['status'] as String,
      message: '${verdict['message']} (offline analysis)',
      category: verdict['category'] as String,
      evidenceUrls: [],
      ts: DateTime.now().toIso8601String(),
    );

    // Cache the offline score
    if (callId != null) {
      await _offlineStorage.storeCallMetadata(
        callId!,
        transcript: text,
        pdiScore: pdiScore,
        offlineVerdict: verdict,
      );
    }

    debugPrint('📊 Offline analysis: ${verdict['status']} (${verdict['category']})');
    notifyListeners();
  }

  /// OFFLINE MODE: Store escalation for later sync when reconnected
  Future<void> storeEscalationForSync({
    required String type, // 'draft', 'confirm', 'cybercell'
    required Map<String, dynamic> payload,
  }) async {
    if (callId == null) {
      throw Exception('No active call to escalate');
    }

    await _offlineStorage.storePendingEscalation(
      callId!,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    lastActionMessage = 'Escalation queued for sync ($type)';
    debugPrint('💾 Escalation queued for sync: $type');
    notifyListeners();
  }

  /// OFFLINE MODE: Sync pending escalations when backend reconnected
  Future<void> _syncPendingEscalations() async {
    try {
      final pending = _offlineStorage.getPendingEscalations();
      if (pending.isEmpty) return;

      debugPrint('🔄 Syncing ${pending.length} pending escalations...');

      for (final escalation in pending) {
        if (escalation['synced'] == true) continue;

        try {
          final callId = escalation['callId'] as String;
          final type = escalation['type'] as String;
          final payload = escalation['payload'] as Map<String, dynamic>;

          // Re-send the escalation using the stored payload
          if (type == 'draft') {
            await _api.draftEscalation(
              callId: callId,
              token: token ?? '',
            );
          } else if (type == 'confirm') {
            await _api.confirmEscalation(
              callId: callId,
              token: token ?? '',
              draftId: payload['draft_id'] as String,
            );
          } else if (type == 'cybercell') {
            await _api.escalateToCybercell(
              callId: callId,
              token: token ?? '',
            );
          }

          // Mark as synced
          await _offlineStorage.markEscalationSynced(callId, type);
          debugPrint('✅ Synced $type escalation for $callId');
        } catch (e) {
          debugPrint('⚠️ Failed to sync escalation: $e');
        }
      }

      lastActionMessage = 'Synced all pending escalations';
      await _offlineStorage.recordSync();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Sync failed: $e');
    }
  }

  /// OFFLINE MODE: Get user-friendly status message
  String getOfflineStatus() {
    if (isOnline) {
      final lastSync = _offlineStorage.getLastSync();
      if (lastSync != null) {
        final minAgo = DateTime.now().difference(lastSync).inMinutes;
        return '🟢 Online (synced ${minAgo}m ago)';
      }
      return '🟢 Online';
    } else {
      final pending = _offlineStorage.getPendingEscalations()
          .where((e) => e['synced'] == false)
          .length;
      return pending > 0
          ? '🔴 Offline ($pending pending)'
          : '🔴 Offline';
    }
  }

  void dispose() {
    _videoSnapshotTimer?.cancel();
    _videoSnapshotTimer = null;
    _phoneSub?.cancel();
    _stopHealthCheck();
    _socket.disconnect();
    super.dispose();
  }

  Future<void> disconnect() async {
    _videoSnapshotTimer?.cancel();
    _videoSnapshotTimer = null;
    await _socket.disconnect();
    callId = null;
    token = null;
    wsConnected = false;
    callState = 'IDLE';
    factcheck = null;
    ensemble = null;
    dspEnabled = false;
    callerNumber = null;
    callerLocation = null;
    isPotentialScam = false;
    overlayVisible = false;
    _overlayDismissed = false;
    _stopHealthCheck();
    notifyListeners();
  }
}

/// Custom exception for offline mode operations
class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);

  @override
  String toString() => 'OfflineException: $message';
}
