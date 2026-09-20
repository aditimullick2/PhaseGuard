import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call.dart';
import '../models/user.dart';
import '../providers/providers.dart';

import '../services/permission_service.dart';
import '../components/app_theme.dart';
import '../components/animated_gif_background.dart';
import '../components/animated_gradient_bg.dart';
import '../components/call_controls.dart';
import '../components/avatar_status.dart';
import 'call_screen.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() =>
      _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ring1, _ring2, _ring3;

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
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for call status changes
    ref.listen<AsyncValue<CallModel?>>(
      callStatusProvider(widget.call.callId),
      (_, next) {
        final call = next.value;
        if (call == null) return;
        if (call.isEnded) {
          if (mounted) Navigator.of(context).pop();
        }
      },
    );

    final isVideo = widget.call.type == 'video';

    return PopScope(
      canPop: false, // Prevent accidental back navigation
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: Stack(
          children: [
            // Animated GIF Background
            const Positioned.fill(
              child: AnimatedGifBackground(
                assetPath: 'assets/background/incoming_call_bg.gif',
                overlayOpacity: 0.4,
                child: SizedBox.shrink(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Call type badge
                  QualityPill(
                    quality: isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                    tone: AppColors.primary,
                  ),
                  const SizedBox(height: 48),

                  // Caller Info
                  Text(
                    widget.call.callerName,
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 32),
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
                              debugPrint('[IncomingCallScreen] Accept button pressed');
                              
                              final status = await ref
                                  .read(permissionServiceProvider)
                                  .requestCallPermissions(requireCamera: isVideo);
                              if (status != CallPermissionStatus.granted) {
                                debugPrint('[IncomingCallScreen] Permissions denied');
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

                              debugPrint('[IncomingCallScreen] Permissions granted, accepting call');
                              
                              try {
                                await ref
                                    .read(callingServiceProvider)
                                    .acceptCall(
                                      callId: widget.call.callId,
                                      channelName: widget.call.agoraChannelName,
                                      type: widget.call.type,
                                    );
                                
                                debugPrint('[IncomingCallScreen] Call accepted successfully');
                              } catch (e) {
                                debugPrint('[IncomingCallScreen] Error accepting call: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to accept call: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                                return;
                              }

                              if (mounted) {
                                debugPrint('[IncomingCallScreen] Navigating to CallScreen');
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
