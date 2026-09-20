import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_shader_kit/flutter_shaders.dart';


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
    // HERO smoky animated background
    if (preset == GradientPreset.hero) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CloudShader(
            style: CloudShaderStyle.realistic,
            animate: true,
            animationSpeed: 0.30,
            cloudDensity: 1.15,
            noisiness: 0.20,
            flowSpeed: 0.08,
            cloudHeight: 2.5,
            brightness: 0.50,
            opacity: 0.90,
            skyColor: const Color(0xFF080D18),
            cloudColor: const Color(0xFF73767D),
            child: child,
          ),
        ),
      );
    }

    // Other presets — keep your existing gradients.
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
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFF8621A6),
            Color(0xFF161B26),
          ],
        );

      case GradientPreset.subtle:
        return const LinearGradient(
          colors: [
            Color(0xFF111827),
            Color(0xFF0F172A),
            Color(0xFF080D18),
          ],
        );

      case GradientPreset.card:
        return const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF111827),
          ],
        );

      case GradientPreset.incomingCall:
        return const LinearGradient(
          colors: [
            Color(0xFF312E81),
            Color(0xFF111827),
            Color(0xFF080D18),
          ],
        );

      case GradientPreset.callActive:
        return const LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF7C3AED),
            Color(0xFF111827),
          ],
        );

      case GradientPreset.hero:
        return const LinearGradient(
          colors: [
            Color(0xFF080D18),
            Color(0xFF111827),
          ],
        );

      case GradientPreset.profile:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xCC6C63FF),
            Color(0xFF1E1D2E),
            Color(0xFF0F0E1A),
          ],
          stops: [0.0, 0.5, 1.0],
        );
    }
  }
}



//  GlassmorphicContainer — frosted glass effect


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
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.white.withValues(alpha: 0.6);
    final defaultBorder = Border.all(
        color: Colors.white.withValues(alpha: 0.1), width: 1);

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 8),
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


