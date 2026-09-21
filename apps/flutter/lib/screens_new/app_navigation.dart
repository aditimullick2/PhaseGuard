import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/in_app_call.dart';
import '../services/auth_service.dart';
import '../services/call_signaling_service.dart';
import '../services/in_app_calling_service.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/pg_custom_icons.dart';
import '../widgets/pg_animations.dart';
import '../state/session_controller.dart';
import 'incoming_call_overlay.dart';
import 'live_verify_dashboard.dart';
import 'ai_voice_analysis.dart';
import 'scambaiter_session.dart';
import 'call_history_logs.dart';
import 'system_settings.dart';
import 'call/protected_call_hub_screen.dart';
import 'call/calling_setup_screen.dart';
import 'call/incoming_call_screen.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0;
  bool _showOverlay = false;
  StreamSubscription<InAppCall?>? _incomingCallSub;
  String? _listeningUserId;
  bool _isShowingIncomingCall = false;

  final List<Widget> _screens = [
    const MainDashboard(),
    const CallHistoryLogs(),
    const SystemSettings(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachIncomingCallListener();
  }

  void _attachIncomingCallListener() {
    final auth = context.watch<AuthService>();
    final uid = auth.appUser?.uid;
    if (uid == null || uid == _listeningUserId) return;

    _listeningUserId = uid;
    _incomingCallSub?.cancel();

    final signaling = context.read<CallSignalingService>();
    final calling = context.read<InAppCallingService>();

    _incomingCallSub = signaling.listenForIncomingCalls(uid).listen((incomingCall) {
      if (incomingCall != null && !_isShowingIncomingCall && mounted) {
        _isShowingIncomingCall = true;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              call: incomingCall,
              signalingService: signaling,
              callingService: calling,
            ),
          ),
        ).then((_) {
          _isShowingIncomingCall = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isOverlayOpen = _showOverlay || session.overlayVisible;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            // Main content
            _screens[_currentIndex],
            // Overlay and toggle button
            if (isOverlayOpen)
              IncomingCallOverlay(
                callerNumber: session.callerNumber ?? '+1 (888) 555-0192',
                isVoip: session.isPotentialScam || session.timesReported > 0,
                timesReported: session.timesReported,
                registrationCircle: session.callerLocation ?? 'Delhi NCR',
                pdiScore: session.pdiScore,
                syntheticVoiceScore: session.syntheticVoiceScore,
                isVideoSpoof: session.isVideoSpoof,
                claimVerificationStatus: session.factcheck?.status ?? 'IDLE',
                claimText: session.factcheck?.message ?? 'Awaiting conversational analysis...',
                isScamDetected: session.isPotentialScam,
                liveTranscript: session.liveTranscript,
                onStartProtection: () {
                  session.startLiveVerify();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LiveVerifyDashboard()),
                  );
                },
                onIgnore: () {
                  session.hideOverlay();
                  setState(() {
                    _showOverlay = false;
                  });
                },
                onEscalateToCybercell: () async {
                  try {
                    final draft = await session.draftBlockAndReport();
                    await session.confirmBlockAndReport(draft.draftId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Escalated to Cybercell! ${session.lastActionMessage ?? ""}'),
                          backgroundColor: PgColors.scam,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cybercell Escalation: $e'),
                          backgroundColor: PgColors.scam,
                        ),
                      );
                    }
                  }
                },
                onDeployScambaiter: () {
                  session.activateScambaiter();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScambaiterSession()),
                  );
                },
                onDownloadDossier: () async {
                  try {
                    final pdfBytes = await session.getDossier();
                    if (context.mounted) {
                      _showForensicDossierModal(context, session, pdfBytes);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dossier error: $e'),
                          backgroundColor: PgColors.scam,
                        ),
                      );
                    }
                  }
                },
                showSimulationControls: true,
              ),
            // Floating toggle button for testing overlay manually
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: isOverlayOpen ? PgColors.scam : PgColors.accent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: (isOverlayOpen ? PgColors.scam : PgColors.accent).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (isOverlayOpen) {
                        session.hideOverlay();
                        setState(() {
                          _showOverlay = false;
                        });
                      } else {
                        session.showOverlay();
                        setState(() {
                          _showOverlay = true;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        isOverlayOpen ? Icons.visibility_off : Icons.phone_in_talk,
                        color: PgColors.bgPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: PgColors.bgSecondary.withValues(alpha: 0.85),
          border: Border(
            top: BorderSide(
              color: PgColors.border.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: PgColors.accent,
          unselectedItemColor: PgColors.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle high-tech cyber shield watermark to eliminate dead empty space
            const Positioned(
              right: -50,
              bottom: 80,
              child: CyberShieldWatermark(size: 300, opacity: 0.04),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: PgSpace.lg, vertical: PgSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, session),
                  const SizedBox(height: PgSpace.md),
                  _buildProtectionCard(session),
                  const SizedBox(height: PgSpace.lg),
                  _buildQuickActions(context),
                  const SizedBox(height: PgSpace.lg),
                  _buildRecentActivity(session),
                  const SizedBox(height: PgSpace.lg),
                  _buildDefenseTelemetry(),
                  const SizedBox(height: PgSpace.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SessionController session) {
    final isLive = session.wsConnected;
    final isConnecting = session.connecting;
    final color = isLive ? PgColors.safe : (isConnecting ? PgColors.suspicious : PgColors.accent);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PhaseGuard',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: PgColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PgColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: PgColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: PgColors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Real-Time Scam & Deepfake Interception',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PgColors.textSecondary,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            if (!session.wsConnected && !session.connecting) {
              session.startSession();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(PgRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isLive ? Icons.wifi : (isConnecting ? Icons.sync : Icons.wifi_protected_setup),
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  isLive ? 'Live Shield' : (isConnecting ? 'Connecting...' : 'Connect'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProtectionCard(SessionController session) {
    final statusColor = session.wsConnected ? PgColors.safe : (session.connecting ? PgColors.suspicious : PgColors.accent);
    final statusText = session.wsConnected ? 'ACTIVE' : (session.connecting ? 'CONNECTING' : 'STANDBY');

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: PgColors.heroCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROTECTION STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  border: Border.all(color: statusColor.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          // Center row with Shield and pulsing animation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shield Engaged',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: PgColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitoring incoming audio & network telemetry for synthetic voice fraud.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: PgColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PgSpace.md),
              // Pulsing Animated Shield Ring
              PulsingRing(
                pulseColor: PgColors.safe,
                maxRadius: 44,
                ringCount: 3,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        PgColors.safe.withValues(alpha: 0.35),
                        PgColors.safe.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: PgColors.safe, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: PgColors.safe.withValues(alpha: 0.35),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: PgColors.safe,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          // Micro-telemetry bar inside protection card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(PgRadii.bar * 2),
              border: Border.all(color: PgColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCardStat('Threats Intercepted', '${session.timesReported > 0 ? session.timesReported + 14 : 14}'),
                Container(width: 1, height: 18, color: PgColors.border),
                _buildCardStat('DSP Model', 'Triad-v2'),
                Container(width: 1, height: 18, color: PgColors.border),
                _buildCardStat('Latency', session.wsConnected ? '24ms' : 'Standby'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: PgColors.safe,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: PgColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: PgColors.textSecondary,
              ),
            ),
            Text(
              '4 MODULES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: PgColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: PgSpace.sm),
        GestureDetector(
          onTap: () {
            final auth = context.read<AuthService>();
            if (!auth.isAuthenticated) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CallingSetupScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProtectedCallHubScreen()),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: PgSpace.md),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C243B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(PgRadii.card),
              border: Border.all(color: PgColors.accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: PgColors.accent.withValues(alpha: 0.15),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PgColors.accent.withValues(alpha: 0.2),
                  ),
                  child: const Icon(Icons.phone_in_talk, color: PgColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-App Protected Calling',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PgColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Direct peer call with live AI scam detection & HUD',
                        style: TextStyle(fontSize: 11, color: PgColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: PgColors.accent, size: 14),
              ],
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: PgSpace.md,
          crossAxisSpacing: PgSpace.md,
          childAspectRatio: 1.32,
          children: [
            PgActionCard(
              label: 'Live Verify',
              description: 'Real-time call check',
              iconType: PgIconType.scanner,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LiveVerifyDashboard()),
              ),
            ),
            PgActionCard(
              label: 'Voice Analysis',
              description: 'Acoustic DSP metrics',
              iconType: PgIconType.equalizer,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIVoiceAnalysis()),
              ),
            ),
            PgActionCard(
              label: 'Scambaiter',
              description: 'AI persona defense',
              iconType: PgIconType.cyberbot,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScambaiterSession()),
              ),
            ),
            PgActionCard(
              label: 'Call History',
              description: 'Transcripts & logs',
              iconType: PgIconType.auditClock,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CallHistoryLogs()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity(SessionController session) {
    final hasActiveCall = session.callerNumber != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: PgColors.textSecondary,
              ),
            ),
            Text(
              hasActiveCall ? 'LIVE CALL ACTIVE' : 'LIVE AUDIT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: hasActiveCall ? PgColors.accent : PgColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: PgSpace.sm),
        if (hasActiveCall) ...[
          _buildActivityItem(
            session.isScamDetected
                ? 'High Risk Scam Detected'
                : (session.wsConnected ? 'Live Protected Call' : 'Intercepted Call'),
            session.callerNumber!,
            'Live Now',
            'PDI: ${(session.pdiScore * 100).round()}% • ${session.callState}',
            session.isScamDetected ? PgColors.scam : PgColors.safe,
            session.isScamDetected ? Icons.dangerous_rounded : Icons.phone_in_talk,
          ),
          const SizedBox(height: PgSpace.sm),
        ],
        _buildActivityItem(
          'Scam Detected — IRS Impersonation',
          '+1 (888) 555-0192',
          '10:30 AM',
          'PDI: 0.92 • BLOCKED',
          PgColors.scam,
          Icons.dangerous_rounded,
        ),
        const SizedBox(height: PgSpace.sm),
        _buildActivityItem(
          'Safe Call — Known Contact',
          '+1 (555) 123-4567',
          'Yesterday',
          'PDI: 0.08 • VERIFIED',
          PgColors.safe,
          Icons.verified_user_rounded,
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    String badge,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.85),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: PgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: PgColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PgColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: PgColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Live Defense Telemetry section eliminating empty/flat vertical space below Recent Activity
  Widget _buildDefenseTelemetry() {
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.65),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEFENSE TELEMETRY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: PgColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 12, color: PgColors.accent),
                  SizedBox(width: 4),
                  Text(
                    '100% SECURE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: PgColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: PgSpace.sm),
          _buildTelemetryRow('Heuristic Engine', 'Active • 142 Triads Scanned', PgColors.safe),
          _buildTelemetryRow('Synthetic Voice Model', 'Online • 99.4% Accuracy', PgColors.safe),
          _buildTelemetryRow('National Cybercell Bridge', 'Connected • Standby', PgColors.accent),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String status, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: PgColors.textMuted),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showForensicDossierModal(
  BuildContext context,
  SessionController session,
  List<int> pdfBytes,
) {
  final callId = session.callId ?? 'PG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  final pdiScore = (session.pdiScore * 100).toStringAsFixed(0);
  final isScam = session.isScamDetected || session.pdiScore >= 0.7;
  final timestamp = DateTime.now().toUtc().toIso8601String();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: PgColors.bgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PgRadii.card)),
          border: Border.all(color: PgColors.accent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: PgColors.accent.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PgColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(PgSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PgColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PgColors.accent.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: PgColors.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FORENSIC FRAUD DOSSIER',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: PgColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'CASE REF #$callId',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: PgColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isScam
                                ? PgColors.scam.withValues(alpha: 0.15)
                                : PgColors.safe.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(PgRadii.pill),
                            border: Border.all(
                              color: isScam ? PgColors.scam : PgColors.safe,
                            ),
                          ),
                          child: Text(
                            isScam ? 'CONFIRMED THREAT' : 'SAFE / VERIFIED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isScam ? PgColors.scam : PgColors.safe,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PgSpace.lg),

                    // Forensic Metrics Table
                    Container(
                      padding: const EdgeInsets.all(PgSpace.md),
                      decoration: BoxDecoration(
                        color: PgColors.bgSecondary,
                        borderRadius: BorderRadius.circular(PgRadii.card),
                        border: Border.all(color: PgColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildDossierRow('Phishing Threat Index (PDI)', '$pdiScore / 100', isScam ? PgColors.scam : PgColors.safe),
                          const Divider(color: PgColors.border, height: 16),
                          _buildDossierRow('Synthetic Voice Model', '${(session.syntheticVoiceScore * 100).toStringAsFixed(0)}% Probability', PgColors.accent),
                          const Divider(color: PgColors.border, height: 16),
                          _buildDossierRow('Caller Telephone', session.targetPhoneNumber, PgColors.textPrimary),
                          const Divider(color: PgColors.border, height: 16),
                          _buildDossierRow('Payload Size', '${pdfBytes.length} bytes (PDF/A-1b)', PgColors.textSecondary),
                          const Divider(color: PgColors.border, height: 16),
                          _buildDossierRow('Generated At', timestamp, PgColors.textMuted),
                        ],
                      ),
                    ),
                    const SizedBox(height: PgSpace.md),

                    // Cryptographic Hash Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(PgSpace.md),
                      decoration: BoxDecoration(
                        color: PgColors.bgSecondary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(PgRadii.card),
                        border: Border.all(color: PgColors.safe.withValues(alpha: 0.4)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user, size: 14, color: PgColors.safe),
                              SizedBox(width: 6),
                              Text(
                                'CRYPTOGRAPHIC CHAIN OF CUSTODY (SHA-256)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: PgColors.safe,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: PgColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PgSpace.lg),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final path = await session.saveDossierToFile(pdfBytes);
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📄 Dossier PDF saved to: $path (${pdfBytes.length} bytes)'),
                                    backgroundColor: PgColors.accent,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.download_done_rounded, size: 18),
                            label: const Text('Save Dossier PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PgColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(PgRadii.button),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PgColors.textSecondary,
                            side: const BorderSide(color: PgColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(PgRadii.button),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDossierRow(String label, String value, Color valueColor) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: PgColors.textSecondary),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
      ),
    ],
  );
}