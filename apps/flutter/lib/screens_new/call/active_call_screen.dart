import 'dart:async';
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/in_app_call.dart';
import '../../services/call_signaling_service.dart';
import '../../services/in_app_calling_service.dart';
import '../../state/session_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_background.dart';
import '../../widgets/pg_gauge.dart';
import '../scambaiter_session.dart';

class ActiveCallScreen extends StatefulWidget {
  final InAppCall call;
  final AppUser remoteUser;
  final bool isCaller;
  final CallSignalingService signalingService;
  final InAppCallingService callingService;

  const ActiveCallScreen({
    super.key,
    required this.call,
    required this.remoteUser,
    required this.isCaller,
    required this.signalingService,
    required this.callingService,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<Uint8List>? _scambaiterAudioSub;
  StreamSubscription<InAppCall?>? _callSub;
  bool _isEnding = false;
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _ensureCallJoined();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAudioProtection());
    _listenToCallState();
  }

  Future<void> _ensureCallJoined() async {
    if (!widget.callingService.isJoined) {
      debugPrint('[ActiveCallScreen] Ensuring call is joined to Agora channel...');
      await widget.callingService.joinCall(
        channelName: widget.call.channelName,
        callType: widget.call.type,
      );
    }
  }

  void _initAudioProtection() {
    final session = context.read<SessionController>();
    
    // Start backend session and wait for it to connect, then start streaming audio
    session.startInAppCallProtection(remotePartyName: widget.remoteUser.displayName).then((_) {
      if (!mounted) return;
      
      debugPrint('[ActiveCallScreen] ✅ Backend session ready. wsConnected=${session.wsConnected}');
      
      // Feed 100ms raw PCM audio chunks from Agora into PhaseGuard's detection pipeline
      _audioSub = widget.callingService.remoteAudioStream.listen((chunk) {
        if (mounted) {
          session.processInAppCallAudioChunk(chunk);
        }
      });

      // Listen to AI Scambaiter TTS bytes and inject them into the active call
      _scambaiterAudioSub = session.scambaiterAudioStream.listen((chunk) {
        if (mounted && widget.callingService.isJoined) {
          widget.callingService.playScambaiterAudio(chunk);
          debugPrint('[ActiveCallScreen] 🔊 AI scambaiter audio sent to SCAMMER (remote caller)');
        }
      });
    }).catchError((e) {
      debugPrint('[ActiveCallScreen] ❌ Backend session failed: $e');
    });
  }

  void _listenToCallState() {
    _callSub = widget.signalingService.streamCall(widget.call.callId).listen((updatedCall) {
      if (updatedCall == null || _isEnding || !mounted) return;
      if (updatedCall.isEnded) {
        _endCallLocally();
      }
    });
  }

