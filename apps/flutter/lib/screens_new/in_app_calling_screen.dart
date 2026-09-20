import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agora_calling_service.dart';
import '../state/session_controller.dart';

/// In-App Calling Screen
/// Displays active call with scam detection integration
class InAppCallingScreen extends StatefulWidget {
  final String callId;
  final String remoteUserName;
  final String remoteUserPhone;
  final bool isVideoCall;
  final int remoteUserId;
  final String agoraToken;
  final String channelName;

  const InAppCallingScreen({
    super.key,
    required this.callId,
    required this.remoteUserName,
    required this.remoteUserPhone,
    required this.isVideoCall,
    required this.remoteUserId,
    required this.agoraToken,
    required this.channelName,
  });

  @override
  State<InAppCallingScreen> createState() => _InAppCallingScreenState();
}

class _InAppCallingScreenState extends State<InAppCallingScreen> {
  late AgoraCallingService _callingService;
  StreamSubscription<Uint8List>? _scambaiterAudioSub;

  @override
  void initState() {
    super.initState();
    _callingService = context.read<AgoraCallingService>();
    _startCall();
    _setupScambaiterAudio();
  }

  Future<void> _startCall() async {
    try {
      final userId = _generateUserId();

      // Connect Agora audio stream to SessionController for dual processing
      final sessionController = context.read<SessionController>();
      _callingService.setAudioChunkCallback((audioChunk) {
        sessionController.processInAppCallAudioChunk(audioChunk);
      });

      if (widget.isVideoCall) {
        await _callingService.startVideoCall(
          callId: widget.callId,
          channelName: widget.channelName,
          userId: userId,
          token: widget.agoraToken,
          remoteUserName: widget.remoteUserName,
        );
      } else {
        await _callingService.startAudioCall(
          callId: widget.callId,
          channelName: widget.channelName,
          userId: userId,
          token: widget.agoraToken,
          remoteUserName: widget.remoteUserName,
        );
      }

      // Start PhaseGuard protection session
      await sessionController.startInAppCallProtection(
        remotePartyName: widget.remoteUserName,
      );
    } catch (e) {
      debugPrint('Failed to start call: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  int _generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
  }

  void _setupScambaiterAudio() {
    final sessionController = context.read<SessionController>();
    // Listen to AI Scambaiter TTS bytes and inject them into the active call
    // SCENARIO: We call victim → Scammer is on victim's phone (remote caller)
    // This AI voice goes to the SCAMMER (who is on the remote end), not the victim
    _scambaiterAudioSub = sessionController.scambaiterAudioStream.listen((chunk) {
      if (mounted && _callingService.isJoined) {
        _callingService.playScambaiterAudio(chunk);
        debugPrint('[InAppCallingScreen] 🔊 AI scambaiter audio sent to SCAMMER (remote caller)');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _callingService.endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer2<AgoraCallingService, SessionController>(
          builder: (context, callingService, sessionController, _) {
            return Stack(
              children: [
                // Video background or audio call UI
                if (widget.isVideoCall)
                  _buildVideoCallUI(callingService)
                else
                  _buildAudioCallUI(callingService, sessionController),

                // Call controls
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: _buildCallControls(callingService),
                ),

                // Scam detection indicator (integrated with PhaseGuard)
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: _buildScamDetectionStatus(sessionController),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAudioCallUI(
    AgoraCallingService callingService,
    SessionController sessionController,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Remote user avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                widget.remoteUserName.isNotEmpty
                    ? widget.remoteUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Remote user name
          Text(
            widget.remoteUserName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Call duration
          const SizedBox(height: 10),
          Consumer<AgoraCallingService>(
            builder: (context, service, _) {
              return Text(
                _formatDuration(service.callDuration),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Connection status
          Consumer<AgoraCallingService>(
            builder: (context, service, _) {
              return Chip(
                label: Text(service.connectionState),
                backgroundColor: service.isConnected ? Colors.green : Colors.orange,
                labelStyle: const TextStyle(color: Colors.white),
              );
            },
          ),

          // Network quality
          const SizedBox(height: 10),
          Consumer<AgoraCallingService>(
            builder: (context, service, _) {
              return Text(
                'Network: ${_getNetworkQuality(service.networkQuality)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCallUI(AgoraCallingService callingService) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Remote video (placeholder)
          Center(
            child: Container(
              color: Colors.grey.shade900,
              child: const Center(
                child: Text(
                  'Video Feed',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // Local video preview (PiP)
          Positioned(
            bottom: 100,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Text(
                    'You',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls(AgoraCallingService callingService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        FloatingActionButton(
          backgroundColor: callingService.isMuted ? Colors.red : Colors.grey.shade700,
          onPressed: callingService.toggleMute,
          child: Icon(
            callingService.isMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
        ),

        // Speaker button (audio only)
        if (!widget.isVideoCall)
          FloatingActionButton(
            backgroundColor: callingService.isSpeakerEnabled
                ? Colors.blue
                : Colors.grey.shade700,
            onPressed: callingService.toggleSpeaker,
            child: Icon(
              callingService.isSpeakerEnabled
                  ? Icons.volume_up
                  : Icons.volume_mute,
              color: Colors.white,
            ),
          ),

        // Camera button (video only)
        if (widget.isVideoCall)
          FloatingActionButton(
            backgroundColor: callingService.isCameraMuted
                ? Colors.red
                : Colors.grey.shade700,
            onPressed: callingService.toggleCamera,
            child: Icon(
              callingService.isCameraMuted
                  ? Icons.videocam_off
                  : Icons.videocam,
              color: Colors.white,
            ),
          ),

        // Switch camera button (video only)
        if (widget.isVideoCall)
          FloatingActionButton(
            backgroundColor: Colors.grey.shade700,
            onPressed: callingService.switchCamera,
            child: const Icon(
              Icons.flip_camera_android,
              color: Colors.white,
            ),
          ),

        // End call button
        FloatingActionButton(
          backgroundColor: Colors.red,
          onPressed: () async {
            await callingService.endCall();
            if (mounted) Navigator.pop(context);
          },
          child: const Icon(
            Icons.call_end,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildScamDetectionStatus(SessionController sessionController) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: sessionController.isScamDetected ? Colors.red : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sessionController.isScamDetected
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: sessionController.isScamDetected
                    ? Colors.red
                    : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sessionController.isScamDetected
                      ? 'SCAM DETECTED'
                      : 'CALL SAFE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sessionController.isScamDetected
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sessionController.riskNote,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getNetworkQuality(int quality) {
    switch (quality) {
      case 0:
        return 'Unknown';
      case 1:
        return 'Excellent';
      case 2:
        return 'Good';
      case 3:
        return 'Fair';
      case 4:
        return 'Poor';
      case 5:
        return 'Bad';
      default:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    _scambaiterAudioSub?.cancel();
    super.dispose();
  }
}
