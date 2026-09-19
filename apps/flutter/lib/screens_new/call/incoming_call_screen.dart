import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/in_app_call.dart';
import '../../services/call_signaling_service.dart';
import '../../services/in_app_calling_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_background.dart';
import 'active_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final InAppCall call;
  final CallSignalingService signalingService;
  final InAppCallingService callingService;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.signalingService,
    required this.callingService,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  StreamSubscription<InAppCall?>? _callSub;
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _listenForRemoteCancel();
  }

  void _listenForRemoteCancel() {
    _callSub = widget.signalingService.streamCall(widget.call.callId).listen((updatedCall) {
      if (updatedCall == null || _isActionTaken || !mounted) return;
      if (updatedCall.isEnded) {
        _isActionTaken = true;
        Navigator.pop(context);
      }
    });
  }

  Future<void> _acceptCall() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _callSub?.cancel();

    await widget.signalingService.answerCall(widget.call.callId);
    await widget.callingService.joinCall(
      channelName: widget.call.channelName,
      callType: widget.call.type,
    );

    if (mounted) {
      final callerUser = AppUser(
        uid: widget.call.callerId,
        displayName: widget.call.callerName,
        photoUrl: widget.call.callerPic,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            call: widget.call,
            remoteUser: callerUser,
            isCaller: false,
            signalingService: widget.signalingService,
            callingService: widget.callingService,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _callSub?.cancel();

    await widget.signalingService.rejectCall(widget.call.callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _declineCall();
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
                        const Icon(Icons.security, color: PgColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'SECURITY NOTICE: Analyzed for scams upon connecting',
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

                  // Pulsing Caller Avatar
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PgColors.bgSecondary,
                        border: Border.all(color: PgColors.safe, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: PgColors.safe.withValues(alpha: 0.35),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.person,
                          size: 68,
                          color: PgColors.safe,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    widget.call.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: PgColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: PgColors.safe.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(PgRadii.pill),
                        ),
                        child: Text(
                          isVideo ? 'INCOMING VIDEO CALL' : 'INCOMING AUDIO CALL',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PgColors.safe,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action Buttons: Decline & Accept
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _declineCall,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: PgColors.scam,
                                boxShadow: [
                                  BoxShadow(
                                    color: PgColors.scam.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Decline', style: TextStyle(color: PgColors.textSecondary, fontSize: 13)),
                        ],
                      ),

                      // Accept
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _acceptCall,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: PgColors.safe,
                                boxShadow: [
                                  BoxShadow(
                                    color: PgColors.safe.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call, color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Accept', style: TextStyle(color: PgColors.safe, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
