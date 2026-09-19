import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Signature Radial / Speedometer Gauge for PhaseGuard metrics (e.g. PDI Score).
/// Features a 240-degree calibrated sweep arc, animated needle/progress track,
/// multi-stop gradient (Green -> Amber -> Red), central score readout, and risk badge.
class PgRadialGauge extends StatefulWidget {
  final double value; // 0.0 to 1.0 (e.g. 0.84)
  final double size;
  final String title;
  final String? subtitle;
  final bool showTicks;
  final Duration animationDuration;
  final Color? customColor;

  const PgRadialGauge({
    super.key,
    required this.value,
    this.size = 190.0,
    this.title = 'PDI SCORE',
    this.subtitle,
    this.showTicks = true,
    this.animationDuration = const Duration(milliseconds: 1400),
    this.customColor,
  });

  @override
  State<PgRadialGauge> createState() => _PgRadialGaugeState();
}

class _PgRadialGaugeState extends State<PgRadialGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PgRadialGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _animation.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForValue(double val) {
    if (widget.customColor != null) return widget.customColor!;
    if (val >= 0.70) return PgColors.scam;
    if (val >= 0.40) return PgColors.suspicious;
    return PgColors.safe;
  }

  String _getRiskLabel(double val) {
    if (val >= 0.70) return 'CRITICAL THREAT';
    if (val >= 0.40) return 'SUSPICIOUS';
    return 'VERIFIED SAFE';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentVal = _animation.value;
        final color = _getColorForValue(currentVal);
        final scoreText = (currentVal * 100).toInt().toString();

        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Custom painted speedometer arc and glow
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SpeedometerPainter(
                  progress: currentVal,
                  color: color,
                  showTicks: widget.showTicks,
                ),
              ),

              // 2. Central data readout
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                      color: PgColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scoreText,
                        style: TextStyle(
                          fontSize: widget.size * 0.24,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: -1.0,
                          height: 1.05,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: widget.size * 0.09,
                          fontWeight: FontWeight.bold,
                          color: color.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Risk pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
                      borderRadius: BorderRadius.circular(PgRadii.pill),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.subtitle ?? _getRiskLabel(currentVal),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final bool showTicks;

  _SpeedometerPainter({
    required this.progress,
    required this.color,
    required this.showTicks,
  });

  // 240-degree arc from 150° (bottom-left) to 390° (bottom-right)
  static const double startAngle = 150.0 * (math.pi / 180.0);
  static const double sweepAngle = 240.0 * (math.pi / 180.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    final strokeWidth = size.width * 0.065;

    // 1. Subtle background ambient glow behind active arc
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress.clamp(0.01, 1.0),
      false,
      glowPaint,
    );

    // 2. Inactive Track (Dark navy/slate with border aesthetic)
    final trackPaint = Paint()
      ..color = PgColors.bgElevated.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 3. Calibrated tick marks around the gauge
    if (showTicks) {
      final tickPaint = Paint()
        ..color = PgColors.textMuted.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;

      final majorTickPaint = Paint()
        ..color = PgColors.textSecondary.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      const int totalTicks = 24;
      for (int i = 0; i <= totalTicks; i++) {
        final tickFraction = i / totalTicks;
        final tickAngle = startAngle + (sweepAngle * tickFraction);
        final isMajor = i % 6 == 0;

        final innerOffset = isMajor ? 14.0 : 8.0;
        final p1 = Offset(
          center.dx + (radius - strokeWidth / 2 - 4) * math.cos(tickAngle),
          center.dy + (radius - strokeWidth / 2 - 4) * math.sin(tickAngle),
        );
        final p2 = Offset(
          center.dx + (radius - strokeWidth / 2 - innerOffset) * math.cos(tickAngle),
          center.dy + (radius - strokeWidth / 2 - innerOffset) * math.sin(tickAngle),
        );
        canvas.drawLine(p1, p2, isMajor ? majorTickPaint : tickPaint);
      }
    }

    // 4. Active Progress Arc with multi-stop cyber gradient
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        PgColors.safe,
        PgColors.suspicious,
        PgColors.scam,
      ],
      stops: const [0.0, 0.45, 0.85],
    );

    final activePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (progress > 0.005) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress.clamp(0.0, 1.0),
        false,
        activePaint,
      );
    }

    // 5. Glowing indicator bead at current progress tip
    if (progress > 0.02) {
      final tipAngle = startAngle + (sweepAngle * progress);
      final tipCenter = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );

      final tipGlow = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(tipCenter, strokeWidth * 0.7, tipGlow);

      final tipBead = Paint()..color = Colors.white;
      canvas.drawCircle(tipCenter, strokeWidth * 0.4, tipBead);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Rich Acoustic Meter for Synthetic Voice Detection (e.g. 78%)
/// Combines a horizontal dynamic meter with acoustic frequency wavebars and status.
class PgAcousticMeter extends StatefulWidget {
  final double value; // 0.0 to 1.0 (e.g. 0.78)
  final String label;
  final bool isSynthetic;

  const PgAcousticMeter({
    super.key,
    required this.value,
    this.label = 'SYNTHETIC VOICE',
    this.isSynthetic = true,
  });

  @override
  State<PgAcousticMeter> createState() => _PgAcousticMeterState();
}

class _PgAcousticMeterState extends State<PgAcousticMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.value >= 0.70
        ? PgColors.scam
        : widget.value >= 0.40
            ? PgColors.suspicious
            : PgColors.safe;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final curVal = _animation.value;
        final score = (curVal * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(PgSpace.md),
          decoration: BoxDecoration(
            color: PgColors.bgSecondary.withValues(alpha: 0.9),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(PgRadii.card),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isSynthetic ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: PgColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(PgRadii.pill),
                    ),
                    child: Text(
                      widget.isSynthetic ? 'CLONE DETECTED' : 'NATURAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '% probability',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PgColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Segmented acoustic bar
              LayoutBuilder(
                builder: (context, constraints) {
                  const int totalSegments = 20;
                  final activeSegments = (totalSegments * curVal).round();

                  return Row(
                    children: List.generate(totalSegments, (idx) {
                      final isActive = idx < activeSegments;
                      final segFraction = idx / totalSegments;
                      final segColor = segFraction >= 0.70
                          ? PgColors.scam
                          : segFraction >= 0.40
                              ? PgColors.suspicious
                              : PgColors.safe;

                      return Expanded(
                        child: Container(
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? segColor
                                : PgColors.bgElevated.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: segColor.withValues(alpha: 0.4),
                                      blurRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
