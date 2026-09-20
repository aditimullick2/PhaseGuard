import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/connectcall_call.dart';
import '../services/connectcall_calling_service.dart';
import '../models/connectcall_user.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';

import '../connectcall_components/app_theme.dart';
import '../connectcall_components/animated_gradient_bg.dart';
import '../connectcall_components/call_controls.dart';
import '../connectcall_components/avatar_status.dart';
import 'incoming_call_overlay.dart';
import 'live_verify_dashboard.dart';
import 'scambaiter_session.dart';

class ConnectCallCallScreen extends StatefulWidget {
  final String callId;
  final UserModel remoteUser;
  final bool isCaller;
  final String callType;

  const ConnectCallCallScreen({
    super.key, 
    required this.callId,
    required this.remoteUser,
    required this.isCaller,
    required this.callType,
  });

  @override
  State<ConnectCallCallScreen> createState() => _ConnectCallCallScreenState();
}

class _ConnectCallCallScreenState extends State<ConnectCallCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _endCall() async {
    if (_isPopping) return;
    setState(() => _isPopping = true);
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.endCall();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleMute() async {
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.toggleMute();
  }

  Future<void> _toggleCamera() async {
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.toggleCamera();
  }

  Future<void> _switchCamera() async {
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.toggleSpeaker();
  }

  @override
  Widget build(BuildContext context) {
    final callingService = context.watch<ConnectCallCallingService>();
    final session = context.watch<SessionController>();

    // Watch call status from Firestore to pop when ended remotely
    // TODO: Add call status listener from ConnectCall providers

    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: PgColors.bgPrimary,
        body: Stack(
          children: [
            // Main call screen (simplified for now)
            _SimpleCallScreen(
              remoteUser: widget.remoteUser,
              callingService: callingService,
              pulseAnim: _pulseAnim,
              onEndCall: _endCall,
              onToggleMute: _toggleMute,
              onToggleSpeaker: _toggleSpeaker,
            ),
            // PhaseGuard detection overlay (appears when scam detected)
            // REMOVED: Manual overlay disabled as requested
            // Auto-activation happens in incoming call screen
          ],
        ),
      ),
    );
  }
}

// Simple Call Screen (Simplified for PhaseGuard integration)

class _SimpleCallScreen extends StatelessWidget {
  final UserModel remoteUser;
  final ConnectCallCallingService callingService;
  final Animation<double> pulseAnim;
  final VoidCallback onEndCall;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;

