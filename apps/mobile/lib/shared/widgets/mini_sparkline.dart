import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A lightweight, high-performance sparkline mini-chart for instrument list tiles
class MiniSparkline extends StatelessWidget {
  final List<double>? points;
  final bool isPositive;
  final bool isFlat;
  final double width;
  final double height;
  final Color? customColor;

  const MiniSparkline({
    super.key,
    this.points,
    required this.isPositive,
    this.isFlat = false,
    this.width = 46.0,
    this.height = 22.0,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = customColor ??
        (isFlat
            ? AppColors.outline
            : isPositive
                ? AppColors.secondary
                : AppColors.tertiary);

    // If points are not provided or have < 2 values, generate an aesthetic micro-trend
    final dataPoints = (points != null && points!.length >= 2)
        ? points!
        : _generateTrendPoints(isPositive, isFlat);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: dataPoints,
          color: color,
        ),
      ),
    );
  }

  static List<double> _generateTrendPoints(bool isPositive, bool isFlat) {
    if (isFlat) {
      return const [10.0, 10.2, 9.8, 10.0, 10.1, 9.9, 10.0];
    }
    if (isPositive) {
      return const [10.0, 10.5, 9.8, 11.2, 11.0, 12.1, 12.5];
    } else {
      return const [12.5, 12.0, 12.2, 11.4, 11.6, 10.8, 10.0];
    }
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter({
    required this.points,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minVal = points.first;
    double maxVal = points.first;
    for (final p in points) {
      if (p < minVal) minVal = p;
      if (p > maxVal) maxVal = p;
    }

    final range = maxVal - minVal;
    final effectiveRange = range == 0 ? 1.0 : range;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);

    // Padding inside sparkline canvas
    const topPad = 2.0;
    const btmPad = 2.0;
    final drawHeight = size.height - topPad - btmPad;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i] - minVal) / effectiveRange;
      final y = size.height - btmPad - (normalizedY * drawHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNormY = (points[i - 1] - minVal) / effectiveRange;
        final prevY = size.height - btmPad - (prevNormY * drawHeight);

        // Smooth cubic bezier curve between points
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Subtle gradient fill under sparkline
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.20),
          color.withOpacity(0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line paint
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}
