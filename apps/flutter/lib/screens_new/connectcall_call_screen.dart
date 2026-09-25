import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/connectcall_calling_service.dart';
import '../models/user.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';

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
  StreamSubscription? _scambaiterSub;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      final callingService = context.read<ConnectCallCallingService>();
      _scambaiterSub = session.scambaiterAudioStream.listen((chunk) {
        callingService.playScambaiterAudio(chunk);
      });
      session.startVideoDeepfakeDetection(callingService);
    });
  }

  @override
  void dispose() {
    _scambaiterSub?.cancel();
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

  Future<void> _toggleSpeaker() async {
    final callingService = context.read<ConnectCallCallingService>();
    await callingService.toggleSpeaker();
  }

  @override
  Widget build(BuildContext context) {
    final callingService = context.watch<ConnectCallCallingService>();

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
            _SimpleCallScreen(
              remoteUser: widget.remoteUser,
              callingService: callingService,
              pulseAnim: _pulseAnim,
              onEndCall: _endCall,
              onToggleMute: _toggleMute,
              onToggleSpeaker: _toggleSpeaker,
            ),
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
                  child: const Icon(
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: PgColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            callingService.isConnected ? 'Connected' : 'Connecting...',
            style: const TextStyle(
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
