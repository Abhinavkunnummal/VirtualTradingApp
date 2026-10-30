import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  bool _isBuy = true;
  String _product = 'CNC'; // CNC (Delivery) or MIS (Intraday)
  String _orderType = 'MARKET'; // MARKET, LIMIT, SL, SL_M
  String _orderVariety = 'REGULAR'; // REGULAR, COVER, BRACKET
  int _quantity = 10;
  double? _customPrice;
  double? _targetPrice;
  double? _stopLossPrice;
  double? _trailingStopLoss;
  bool _enableTrailing = false;
  bool _isSubmitting = false;

  double _getRequiredMargin(double currentLtp) {
    final effectivePrice = _orderType == 'MARKET' ? currentLtp : (_customPrice ?? currentLtp);
    final raw = _quantity * effectivePrice;
    return _product == 'MIS' ? raw / 5 : raw; // 5x leverage for MIS
  }

  double get _brokerage => 20.00;
  double _getTaxes(double currentLtp) => _getRequiredMargin(currentLtp) * 0.001;

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: AppTypography.bodyMd.copyWith(color: AppColors.onError))),
          ],
        ),
      ),
    );
  }

  Future<void> _executeOrder(String symbol, String exchange, double currentLtp) async {
    final effectivePrice = _orderType == 'MARKET' ? currentLtp : (_customPrice ?? currentLtp);
    final isCrypto = symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => symbol.contains(c));
    final currency = (isCrypto || exchange == 'US') ? '\$' : '₹';

    // Client-side validations for Cover and Bracket orders
    if (_orderVariety == 'COVER') {
      final sl = _stopLossPrice ?? (_isBuy ? effectivePrice * 0.98 : effectivePrice * 1.02);
      if (_isBuy && sl >= effectivePrice) {
        _showErrorToast('Cover order stop-loss must be lower than entry price (₹${effectivePrice.toStringAsFixed(2)})');
        return;
      }
      if (!_isBuy && sl <= effectivePrice) {
        _showErrorToast('Cover order stop-loss must be higher than entry price (₹${effectivePrice.toStringAsFixed(2)})');
        return;
      }
    }

    if (_orderVariety == 'BRACKET') {
      final target = _targetPrice ?? (_isBuy ? effectivePrice * 1.02 : effectivePrice * 0.98);
      final sl = _stopLossPrice ?? (_isBuy ? effectivePrice * 0.98 : effectivePrice * 1.02);
      if (_isBuy) {
        if (target <= effectivePrice) {
          _showErrorToast('Bracket target must be higher than entry price (₹${effectivePrice.toStringAsFixed(2)})');
          return;
        }
        if (sl >= effectivePrice) {
          _showErrorToast('Bracket stop-loss must be lower than entry price (₹${effectivePrice.toStringAsFixed(2)})');
          return;
        }
      } else {
        if (target >= effectivePrice) {
          _showErrorToast('Bracket target must be lower than entry price (₹${effectivePrice.toStringAsFixed(2)})');
          return;
        }
        if (sl <= effectivePrice) {
          _showErrorToast('Bracket stop-loss must be higher than entry price (₹${effectivePrice.toStringAsFixed(2)})');
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(submitOrderProvider).submitOrder(
            symbol: symbol,
            exchange: exchange,
            side: _isBuy ? 'BUY' : 'SELL',
            orderType: _orderType,
            product: _product,
            quantity: _quantity,
            limitPrice: _orderType == 'MARKET' ? null : (_customPrice ?? currentLtp),
            orderVariety: _orderVariety,
            targetPrice: _orderVariety == 'BRACKET'
                ? (_targetPrice ?? (_isBuy ? effectivePrice * 1.02 : effectivePrice * 0.98))
                : null,
            stopLossPrice: (_orderVariety == 'COVER' || _orderVariety == 'BRACKET')
                ? (_stopLossPrice ?? (_isBuy ? effectivePrice * 0.98 : effectivePrice * 1.02))
                : null,
            trailingStopLoss:
                (_orderVariety == 'BRACKET' && _enableTrailing) ? (_trailingStopLoss ?? 2.0) : null,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final isSuccess = result['success'] == true;
      final message = result['message'] as String? ?? 'Execution status';
      final execution = result['execution'] as Map<String, dynamic>?;
      final conciseNotification = result['conciseNotification'] as String? ??
          '${_isBuy ? 'BUY' : 'SELL'} $_quantity $symbol — Paper order filled';

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _isBuy ? AppColors.secondary : AppColors.tertiary),
            ),
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: _isBuy ? AppColors.secondary : AppColors.tertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conciseNotification,
                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      showDialog<void>(
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
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? (_isBuy ? AppColors.secondary : AppColors.tertiary) : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? 'Simulated Order Filled' : 'Order Rejected',
                style: AppTypography.headlineSm.copyWith(
                  color: isSuccess ? AppColors.secondary : AppColors.error,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_isBuy ? 'BUY' : 'SELL'} $_quantity ${isCrypto ? 'Lot(s)' : 'Shares'} of $symbol ($_product)',
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (isSuccess) ...[
                Text(
                  'You booked successfully with the order!',
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (execution != null) ...[
                Text(
                  'Fill Price: $currency${execution['executionPrice']}',
                  style: AppTypography.numericTable.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                Text('Slippage: $currency${execution['slippage']}', style: AppTypography.bodyMd),
                Text('Brokerage & Fees: $currency${execution['fees']}', style: AppTypography.bodyMd),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  message,
                  style: AppTypography.labelSm.copyWith(
                    color: isSuccess ? AppColors.onSurface : AppColors.error,
                  ),
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
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.errorContainer, content: Text(e.toString())),
        );
      }
    }
  }

  void _showOrderHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final historyAsync = ref.watch(orderHistoryProvider);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Simulated Order Book', style: AppTypography.headlineSm),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: historyAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Center(
                          child: Text('No orders placed yet.', style: AppTypography.bodyMd),
                        );
                      }
                      return ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          final isBuy = o['side'] == 'BUY';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(8),
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
                                        Text(
                                          '${o['side']} ${o['quantity']} ${o['symbol']}',
                                          style: AppTypography.bodyLg.copyWith(
                                            color: isBuy ? AppColors.secondary : AppColors.tertiary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(o['orderType'] as String? ?? 'MARKET', style: AppTypography.labelSm.copyWith(fontSize: 9)),
                                        ),
                                      ],
                                    ),
                                    Text('Status: ${o['status']}', style: AppTypography.labelSm),
                                  ],
                                ),
                                Text(
                                  o['averagePrice'] != null ? '₹${o['averagePrice']}' : 'Market',
                                  style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text(err.toString(), style: AppTypography.bodyMd)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showInstrumentPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) => Consumer(
            builder: (context, ref, _) {
              final marketsAsync = ref.watch(marketOverviewProvider);

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Instrument', style: AppTypography.headlineSm),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search stock, crypto, commodity...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
                          filled: true,
                          fillColor: AppColors.surfaceLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: marketsAsync.when(
                          data: (instruments) {
                            final filtered = instruments.where((inst) {
                              if (searchQuery.isEmpty) return true;
                              return inst.symbol.toLowerCase().contains(searchQuery) ||
                                  inst.name.toLowerCase().contains(searchQuery);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text('No instruments matching "$searchQuery"', style: AppTypography.bodyMd),
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final inst = filtered[index];
                                final currency = inst.category == 'US' || inst.category == 'CRYPTO' ? '\$' : '₹';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  tileColor: AppColors.surfaceLowest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: AppColors.borderSubtle),
                                  ),
                                  onTap: () {
                                    ref.read(selectedTradeInstrumentProvider.notifier).state = inst;
                                    setState(() => _customPrice = null);
                                    Navigator.of(ctx).pop();
                                  },
                                  title: Row(
                                    children: [
                                      Text(inst.symbol, style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(inst.exchange, style: AppTypography.labelSm.copyWith(fontSize: 10)),
                                    ],
                                  ),
                                  subtitle: Text(inst.name, style: AppTypography.bodyMd.copyWith(fontSize: 11)),
                                  trailing: Text(
                                    '$currency${inst.price.toStringAsFixed(2)}',
                                    style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text(err.toString(), style: AppTypography.bodyMd)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final instrument = ref.watch(selectedTradeInstrumentProvider);
    final interval = ref.watch(selectedCandleIntervalProvider);
    final range = ref.watch(selectedHistoryRangeProvider);
    final candlesAsync = ref.watch(candlesProvider(CandleQuery(symbol: instrument.symbol, interval: interval, range: range)));
    final portfolioAsync = ref.watch(portfolioProvider);

    final availableCash = portfolioAsync.valueOrNull?.availableCash ?? 1000000.0;
    final liveQuote = ref.watch(liveQuoteForSymbolProvider(instrument.symbol));
    final ltp = (liveQuote != null && liveQuote.price > 0)
        ? liveQuote.price
        : ((candlesAsync.valueOrNull?.isNotEmpty ?? false)
            ? candlesAsync.valueOrNull!.last.close
            : instrument.price);
    final currency = instrument.category == 'US' || instrument.category == 'CRYPTO' ? '\$' : '₹';
    final priceToUse = _customPrice ?? ltp;
    final requiredMargin = _getRequiredMargin(ltp);
    final taxes = _getTaxes(ltp);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order Ticket & Execution', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change Instrument',
            onPressed: _showInstrumentPickerSheet,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order History',
            onPressed: _showOrderHistorySheet,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(instrument.symbol, style: AppTypography.headlineSm),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${instrument.category} ${instrument.exchange}', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(instrument.name, style: AppTypography.bodyMd, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$currency${ltp.toStringAsFixed(2)}', style: AppTypography.numericTicker),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            instrument.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            size: 16,
                            color: instrument.isPositive ? AppColors.secondary : AppColors.tertiary,
                          ),
                          Text(
                            '${instrument.isPositive ? '+' : ''}${instrument.change.toStringAsFixed(2)} (${instrument.changePercent.toStringAsFixed(2)}%)',
                            style: AppTypography.numericTable.copyWith(
                              color: instrument.isPositive ? AppColors.secondary : AppColors.tertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Candlestick Chart View
            CandlestickChartView(
              symbol: instrument.symbol,
              candles: candlesAsync.valueOrNull ?? [],
              currentPrice: ltp,
              currencySymbol: currency,
              isLoading: candlesAsync.isLoading,
              errorMessage: candlesAsync.hasError ? candlesAsync.error.toString() : null,
              selectedInterval: interval,
              onIntervalChanged: (newInterval) {
                ref.read(selectedCandleIntervalProvider.notifier).state = newInterval;
              },
              selectedRange: range,
              onRangeChanged: (newRange) {
                ref.read(selectedHistoryRangeProvider.notifier).state = newRange;
              },
              status: instrument.isSimulated ? 'SIMULATED' : 'LIVE',
              onRetry: () => ref.refresh(candlesProvider(CandleQuery(symbol: instrument.symbol, interval: interval, range: range))),
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
                      ),
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
                      ),
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

            // Execution Mode (Market, Limit, SL, SL-M)
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

            // Order Variety (Regular, Cover, Bracket)
            Text('Order Variety', style: AppTypography.labelSm),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    title: 'Regular',
                    subtitle: 'Single Leg Order',
                    isSelected: _orderVariety == 'REGULAR',
                    onTap: () => setState(() => _orderVariety = 'REGULAR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChoiceCard(
                    title: 'Cover (CO)',
                    subtitle: 'Mandatory SL Protection',
                    isSelected: _orderVariety == 'COVER',
                    onTap: () => setState(() {
                      _orderVariety = 'COVER';
                      _stopLossPrice ??= _isBuy ? (priceToUse * 0.98) : (priceToUse * 1.02);
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChoiceCard(
                    title: 'Bracket (BO)',
                    subtitle: 'Target + SL + OCO',
                    isSelected: _orderVariety == 'BRACKET',
                    onTap: () => setState(() {
                      _orderVariety = 'BRACKET';
                      _targetPrice ??= _isBuy ? (priceToUse * 1.02) : (priceToUse * 0.98);
                      _stopLossPrice ??= _isBuy ? (priceToUse * 0.98) : (priceToUse * 1.02);
                    }),
                  ),
                ),
              ],
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
              Text('Limit Price ($currency)', style: AppTypography.labelSm),
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
                      onPressed: () => setState(() => _customPrice = priceToUse - 0.50),
                    ),
                    Text('$currency${priceToUse.toStringAsFixed(2)}', style: AppTypography.numericTicker),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.onSurface),
                      onPressed: () => setState(() => _customPrice = priceToUse + 0.50),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cover Order Stop-Loss Input
            if (_orderVariety == 'COVER') ...[
              Text('Cover Stop-Loss Trigger ($currency)', style: AppTypography.labelSm),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tertiary.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02);
                        _stopLossPrice = current - 1.0;
                      }),
                    ),
                    Text(
                      '$currency${(_stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02)).toStringAsFixed(2)}',
                      style: AppTypography.numericTicker.copyWith(color: AppColors.tertiary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02);
                        _stopLossPrice = current + 1.0;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bracket Order Target & Stop-Loss Inputs
            if (_orderVariety == 'BRACKET') ...[
              Text('Target Profit Price ($currency)', style: AppTypography.labelSm),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _targetPrice ?? (_isBuy ? priceToUse * 1.02 : priceToUse * 0.98);
                        _targetPrice = current - 1.0;
                      }),
                    ),
                    Text(
                      '$currency${(_targetPrice ?? (_isBuy ? priceToUse * 1.02 : priceToUse * 0.98)).toStringAsFixed(2)}',
                      style: AppTypography.numericTicker.copyWith(color: AppColors.secondary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _targetPrice ?? (_isBuy ? priceToUse * 1.02 : priceToUse * 0.98);
                        _targetPrice = current + 1.0;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text('Stop-Loss Trigger Price ($currency)', style: AppTypography.labelSm),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tertiary.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02);
                        _stopLossPrice = current - 1.0;
                      }),
                    ),
                    Text(
                      '$currency${(_stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02)).toStringAsFixed(2)}',
                      style: AppTypography.numericTicker.copyWith(color: AppColors.tertiary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.onSurface),
                      onPressed: () => setState(() {
                        final current = _stopLossPrice ?? (_isBuy ? priceToUse * 0.98 : priceToUse * 1.02);
                        _stopLossPrice = current + 1.0;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Trailing Stop-Loss Toggle & Step
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trailing Stop-Loss', style: AppTypography.labelMd),
                        Switch(
                          value: _enableTrailing,
                          activeColor: AppColors.primaryBrand,
                          onChanged: (val) => setState(() => _enableTrailing = val),
                        ),
                      ],
                    ),
                    if (_enableTrailing) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Trailing Step (₹)', style: AppTypography.labelSm),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () {
                                  final current = _trailingStopLoss ?? 2.0;
                                  if (current > 0.5) setState(() => _trailingStopLoss = current - 0.5);
                                },
                              ),
                              Text('₹${(_trailingStopLoss ?? 2.0).toStringAsFixed(1)}', style: AppTypography.numericTable),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () {
                                  final current = _trailingStopLoss ?? 2.0;
                                  setState(() => _trailingStopLoss = current + 0.5);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
                  _buildAuditRow('Required Margin', '$currency${requiredMargin.toStringAsFixed(2)}', isBold: true),
                  const SizedBox(height: 6),
                  _buildAuditRow('Available Virtual Margin', '$currency${availableCash.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _buildAuditRow('Simulated Brokerage', '$currency${_brokerage.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _buildAuditRow('Simulated STT & Charges', '$currency${taxes.toStringAsFixed(2)}'),
                  const Divider(color: AppColors.borderSubtle, height: 16),
                  _buildAuditRow(
                    'Total Simulated Outlay',
                    '$currency${(requiredMargin + _brokerage + taxes).toStringAsFixed(2)}',
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
                onPressed: _isSubmitting ? null : () => _executeOrder(instrument.symbol, instrument.exchange, ltp),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isBuy ? 'Place Simulated BUY Order' : 'Place Simulated SELL Order',
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
