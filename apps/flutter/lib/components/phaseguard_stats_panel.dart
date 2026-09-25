import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session_controller.dart';
import 'app_theme.dart';
import 'animated_gradient_bg.dart';

class PhaseGuardStatsPanel extends StatelessWidget {
  const PhaseGuardStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // We assume SessionController is provided up the tree via Provider
    final session = context.watch<SessionController>();
    
    // Level 1: Scam Text Analysis
    final pdiScore = session.pdiScore;
    final isScam = session.pdiScore >= 0.70;
    
    // Level 2: Deepfake Analysis
    final synthScore = session.syntheticVoiceScore;
    final isSynth = session.syntheticVoiceScore >= 0.70;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'PhaseGuard Active',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary, blurRadius: 4, spreadRadius: 1)
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Level 1: Text
          _buildStatRow(
            'Scam Text (L1)',
            pdiScore,
            isScam ? AppColors.error : AppColors.success,
            isScam ? Icons.warning_rounded : Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 12),
          
          // Level 2: Audio
          _buildStatRow(
            'Deepfake Audio (L2)',
            synthScore,
            isSynth ? AppColors.error : AppColors.success,
            isSynth ? Icons.record_voice_over_rounded : Icons.mic_none_rounded,
          ),

          if (session.liveTranscript.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Text(
              '"${session.liveTranscript}"',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondaryText, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, double score, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score,
                  backgroundColor: Colors.white12,
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${(score * 100).toInt()}%',
          style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
