import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Multi-ring expanding ripple aura that pulses around an active center (e.g. Shield).
class PulsingRing extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final double maxRadius;
  final int ringCount;
  final Duration duration;

  const PulsingRing({
    super.key,
    required this.child,
    this.pulseColor = PgColors.safe,
    this.maxRadius = 38.0,
    this.ringCount = 3,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PulsingRingPainter(
            animationValue: _controller.value,
            color: widget.pulseColor,
            maxRadius: widget.maxRadius,
            ringCount: widget.ringCount,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _PulsingRingPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double maxRadius;
  final int ringCount;

  _PulsingRingPainter({
    required this.animationValue,
    required this.color,
    required this.maxRadius,
    required this.ringCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2;

    for (int i = 0; i < ringCount; i++) {
      // Stagger each ring's progress
      final ringProgress = (animationValue + (i / ringCount)) % 1.0;
      final ringRadius = baseRadius + (maxRadius - baseRadius) * ringProgress;
      // Fade out as it expands
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.45;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 * (1.0 - ringProgress)).clamp(0.8, 2.2);

      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsingRingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Live oscillating audio waveform widget driven by an AnimationController.
/// Mimics real-time DSP spectrum analyzer activity during active voice analysis.
class LiveWaveform extends StatefulWidget {
  final int barCount;
  final double height;
  final Color activeColor;
  final Color baseColor;
  final bool isAnalyzing;

  const LiveWaveform({
    super.key,
    this.barCount = 28,
    this.height = 48.0,
    this.activeColor = PgColors.accent,
    this.baseColor = PgColors.waveformInactive,
    this.isAnalyzing = true,
  });

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isAnalyzing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LiveWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnalyzing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnalyzing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _WaveformPainter(
              progress: _controller.value,
              barCount: widget.barCount,
              activeColor: widget.activeColor,
              baseColor: widget.baseColor,
              isAnalyzing: widget.isAnalyzing,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final int barCount;
  final Color activeColor;
  final Color baseColor;
  final bool isAnalyzing;

  _WaveformPainter({
    required this.progress,
    required this.barCount,
    required this.activeColor,
    required this.baseColor,
    required this.isAnalyzing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width / (barCount * 1.6)).clamp(2.5, 6.0);
    final totalSpacing = size.width - (barCount * barWidth);
    final gap = totalSpacing / (barCount - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      
      // Generate fluid harmonic height curve
      double heightFactor;
      if (isAnalyzing) {
        // Multi-frequency wave formula
        final t = progress * 2 * math.pi;
        final wave1 = math.sin(t + (i * 0.45));
        final wave2 = math.cos(t * 1.5 - (i * 0.25));
        final envelope = math.sin((i / (barCount - 1)) * math.pi); // bell curve taper at edges
        heightFactor = (0.2 + (0.4 * (wave1.abs())) + (0.4 * (wave2.abs()))) * envelope;
        heightFactor = heightFactor.clamp(0.12, 1.0);
      } else {
        heightFactor = 0.15;
      }

      final barH = size.height * heightFactor;
      final top = centerY - barH / 2;
      final bottom = centerY + barH / 2;

      // Color gradient or glow for higher energy bars
      final isHighEnergy = heightFactor > 0.65;
      final paint = Paint()
        ..color = isAnalyzing
            ? (isHighEnergy ? activeColor : activeColor.withValues(alpha: 0.65))
            : baseColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isAnalyzing != isAnalyzing;
  }
}

/// Subtle vector shield watermark with faint cyber grid lines and soft ambient gradient.
/// Eliminates flat empty spacing while keeping the interface feeling high-tech and uncluttered.
class CyberShieldWatermark extends StatelessWidget {
  final double size;
  final double opacity;

  const CyberShieldWatermark({
    super.key,
    this.size = 280.0,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size(size, size * 1.15),
          painter: _CyberShieldWatermarkPainter(),
        ),
      ),
    );
  }
}

class _CyberShieldWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final linePaint = Paint()
      ..color = PgColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Outer shield silhouette
    final path = Path()
      ..moveTo(w / 2, 8)
      ..lineTo(w - 12, h * 0.18)
      ..lineTo(w - 12, h * 0.58)
      ..quadraticBezierTo(w - 12, h * 0.88, w / 2, h - 8)
      ..quadraticBezierTo(12, h * 0.88, 12, h * 0.58)
      ..lineTo(12, h * 0.18)
      ..close();

    canvas.drawPath(path, linePaint);

    // Inner nested shield
    final innerPath = Path()
      ..moveTo(w / 2, 28)
      ..lineTo(w - 32, h * 0.22)
      ..lineTo(w - 32, h * 0.55)
      ..quadraticBezierTo(w - 32, h * 0.82, w / 2, h - 28)
      ..quadraticBezierTo(32, h * 0.82, 32, h * 0.55)
      ..lineTo(32, h * 0.22)
      ..close();

    canvas.drawPath(innerPath, linePaint..strokeWidth = 0.8);

    // Subtle concentric radar rings inside shield
    canvas.drawCircle(center, w * 0.22, linePaint..strokeWidth = 0.6);
    canvas.drawCircle(center, w * 0.36, linePaint..strokeWidth = 0.4);

    // Subtle crosshairs
    canvas.drawLine(Offset(center.dx, 16), Offset(center.dx, h - 16), linePaint..strokeWidth = 0.5);
    canvas.drawLine(Offset(20, center.dy), Offset(w - 20, center.dy), linePaint..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(covariant _CyberShieldWatermarkPainter oldDelegate) => false;
}
