import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/in_app_call.dart';
import '../../services/call_signaling_service.dart';
import '../../services/in_app_calling_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_background.dart';
import 'active_call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  final InAppCall call;
  final AppUser remoteUser;
  final CallSignalingService signalingService;
  final InAppCallingService callingService;

  const OutgoingCallScreen({
    super.key,
    required this.call,
    required this.remoteUser,
    required this.signalingService,
    required this.callingService,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<InAppCall?>? _callSub;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.callingService.joinCall(
      channelName: widget.call.channelName,
      callType: widget.call.type,
    );

    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callSub = widget.signalingService.streamCall(widget.call.callId).listen((updatedCall) async {
      if (updatedCall == null || _isNavigating || !mounted) return;

      if (updatedCall.status == 'connected') {
        _isNavigating = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              call: updatedCall,
              remoteUser: widget.remoteUser,
              isCaller: true,
              signalingService: widget.signalingService,
              callingService: widget.callingService,
            ),
          ),
        );
      } else if (updatedCall.isEnded) {
        _isNavigating = true;
        await widget.callingService.leaveCall();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call ${updatedCall.status}: ${widget.remoteUser.displayName}'),
              backgroundColor: PgColors.suspicious,
            ),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _cancelCall() async {
    _callSub?.cancel();
    await widget.signalingService.endCall(widget.call.callId);
    await widget.callingService.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelCall();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PgSpace.lg, vertical: PgSpace.xl),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Scam analysis disclosure banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: PgColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(PgRadii.pill),
                      border: Border.all(color: PgColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield, color: PgColors.accent, size: 16),
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

                  const Spacer(),

                  // Pulsing Radar Rings & Remote User Avatar
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PgColors.bgSecondary,
                        border: Border.all(color: PgColors.accent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: PgColors.accent.withValues(alpha: 0.35),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.person,
                          size: 72,
                          color: PgColors.accent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    widget.remoteUser.displayName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: PgColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVideo ? 'Calling with Video Protection...' : 'Calling with Audio Protection...',
                    style: TextStyle(
                      fontSize: 14,
                      color: PgColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),

                  const Spacer(),

                  // End / Cancel Call Button
                  GestureDetector(
                    onTap: _cancelCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PgColors.scam,
                        boxShadow: [
                          BoxShadow(
                            color: PgColors.scam.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cancel Call',
                    style: TextStyle(fontSize: 13, color: PgColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
