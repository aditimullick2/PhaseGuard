import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_capture_test.dart';
import '../services/call_socket.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';
import 'deep_test_screen.dart';
import '../widgets/app_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CallSocket _callSocket = CallSocket();
  List<double> _audioLevels = List.filled(50, 0.0);
  Timer? _audioTimer;
  
  @override
  void initState() {
    super.initState();
    // Initialize session on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      if (session.callId == null && !session.connecting) {
        session.startSession();
      }
    });
    
    // Start audio level simulation for visualization
    _startAudioVisualization();
  }
  
  @override
  void dispose() {
    _audioTimer?.cancel();
    _callSocket.disconnect();
    super.dispose();
  }
  
  void _startAudioVisualization() {
    _audioTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final session = context.read<SessionController>();
      if (session.wsConnected && session.protectionActive) {
        setState(() {
          // Simulate audio levels (in real app, would come from actual audio data)
          for (int i = 0; i < _audioLevels.length - 1; i++) {
            _audioLevels[i] = _audioLevels[i + 1];
          }
          _audioLevels[_audioLevels.length - 1] = math.Random().nextDouble() * 0.8;
        });
      } else {
        setState(() {
          _audioLevels = List.filled(50, 0.0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Consumer<SessionController>(
            builder: (context, session, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: PgSpace.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(session),
                    const SizedBox(height: PgSpace.section),
                    _buildProtectionCard(session),
                    const SizedBox(height: PgSpace.section),
                    _buildAudioVisualization(session),
                    const SizedBox(height: PgSpace.section),
                    _buildCaptureMethodInfo(session),
                    const SizedBox(height: PgSpace.section),
                    _buildCallStatus(session),
                    const SizedBox(height: PgSpace.section),
                    if (session.wsConnected) _buildTranscriptWidget(session),
                    const SizedBox(height: PgSpace.section),
                    if (session.wsConnected) _buildFactCheckWidget(session),
                    const SizedBox(height: PgSpace.section),
                    _buildActionButtons(context, session),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
        ),
          ),
        );
  }

  Widget _buildHeader(SessionController session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PhaseGuard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: PgColors.white,
              ),
            ),
            _buildStatusBadge(session),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Call Protection Active',
          style: TextStyle(
            fontSize: 14,
            color: PgColors.mediumBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(SessionController session) {
    Color statusColor;
    if (session.wsConnected) {
      statusColor = PgColors.safe;
    } else if (session.connecting) {
      statusColor = PgColors.warn;
    } else {
      statusColor = PgColors.crit;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        border: Border.all(color: statusColor, width: 1.5),
        borderRadius: BorderRadius.circular(PgRadius.bar),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.connecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(PgColors.warn),
              ),
            )
          else
            Icon(
              session.wsConnected ? Icons.wifi : Icons.offline_bolt,
              size: 12,
              color: statusColor,
            ),
          const SizedBox(width: 6),
          Text(
            session.callStatusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionCard(SessionController session) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Protection Status'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Status',
                value: session.protectionActive ? 'Active' : 'Inactive',
                color: session.protectionActive ? PgColors.safe : PgColors.crit,
              ),
              _buildStatItem(
                label: 'Calls Monitored',
                value: '0',
                color: PgColors.accentBlue,
              ),
              _buildStatItem(
                label: 'Threats Blocked',
                value: '0',
                color: PgColors.crit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: PgColors.mediumBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioVisualization(SessionController session) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Real-Time Audio'),
              if (session.wsConnected && session.protectionActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PgColors.safe.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(PgRadius.bar),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: PgColors.safe,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: _AudioWaveformPainter(_audioLevels),
              size: const Size(double.infinity, 60),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                session.wsConnected ? 'Signal Active' : 'Signal Inactive',
                style: TextStyle(
                  fontSize: 11,
                  color: session.wsConnected ? PgColors.safe : PgColors.mediumBlue,
                ),
              ),
              Text(
                'Sample Rate: 16kHz',
                style: const TextStyle(
                  fontSize: 11,
                  color: PgColors.mediumBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptWidget(SessionController session) {
    final tr = session.transcript;
    if (tr == null) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Live Transcript'),
              if (tr.confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PgColors.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(PgRadius.bar),
                  ),
                  child: Text(
                    '${(tr.confidence! * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: PgColors.accentBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr.text,
            style: const TextStyle(
              fontSize: 13,
              color: PgColors.lightBlue,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (tr.language != null) ...[
                Text(
                  tr.language!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: PgColors.mediumBlue,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                tr.timestamp,
                style: const TextStyle(
                  fontSize: 10,
                  color: PgColors.mediumBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureMethodInfo(SessionController session) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Audio Capture Method'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PgColors.warn.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(PgRadius.bar),
                ),
                child: const Text(
                  'LIMITED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: PgColors.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Android does not allow direct call audio capture via public APIs.',
            style: TextStyle(
              fontSize: 12,
              color: PgColors.lightBlue,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Available methods:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PgColors.white,
            ),
          ),
          const SizedBox(height: 4),
          _buildCaptureMethodItem(
            'Browser Mic',
            'Captures room audio through microphone (recommended)',
            PgColors.accentBlue,
          ),
          _buildCaptureMethodItem(
            'Bluetooth SCO',
            'Headset required, untested - needs real call verification',
            PgColors.warn,
          ),
          _buildCaptureMethodItem(
            'Shizuku',
            'Experimental, ROM-dependent, requires real device testing',
            PgColors.dspAccent,
          ),
          const SizedBox(height: 8),
          const Text(
            'MediaProjection/Accessibility Service cannot capture call audio directly.',
            style: TextStyle(
              fontSize: 10,
              color: PgColors.mediumBlue,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureMethodItem(String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.lightBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatus(SessionController session) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Current Call'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call ID',
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.mediumBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.callId?.substring(0, 12) ?? 'None',
                    style: PgType.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: PgColors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PgColors.accentBlue.withValues(alpha: 0.2),
                  border: Border.all(
                    color: PgColors.accentBlue,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(PgRadius.bar),
                ),
                child: Text(
                  session.callTag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PgColors.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRiskGauge(session),
        ],
      ),
    );
  }

  Widget _buildRiskGauge(SessionController session) {
    final riskState = session.riskState;
    Color riskColor;
    switch (session.factcheck?.status) {
      case 'SAFE':
        riskColor = PgColors.safe;
        break;
      case 'CRITICAL':
        riskColor = PgColors.crit;
        break;
      case 'WARNING':
      case 'UNCERTAIN':
        riskColor = PgColors.warn;
        break;
      default:
        riskColor = PgColors.mediumBlue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Risk Level',
              style: const TextStyle(
                fontSize: 11,
                color: PgColors.mediumBlue,
              ),
            ),
            Text(
              riskState,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: riskColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: session.gaugeDegrees / 90,
            minHeight: 6,
            backgroundColor: PgColors.glassBgStrong,
            valueColor: AlwaysStoppedAnimation(riskColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          session.riskNote,
          style: const TextStyle(
            fontSize: 10,
            color: PgColors.mediumBlue,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFactCheckWidget(SessionController session) {
    final fc = session.factcheck;
    if (fc == null) return const SizedBox.shrink();

    Color statusColor;
    IconData statusIcon;
    switch (fc.status) {
      case 'SAFE':
        statusColor = PgColors.safe;
        statusIcon = Icons.check_circle;
        break;
      case 'CRITICAL':
        statusColor = PgColors.crit;
        statusIcon = Icons.warning;
        break;
      case 'WARNING':
      case 'UNCERTAIN':
        statusColor = PgColors.warn;
        statusIcon = Icons.error_outline;
        break;
      case 'VERIFYING':
        statusColor = PgColors.accentBlue;
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = PgColors.mediumBlue;
        statusIcon = Icons.info_outline;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionTitle('Scam Detection'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(PgRadius.bar),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      fc.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fc.message,
            style: const TextStyle(
              fontSize: 12,
              color: PgColors.lightBlue,
              height: 1.5,
            ),
          ),
          if (fc.category != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PgColors.glassBg,
                borderRadius: BorderRadius.circular(PgRadius.bar),
              ),
              child: Text(
                fc.category!,
                style: const TextStyle(
                  fontSize: 10,
                  color: PgColors.mediumBlue,
                ),
              ),
            ),
          ],
          if (fc.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.link, size: 12, color: PgColors.mediumBlue),
                const SizedBox(width: 4),
                Text(
                  'Evidence: ${fc.evidenceUrls.length} source(s)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: PgColors.mediumBlue,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SessionController session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Actions'),
        const SizedBox(height: 12),
        if (!session.wsConnected)
          ElevatedButton.icon(
            onPressed: session.connecting
                ? null
                : () {
                    session.startSession();
                  },
            icon: session.connecting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(PgColors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(session.connecting ? 'Connecting...' : 'Start Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PgColors.accentBlue,
              foregroundColor: PgColors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PgRadius.bar),
              ),
            ),
          )
        else ...[
          _buildActionButton(
            onPressed: () {
              _showBlockReportDialog(context, session);
            },
            label: 'Block & Report',
            icon: Icons.block,
            color: PgColors.crit,
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            onPressed: () {
              session.continueMonitoring();
            },
            label: 'Continue Monitoring',
            icon: Icons.visibility,
            color: PgColors.accentBlue,
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AudioCaptureTestScreen(),
                ),
              );
            },
            label: 'Test Audio Capture',
            icon: Icons.mic,
            color: PgColors.warn,
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DeepTestScreen(),
                ),
              );
            },
            label: 'Deep Test Lab (Compare Models)',
            icon: Icons.science,
            color: Colors.purple,
          ),
        ],
        if (session.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PgColors.crit.withValues(alpha: 0.1),
              border: Border.all(color: PgColors.crit, width: 1),
              borderRadius: BorderRadius.circular(PgRadius.bar),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: PgColors.crit),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.error!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PgColors.crit,
                    ),
                  ),
                ),
                if (session.wsConnected)
                  TextButton(
                    onPressed: () {
                      session.clearError();
                    },
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(
                        fontSize: 10,
                        color: PgColors.crit,
                      ),
                    ),
                  ),
                if (!session.wsConnected && !session.connecting)
                  TextButton(
                    onPressed: () {
                      session.startSession();
                    },
                    child: const Text(
                      'Reconnect',
                      style: TextStyle(
                        fontSize: 10,
                        color: PgColors.crit,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PgRadius.bar),
        ),
      ),
    );
  }

  void _showBlockReportDialog(BuildContext context, SessionController session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PgColors.bgSecondary,
        title: const Text(
          'Block & Report',
          style: TextStyle(color: PgColors.white),
        ),
        content: const Text(
          'This will escalate and block the current call. Continue?',
          style: TextStyle(color: PgColors.lightBlue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final draft = await session.draftBlockAndReport();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Escalation ready: ${draft.draftId}'),
                      backgroundColor: PgColors.safe,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: PgColors.crit,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Draft Report',
              style: TextStyle(color: PgColors.suspicious),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await session.escalateToCybercell();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Escalated to 1930 Cybercell'),
                      backgroundColor: PgColors.safe,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: PgColors.crit,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Escalate to 1930',
              style: TextStyle(color: PgColors.crit),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  final List<double> audioLevels;

  _AudioWaveformPainter(this.audioLevels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PgColors.accentBlue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final barWidth = size.width / audioLevels.length;
    final baseline = size.height / 2;

    for (int i = 0; i < audioLevels.length; i++) {
      final level = audioLevels[i];
      final barHeight = level * size.height * 0.8;
      final x = i * barWidth;

      final path = Path();
      path.moveTo(x, baseline - barHeight / 2);
      path.lineTo(x, baseline + barHeight / 2);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_AudioWaveformPainter oldDelegate) {
    return true;
  }
}