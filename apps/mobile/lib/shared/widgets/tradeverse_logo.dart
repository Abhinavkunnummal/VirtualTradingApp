import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class TradeVerseLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDarkBackground;

  const TradeVerseLogo({
    super.key,
    this.size = 40,
    this.showText = false,
    this.isDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF101419),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
            blurRadius: size * 0.3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _TradeVerseLogoPainter(),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        SizedBox(width: size * 0.28),
        Text(
          'TradeVerse',
          style: AppTypography.headlineSm.copyWith(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: size * 0.16,
            vertical: size * 0.05,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
            ),
            borderRadius: BorderRadius.circular(size * 0.12),
          ),
          child: Text(
            'AI',
            style: AppTypography.labelSm.copyWith(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeVerseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Violet accent paint
    final violetPaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.fill;

    // Cyan accent paint
    final cyanPaint = Paint()
      ..color = const Color(0xFF00F5D4)
      ..style = PaintingStyle.fill;

    // Wick paint
    final wickPaint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.7)
      ..strokeWidth = w * 0.04
      ..style = PaintingStyle.stroke;

    // 1. Horizontal crossbar of 'T' (representing resistance/breakout level)
    final crossBarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.22, w * 0.60, h * 0.13),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(crossBarRect, violetPaint);

    // 2. Central vertical stem of 'T' formed by primary candlestick bar
    // Upper wick
    canvas.drawLine(
      Offset(w * 0.50, h * 0.35),
      Offset(w * 0.50, h * 0.40),
      wickPaint,
    );
    // Candle body
    final stemBarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.43, h * 0.40, w * 0.14, h * 0.36),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(stemBarRect, violetPaint);
    // Lower wick
    canvas.drawLine(
      Offset(w * 0.50, h * 0.76),
      Offset(w * 0.50, h * 0.82),
      wickPaint,
    );

    // 3. Upward geometric signal accent bar (Bullish breakout in neon cyan)
    final signalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.64, h * 0.44, w * 0.12, h * 0.24),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(signalRect, cyanPaint);

    // Cyan wick
    final cyanWickPaint = Paint()
      ..color = const Color(0xFF00F5D4)
      ..strokeWidth = w * 0.04
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.70, h * 0.38),
      Offset(w * 0.70, h * 0.72),
      cyanWickPaint,
    );

    // 4. Left foundation support candle bar
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.54, w * 0.11, h * 0.20),
      Radius.circular(w * 0.03),
    );
    final mutedViolet = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(leftRect, mutedViolet);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
