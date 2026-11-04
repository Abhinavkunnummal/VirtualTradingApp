import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/core/widgets/app_shimmer.dart';
import 'package:tradeverse_mobile/core/widgets/empty_state_view.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/order_confirmation_sheet.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _ordersFilter = 'All'; // All, Pending, Executed, Cancelled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSquareOffSheet(HoldingModel holding, double currentLtp) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SquareOffModal(
        holding: holding,
        currentLtp: currentLtp,
        onSquareOff: (qty, orderType, limitPrice) async {
          Navigator.of(ctx).pop();
          final result = await ref.read(submitOrderProvider).squareOffPosition(
            symbol: holding.symbol,
            quantity: qty,
            orderType: orderType,
            limitPrice: limitPrice,
          );

          if (!mounted) return;
          if (result['success'] == true) {
            OrderConfirmationSheet.show(
              context,
              symbol: holding.symbol,
              exchange: holding.exchange,
              side: 'SELL',
              orderType: orderType,
              product: holding.product,
              quantity: qty ?? holding.quantity,
              price: (result['exitPrice'] as num?)?.toDouble() ?? currentLtp,
              marginUsed: (result['netProceeds'] as num?)?.toDouble(),
              fees: (result['fees'] as num?)?.toDouble(),
              realizedPnl: (result['realizedPnl'] as num?)?.toDouble(),
              realizedPnlPercent: (result['realizedPnlPercent'] as num?)?.toDouble(),
              isExit: true,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.errorContainer,
                content: Text(
                  result['message'] as String? ?? 'Square-off failed.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onError),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _navigateToChartWithHolding(HoldingModel holding) {
    final instruments = ref.read(marketOverviewProvider).valueOrNull ?? [];
    final cleanSym = holding.symbol.toUpperCase().trim();
    final matched = instruments.firstWhere(
      (i) => i.symbol.toUpperCase() == cleanSym || i.symbol.toUpperCase() == cleanSym.replaceAll(' ', ''),
      orElse: () => InstrumentModel(
        symbol: holding.symbol,
        name: holding.symbol,
        exchange: holding.exchange,
        category: 'EQUITY',
        price: holding.ltp > 0 ? holding.ltp : holding.averageBuyPrice,
        change: 0.0,
        changePercent: 0.0,
        isPositive: true,
      ),
    );

    ref.read(selectedTradeInstrumentProvider.notifier).state = matched;
    ref.read(liveQuotesProvider.notifier).trackSymbol(matched.symbol);
    context.push('/tradingview-pro');
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider).valueOrNull;
    final liveQuotes = ref.watch(liveQuotesProvider);
    final pnlSummary = ref.watch(pnlSummaryProvider).valueOrNull;

    // Calculate aggregated live P&Ls
    final holdings = portfolio?.holdings ?? [];
    double totalUnrealized = 0.0;
    for (final h in holdings) {
      final liveQuote = liveQuotes[h.symbol.toUpperCase()];
      final ltp = (liveQuote != null && liveQuote.price > 0) ? liveQuote.price : h.ltp;
      totalUnrealized += (ltp - h.averageBuyPrice) * h.quantity;
    }

    final totalRealized = pnlSummary?.totalRealizedPnl ?? 0.0;
    final netPnl = totalUnrealized + totalRealized;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Orders & Positions', style: AppTypography.headlineSm),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh Orders',
            onPressed: () {
              ref.invalidate(portfolioProvider);
              ref.invalidate(orderHistoryProvider);
              ref.invalidate(pnlSummaryProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1.0),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryBrand,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.outline,
              labelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Positions (${holdings.length})'),
                const Tab(text: 'Orders'),
                const Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Persistent Top Summary Header
            _buildSummaryHeader(
              totalUnrealized: totalUnrealized,
              totalRealized: totalRealized,
              netPnl: netPnl,
              availableCash: portfolio?.availableCash ?? 0.0,
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOpenPositionsTab(holdings, liveQuotes),
                  _buildOrdersTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader({
    required double totalUnrealized,
    required double totalRealized,
    required double netPnl,
    required double availableCash,
  }) {
    final unrlPos = totalUnrealized >= 0;
    final rlPos = totalRealized >= 0;
    final netPos = netPnl >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unrealized P&L', style: AppTypography.labelSm.copyWith(color: AppColors.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${unrlPos ? '+' : ''}₹${totalUnrealized.toStringAsFixed(2)}',
                        style: AppTypography.numericTable.copyWith(
                          color: unrlPos ? AppColors.secondary : AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: AppColors.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 6)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Realized P&L', style: AppTypography.labelSm.copyWith(color: AppColors.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        '${rlPos ? '+' : ''}₹${totalRealized.toStringAsFixed(2)}',
                        style: AppTypography.numericTable.copyWith(
                          color: rlPos ? AppColors.secondary : AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: AppColors.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 6)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net P&L', style: AppTypography.labelSm.copyWith(color: AppColors.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${netPos ? '+' : ''}₹${netPnl.toStringAsFixed(2)}',
                        style: AppTypography.numericTable.copyWith(
                          color: netPos ? AppColors.secondary : AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Available Wallet Cash: ₹${availableCash.toStringAsFixed(2)}',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context.go('/portfolio'),
                child: Text(
                  '+ Add Funds',
                  style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenPositionsTab(List<HoldingModel> holdings, Map<String, LiveQuote> liveQuotes) {
    if (holdings.isEmpty) {
      return EmptyStateView(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No Open Positions',
        message: 'You have no active open positions. Execute simulated trades to monitor real-time P&L.',
        actionLabel: 'Explore Markets',
        onAction: () {
          HapticFeedback.lightImpact();
          context.go('/markets');
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: holdings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final holding = holdings[index];
        final liveQuote = liveQuotes[holding.symbol.toUpperCase()];
        final ltp = (liveQuote != null && liveQuote.price > 0) ? liveQuote.price : holding.ltp;
        final invested = holding.quantity * holding.averageBuyPrice;
        final currentVal = holding.quantity * ltp;
        final pnl = currentVal - invested;
        final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
        final isPos = pnl >= 0;

        final isCrypto = holding.symbol.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => holding.symbol.contains(c));
        final currency = (isCrypto || holding.exchange == 'US') ? '\$' : '₹';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Symbol, Product Chip & P&L
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          holding.symbol,
                          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            holding.product,
                            style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.primary),
                          ),
                        ),
                        Text(
                          '(${holding.exchange})',
                          style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${isPos ? '+' : ''}$currency${pnl.toStringAsFixed(2)}',
                          style: AppTypography.numericTable.copyWith(
                            color: isPos ? AppColors.secondary : AppColors.tertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${isPos ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                        style: AppTypography.labelSm.copyWith(
                          color: isPos ? AppColors.secondary : AppColors.tertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Metrics Row: Qty, Avg Buy, LTP
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11), maxLines: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('${holding.quantity}', style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avg Buy', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11), maxLines: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('$currency${holding.averageBuyPrice.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live LTP', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11), maxLines: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('$currency${ltp.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Current Value', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11), maxLines: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text('$currency${currentVal.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (holding.stopLoss != null || holding.targetPrice != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (holding.stopLoss != null)
                      Text(
                        'SL: $currency${holding.stopLoss!.toStringAsFixed(2)}',
                        style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontSize: 10),
                      ),
                    if (holding.targetPrice != null)
                      Text(
                        'Target: $currency${holding.targetPrice!.toStringAsFixed(2)}',
                        style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 8),

              // Action Buttons: Square Off & View Chart
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('view_chart_${holding.symbol}'),
                    icon: const Icon(Icons.candlestick_chart_outlined, size: 14),
                    label: const Text('View chart'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _navigateToChartWithHolding(holding),
                  ),
                  ElevatedButton.icon(
                    key: ValueKey('square_off_${holding.symbol}'),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Sell / Square off'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showSquareOffSheet(holding, ltp),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    final orderHistoryAsync = ref.watch(orderHistoryProvider);

    return Column(
      children: [
        // Filter Chips Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Executed', 'Cancelled'].map((f) {
                final isSelected = _ordersFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f, style: AppTypography.labelSm.copyWith(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBrand.withOpacity(0.2),
                    backgroundColor: AppColors.surfaceContainer,
                    side: BorderSide(color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle),
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _ordersFilter = f);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: orderHistoryAsync.when(
            data: (rawOrders) {
              final filtered = rawOrders.where((o) {
                final st = (o['status'] as String? ?? '').toUpperCase();
                if (_ordersFilter == 'Pending') return st == 'PENDING';
                if (_ordersFilter == 'Executed') return st == 'FILLED';
                if (_ordersFilter == 'Cancelled') return st == 'CANCELLED';
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No $_ordersFilter Orders',
                  message: _ordersFilter == 'All'
                      ? 'You haven\'t placed any simulated orders today.'
                      : 'No orders with status "$_ordersFilter" found in today\'s session.',
                  actionLabel: _ordersFilter == 'All' ? 'Place an Order' : null,
                  onAction: _ordersFilter == 'All'
                      ? () {
                          HapticFeedback.lightImpact();
                          context.go('/trade');
                        }
                      : null,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final order = filtered[idx];
                  final isBuy = (order['side'] as String? ?? 'BUY') == 'BUY';
                  final status = (order['status'] as String? ?? 'FILLED').toUpperCase();
                  final isPending = status == 'PENDING';
                  final price = (order['averagePrice'] as num?)?.toDouble() ?? (order['limitPrice'] as num?)?.toDouble() ?? 0.0;
                  final orderId = order['id'] as String? ?? '';

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isBuy ? AppColors.secondary : AppColors.tertiary).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isBuy ? 'BUY' : 'SELL',
                                      style: AppTypography.labelSm.copyWith(
                                        color: isBuy ? AppColors.secondary : AppColors.tertiary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      order['symbol'] as String? ?? '',
                                      style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${order['product'] ?? 'CNC'} • ${order['orderType'] ?? 'MARKET'}',
                                    style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${order['quantity']} @ ₹${price.toStringAsFixed(2)}',
                                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? AppColors.warning.withOpacity(0.15)
                                    : (status == 'FILLED' ? AppColors.secondary.withOpacity(0.15) : AppColors.outline.withOpacity(0.15)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: AppTypography.labelSm.copyWith(
                                  color: isPending
                                      ? AppColors.warning
                                      : (status == 'FILLED' ? AppColors.secondary : AppColors.outline),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                key: ValueKey('cancel_order_$orderId'),
                                icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.tertiary),
                                tooltip: 'Cancel Order',
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  final ok = await ref.read(submitOrderProvider).cancelOrder(orderId);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Order cancelled successfully.' : 'Failed to cancel.')),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const OrdersSkeleton(count: 4),
            error: (err, _) => Center(child: Text('Error loading orders: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final historyAsync = ref.watch(closedTradesHistoryProvider);

    return historyAsync.when(
      data: (trades) {
        if (trades.isEmpty) {
          return EmptyStateView(
            icon: Icons.history_toggle_off,
            title: 'No Closed Trades',
            message: 'Positions squared off during your trading sessions will appear here with realized P&L.',
            actionLabel: 'Explore Markets',
            onAction: () {
              HapticFeedback.lightImpact();
              context.go('/markets');
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: trades.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final trade = trades[idx];
            final isPos = trade.realizedPnl >= 0;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trade.symbol,
                                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${trade.product} • ${trade.side}',
                                style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${trade.quantity} | Buy: ₹${trade.entryPrice.toStringAsFixed(2)} → Exit: ₹${trade.exitPrice.toStringAsFixed(2)}',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isPos ? '+' : ''}₹${trade.realizedPnl.toStringAsFixed(2)}',
                        style: AppTypography.numericTable.copyWith(
                          color: isPos ? AppColors.secondary : AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${isPos ? '+' : ''}${trade.realizedPnlPercent.toStringAsFixed(2)}%',
                        style: AppTypography.labelSm.copyWith(
                          color: isPos ? AppColors.secondary : AppColors.tertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const OrdersSkeleton(count: 4),
      error: (err, _) => Center(child: Text('Error loading history: $err')),
    );
  }
}

class _SquareOffModal extends StatefulWidget {
  final HoldingModel holding;
  final double currentLtp;
  final void Function(int? qty, String orderType, double? limitPrice) onSquareOff;

  const _SquareOffModal({
    required this.holding,
    required this.currentLtp,
    required this.onSquareOff,
  });

  @override
  State<_SquareOffModal> createState() => _SquareOffModalState();
}

class _SquareOffModalState extends State<_SquareOffModal> {
  late int _quantityToClose;
  String _orderType = 'MARKET'; // MARKET, LIMIT
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _quantityToClose = widget.holding.quantity;
    _priceController = TextEditingController(text: widget.currentLtp.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exitPrice = _orderType == 'LIMIT'
        ? (double.tryParse(_priceController.text) ?? widget.currentLtp)
        : widget.currentLtp;
    final costBasis = _quantityToClose * widget.holding.averageBuyPrice;
    final estimatedProceeds = _quantityToClose * exitPrice;
    final estimatedPnl = estimatedProceeds - costBasis;
    final isPos = estimatedPnl >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Square Off: ${widget.holding.symbol}',
                    style: AppTypography.headlineSm.copyWith(fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Available Position: ${widget.holding.quantity} shares @ ₹${widget.holding.averageBuyPrice.toStringAsFixed(2)}',
                style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
              ),
              const SizedBox(height: 16),

              // Order Type Toggle
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Market Exit')),
                      selected: _orderType == 'MARKET',
                      selectedColor: AppColors.primaryBrand.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) setState(() => _orderType = 'MARKET');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Limit Exit')),
                      selected: _orderType == 'LIMIT',
                      selectedColor: AppColors.primaryBrand.withOpacity(0.2),
                      onSelected: (val) {
                        if (val) setState(() => _orderType = 'LIMIT');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quantity Slider / Selector
              Text('Quantity to Sell: $_quantityToClose shares', style: AppTypography.labelSm),
              Slider(
                value: _quantityToClose.toDouble(),
                min: 1,
                max: widget.holding.quantity.toDouble(),
                divisions: widget.holding.quantity > 1 ? widget.holding.quantity - 1 : 1,
                activeColor: AppColors.tertiary,
                onChanged: (val) {
                  setState(() => _quantityToClose = val.toInt());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantityToClose = (widget.holding.quantity / 2).ceil());
                    },
                    child: const Text('Sell 50%'),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantityToClose = widget.holding.quantity);
                    },
                    child: const Text('Sell All (100%)'),
                  ),
                ],
              ),

              if (_orderType == 'LIMIT') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Limit Exit Price (₹)',
                    filled: true,
                    fillColor: AppColors.surfaceLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 14),

              // Estimated Realized P&L Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estimated Realized P&L:', style: AppTypography.labelSm),
                    Text(
                      '${isPos ? '+' : ''}₹${estimatedPnl.toStringAsFixed(2)}',
                      style: AppTypography.numericTable.copyWith(
                        color: isPos ? AppColors.secondary : AppColors.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('confirm_square_off_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onSquareOff(
                      _quantityToClose,
                      _orderType,
                      _orderType == 'LIMIT' ? double.tryParse(_priceController.text) : null,
                    );
                  },
                  child: Text('Confirm Square Off ($_quantityToClose Shares)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