  Future<void> _endCallLocally() async {
    if (_isEnding) return;
    _isEnding = true;
    _audioSub?.cancel();
    _scambaiterAudioSub?.cancel();
    _callSub?.cancel();

    final duration = widget.callingService.callDurationSeconds;
    await widget.signalingService.endCall(widget.call.callId, durationSeconds: duration);
    await widget.callingService.leaveCall();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call ended (${_formatDuration(duration)}) • Protected by PhaseGuard'),
          backgroundColor: PgColors.accentDim,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final calling = widget.callingService;
    final isVideo = widget.call.type == 'video';
    final durationText = _formatDuration(calling.callDurationSeconds);

    final pdiScore = session.pdiScore;
    final isScam = session.isScamDetected;
    final riskColor = isScam
        ? PgColors.scam
        : (pdiScore >= 0.40 ? PgColors.suspicious : PgColors.safe);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCallLocally();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Scam analysis disclosure notice
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: PgSpace.md, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: PgColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(PgRadii.pill),
                    border: Border.all(color: PgColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, color: PgColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'NOTICE: This call is analyzed for scams by PhaseGuard AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PgColors.accent.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Header: Peer info, call timer, security status
                _buildTopHeader(durationText, isScam, riskColor),

                const SizedBox(height: 8),

                // Main Call Content: Video or Audio Visualizer
                Expanded(
                  child: isVideo && calling.isConnected && calling.remoteUid != null && calling.engine != null
                      ? _buildVideoView(calling)
                      : _buildAudioProtectionHud(session, pdiScore, isScam, riskColor),
                ),

                // Bottom Call Controls Row
                _buildCallControls(calling, isVideo),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(String durationText, bool isScam, Color riskColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: PgSpace.md, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(PgRadii.card),
        border: Border.all(
          color: isScam ? PgColors.scam : PgColors.border,
          width: isScam ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: PgColors.bgElevated,
            radius: 20,
            child: Text(
              widget.remoteUser.displayName.isNotEmpty
                  ? widget.remoteUser.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: PgColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.remoteUser.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PgColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: riskColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      durationText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PgColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(PgRadii.pill),
              border: Border.all(color: riskColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isScam ? Icons.warning_amber_rounded : Icons.shield_outlined,
                  size: 14,
                  color: riskColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isScam ? 'SCAM ALERT' : 'PROTECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoView(InAppCallingService calling) {
    return Stack(
      children: [
        // Remote Fullscreen Video
        ClipRRect(
          borderRadius: BorderRadius.circular(PgRadii.card),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: calling.engine!,
              canvas: VideoCanvas(uid: calling.remoteUid),
              connection: RtcConnection(channelId: widget.call.channelName),
            ),
          ),
        ),

        // Local Preview Pip
        Positioned(
          right: 16,
          top: 16,
          width: 100,
          height: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: PgColors.accent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: calling.engine!,
                  canvas: VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioProtectionHud(
    SessionController session,
    double pdiScore,
    bool isScam,
    Color riskColor,
  ) {
    final transcript = session.liveTranscript.isNotEmpty
        ? session.liveTranscript
        : 'Listening to remote call audio for fraudulent patterns...';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: PgSpace.md, vertical: 8),
      child: Column(
        children: [
          // Live Risk Meter Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: PgColors.cyberCardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(PgRadii.card),
              border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FRAUD RISK METER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: PgColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '${(pdiScore * 100).clamp(0, 100).round()}% RISK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: PgRadialGauge(
                    value: pdiScore,
                    size: 140,
                    title: 'FRAUD PDI',
                    customColor: riskColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isScam
                      ? 'CRITICAL THREAT: Scam patterns identified'
                      : (pdiScore >= 0.40 ? 'SUSPICIOUS: Verification in progress' : 'SAFE: No scam keywords detected'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Live Transcript Ticker Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PgColors.bgSecondary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(PgRadii.card),
              border: Border.all(color: PgColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.subtitles_outlined, size: 16, color: PgColors.accent),
                    SizedBox(width: 8),
                    Text(
                      'LIVE CALL TRANSCRIPT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: PgColors.accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  transcript,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: PgColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Scam Intervention Banner (Shows when scam detected)
          if (isScam) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PgColors.scam.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(PgRadii.card),
                border: Border.all(color: PgColors.scam, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: PgColors.scam, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.claimText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PgColors.scam,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PgColors.scam,
                            side: const BorderSide(color: PgColors.scam),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isReporting ? null : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isReporting = true);
                            try {
                              await session.escalateToCybercell();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Reported to National Cyber Crime Portal (1930)'),
                                  backgroundColor: PgColors.scam,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Report failed: $e'), backgroundColor: PgColors.scam),
                              );
                            } finally {
                              if (mounted) setState(() => _isReporting = false);
                            }
                          },
                          icon: _isReporting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(PgColors.scam)))
                              : const Icon(Icons.security, size: 16),
                          label: Text(_isReporting ? 'Reporting...' : 'Cybercell 1930', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PgColors.accent,
                            foregroundColor: PgColors.bgPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            session.activateScambaiter();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScambaiterSession()),
                            );
                          },
                          icon: const Icon(Icons.smart_toy_outlined, size: 16),
                          label: const Text('Scambaiter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallControls(InAppCallingService calling, bool isVideo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(PgRadii.pill),
        border: Border.all(color: PgColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute Toggle
          IconButton(
            onPressed: () => calling.toggleMute(),
            icon: Icon(
              calling.isMuted ? Icons.mic_off : Icons.mic,
              color: calling.isMuted ? PgColors.scam : PgColors.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Speaker Toggle
          IconButton(
            onPressed: () => calling.toggleSpeaker(),
            icon: Icon(
              calling.isSpeakerphoneOn ? Icons.volume_up : Icons.volume_off,
              color: calling.isSpeakerphoneOn ? PgColors.accent : PgColors.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Video toggles (if video call)
          if (isVideo) ...[
            IconButton(
              onPressed: () => calling.toggleCamera(),
              icon: Icon(
                calling.isCameraOff ? Icons.videocam_off : Icons.videocam,
                color: calling.isCameraOff ? PgColors.scam : PgColors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            IconButton(
              onPressed: () => calling.switchCamera(),
              icon: const Icon(Icons.flip_camera_ios, color: PgColors.textPrimary, size: 24),
            ),
            const SizedBox(width: 14),
          ],

          // End Call Button
          GestureDetector(
            onTap: _endCallLocally,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PgColors.scam,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
