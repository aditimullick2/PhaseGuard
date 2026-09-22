import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/offline_dossier_service.dart';
import '../state/session_controller.dart';
import '../providers/providers.dart';
import 'app_theme.dart';
import 'dart:ui' as ui;

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

enum _SecurityLevel { scanning, safe, suspicious, highRisk, unknown }

_SecurityLevel _evaluate(SessionController s) {
  if (s.isScamDetected) return _SecurityLevel.highRisk;

  final pdi = s.pdiScore;
  final synth = s.syntheticVoiceScore;
  final hasData = s.wsConnected || s.liveTranscript.isNotEmpty;

  if (!hasData) return _SecurityLevel.scanning;
  
  // Lowered thresholds for better scam detection
  // HIGH RISK if either scam text OR deepfake is detected with moderate confidence
  if (pdi >= 0.50 || synth >= 0.50) return _SecurityLevel.highRisk;
  
  // Suspicious if either is moderately high
  if (pdi >= 0.30 || synth >= 0.30) return _SecurityLevel.suspicious;
  
  return _SecurityLevel.safe;
}

Color _levelColor(_SecurityLevel lvl) {
  switch (lvl) {
    case _SecurityLevel.scanning:  return Colors.grey;
    case _SecurityLevel.safe:      return AppColors.success;
    case _SecurityLevel.suspicious:return Colors.orangeAccent;
    case _SecurityLevel.highRisk:  return AppColors.error;
    case _SecurityLevel.unknown:   return Colors.grey;
  }
}

IconData _levelIcon(_SecurityLevel lvl) {
  switch (lvl) {
    case _SecurityLevel.scanning:  return Icons.radar_rounded;
    case _SecurityLevel.safe:      return Icons.verified_user_rounded;
    case _SecurityLevel.suspicious:return Icons.warning_amber_rounded;
    case _SecurityLevel.highRisk:  return Icons.gpp_bad_rounded;
    case _SecurityLevel.unknown:   return Icons.help_outline_rounded;
  }
}

String _levelTitle(_SecurityLevel lvl) {
  switch (lvl) {
    case _SecurityLevel.scanning:  return 'SCANNING';
    case _SecurityLevel.safe:      return 'SAFE';
    case _SecurityLevel.suspicious:return 'SUSPICIOUS';
    case _SecurityLevel.highRisk:  return 'HIGH RISK';
    case _SecurityLevel.unknown:   return 'UNKNOWN';
  }
}

String _levelBody(_SecurityLevel lvl, SessionController s) {
  switch (lvl) {
    case _SecurityLevel.scanning:  return 'Checking the call...\nProtection is active.';
    case _SecurityLevel.safe:      return 'Voice appears normal.\nProtection active.';
    case _SecurityLevel.suspicious:return 'Something looks unusual.\nPlease be careful with this call.';
    case _SecurityLevel.highRisk:  
      if (s.syntheticVoiceScore >= 0.50) {
        return 'Possible AI-generated voice detected!\nDo NOT share sensitive information.';
      } else {
        return 'High Risk Call detected!\nDo NOT share sensitive information.';
      }
    case _SecurityLevel.unknown:   return 'Unable to verify voice.\nStay cautious with this call.';
  }
}

// ─────────────────────────────────────────────────────────────
// Full Security Overlay Modal  (shown via bottom sheet)
// ─────────────────────────────────────────────────────────────

