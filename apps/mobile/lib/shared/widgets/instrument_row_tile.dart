import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'mini_sparkline.dart';
import 'instrument_price_column.dart';

/// Standard financial instrument row tile used across Markets, Search, and Watchlist
class InstrumentRowTile extends StatelessWidget {
  final String symbol;
  final String name;
  final String exchange;
  final String category;
  final double price;
  final double change;
  final double changePercent;
  final int lotSize;
  final double tickSize;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onTradeTap;
  final bool showSparkline;
  final bool showTradeButton;
  final Key? tradeButtonKey;

  const InstrumentRowTile({
    super.key,
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.category,
    required this.price,
    required this.change,
    required this.changePercent,
    this.lotSize = 1,
    this.tickSize = 0.05,
    this.currency = '₹',
    required this.onTap,
    this.onTradeTap,
    this.showSparkline = true,
    this.showTradeButton = true,
    this.tradeButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final isCrypto = category == 'CRYPTO' || exchange == 'CRYPTO' || symbol.contains('/');
    final isPos = change > 0.0001;
    final isNeg = change < -0.0001;
    final isFlat = !isPos && !isNeg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Section: Symbol, Exchange badge, Category badge, Name, Lot info
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          symbol,
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exchange,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              color: AppColors.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (category == 'ETF')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBrand.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ETF',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 8,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (category == 'IPO')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'IPO',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 8,
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: AppTypography.bodyMd.copyWith(
                        fontSize: 11,
                        color: AppColors.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Lot: $lotSize',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            color: AppColors.outline,
                          ),
                        ),
                        Text(
                          '•',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            color: AppColors.outline,
                          ),
                        ),
                        Text(
                          'Tick: $currency$tickSize',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Middle Section: Sparkline Mini-Chart (if enabled)
              if (showSparkline) ...[
                const SizedBox(width: 4),
                Flexible(
                  flex: 2,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MiniSparkline(
                        isPositive: isPos,
                        isFlat: isFlat,
                        width: 36.0,
                        height: 18.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 6),

              // Right Section: Strictly Right-Aligned Financial Price Column & Trade Action
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 70.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InstrumentPriceColumn(
                      price: price,
                      change: change,
                      changePercent: changePercent,
                      currency: currency,
                      isCrypto: isCrypto,
                      minWidth: 70.0,
                    ),
                    if (showTradeButton && onTradeTap != null) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        key: tradeButtonKey ?? ValueKey('trade_btn_$symbol'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onTradeTap!();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBrand.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primaryBrand.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz, size: 11, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                'TRADE',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
