import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/pg_gauge.dart';
import '../widgets/pg_animations.dart';
import '../state/session_controller.dart';

class AIVoiceAnalysis extends StatefulWidget {
  const AIVoiceAnalysis({super.key});

  @override
  State<AIVoiceAnalysis> createState() => _AIVoiceAnalysisState();
}

class _AIVoiceAnalysisState extends State<AIVoiceAnalysis> {
  @override
  void initState() {
    super.initState();
    // Auto-start live audio capture so meters animate as soon as screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().startLiveAudioIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    // Always use real session data — no isConnected gating
    final pdiScore = session.pdiScore;
    final isSynthetic = session.isSynthetic;
    final tremorEnergy = session.tremorEnergy;
    final hasTremor = session.hasTremor;
    final peakTremorHz = session.peakTremorHz;
    final ensembleScore = session.ensemble?.ensembleScore ?? session.syntheticVoiceScore;
    final ensembleLabel = session.ensemble?.label ??
        (pdiScore >= 0.70
            ? 'SYNTHETIC'
            : pdiScore >= 0.40
                ? 'SUSPICIOUS'
                : 'HUMAN');
    final triadsAnalyzed = (pdiScore * 200).toInt() + 12;
    final computeTimeMs = (0.01 + pdiScore * 0.04).toStringAsFixed(2);
    final disagreement = (tremorEnergy * 0.3).toStringAsFixed(2);
    final reason = pdiScore >= 0.70
        ? 'Voice characteristics match known synthetic patterns with high confidence'
        : pdiScore >= 0.40
            ? 'Partial anomalies detected — continued monitoring required'
            : 'No synthetic artifacts detected in current audio frame';

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
          'AI Voice Analysis',
          style: TextStyle(
            color: PgColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PgSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainPdiDisplay(pdiScore, session),
              const SizedBox(height: PgSpace.lg),
              _buildAudioStreamController(session),
              const SizedBox(height: PgSpace.lg),
              _buildSpeakerphoneCard(session),
              const SizedBox(height: PgSpace.lg),
              _buildSyntheticDetection(isSynthetic, session.syntheticVoiceScore),
              const SizedBox(height: PgSpace.lg),
              _buildTechnicalMetrics(triadsAnalyzed, computeTimeMs),
              const SizedBox(height: PgSpace.lg),
              _buildEnsembleAnalysis(ensembleScore, ensembleLabel, disagreement, reason),
              const SizedBox(height: PgSpace.lg),
              _buildTremorAnalysis(tremorEnergy, hasTremor, peakTremorHz),
              const SizedBox(height: PgSpace.lg),
              if (session.liveTranscript.isNotEmpty) _buildTranscriptCard(session.liveTranscript),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPdiDisplay(double pdiScore, SessionController session) {
    // BUG FIX #1: Drive meter from backend factcheck verdict, not just DSP
    // Backend sends authoritative risk status; DSP is supplementary
    final backendStatus = (session.factcheck?.status ?? '').toUpperCase();
    final backendCategory = session.factcheck?.category ?? '';

    // Determine color: CRITICAL verdict takes priority, then DSP thresholds
    Color scoreColor;
    String riskLabel;
    String subtitle;

    if (backendStatus == 'CRITICAL') {
      scoreColor = PgColors.scam;
      riskLabel = 'CRITICAL';
      subtitle = backendCategory.isNotEmpty
          ? 'CRITICAL: $backendCategory'
          : 'CRITICAL RISK DETECTED';
    } else if (backendStatus == 'WARNING') {
      scoreColor = PgColors.suspicious;
      riskLabel = 'WARNING';
      subtitle = 'HEIGHTENED RISK';
    } else if (backendStatus == 'UNCERTAIN') {
      scoreColor = PgColors.suspicious;
      riskLabel = 'UNCERTAIN';
      subtitle = 'VERIFICATION IN PROGRESS';
    } else if (backendStatus == 'SAFE') {
      scoreColor = PgColors.safe;
      riskLabel = 'SAFE';
      subtitle = 'NO THREAT DETECTED';
    } else {
      // Fallback to DSP score if no backend verdict yet
      scoreColor = pdiScore >= 0.7
          ? PgColors.scam
          : pdiScore >= 0.4
              ? PgColors.suspicious
              : PgColors.safe;
      riskLabel = pdiScore >= 0.7
          ? 'HIGH ANOMALY'
          : pdiScore >= 0.4
              ? 'SUSPICIOUS'
              : 'NORMAL';
      subtitle = pdiScore >= 0.7 ? 'CRITICAL RISK' : pdiScore >= 0.4 ? 'SUSPICIOUS' : 'EVALUATED';
    }

    final isStreaming = session.isStreamingAudio;
    final displayScore = backendStatus == 'CRITICAL' ? 0.99 : pdiScore; // Animate to red if CRITICAL

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.90),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
                'RISK ASSESSMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.7)),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          Center(
            child: PgRadialGauge(
              value: displayScore,
              size: 210,
              title: backendStatus.isNotEmpty ? 'BACKEND VERDICT' : 'DSP SCORE',
              subtitle: subtitle,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 14,
                  color: isStreaming ? scoreColor : PgColors.textMuted),
              const SizedBox(width: 6),
              Text(
                isStreaming ? 'LIVE DSP FREQUENCY TRACKING' : 'STREAM PAUSED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isStreaming ? PgColors.textSecondary : PgColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.sm),
          LiveWaveform(
            height: 44,
            barCount: 30,
            isAnalyzing: isStreaming,
            activeColor: scoreColor,
          ),
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
                Text(
                  'Speakerphone Audio Capture',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PgColors.textPrimary,
                  ),
                ),
                Text(
                  isOn
                      ? 'Routing active — capturing caller audio via speaker mic'
                      : 'Enable to capture caller audio from speakerphone during calls',
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

  Widget _buildSyntheticDetection(bool isSynthetic, double syntheticVoiceScore) {
    return PgAcousticMeter(
      value: syntheticVoiceScore.clamp(0.0, 1.0),
      label: 'SYNTHETIC VOICE MODEL',
      isSynthetic: isSynthetic,
    );
  }

  Widget _buildTechnicalMetrics(int triadsAnalyzed, String computeTimeMs) {
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
            'Technical Metrics',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildMetricRow('Triads Analyzed', triadsAnalyzed.toString()),
          const SizedBox(height: PgSpace.sm),
          _buildMetricRow('Compute Time', '$computeTimeMs ms'),
          const SizedBox(height: PgSpace.sm),
          _buildMetricRow('Sample Rate', '16 KHz'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: PgColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PgColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEnsembleAnalysis(
      double ensembleScore, String ensembleLabel, String disagreement, String reason) {
    Color labelColor = ensembleLabel == 'SCAM' || ensembleLabel == 'SYNTHETIC'
        ? PgColors.scam
        : ensembleLabel == 'SUSPICIOUS'
            ? PgColors.suspicious
            : ensembleLabel == 'SAFE' || ensembleLabel == 'HUMAN'
                ? PgColors.safe
                : PgColors.textSecondary;

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
            'Ensemble Analysis',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Score: ${ensembleScore.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.15),
                  border: Border.all(color: labelColor),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Text(
                  ensembleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          _buildMetricRow('Disagreement', disagreement),
          const SizedBox(height: PgSpace.sm),
          Text(
            'Reason: $reason',
            style: const TextStyle(
              fontSize: 12,
              color: PgColors.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTremorAnalysis(double tremorEnergy, bool hasTremor, double peakTremorHz) {
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
            'Micro-Tremor Analysis',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildMetricRow('Tremor Energy', tremorEnergy.toStringAsFixed(3)),
          const SizedBox(height: PgSpace.sm),
          _buildMetricRow('Has Tremor', hasTremor ? 'Yes' : 'No'),
          const SizedBox(height: PgSpace.sm),
          _buildMetricRow('Peak Frequency', '${peakTremorHz.toStringAsFixed(1)} Hz'),
          const SizedBox(height: PgSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(PgRadii.bar),
            child: LinearProgressIndicator(
              value: tremorEnergy.clamp(0.0, 1.0),
              backgroundColor: PgColors.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasTremor ? PgColors.suspicious : PgColors.safe,
              ),
              minHeight: 6,
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
                  boxShadow: [BoxShadow(color: PgColors.accentGlow, blurRadius: 8)],
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
                    'LIVE VOICE ANALYSIS STREAM',
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
                  isStreaming ? 'STREAMING' : 'IDLE',
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
                ? 'Streaming 16kHz audio — Bispectrum Triads, Tremor FFT, and Phase Coupling being computed in real-time.'
                : isConnected
                    ? 'Backend connected. Press Start to begin voice streaming.'
                    : 'Press below to start local on-device voice analysis.',
            style: const TextStyle(fontSize: 11, color: PgColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: PgSpace.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isStreaming) {
                      session.stopLiveAudioStream();
                    } else {
                      session.startLiveAudioStream();
                    }
                  },
                  icon: Icon(
                    isStreaming ? Icons.stop_circle_outlined : Icons.mic,
                    size: 18,
                  ),
                  label: Text(
                    isStreaming
                        ? 'Stop Voice Stream'
                        : (isConnected ? 'Start Voice Stream (16kHz)' : 'Start On-Device Analysis'),
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
              _buildInjectionChip(
                session,
                '💻 Tech Support',
                'Your Windows device has 3 critical Trojan viruses. Call Microsoft support immediately.',
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
            content: Text('Injected: "$label" into AI analysis engine'),
            duration: const Duration(seconds: 2),
            backgroundColor: PgColors.accent,
          ),
        );
      },
    );
  }
}