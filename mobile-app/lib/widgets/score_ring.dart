import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// An animated circular gauge that fills proportionally to [value] (0..1) and
/// shows a bold [label] (e.g. "85%" or "28/36") in the centre.
class ScoreRing extends StatelessWidget {
  final double value;
  final String label;
  final String? caption;
  final Color color;
  final double size;
  final double strokeWidth;

  /// Spoken description. Defaults to the label and caption, which is what a
  /// sighted user reads off the ring.
  final String? semanticLabel;

  const ScoreRing({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    required this.color,
    this.size = 150,
    this.strokeWidth = 12,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? (caption == null ? label : '$caption: $label'),
      readOnly: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return CustomPaint(
                painter: _RingPainter(
                  value: animatedValue,
                  color: color,
                  strokeWidth: strokeWidth,
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(strokeWidth + 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: size * 0.28,
                              fontWeight: FontWeight.bold,
                              color: color,
                              height: 1.0,
                            ),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              caption!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withAlpha(120), color],
        transform: const GradientRotation(startAngle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
