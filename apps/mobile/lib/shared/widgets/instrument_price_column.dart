import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A strictly right-aligned, monospace tabular financial price and percentage column
class InstrumentPriceColumn extends StatelessWidget {
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final bool isCrypto;
  final double? minWidth;
  final bool showChangeNominal;

  const InstrumentPriceColumn({
    super.key,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency = '₹',
    this.isCrypto = false,
    this.minWidth = 78.0,
    this.showChangeNominal = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPos = change > 0.0001;
    final isNeg = change < -0.0001;
    final isFlat = !isPos && !isNeg;

    // Strict color assignment: Green for positive, Red for negative, subtle grey for flat
    final Color changeColor = isFlat
        ? AppColors.outline
        : (isPos ? AppColors.secondary : AppColors.tertiary);

    // Consistent formatting: 4 decimals for sub-$1 crypto, 2 decimals for all others
    final bool use4Decimals = isCrypto && price > 0 && price < 1.0;
    final String priceStr = '$currency${price.toStringAsFixed(use4Decimals ? 4 : 2)}';

    // Format change and change percent
    final String sign = isPos ? '+' : (isNeg ? '-' : '');
    final String changeNominalStr = '$sign$currency${change.abs().toStringAsFixed(2)}';
    final String changePercentStr = '$sign${changePercent.abs().toStringAsFixed(2)}%';

    final String secondaryLine = showChangeNominal
        ? '$changeNominalStr ($changePercentStr)'
        : changePercentStr;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth ?? 78.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Primary Price: Tabular figures, right-aligned
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              priceStr,
              textAlign: TextAlign.right,
              style: AppTypography.numericTable.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Secondary Change % / Nominal: Tabular figures, right-aligned
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              secondaryLine,
              textAlign: TextAlign.right,
              style: AppTypography.numericTable.copyWith(
                color: changeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
