import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Cohesive, custom-stroked icon set designed specifically for PhaseGuard.
/// Standardized on 2.0dp stroke width, rounded caps, and consistent radii.
enum PgIconType {
  scanner,   // Live Verify
  equalizer, // Voice Analysis
  cyberbot,  // Scambaiter
  auditClock // Call History
}

class PgCustomIcon extends StatelessWidget {
  final PgIconType type;
  final double size;
  final Color color;
  final double strokeWidth;

  const PgCustomIcon({
    super.key,
    required this.type,
    this.size = 28.0,
    this.color = PgColors.accent,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _PgIconPainter(
          type: type,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _PgIconPainter extends CustomPainter {
  final PgIconType type;
  final Color color;
  final double strokeWidth;

  _PgIconPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (type) {
      case PgIconType.scanner:
        // Live Verify: Cyber precision target reticle with center aperture
        final center = Offset(w / 2, h / 2);
        // Outer curved corner brackets
        final bracketLen = w * 0.22;
        final pad = w * 0.08;

        // Top-left bracket
        final pathTL = Path()
          ..moveTo(pad, pad + bracketLen)
          ..lineTo(pad, pad + 4)
          ..quadraticBezierTo(pad, pad, pad + 4, pad)
          ..lineTo(pad + bracketLen, pad);
        canvas.drawPath(pathTL, paint);

        // Top-right bracket
        final pathTR = Path()
          ..moveTo(w - pad - bracketLen, pad)
          ..lineTo(w - pad - 4, pad)
          ..quadraticBezierTo(w - pad, pad, w - pad, pad + 4)
          ..lineTo(w - pad, pad + bracketLen);
        canvas.drawPath(pathTR, paint);

        // Bottom-left bracket
        final pathBL = Path()
          ..moveTo(pad, h - pad - bracketLen)
          ..lineTo(pad, h - pad - 4)
          ..quadraticBezierTo(pad, h - pad, pad + 4, h - pad)
          ..lineTo(pad + bracketLen, h - pad);
        canvas.drawPath(pathBL, paint);

        // Bottom-right bracket
        final pathBR = Path()
          ..moveTo(w - pad - bracketLen, h - pad)
          ..lineTo(w - pad - 4, h - pad)
          ..quadraticBezierTo(w - pad, h - pad, w - pad, h - pad - 4)
          ..lineTo(w - pad, h - pad - bracketLen);
        canvas.drawPath(pathBR, paint);

        // Center target circle & crosshairs
        final r = w * 0.22;
        canvas.drawCircle(center, r, paint);
        canvas.drawCircle(center, r, fillPaint);
        canvas.drawCircle(center, 2.0, Paint()..color = color..style = PaintingStyle.fill);

        // Micro crosshair ticks
        canvas.drawLine(Offset(center.dx - r - 3, center.dy), Offset(center.dx - r + 3, center.dy), paint);
        canvas.drawLine(Offset(center.dx + r - 3, center.dy), Offset(center.dx + r + 3, center.dy), paint);
        canvas.drawLine(Offset(center.dx, center.dy - r - 3), Offset(center.dx, center.dy - r + 3), paint);
        canvas.drawLine(Offset(center.dx, center.dy + r - 3), Offset(center.dx, center.dy + r + 3), paint);
        break;

      case PgIconType.equalizer:
        // Voice Analysis: Symmetrical calibrated frequency bars with rounded ends
        const int barCount = 5;
        final barHeights = [0.45, 0.75, 1.0, 0.65, 0.40];
        final spacing = w / (barCount + 1);
        final maxH = h * 0.72;
        final centerY = h / 2;

        for (int i = 0; i < barCount; i++) {
          final x = spacing * (i + 1);
          final barH = maxH * barHeights[i];
          canvas.drawLine(
            Offset(x, centerY - barH / 2),
            Offset(x, centerY + barH / 2),
            paint..strokeWidth = strokeWidth * 1.1,
          );
        }

        // Horizontal baseline reference ticks
        final basePaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.12, h * 0.90), Offset(w * 0.88, h * 0.90), basePaint);
        break;

      case PgIconType.cyberbot:
        // Scambaiter: Sleek AI autonomous agent shield visor
        final pad = w * 0.12;
        // Head / Shield outline
        final shieldPath = Path()
          ..moveTo(w / 2, pad)
          ..lineTo(w - pad, pad + h * 0.15)
          ..lineTo(w - pad, pad + h * 0.45)
          ..quadraticBezierTo(w - pad, h - pad, w / 2, h - pad + 2)
          ..quadraticBezierTo(pad, h - pad, pad, pad + h * 0.45)
          ..lineTo(pad, pad + h * 0.15)
          ..close();
        canvas.drawPath(shieldPath, paint);
        canvas.drawPath(shieldPath, fillPaint);

        // Cyber visor slot
        final visorY = h * 0.42;
        final visorPath = Path()
          ..moveTo(pad + w * 0.14, visorY)
          ..lineTo(w - pad - w * 0.14, visorY);
        canvas.drawPath(visorPath, paint);

        // Visor glow dot in center
        canvas.drawCircle(Offset(w / 2, visorY), 2.2, Paint()..color = color..style = PaintingStyle.fill);

        // Antennas / neural node ticks on top
        canvas.drawLine(Offset(w / 2, pad), Offset(w / 2, pad - 3), paint);
        break;

      case PgIconType.auditClock:
        // Call History: Chronological shield audit clock
        final center = Offset(w / 2, h / 2);
        final r = w * 0.38;

        // Outer clock dial
        canvas.drawCircle(center, r, paint);
        canvas.drawCircle(center, r, fillPaint);

        // Clock hands (pointing to 10:10 cyber audit stance)
        final hourEnd = Offset(
          center.dx + (r * 0.45) * math.cos(-120 * math.pi / 180),
          center.dy + (r * 0.45) * math.sin(-120 * math.pi / 180),
        );
        final minEnd = Offset(
          center.dx + (r * 0.68) * math.cos(35 * math.pi / 180),
          center.dy + (r * 0.68) * math.sin(35 * math.pi / 180),
        );

        canvas.drawLine(center, hourEnd, paint);
        canvas.drawLine(center, minEnd, paint);
        canvas.drawCircle(center, 2.0, Paint()..color = color..style = PaintingStyle.fill);

        // Counter-clockwise history back-tick arrow arc
        final arrowPaint = Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r + 3),
          -160 * math.pi / 180,
          80 * math.pi / 180,
          false,
          arrowPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PgIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// A designed, premium Quick Action Card with tactile feedback,
/// consistent stroke icon, brand cyan styling, and subtle hover/press glow.
class PgActionCard extends StatefulWidget {
  final String label;
  final String description;
  final PgIconType iconType;
  final VoidCallback onTap;
  final Color accentColor;

  const PgActionCard({
    super.key,
    required this.label,
    required this.description,
    required this.iconType,
    required this.onTap,
    this.accentColor = PgColors.accent,
  });

  @override
  State<PgActionCard> createState() => _PgActionCardState();
}

class _PgActionCardState extends State<PgActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(PgSpace.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PgColors.bgSecondary.withValues(alpha: 0.92),
                Color(0xFF142032).withValues(alpha: 0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: _isPressed ? 0.6 : 0.25),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(PgRadii.card),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: _isPressed ? 0.15 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Badge container
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: PgCustomIcon(
                      type: widget.iconType,
                      size: 24,
                      color: widget.accentColor,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: PgColors.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PgColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: PgColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
