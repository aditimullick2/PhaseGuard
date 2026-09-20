import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connectcall_call.dart';
import '../models/connectcall_user.dart';
import '../providers/providers.dart';
import '../state/session_controller.dart';
import '../services/local_scambaiter_service.dart';

import '../connectcall_components/app_theme.dart';
import '../connectcall_components/animated_gif_background.dart';
import '../connectcall_components/animated_gradient_bg.dart';
import '../connectcall_components/call_controls.dart';
import '../connectcall_components/avatar_status.dart';
import 'connectcall_call_screen.dart';

class ConnectCallIncomingCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const ConnectCallIncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<ConnectCallIncomingCallScreen> createState() =>
      _ConnectCallIncomingCallScreenState();
}

class _ConnectCallIncomingCallScreenState extends ConsumerState<ConnectCallIncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ring1, _ring2, _ring3;
  final LocalScambaiterService _scambaiterService = LocalScambaiterService();

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _ring1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0, 0.6)),
    );
    _ring2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.2, 0.8)),
    );
    _ring3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringCtrl, curve: const Interval(0.4, 1.0)),
    );
    
    // Auto-activate scambaiter if scam detected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      if (session.isScamDetected) {
        _autoActivateScambaiter();
      }
    });
  }
  
  void _autoActivateScambaiter() {
    // Auto-activate scambaiter when scammer calls
    final session = context.read<SessionController>();
    _scambaiterService.autoActivateOnScam(
      'Scam call detected',
      'YOUR_AI_API_KEY', // TODO: Replace with actual API key
    );
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for call status changes
    // TODO: Add call status listener from ConnectCall providers

    final isVideo = widget.call.type == 'video';

    return PopScope(
      canPop: false, // Prevent accidental back navigation
      child: Scaffold(
        backgroundColor: PgColors.bgPrimary,
        body: Stack(
          children: [
            // Animated GIF Background
            const Positioned.fill(
              child: AnimatedGifBackground(
                assetPath: 'connectcall_assets/background/incoming_call_bg.gif',
                overlayOpacity: 0.4,
                child: SizedBox.shrink(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Call type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: PgColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PgColors.accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                      style: TextStyle(
                        color: PgColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Caller Info
                  Text(
                    widget.call.callerName,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: PgColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ConnectCall',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.secondaryText),
                  ),
                  const Spacer(),

                  // Animated rings + Avatar
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildRing(_ring3),
                        _buildRing(_ring2),
                        _buildRing(_ring1),
                        
                        // Avatar
                        AvatarStatus(
                          name: widget.call.callerName,
                          photoUrl: widget.call.callerPic,
                          size: 100,
                          online: true,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Accept / Decline Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                    child: GlassmorphicContainer(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                      borderRadius: BorderRadius.circular(40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ActionButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.onError, size: 32),
                            bg: AppColors.error,
                            label: 'Decline',
                            onTap: () async {
                              await ref
                                  .read(callingServiceProvider)
                                  .rejectCall(widget.call.callId);
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                          ActionButton(
                            icon: Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                color: AppColors.onPrimary,
                                size: 32),
                            bg: AppColors.success,
                            label: 'Accept',
                            onTap: () async {
                              final status = await ref
                                  .read(permissionServiceProvider)
                                  .requestCallPermissions(requireCamera: isVideo);
                              if (status != CallPermissionStatus.granted) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Permissions required to accept.'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                                return;
                              }

                              await ref
                                  .read(callingServiceProvider)
                                  .acceptCall(
                                    callId: widget.call.callId,
                                    channelName: widget.call.agoraChannelName,
                                    type: widget.call.type,
                                  );

                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CallScreen(
                                      callId: widget.call.callId,
                                      remoteUser: UserModel(
                                        uid: widget.call.callerId,
                                        name: widget.call.callerName,
                                        email: '',
                                        isOnline: true,
                                      ),
                                      isCaller: false,
                                      callType: widget.call.type,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        return Container(
          width: 100 + (140 * anim.value),
          height: 100 + (140 * anim.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 1 - anim.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
