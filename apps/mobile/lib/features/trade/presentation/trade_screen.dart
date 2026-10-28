import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  bool _isBuy = true;
  String _product = 'CNC'; // CNC (Delivery) or MIS (Intraday)
  String _orderType = 'MARKET'; // MARKET, LIMIT, SL, SL_M
  int _quantity = 10;
  double _price = 2945.50;
  final double _ltp = 2945.50;
  final double _availableMargin = 425000.00;

  double get _requiredMargin {
    final raw = _quantity * (_orderType == 'MARKET' ? _ltp : _price);
    return _product == 'MIS' ? raw / 5 : raw; // 5x leverage for MIS
  }

  double get _brokerage => 20.00;
  double get _taxes => _requiredMargin * 0.001; // ~0.1% simulated taxes

  void _executeOrder() {
    final total = _requiredMargin + _brokerage + _taxes;
    if (total > _availableMargin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.errorContainer,
          content: Text('Order rejected: Insufficient virtual margin in Sandbox account.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Row(
          children: [
            Icon(
              _isBuy ? Icons.check_circle : Icons.remove_circle,
              color: _isBuy ? AppColors.secondary : AppColors.tertiary,
            ),
            const SizedBox(width: 8),
            Text('Order Executed', style: AppTypography.headlineSm),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_isBuy ? 'BUY' : 'SELL'} $_quantity Shares of RELIANCE ($_product)',
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Execution Price: ₹$_ltp', style: AppTypography.numericTable),
            Text('Order Type: $_orderType', style: AppTypography.bodyMd),
            Text('Brokerage: ₹${_brokerage.toStringAsFixed(2)} (Simulated)', style: AppTypography.bodyMd),
            Text('Estimated Net Cost: ₹${total.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Simulated order settled in virtual portfolio. Fictional balance updated.',
                style: AppTypography.labelSm.copyWith(color: AppColors.outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Done', style: AppTypography.labelMd.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order Ticket & Execution', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Interactive Candlestick Chart Drawer')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('RELIANCE', style: AppTypography.headlineSm),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('EQ NSE', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Reliance Industries Ltd.', style: AppTypography.bodyMd),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹2,945.50', style: AppTypography.numericTicker),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.arrow_drop_up, size: 16, color: AppColors.secondary),
                          Text('+18.40 (+0.63%)', style: AppTypography.numericTable.copyWith(color: AppColors.secondary, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Buy / Sell Toggle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isBuy = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isBuy ? AppColors.secondaryContainer : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isBuy ? AppColors.secondary : AppColors.borderSubtle,
                          width: 1.5,
                        ),
                      ],
                      alignment: Alignment.center,
                      child: Text(
                        'BUY (LONG)',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 14,
                          color: _isBuy ? AppColors.surfaceLowest : AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isBuy = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isBuy ? AppColors.tertiaryContainer : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_isBuy ? AppColors.tertiary : AppColors.borderSubtle,
                          width: 1.5,
                        ),
                      ],
                      alignment: Alignment.center,
                      child: Text(
                        'SELL (SHORT)',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 14,
                          color: !_isBuy ? Colors.white : AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Selection (CNC vs MIS)
            Text('Product Execution', style: AppTypography.labelSm),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    title: 'Delivery (CNC)',
                    subtitle: 'Full Cash • Long Term',
                    isSelected: _product == 'CNC',
                    onTap: () => setState(() => _product = 'CNC'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildChoiceCard(
                    title: 'Intraday (MIS)',
                    subtitle: 'Auto square-off • 5x Leverage',
                    isSelected: _product == 'MIS',
                    onTap: () => setState(() => _product = 'MIS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order Type (Market, Limit, SL, SL-M)
            Text('Execution Mode', style: AppTypography.labelSm),
            const SizedBox(height: 6),
            Row(
              children: ['MARKET', 'LIMIT', 'SL', 'SL_M'].map((type) {
                final isSelected = _orderType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _orderType = type),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBrand.withOpacity(0.2) : AppColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          type,
                          style: AppTypography.labelSm.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.outline,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Quantity Stepper
            Text('Shares (Quantity)', style: AppTypography.labelSm),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: AppColors.onSurface),
                    onPressed: () {
                      if (_quantity > 1) setState(() => _quantity--);
                    },
                  ),
                  Text('$_quantity', style: AppTypography.numericTicker),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.onSurface),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Quick Quantity Chips
            Row(
              children: [10, 25, 50, 100].map((qty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text('+$qty', style: AppTypography.labelSm.copyWith(fontSize: 10)),
                    backgroundColor: AppColors.surfaceContainer,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    onPressed: () => setState(() => _quantity += qty),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Limit Price (if not market)
            if (_orderType != 'MARKET') ...[
              Text('Limit Price (₹)', style: AppTypography.labelSm),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.onSurface),
                      onPressed: () => setState(() => _price -= 0.50),
                    ),
                    Text('₹${_price.toStringAsFixed(2)}', style: AppTypography.numericTicker),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.onSurface),
                      onPressed: () => setState(() => _price += 0.50),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Margin & Charges Breakdown Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildAuditRow('Required Margin', '₹${_requiredMargin.toStringAsFixed(2)}', isBold: true),
                  const SizedBox(height: 6),
                  _buildAuditRow('Available Virtual Margin', '₹${_availableMargin.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _buildAuditRow('Simulated Brokerage', '₹${_brokerage.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _buildAuditRow('Simulated STT & Charges', '₹${_taxes.toStringAsFixed(2)}'),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _buildAuditRow(
                    'Total Simulated Outlay',
                    '₹${(_requiredMargin + _brokerage + _taxes).toStringAsFixed(2)}',
                    isPrimary: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuy ? AppColors.secondaryContainer : AppColors.tertiaryContainer,
                  foregroundColor: _isBuy ? AppColors.surfaceLowest : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: _executeOrder,
                child: Text(
                  _isBuy ? 'Simulate BUY Order' : 'Simulate SELL Order',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 16,
                    color: _isBuy ? AppColors.surfaceLowest : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBrand.withOpacity(0.15) : AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.headlineSm.copyWith(
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTypography.labelSm.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, {bool isBold = false, bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
        Text(
          value,
          style: AppTypography.numericTable.copyWith(
            fontWeight: isBold || isPrimary ? FontWeight.bold : FontWeight.w500,
            color: isPrimary ? AppColors.primary : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