  const _SimpleCallScreen({
    required this.remoteUser,
    required this.callingService,
    required this.pulseAnim,
    required this.onEndCall,
    required this.onToggleMute,
    required this.onToggleSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnim.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: PgColors.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: PgColors.accent,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            remoteUser.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: PgColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            callingService.isConnected ? 'Connected' : 'Connecting...',
            style: TextStyle(
              fontSize: 16,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onToggleMute,
                icon: Icon(
                  callingService.isMuted ? Icons.mic_off : Icons.mic,
                  color: PgColors.textPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: onToggleSpeaker,
                icon: Icon(
                  callingService.isSpeakerEnabled ? Icons.volume_up : Icons.volume_down,
                  color: PgColors.textPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: onEndCall,
                icon: const Icon(
                  Icons.call_end,
                  color: PgColors.scam,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//  Audio Call Screen


class _AudioCallScreen extends StatelessWidget {
  final UserModel remoteUser;
  final bool isCaller;
  final CallingService callingService;
  final Animation<double> pulseAnim;
  final VoidCallback onEndCall;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;

  const _AudioCallScreen({
    required this.remoteUser,
    required this.isCaller,
    required this.callingService,
    required this.pulseAnim,
    required this.onEndCall,
    required this.onToggleMute,
    required this.onToggleSpeaker,
  });

  String get _statusText {
    switch (callingService.connectionState) {
      case 'Disconnected':
        return 'Disconnected';
      case 'Connecting...':
        return 'Connecting...';
      case 'Connected':
        if (!callingService.isConnected) {
          return 'Ringing...';
        }
        return 'Connected';
      case 'Reconnecting...':
        return 'Reconnecting...';
      case 'Connection Failed':
        return 'Failed';
      default:
        return 'Connecting...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = callingService.connectionState == 'Connected' &&
        callingService.isConnected;

    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: AnimatedGradientBg(
            preset: isConnected ? GradientPreset.callActive : GradientPreset.hero,
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {}, // Minimize/PiP in future
                      child: GlassmorphicContainer(
                        padding: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.onPrimary, size: 28),
                      ),
                    ),
                    const QualityPill(quality: 'HD Audio', tone: AppColors.success),
                    const SizedBox(width: 44), // balance back button
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Status
              Text(_statusText,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText)),
              const SizedBox(height: 40),

              // Pulsing Avatar
              ScaleTransition(
                scale: isConnected ? pulseAnim : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: AvatarStatus(
                    name: remoteUser.name,
                    photoUrl: remoteUser.photoUrl,
                    size: 160,
                    online: true,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Name
              Text(
                remoteUser.name,
                style: AppTextStyles.titleLarge.copyWith(fontSize: 32),
              ),

              const Spacer(),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  borderRadius: BorderRadius.circular(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ControlButton(
                        icon: Icon(
                          callingService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: callingService.isMuted ? AppColors.tertiary : AppColors.primary,
                          size: 28,
                        ),
                        label: 'Mute',
                        onTap: onToggleMute,
                      ),
                      
                      ControlButton(
                        icon: const Icon(Icons.call_end_rounded, color: AppColors.onError, size: 36),
                        isDanger: true,
                        size: 72,
                        onTap: onEndCall,
                      ),

                      ControlButton(
                        icon: Icon(
                          callingService.isSpeakerEnabled ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        label: 'Speaker',
                        onTap: onToggleSpeaker,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


//  Video Call Screen


class _VideoCallScreen extends StatelessWidget {
  final UserModel remoteUser;
  final bool isCaller;
  final CallingService callingService;
  final VoidCallback onEndCall;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;

  const _VideoCallScreen({
    required this.remoteUser,
    required this.isCaller,
    required this.callingService,
    required this.onEndCall,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = callingService.connectionState == 'Connected' &&
        callingService.isConnected;

    return Stack(
      children: [
        // Background (shown while connecting or if remote camera is off)
        Positioned.fill(
          child: AnimatedGradientBg(
            preset: isConnected ? GradientPreset.videoCall : GradientPreset.hero,
          ),
        ),

        // Remote Video (Full Screen)
        if (isConnected)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: callingService.engine!,
                canvas: VideoCanvas(uid: callingService.remoteUid!),
                connection: RtcConnection(channelId: callingService.currentCallId!),
              ),
            ),
          ),

        // Local Video (PiP)
        if (isConnected && !callingService.isCameraMuted)
          Positioned(
            right: 24,
            top: MediaQuery.of(context).padding.top + 80,
            width: 120,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.surface30, width: 2),
                ),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: callingService.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        // UI Overlay
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassmorphicContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {},
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const QualityPill(quality: 'HD Video', tone: AppColors.primary),
                    GlassmorphicContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: onSwitchCamera,
                        child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!isConnected) ...[
                const SizedBox(height: 120),
                AvatarStatus(
                  name: remoteUser.name,
                  photoUrl: remoteUser.photoUrl,
                  size: 120,
                ),
                const SizedBox(height: 24),
                Text(remoteUser.name, style: AppTextStyles.titleLarge),
                const SizedBox(height: 8),
                Text('Calling...', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText)),
              ],

              const Spacer(),

              // Controls Bar (Glassmorphic)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  borderRadius: BorderRadius.circular(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ControlButton2(
                        icon: Icon(
                          callingService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                        isActive: callingService.isMuted,
                        onTap: onToggleMute,
                      ),
                      ControlButton2(
                        icon: Icon(
                          callingService.isCameraMuted ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          color: Colors.white,
                        ),
                        isActive: callingService.isCameraMuted,
                        onTap: onToggleCamera,
                      ),
                      ControlButton2(
                        icon: Icon(
                          callingService.isSpeakerEnabled ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          color: Colors.white,
                        ),
                        isActive: callingService.isSpeakerEnabled,
                        onTap: onToggleSpeaker,
                      ),
                      ControlButton2(
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                        isDanger: true,
                        onTap: onEndCall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


void _showForensicDossierModal(BuildContext context, SessionController session, Uint8List pdfBytes) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: PgColors.bgSecondary,
      title: const Text('Forensic Dossier'),
      content: const Text('Scam evidence PDF generated successfully'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
