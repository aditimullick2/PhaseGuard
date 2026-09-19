import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Reusable animated background widget that displays the assets GIF
/// with an elegant dark overlay for optimal cyber-defense aesthetic and readability.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    this.child,
    this.overlayOpacity = 0.72,
  });

  final Widget? child;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background Animated GIF
        Image.asset(
          PgAssets.backgroundGif,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              PgAssets.backgroundGifOriginal,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, st) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: PgColors.screenGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            );
          },
        ),

        // 2. High-tech subtle dark vignette / gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PgColors.bgPrimary.withValues(alpha: (overlayOpacity * 0.8).clamp(0.0, 1.0)),
                PgColors.bgPrimary.withValues(alpha: overlayOpacity.clamp(0.0, 1.0)),
                PgColors.bgPrimary.withValues(alpha: (overlayOpacity * 1.15).clamp(0.0, 1.0)),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // 3. Subtle ambient cyan glow to blend with PhaseGuard theme
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.4),
              radius: 1.2,
              colors: [
                PgColors.accentGlow.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // 4. Content layer
        ?child,
      ],
    );
  }
}
