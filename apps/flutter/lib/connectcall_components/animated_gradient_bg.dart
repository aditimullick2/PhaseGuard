import 'dart:ui' as ui;
import 'package:flutter/material.dart';


//  AnimatedGradientBg — simulates FbmGradientShaderFill



enum GradientPreset {
  /// Primary hero gradient (indigo → purple on dark)
  hero,

  /// Rich violet-purple-magenta (video call background)
  videoCall,

  /// Subtle indigo wash on dark (home/list background)
  subtle,

  /// Indigo-dark secondary background blend
  card,

  /// Primary with light sweep (incoming call)
  incomingCall,

  /// Full-spectrum vivid (call in progress)
  callActive,

  /// Profile header gradient
  profile,
}

class AnimatedGradientBg extends StatelessWidget {
  final GradientPreset preset;
  final Widget? child;
  final double? height;
  final BorderRadius? borderRadius;

  const AnimatedGradientBg({
    super.key,
    this.preset = GradientPreset.subtle,
    this.child,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Subtle static dark gradient for hero (replacing smoky nebula texture)
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _buildGradient(preset),
      ),
      child: child,
    );
  }

  LinearGradient _buildGradient(GradientPreset preset) {
    switch (preset) {
      case GradientPreset.videoCall:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E1A33),
            Color(0xFF091020),
            Color(0xFF050505),
          ],
        );

      case GradientPreset.subtle:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF080808),
            Color(0xFF050505),
          ],
        );

      case GradientPreset.card:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF15171B),
            Color(0xFF101114),
          ],
        );

      case GradientPreset.incomingCall:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F2248),
            Color(0xFF091224),
            Color(0xFF050505),
          ],
        );

      case GradientPreset.callActive:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E1D3D),
            Color(0xFF081020),
            Color(0xFF050505),
          ],
        );

      case GradientPreset.hero:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1224),
            Color(0xFF080808),
            Color(0xFF050505),
          ],
        );

      case GradientPreset.profile:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x331455D9),
            Color(0xFF101114),
            Color(0xFF050505),
          ],
          stops: [0.0, 0.45, 1.0],
        );
    }
  }
}



//  GlassmorphicContainer — charcoal surface with hairline border


class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;
  final double blurSigma;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.border,
    this.blurSigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = isDark 
        ? const Color(0xFF101114).withValues(alpha: 0.90) 
        : Colors.white.withValues(alpha: 0.9);
    final defaultBorder = Border.all(
        color: Colors.white.withValues(alpha: 0.08), width: 1); // 1px hairline border

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? defaultBgColor,
              border: border ?? defaultBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}


