import 'package:flutter/material.dart';

class AnimatedGifBackground extends StatelessWidget {
  final String assetPath;
  final double overlayOpacity;
  final Widget child;

  const AnimatedGifBackground({
    super.key,
    required this.assetPath,
    this.overlayOpacity = 0.5,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color overlayColor = isDark ? Colors.black : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        IgnorePointer(
          child: Container(
            color: overlayColor.withValues(alpha: overlayOpacity),
          ),
        ),
        child,
      ],
    );
  }
}
