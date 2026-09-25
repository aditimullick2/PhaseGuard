import 'package:flutter/material.dart';

class PhaseGuardLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final Color glowColor;

  const PhaseGuardLogo({
    super.key,
    this.size = 56.0,
    this.showGlow = false,
    this.glowColor = const Color(0xFF2678FF),
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (showGlow) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.5),
              blurRadius: size * 0.4,
              spreadRadius: 2,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        child: image,
      );
    }

    return image;
  }
}