class SecurityOverlayModal extends ConsumerWidget {
  const SecurityOverlayModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = context.watch<SessionController>();
    final level   = _evaluate(session);
    final color   = _levelColor(level);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Big status icon ──
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(_levelIcon(level), color: color, size: 40),
            ),
            const SizedBox(height: 16),

            // ── Status title ──
            Text(
              _levelTitle(level),
              style: AppTextStyles.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // ── Human-readable body ──
            Text(
              _levelBody(level, session),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 17,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // ── AI Voice Meter ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI Voice Meter (Deepfake)',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Scam probability bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white12,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: session.pdiScore.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: session.pdiScore >= 0.50
                              ? AppColors.error
                              : session.pdiScore >= 0.30
                                  ? Colors.orangeAccent
                                  : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(session.pdiScore * 100).toInt()}% AI Voice Probability',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        session.pdiScore >= 0.50 ? 'HIGH RISK' : 
                        session.pdiScore >= 0.30 ? 'MEDIUM' : 'LOW',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: session.pdiScore >= 0.50
                              ? AppColors.error
                              : session.pdiScore >= 0.30
                                  ? Colors.orangeAccent
                                  : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Scam Content Meter ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Scam Text Meter (Content)',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Scam probability bar
                  Builder(builder: (context) {
                    double scamScore = session.isPotentialScam ? 0.85 : 
                                       (session.factcheck?.status == 'CRITICAL' ? 0.9 : 
                                       (session.factcheck?.status == 'WARNING' ? 0.5 : 0.05));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white12,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: scamScore,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: scamScore >= 0.8
                                    ? AppColors.error
                                    : scamScore >= 0.4
                                        ? Colors.orangeAccent
                                        : AppColors.success,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(scamScore * 100).toInt()}% Scam Probability',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              scamScore >= 0.8 ? 'CRITICAL' : 
                              scamScore >= 0.4 ? 'WARNING' : 'SAFE',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: scamScore >= 0.8
                                    ? AppColors.error
                                    : scamScore >= 0.4
                                        ? Colors.orangeAccent
                                        : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Detail rows ──
            _DetailRow(
              icon: Icons.record_voice_over_rounded,
              label: 'Voice Authenticity',
              value: _synthLabel(session.syntheticVoiceScore),
              valueColor: session.syntheticVoiceScore >= 0.50
                  ? AppColors.error
                  : session.syntheticVoiceScore >= 0.30
                      ? Colors.orangeAccent
                      : AppColors.success,
            ),
            const Divider(color: Colors.white12, height: 20),

            _DetailRow(
              icon: Icons.manage_search_rounded,
              label: 'Scam Text Analysis',
              value: _scamLabel(session.pdiScore),
              valueColor: session.pdiScore >= 0.50
                  ? AppColors.error
                  : session.pdiScore >= 0.30
                      ? Colors.orangeAccent
                      : AppColors.success,
            ),
            const Divider(color: Colors.white12, height: 20),

            _DetailRow(
              icon: Icons.fact_check_rounded,
              label: 'Claim Verification',
              value: _factcheckLabel(session.claimVerificationStatus),
              valueColor: session.claimVerificationStatus == 'CRITICAL'
                  ? AppColors.error
                  : session.claimVerificationStatus == 'SAFE'
                      ? AppColors.success
                      : Colors.orangeAccent,
            ),

            // ── Live transcript snippet ──
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.mic_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text('Live Transcript',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    session.liveTranscript.isNotEmpty 
                        ? session.liveTranscript 
                        : 'Waiting for scammer speech...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: session.liveTranscript.isNotEmpty 
                          ? Colors.white70 
                          : Colors.white38,
                      fontStyle: session.liveTranscript.isNotEmpty 
                          ? FontStyle.italic 
                          : FontStyle.normal,
                      height: 1.5,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── HIGH RISK extra warning banner ──
            if (level == _SecurityLevel.highRisk) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.block_rounded, color: AppColors.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      session.highRiskWarningText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            // ── Deploy Scambaiter Button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  // Activate AI scambaiter
                  try {
                    debugPrint('[SecurityOverlay] Activating Deploy Scambaiter mode');
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Deploy Scambaiter activating...'),
                          backgroundColor: AppColors.primary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    
                    // Tell backend to activate scambaiter. The backend will now
                    // automatically generate AI voice responses based on the caller's transcript
                    // and stream binary PCM frames back via WebSocket to the app.
                    await session.activateScambaiter();
                    debugPrint('[SecurityOverlay] Deploy Scambaiter activated - waiting for backend stream');
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Deploy Scambaiter AI active! Scammer will hear AI voice when they speak.'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    debugPrint('[SecurityOverlay] Error activating Deploy Scambaiter: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to activate Scambaiter: $e'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Deploy Scambaiter', style: AppTextStyles.labelMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── PDF Report Button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  // Generate PDF report with scam details and transcript
                  try {
                    debugPrint('[SecurityOverlay] Generating PDF report...');
                    
                    // Show loading
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Generating PDF report...'),
                          backgroundColor: AppColors.primary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    
                    // Generate PDF with current data
                    await _generatePDFReport(session);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PDF report generated successfully!'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    debugPrint('[SecurityOverlay] Error generating PDF: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to generate PDF: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('PDF Report', style: AppTextStyles.labelMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Close button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Close',
                    style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _synthLabel(double score) {
    if (score >= 0.50) return 'AI-generated ⚠';
    if (score >= 0.30) return 'Suspicious';
    return 'Natural ✓';
  }

  String _scamLabel(double score) {
    if (score >= 0.50) return 'Scam detected ⚠';
    if (score >= 0.30) return 'Suspicious';
    return 'Normal ✓';
  }

  String _factcheckLabel(String status) {
    switch (status) {
      case 'CRITICAL': return 'Failed — Scam ⚠';
      case 'SAFE':     return 'Verified ✓';
      case 'VERIFYING':return 'Checking...';
      default:         return status;
    }
  }

  Future<void> _generatePDFReport(SessionController session) async {
    try {
      debugPrint('[SecurityOverlay] Fetching Dossier PDF from backend...');
      
      // Fetch PDF from backend which automatically saves it to local storage
      await session.getDossier();
      
      // Share the PDF
      if (session.lastSavedPdfPath != null) {
        await OfflineDossierService.sharePdf(session.lastSavedPdfPath!, session.callId ?? 'UNKNOWN');
      } else {
        throw Exception("Failed to save dossier locally");
      }
      
    } catch (e) {
      debugPrint('[SecurityOverlay] Error in PDF generation: $e');
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Detail row helper
// ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
        ),
        Text(value,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SecurityPill — compact tap-to-open pill shown on call screen
// ─────────────────────────────────────────────────────────────

class SecurityPill extends StatelessWidget {
  const SecurityPill({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final level   = _evaluate(session);
    final color   = _levelColor(level);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const SecurityOverlayModal(),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_levelIcon(level), color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              '🛡 ${_levelTitle(level)}',
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PhaseGuardHomeCard — shown on Home Screen dashboard
// Gives elderly users a glanceable security status at a glance
// ─────────────────────────────────────────────────────────────

class PhaseGuardHomeCard extends StatelessWidget {
  const PhaseGuardHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final level   = _evaluate(session);
    final color   = _levelColor(level);
    final isActive = session.wsConnected || session.isCallAudioCaptureActive;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const SecurityOverlayModal(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              Colors.black.withValues(alpha: 0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Big icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(_levelIcon(level), color: color, size: 28),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      'PhaseGuard',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live indicator dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.success : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'LIVE' : 'STANDBY',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isActive ? AppColors.success : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _levelTitle(level),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _levelBody(level, session).split('\n').first,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.7), size: 22),
          ],
        ),
      ),
    );
  }
}
