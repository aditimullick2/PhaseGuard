import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/call.dart';
import '../providers/providers.dart';
import '../services/calling_service.dart';
import '../models/user.dart';

import '../components/app_theme.dart';
import '../components/animated_gradient_bg.dart';
import '../components/call_controls.dart';
import '../components/avatar_status.dart';
import '../components/security_overlay_modal.dart';
import 'package:provider/provider.dart' as prov;
import '../state/session_controller.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final UserModel remoteUser;
  final bool isCaller;
  final String callType;

  const CallScreen({
    super.key, 
    required this.callId,
    required this.remoteUser,
    required this.isCaller,
    required this.callType,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _isPopping = false;
  bool _securityAlertShown = false; // prevent duplicate auto-open

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

    // Start PhaseGuard AI security analysis when call begins
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final session = prov.Provider.of<SessionController>(context, listen: false);
          final callingService = ref.read(callingServiceProvider);
          
          session.callerNumber = widget.remoteUser.name;
          session.callState = 'ACTIVE';
          
          // Real-time scam detection will work when audio is captured
          // Transcript will be updated via WebSocket when scammer speaks
          // Scam detection will run automatically on the transcript
          
          // Connect audio capture from CallingService to SessionController
          final audioStream = callingService.audioCaptureStream;
          if (audioStream != null) {
            audioStream.listen((audioData) {
              // debugPrint('🎤 Audio chunk received: ${audioData.length} bytes');
              // Send audio to SessionController for LEVEL 2 deepfake analysis
              session.processInAppCallAudioChunk(audioData);
            });
          } else {
            debugPrint('⚠️ PhaseGuard: Audio capture stream not available');
          }

          // Listen to AI Scambaiter TTS bytes and inject them into the active call
          session.scambaiterAudioStream.listen((chunk) {
            if (callingService.isJoined) {
              callingService.playScambaiterAudio(chunk);
              debugPrint('[CallScreen] 🔊 AI scambaiter audio sent to SCAMMER (remote caller)');
            } else {
              debugPrint('[CallScreen] ❌ Scambaiter audio NOT sent - isJoined=${callingService.isJoined}');
            }
          });

          debugPrint('🛡 PhaseGuard: AI security engine started for call with ${widget.remoteUser.name}');
        } catch (e) {
          debugPrint('⚠️ PhaseGuard: Could not start AI engine: $e');
        }
      }
    });
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
    // Reset PhaseGuard session state when call ends
    try {
      final session = prov.Provider.of<SessionController>(context, listen: false);
      session.callState = 'IDLE';
    } catch (_) {}
    super.dispose();
  }

  Future<void> _endCall() async {
    if (_isPopping) return;
    debugPrint('[CallScreen] User requested to end call');
    setState(() => _isPopping = true);
    
    try {
      await ref.read(callingServiceProvider).endCall();
      debugPrint('[CallScreen] End call completed');
    } catch (e) {
      debugPrint('[CallScreen] Error ending call: $e');
    }
    
    // Force close even if endCall fails
    if (mounted && Navigator.of(context).canPop()) {
      debugPrint('[CallScreen] Forcing screen close');
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleMute() async {
    final svc = ref.read(callingServiceProvider);
    await svc.toggleMute();
  }

  Future<void> _toggleCamera() async {
    final svc = ref.read(callingServiceProvider);
    await svc.toggleCamera();
  }

  Future<void> _switchCamera() async {
    await ref.read(callingServiceProvider).switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    final svc = ref.read(callingServiceProvider);
    await svc.toggleSpeaker();
  }

  @override
  Widget build(BuildContext context) {
    final callingService = ref.watch(callingServiceProvider);

    // Watch call status from Firestore to pop when ended remotely
    ref.listen<AsyncValue<CallModel?>>(
      callStatusProvider(widget.callId),
      (_, next) {
        final call = next.value;
        if (call == null) return;
        debugPrint('[CallScreen] Call status changed: ${call.status}');
        if (call.isEnded && mounted) {
          if (!_isPopping) {
            debugPrint('[CallScreen] Call ended/disconnected, auto-closing screen...');
            setState(() => _isPopping = true);
            
            // Force close and go back to home screen
            if (mounted) {
              debugPrint('[CallScreen] Navigating back to home screen');
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
      },
    );

    // Auto-open security overlay when HIGH RISK is detected
    final session = prov.Provider.of<SessionController>(context, listen: false);
    session.addListener(() {
      if (!mounted || _securityAlertShown) return;
      if (session.isScamDetected || session.pdiScore >= 0.70 || session.syntheticVoiceScore >= 0.70) {
        _securityAlertShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const SecurityOverlayModal(),
            );
          }
        });
      }
    });

    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: widget.callType == 'video'
            ? _VideoCallScreen(
                remoteUser: widget.remoteUser,
                isCaller: widget.isCaller,
                callingService: callingService,
                onEndCall: _endCall,
                onToggleMute: _toggleMute,
                onToggleCamera: _toggleCamera,
                onSwitchCamera: _switchCamera,
                onToggleSpeaker: _toggleSpeaker,
              )
            : _AudioCallScreen(
                remoteUser: widget.remoteUser,
                isCaller: widget.isCaller,
                callingService: callingService,
                pulseAnim: _pulseAnim,
                onEndCall: _endCall,
                onToggleMute: _toggleMute,
                onToggleSpeaker: _toggleSpeaker,
              ),
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
                      onTap: () {
                        // Show call options menu
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBackground,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    children: [
                                      _MenuOption(
                                        icon: Icons.security_rounded,
                                        title: 'Security Overlay',
                                        onTap: () {
                                          Navigator.pop(context);
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            isScrollControlled: true,
                                            builder: (_) => const SecurityOverlayModal(),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        );
                      },
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

              // Security Overlay Trigger
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: SecurityPill()),
              ),
              const SizedBox(height: 16),

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
                        onTap: () {
                          // Show call options menu
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBackground,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Column(
                                      children: [
                                        _MenuOption(
                                          icon: Icons.security_rounded,
                                          title: 'Security Overlay',
                                          onTap: () {
                                            Navigator.pop(context);
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor: Colors.transparent,
                                              isScrollControlled: true,
                                              builder: (_) => const SecurityOverlayModal(),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          );
                        },
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

              // Security Overlay Trigger
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: SecurityPill()),
              ),
              const SizedBox(height: 16),

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

// Menu option widget for call options
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary10,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}
