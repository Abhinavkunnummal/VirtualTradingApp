import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';

class OrderConfirmationSheet extends StatelessWidget {
  final String symbol;
  final String exchange;
  final String side;
  final String orderType;
  final String product;
  final int quantity;
  final double price;
  final double? marginUsed;
  final double? fees;
  final double? realizedPnl;
  final double? realizedPnlPercent;
  final bool isExit;
  final bool isPending;

  const OrderConfirmationSheet({
    super.key,
    required this.symbol,
    required this.exchange,
    required this.side,
    required this.orderType,
    required this.product,
    required this.quantity,
    required this.price,
    this.marginUsed,
    this.fees,
    this.realizedPnl,
    this.realizedPnlPercent,
    this.isExit = false,
    this.isPending = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String symbol,
    required String exchange,
    required String side,
    required String orderType,
    required String product,
    required int quantity,
    required double price,
    double? marginUsed,
    double? fees,
    double? realizedPnl,
    double? realizedPnlPercent,
    bool isExit = false,
    bool isPending = false,
  }) async {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderConfirmationSheet(
        symbol: symbol,
        exchange: exchange,
        side: side,
        orderType: orderType,
        product: product,
        quantity: quantity,
        price: price,
        marginUsed: marginUsed,
        fees: fees,
        realizedPnl: realizedPnl,
        realizedPnlPercent: realizedPnlPercent,
        isExit: isExit,
        isPending: isPending,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCrypto = symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => symbol.contains(c));
    final currency = (isCrypto || exchange == 'US') ? '\$' : '₹';
    final isBuy = side.toUpperCase() == 'BUY';
    final pnl = realizedPnl;
    final isProfit = pnl != null && pnl >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status Icon Banner
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isExit
                      ? (isProfit ? AppColors.secondary.withOpacity(0.15) : AppColors.tertiary.withOpacity(0.15))
                      : (isBuy ? AppColors.secondary.withOpacity(0.15) : AppColors.tertiary.withOpacity(0.15)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isExit
                        ? (isProfit ? AppColors.secondary : AppColors.tertiary)
                        : (isBuy ? AppColors.secondary : AppColors.tertiary),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isExit ? (isProfit ? Icons.trending_up : Icons.trending_down) : (isPending ? Icons.hourglass_top : Icons.check_circle_outline),
                  size: 30,
                  color: isExit
                      ? (isProfit ? AppColors.secondary : AppColors.tertiary)
                      : (isBuy ? AppColors.secondary : AppColors.tertiary),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                isExit
                    ? (isProfit ? 'Position Squared Off (Profit Booked! 🎉)' : 'Position Squared Off')
                    : (isPending ? 'Pending Order Placed' : 'Order Executed Successfully'),
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isExit
                      ? (isProfit ? AppColors.secondary : AppColors.tertiary)
                      : AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                '$side $quantity share(s) of $symbol on $exchange',
                style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Booked Realized P&L Card (for exits)
              if (isExit && pnl != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isProfit ? AppColors.secondary : AppColors.tertiary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isProfit ? AppColors.secondary : AppColors.tertiary).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Realized Profit / Loss', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                          const SizedBox(height: 2),
                          Text(
                            '${isProfit ? '+' : ''}$currency${pnl.toStringAsFixed(2)}',
                            style: AppTypography.headlineSm.copyWith(
                              color: isProfit ? AppColors.secondary : AppColors.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      if (realizedPnlPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isProfit ? AppColors.secondary : AppColors.tertiary).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${realizedPnlPercent!.toStringAsFixed(2)}%',
                            style: AppTypography.labelSm.copyWith(
                              color: isProfit ? AppColors.secondary : AppColors.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Order Details Table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildRow('Side', side, color: isBuy ? AppColors.secondary : AppColors.tertiary),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _buildRow('Order Type', orderType),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _buildRow('Product', product == 'MIS' ? 'Intraday (MIS 5x)' : 'Delivery (CNC)'),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _buildRow('Quantity', '$quantity shares'),
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    _buildRow('Execution Price', '$currency${price.toStringAsFixed(2)}'),
                    if (marginUsed != null) ...[
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _buildRow(isExit ? 'Proceeds Credited' : 'Margin Used', '$currency${marginUsed!.toStringAsFixed(2)}'),
                    ],
                    if (fees != null && fees! > 0) ...[
                      const Divider(color: AppColors.borderSubtle, height: 16),
                      _buildRow('Brokerage & Taxes', '$currency${fees!.toStringAsFixed(2)}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurface,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/orders');
                      },
                      child: const Text('View in Orders'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
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

  Widget _buildRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
        Text(
          value,
          style: AppTypography.labelSm.copyWith(
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
