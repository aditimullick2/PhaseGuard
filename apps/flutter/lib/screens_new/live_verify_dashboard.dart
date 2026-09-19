import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/pg_gauge.dart';
import '../widgets/pg_animations.dart';
import '../state/session_controller.dart';

class LiveVerifyDashboard extends StatefulWidget {
  const LiveVerifyDashboard({super.key});

  @override
  State<LiveVerifyDashboard> createState() => _LiveVerifyDashboardState();
}

class _LiveVerifyDashboardState extends State<LiveVerifyDashboard> {
  @override
  void initState() {
    super.initState();
    // Auto-start streaming so meter animates immediately on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().startLiveAudioIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isConnected = session.wsConnected;
    final isConnecting = session.connecting;

    // Always use live session values — on-device STT updates pdiScore,
    // isPotentialScam, etc. locally even without WebSocket connection
    final pdiScore = session.pdiScore;
    final verdict = session.isScamDetected ? 'SCAM' : session.riskState;
    final verdictMessage = session.claimText;
    final transcript = session.liveTranscript.isNotEmpty
        ? session.liveTranscript
        : 'Waiting for speech...';
    final evidenceUrls = (session.factcheck?.evidenceUrls.isNotEmpty == true)
        ? session.factcheck!.evidenceUrls
        : <String>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PgColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Verify',
          style: TextStyle(
            color: PgColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              if (!isConnected && !isConnecting) {
                session.startSession();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isConnected
                    ? PgColors.safe.withValues(alpha: 0.15)
                    : (isConnecting ? PgColors.suspicious.withValues(alpha: 0.15) : PgColors.accent.withValues(alpha: 0.15)),
                border: Border.all(
                  color: isConnected
                      ? PgColors.safe
                      : (isConnecting ? PgColors.suspicious : PgColors.accent),
                ),
                borderRadius: BorderRadius.circular(PgRadii.pill),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.wifi : (isConnecting ? Icons.sync : Icons.wifi_off),
                    size: 16,
                    color: isConnected
                        ? PgColors.safe
                        : (isConnecting ? PgColors.suspicious : PgColors.accent),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected ? 'Live WSS' : (isConnecting ? 'Connecting...' : 'Connect'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? PgColors.safe
                          : (isConnecting ? PgColors.suspicious : PgColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: PgSpace.md),
        ],
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PgSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPdiScoreCard(pdiScore, verdict),
              const SizedBox(height: PgSpace.lg),
              _buildAudioStreamController(session),
              const SizedBox(height: PgSpace.lg),
              _buildSpeakerphoneCard(session),
              const SizedBox(height: PgSpace.lg),
              _buildVerdictCard(verdict, verdictMessage),
              const SizedBox(height: PgSpace.lg),
              _buildTranscriptCard(transcript),
              const SizedBox(height: PgSpace.lg),
              if (evidenceUrls.isNotEmpty) _buildEvidenceCard(evidenceUrls),
              const SizedBox(height: PgSpace.lg),
              _buildWaveformVisualization(isConnected || session.isStreamingAudio),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdiScoreCard(double pdiScore, String verdict) {
    Color scoreColor = pdiScore >= 0.7
        ? PgColors.scam
        : pdiScore >= 0.4
            ? PgColors.suspicious
            : PgColors.safe;

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.90),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.55),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.15),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIGNATURE METRIC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.16),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.8)),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withValues(alpha: 0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scoreColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: scoreColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Center(
            child: PgRadialGauge(
              value: pdiScore,
              size: 210,
              title: 'PDI THREAT INDEX',
              subtitle: verdict,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictCard(String verdict, String verdictMessage) {
    Color verdictColor;
    switch (verdict) {
      case 'SAFE':
        verdictColor = PgColors.safe;
        break;
      case 'SCAM':
        verdictColor = PgColors.scam;
        break;
      case 'SUSPICIOUS':
        verdictColor = PgColors.suspicious;
        break;
      default:
        verdictColor = PgColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.1),
        border: Border.all(color: verdictColor, width: 2),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verdict == 'SCAM' ? Icons.warning : Icons.info,
                color: verdictColor,
                size: 24,
              ),
              const SizedBox(width: PgSpace.sm),
              Text(
                verdict == 'SCAM' ? 'SCAM ALERT' : 'Analysis Result',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: verdictColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Text(
            verdictMessage,
            style: const TextStyle(
              fontSize: 14,
              color: PgColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(String transcript) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Transcript',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PgColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: PgColors.accentGlow,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Container(
            padding: const EdgeInsets.all(PgSpace.md),
            decoration: BoxDecoration(
              color: PgColors.bgElevated,
              borderRadius: BorderRadius.circular(PgRadii.bar),
            ),
            child: Text(
              transcript,
              style: const TextStyle(
                fontSize: 13,
                color: PgColors.textPrimary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(List<String> evidenceUrls) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.82),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidence Sources',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          ...evidenceUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: PgSpace.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 16,
                      color: PgColors.accent,
                    ),
                    const SizedBox(width: PgSpace.sm),
                    Expanded(
                      child: Text(
                        url,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PgColors.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSpeakerphoneCard(SessionController session) {
    final isOn = session.isSpeakerphoneOn;
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.88),
        border: Border.all(
          color: isOn
              ? PgColors.accent.withValues(alpha: 0.7)
              : PgColors.border.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Row(
        children: [
          Icon(
            isOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: isOn ? PgColors.accent : PgColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: PgSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Speakerphone Audio Capture',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PgColors.textPrimary,
                  ),
                ),
                Text(
                  isOn
                      ? 'Routing active — capturing caller audio via speaker mic'
                      : 'Enable to route call audio through speakerphone for analysis',
                  style: const TextStyle(
                    fontSize: 11,
                    color: PgColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: (_) => session.toggleSpeakerphone(),
            activeColor: PgColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformVisualization(bool isStreaming) {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.85),
        border: Border.all(color: PgColors.border.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: PgColors.accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE AUDIO SPECTRUM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: PgColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isStreaming ? PgColors.accent : PgColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isStreaming ? '16kHz STREAM' : 'PAUSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isStreaming ? PgColors.accent : PgColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          LiveWaveform(
            isAnalyzing: isStreaming,
            height: 52,
            barCount: 36,
            activeColor: PgColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioStreamController(SessionController session) {
    final isStreaming = session.isStreamingAudio;
    final isConnected = session.wsConnected;

    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.90),
        border: Border.all(
          color: isStreaming
              ? PgColors.accent.withValues(alpha: 0.7)
              : PgColors.border.withValues(alpha: 0.8),
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          if (isStreaming)
            BoxShadow(
              color: PgColors.accent.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq,
                    size: 18,
                    color: isStreaming ? PgColors.accent : PgColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VOICE DSP & STREAMING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: PgColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isStreaming
                      ? PgColors.safe.withValues(alpha: 0.15)
                      : PgColors.border.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                  border: Border.all(
                    color: isStreaming ? PgColors.safe : PgColors.border,
                  ),
                ),
                child: Text(
                  isStreaming ? 'STREAMING ACTIVE' : 'STREAM IDLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isStreaming ? PgColors.safe : PgColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.sm),
          Text(
            isStreaming
                ? 'Streaming 16kHz PCM16 audio packets to Bispectrum DSP & Whisper STT loop...'
                : 'Tap below to stream live audio frames or inject test scam voice scenarios.',
            style: const TextStyle(fontSize: 11, color: PgColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isConnected
                      ? () {
                          if (isStreaming) {
                            session.stopLiveAudioStream();
                          } else {
                            session.startLiveAudioStream();
                          }
                        }
                      : () => session.startSession(),
                  icon: Icon(
                    isStreaming ? Icons.stop_circle_outlined : Icons.mic,
                    size: 18,
                  ),
                  label: Text(
                    isStreaming
                        ? 'Stop Audio Stream'
                        : (isConnected ? 'Stream Voice Audio' : 'Connect & Stream'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStreaming
                        ? PgColors.scam.withValues(alpha: 0.2)
                        : PgColors.accent.withValues(alpha: 0.2),
                    foregroundColor: isStreaming ? PgColors.scam : PgColors.accent,
                    side: BorderSide(
                      color: isStreaming ? PgColors.scam : PgColors.accent,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PgRadii.button),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.sm),
          const Text(
            'Quick Speech Injections:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PgColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInjectionChip(
                session,
                '🚨 IRS Threat',
                r'This is IRS badge number 12345. You owe $5,000 back taxes. Pay immediately or police will arrest you.',
              ),
              _buildInjectionChip(
                session,
                '🏦 Bank OTP',
                'Your Wells Fargo checking account is compromised. Please read back the 6 digit OTP sent to your phone.',
              ),
              _buildInjectionChip(
                session,
                '📦 Customs Fraud',
                'US Customs and Border Protection. We confiscated an illegal parcel with your passport details.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInjectionChip(SessionController session, String label, String text) {
    return ActionChip(
      backgroundColor: PgColors.bgPrimary,
      side: BorderSide(color: PgColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PgRadii.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PgColors.textPrimary),
      ),
      onPressed: () {
        session.injectCallerSpeech(text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Injected: "$label" into live STT & Factcheck loop'),
            duration: const Duration(seconds: 2),
            backgroundColor: PgColors.accent,
          ),
        );
      },
    );
  }
}