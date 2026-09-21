import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/pg_gauge.dart';
import '../widgets/pg_animations.dart';

class IncomingCallOverlay extends StatefulWidget {
  final String callerNumber;
  final bool isVoip;
  final int timesReported;
  final String registrationCircle;
  final VoidCallback onStartProtection;
  final VoidCallback onIgnore;
  final VoidCallback onEscalateToCybercell;
  final VoidCallback onDeployScambaiter;
  final VoidCallback onDownloadDossier;
  final bool showSimulationControls;
  final double? pdiScore;
  final double? syntheticVoiceScore;
  final bool? isVideoSpoof;
  final String? claimVerificationStatus;
  final String? claimText;
  final bool? isScamDetected;
  final String? liveTranscript;

  const IncomingCallOverlay({
    super.key,
    required this.callerNumber,
    this.isVoip = false,
    this.timesReported = 0,
    this.registrationCircle = 'Unknown',
    required this.onStartProtection,
    required this.onIgnore,
    required this.onEscalateToCybercell,
    required this.onDeployScambaiter,
    required this.onDownloadDossier,
    this.showSimulationControls = true,
    this.pdiScore,
    this.syntheticVoiceScore,
    this.isVideoSpoof,
    this.claimVerificationStatus,
    this.claimText,
    this.isScamDetected,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  // Local overrides for simulation controls
  double? _simPdiScore;
  double? _simSyntheticVoiceScore;
  bool? _simIsVideoSpoof;
  String? _simClaimVerificationStatus;
  String? _simClaimText;
  bool? _simIsScamDetected;

  double get pdiScore => _simPdiScore ?? widget.pdiScore ?? 0.84;
  double get syntheticVoiceScore => _simSyntheticVoiceScore ?? widget.syntheticVoiceScore ?? 0.78;
  bool get isVideoSpoof => _simIsVideoSpoof ?? widget.isVideoSpoof ?? false;
  String get claimVerificationStatus => _simClaimVerificationStatus ?? widget.claimVerificationStatus ?? 'VERIFYING';
  String get claimText => _simClaimText ?? widget.claimText ?? 'This is the IRS calling about your tax return...';
  bool get isScamDetected => _simIsScamDetected ?? widget.isScamDetected ?? (pdiScore >= 0.70);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AppBackground(
        overlayOpacity: 0.65,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PgSpace.lg),
            child: Column(
              children: [
                const SizedBox(height: PgSpace.lg),
                // Caller Avatar with glowing pulse ring
                PulsingRing(
                  pulseColor: isScamDetected ? PgColors.scam : PgColors.accent,
                  maxRadius: 54,
                  ringCount: 3,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isScamDetected
                            ? [PgColors.scam, PgColors.scamDim]
                            : [PgColors.accent, PgColors.accentDim],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isScamDetected ? PgColors.scam : PgColors.accent).withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 42,
                      color: PgColors.bgPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: PgSpace.lg),
                Text(
                  widget.callerNumber,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: PgColors.textPrimary,
                  ),
                ),
                const SizedBox(height: PgSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PgSpace.md,
                    vertical: PgSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: PgColors.accent.withValues(alpha: 0.15),
                    border: Border.all(color: PgColors.accent),
                    borderRadius: BorderRadius.circular(PgRadii.pill),
                  ),
                  child: const Text(
                    'Incoming Call',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PgColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: PgSpace.xl),
                _buildIntelligenceCard(),
                const SizedBox(height: PgSpace.lg),
                if (widget.showVoiceAnalysis) ...[
                  const SizedBox(height: PgSpace.md),
                  _buildVoiceAnalysisMeters(),
                ],
                if (widget.liveTranscript != null && widget.liveTranscript!.isNotEmpty) ...[
                  const SizedBox(height: PgSpace.md),
                  _buildLiveTranscript(),
                ],
                const SizedBox(height: PgSpace.lg),
                // Claim Verification Box
                _buildClaimVerification(),
                const SizedBox(height: PgSpace.lg),
                // Scam Action Buttons (shown when scam detected)
                if (isScamDetected) _buildScamActionButtons(),
                const SizedBox(height: PgSpace.lg),
                // Simulation controls for testing
                _buildSimulationControls(),
                const SizedBox(height: PgSpace.lg),
                // Original buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onIgnore,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PgColors.bgSecondary,
                          foregroundColor: PgColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: PgSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PgRadii.button),
                          ),
                        ),
                        child: const Text('Ignore'),
                      ),
                    ),
                    const SizedBox(width: PgSpace.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onStartProtection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PgColors.accent,
                          foregroundColor: PgColors.bgPrimary,
                          padding: const EdgeInsets.symmetric(vertical: PgSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PgRadii.button),
                          ),
                        ),
                        child: const Text(
                          'Start Protection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PgSpace.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligenceCard() {
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary,
        border: Border.all(color: PgColors.border),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Number Intelligence',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildIntelligenceItem(
            'VOIP Detection',
            widget.isVoip ? 'Likely VOIP' : 'Standard Line',
            widget.isVoip ? PgColors.suspicious : PgColors.safe,
          ),
          const SizedBox(height: PgSpace.sm),
          _buildIntelligenceItem(
            'Times Reported',
            widget.timesReported.toString(),
            widget.timesReported > 0 ? PgColors.scam : PgColors.safe,
          ),
          const SizedBox(height: PgSpace.sm),
          _buildIntelligenceItem(
            'Registration',
            widget.registrationCircle,
            PgColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceItem(String label, String value, Color color) {
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTranscript() {
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary,
        border: Border.all(color: PgColors.border),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Transcript',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.sm),
          Text(
            widget.liveTranscript ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: PgColors.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceAnalysisMeters() {
    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.92),
        border: Border.all(
          color: (pdiScore >= 0.7 ? PgColors.scam : PgColors.border).withValues(alpha: 0.6),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(PgRadii.card),
        boxShadow: [
          BoxShadow(
            color: (pdiScore >= 0.7 ? PgColors.scam : PgColors.accent).withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
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
                'AI VOICE & HEURISTIC ANALYSIS',
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
                  color: PgColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                  border: Border.all(color: PgColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'REAL-TIME DSP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: PgColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PgSpace.md),
          // Signature Radial Speedometer Gauge as centerpiece
          Center(
            child: PgRadialGauge(
              value: pdiScore,
              size: 210,
              title: 'PDI THREAT SCORE',
              subtitle: pdiScore >= 0.7 ? 'CRITICAL RISK' : pdiScore >= 0.4 ? 'SUSPICIOUS' : 'SAFE',
            ),
          ),
          const SizedBox(height: PgSpace.md),
          // Acoustic Voice Meter
          PgAcousticMeter(
            value: syntheticVoiceScore,
            label: 'SYNTHETIC VOICE ANALYSIS',
            isSynthetic: syntheticVoiceScore >= 0.50,
          ),
          // Video Liveness Badge
          if (isVideoSpoof) ...[
            const SizedBox(height: PgSpace.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: PgSpace.md, vertical: PgSpace.sm),
              decoration: BoxDecoration(
                color: PgColors.error.withValues(alpha: 0.15),
                border: Border.all(color: PgColors.error.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_off, color: PgColors.error, size: 20),
                  const SizedBox(width: PgSpace.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIDEO LIVENESS: SPOOF DETECTED',
                          style: TextStyle(
                            color: PgColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Static photo or screen detected. Real human presence not found.',
                          style: TextStyle(
                            color: PgColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimVerification() {
    Color statusColor;
    switch (claimVerificationStatus) {
      case 'SAFE':
        statusColor = PgColors.safe;
        break;
      case 'SCAM':
        statusColor = PgColors.scam;
        break;
      case 'VERIFYING':
        statusColor = PgColors.suspicious;
        break;
      default:
        statusColor = PgColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(PgSpace.lg),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary,
        border: Border.all(color: PgColors.border),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Claim Verification',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PgColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(PgRadii.pill),
                ),
                child: Text(
                  claimVerificationStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
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
              claimText,
              style: const TextStyle(
                fontSize: 13,
                color: PgColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: PgSpace.md),
          if (claimVerificationStatus == 'VERIFYING')
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(PgColors.accent),
                  ),
                ),
                const SizedBox(width: PgSpace.sm),
                const Text(
                  'Analyzing claim against databases...',
                  style: TextStyle(
                    fontSize: 12,
                    color: PgColors.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScamActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scam Detected - Take Action',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PgColors.scam,
          ),
        ),
        const SizedBox(height: PgSpace.md),
        _buildActionButton(
          'Escalate to Cybercell',
          Icons.security,
          PgColors.scam,
          widget.onEscalateToCybercell,
        ),
        const SizedBox(height: PgSpace.sm),
        _buildActionButton(
          'Deploy Scambaiter',
          Icons.smart_toy,
          PgColors.accent,
          widget.onDeployScambaiter,
        ),
        const SizedBox(height: PgSpace.sm),
        _buildActionButton(
          'Download Dossier PDF',
          Icons.download,
          PgColors.textSecondary,
          widget.onDownloadDossier,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PgRadii.button),
        ),
      ),
    );
  }

  Widget _buildSimulationControls() {
    if (!widget.showSimulationControls) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(PgSpace.md),
      decoration: BoxDecoration(
        color: PgColors.bgSecondary.withValues(alpha: 0.5),
        border: Border.all(color: PgColors.borderAccent),
        borderRadius: BorderRadius.circular(PgRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulation Controls',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PgColors.textSecondary,
            ),
          ),
          const SizedBox(height: PgSpace.md),
          _buildSimulationToggle(
            'Simulate Scam Detection',
            isScamDetected,
            (value) {
              setState(() {
                _simIsScamDetected = value;
                if (value) {
                  _simClaimVerificationStatus = 'SCAM';
                } else {
                  _simClaimVerificationStatus = 'VERIFYING';
                }
              });
            },
          ),
          const SizedBox(height: PgSpace.sm),
          _buildSimulationToggle(
            'High PDI Score',
            pdiScore >= 0.7,
            (value) {
              setState(() {
                _simPdiScore = value ? 0.84 : 0.25;
              });
            },
          ),
          const SizedBox(height: PgSpace.sm),
          _buildSimulationToggle(
            'Synthetic Voice',
            syntheticVoiceScore >= 0.7,
            (value) {
              setState(() {
                _simSyntheticVoiceScore = value ? 0.78 : 0.35;
              });
            },
          ),
          const SizedBox(height: PgSpace.sm),
          _buildSimulationToggle(
            'Video Spoof',
            isVideoSpoof,
            (value) {
              setState(() {
                _simIsVideoSpoof = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationToggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: PgColors.textSecondary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: PgColors.accent,
        ),
      ],
    );
  }
}