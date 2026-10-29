import 'package:flutter/material.dart';

import '../models/zodiac.dart';
import '../theme/app_theme.dart';

/// Maps a deterministic day-score to its band colour, shared by the forecast
/// chart and the score-band chip so the palette stays consistent.
Color forecastScoreColor(int score) {
  if (score >= 85) return const Color(0xFF00BFA5); // Excellent
  if (score >= 72) return const Color(0xFF00BCD4); // Favorable
  if (score >= 62) return const Color(0xFFFFD700); // Steady
  if (score >= 52) return const Color(0xFFFF9800); // Mixed
  return const Color(0xFFFF5252); // Challenging
}

/// A custom-painted energy forecast line chart.
///
/// In [compact] mode it renders a small sparkline (for the daily card);
/// otherwise a full chart with gridlines, band-coloured points and an optional
/// best-day marker (for the detail screen). No third-party charting package —
/// consistent with the app's other hand-painted gauges.
class EnergyForecastChart extends StatelessWidget {
  final List<ForecastPoint> points;
  final bool compact;
  final ForecastPoint? bestDay;

  const EnergyForecastChart({
    super.key,
    required this.points,
    this.compact = false,
    this.bestDay,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final duration = Duration(milliseconds: compact ? 650 : 900);
    return Semantics(
      label: _describe(),
      readOnly: true,
      child: SizedBox(
        height: compact ? 44 : 180,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _ForecastPainter(
              points: points,
              progress: t,
              compact: compact,
              bestDate: bestDay?.date,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  /// Textual equivalent of the line: without it a screen-reader user gets
  /// nothing at all from one of the product's headline outputs.
  String _describe() {
    final first = points.first;
    final buffer = StringBuffer(
      'Energy forecast over ${points.length} days. '
      'Today ${first.score}, ${first.band.toLowerCase()}.',
    );
    final best = bestDay;
    if (best != null) {
      buffer.write(
        ' Best day ${best.date.day}/${best.date.month} at ${best.score}.',
      );
    }
    return buffer.toString();
  }
}

class _ForecastPainter extends CustomPainter {
  final List<ForecastPoint> points;
  final double progress;
  final bool compact;
  final DateTime? bestDate;

  static const double _minY = 40;
  static const double _maxY = 100;
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  _ForecastPainter({
    required this.points,
    required this.progress,
    required this.compact,
    this.bestDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = points.length;
    if (n < 2) return;

    final double leftPad = compact ? 0 : 26;
    final double rightPad = compact ? 2 : 6;
    final double topPad = compact ? 4 : 8;
    final double bottomPad = compact ? 4 : 18;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final baseline = topPad + chartH;

    double xAt(int i) => leftPad + chartW * (i / (n - 1));
    double yAt(num score) {
      final clamped = score.clamp(_minY, _maxY).toDouble();
      return topPad + chartH * (1 - (clamped - _minY) / (_maxY - _minY));
    }

    // Gridlines + y labels (full chart only).
    if (!compact) {
      final gridPaint = Paint()
        ..color = AppColors.textMuted.withAlpha(28)
        ..strokeWidth = 1;
      final tp = TextPainter(textDirection: TextDirection.ltr);
      for (final g in const [50, 60, 70, 80, 90]) {
        final y = yAt(g);
        canvas.drawLine(
          Offset(leftPad, y),
          Offset(size.width - rightPad, y),
          gridPaint,
        );
        tp.text = TextSpan(
          text: '$g',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
        );
        tp.layout();
        tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
      }
    }

    final revealX = leftPad + chartW * progress;

    // Line path.
    final linePath = Path();
    for (var i = 0; i < n; i++) {
      final x = xAt(i);
      final y = yAt(points[i].score);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    // Reveal the line + fill left-to-right.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, revealX + 1.5, size.height));

    final fillPath = Path.from(linePath)
      ..lineTo(xAt(n - 1), baseline)
      ..lineTo(xAt(0), baseline)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withAlpha(compact ? 64 : 48),
          AppColors.accent.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2 : 2.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
    canvas.restore();

    if (compact) {
      // A single dot at the latest revealed point.
      final x = xAt(n - 1);
      if (x <= revealX + 0.5) {
        canvas.drawCircle(
          Offset(x, yAt(points[n - 1].score)),
          3,
          Paint()..color = AppColors.accent,
        );
      }
      return;
    }

    // Band-coloured dots, revealed with the line.
    for (var i = 0; i < n; i++) {
      final x = xAt(i);
      if (x > revealX + 0.5) break;
      canvas.drawCircle(
        Offset(x, yAt(points[i].score)),
        2.4,
        Paint()..color = forecastScoreColor(points[i].score),
      );
    }

    // Best-day marker.
    if (bestDate != null) {
      final bi = points.indexWhere(
        (p) =>
            p.date.year == bestDate!.year &&
            p.date.month == bestDate!.month &&
            p.date.day == bestDate!.day,
      );
      if (bi >= 0 && xAt(bi) <= revealX + 0.5) {
        final c = Offset(xAt(bi), yAt(points[bi].score));
        canvas.drawCircle(
          c,
          5,
          Paint()
            ..color = AppColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(c, 2.4, Paint()..color = AppColors.accent);
      }
    }

    // X labels: Today, midpoint, and the last day.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final labels = <int, String>{
      0: 'Today',
      n - 1: _shortDate(points[n - 1].date),
    };
    if (n > 6) labels[n ~/ 2] = _shortDate(points[n ~/ 2].date);
    labels.forEach((i, text) {
      tp.text = TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
      );
      tp.layout();
      var dx = xAt(i) - tp.width / 2;
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - tp.height));
    });
  }

  static String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  bool shouldRepaint(_ForecastPainter old) =>
      old.progress != progress ||
      old.points != points ||
      old.bestDate != bestDate;
}
