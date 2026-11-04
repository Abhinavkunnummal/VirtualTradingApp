import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/shared/widgets/loading_state_widget.dart';
import 'package:tradeverse_mobile/shared/widgets/error_state_widget.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _positions = [
    {
      'symbol': 'NIFTY 24850 CE',
      'exchange': 'NFO',
      'product': 'MIS',
      'qty': 75,
      'avg': 142.50,
      'ltp': 164.20,
      'pnl': 1627.50,
      'pnlPct': 15.22,
      'isPos': true,
    },
    {
      'symbol': 'INFY',
      'exchange': 'NSE',
      'product': 'MIS (5x)',
      'qty': 100,
      'avg': 1872.00,
      'ltp': 1885.20,
      'pnl': 1320.00,
      'pnlPct': 0.70,
      'isPos': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTopUpModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final amountController = TextEditingController(text: '100000');
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Add Virtual Practice Funds',
                        style: AppTypography.headlineSm.copyWith(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Top up fictional capital in your paper-trading sandbox. No real fiat deposit.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                ),
                const SizedBox(height: 16),

                // Quick preset chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [50000.0, 100000.0, 500000.0, 1000000.0].map((amt) {
                    final label = '+₹${(amt / 1000).toStringAsFixed(0)}K';
                    return ActionChip(
                      backgroundColor: AppColors.surfaceLowest,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      label: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                      onPressed: () {
                        amountController.text = amt.toStringAsFixed(0);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyLg,
                  decoration: InputDecoration(
                    labelText: 'Amount (INR)',
                    prefixText: '₹ ',
                    prefixStyle: AppTypography.bodyLg.copyWith(color: AppColors.secondary),
                    filled: true,
                    fillColor: AppColors.surfaceLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    label: const Text('Credit Virtual Funds'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final entered = double.tryParse(amountController.text) ?? 100000.0;
                      Navigator.of(ctx).pop();
                      final success = await ref.read(portfolioProvider.notifier).topUpVirtualFunds(entered);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Credited ₹${entered.toStringAsFixed(0)} in virtual sandbox funds.'
                                  : 'Top-up failed. Check connection.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWithdrawModal(double currentCash) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final amountController = TextEditingController(
          text: currentCash > 50000 ? '50000' : currentCash.toStringAsFixed(0),
        );
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Withdraw Virtual Funds',
                          style: AppTypography.headlineSm.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available Cash: ₹${currentCash.toStringAsFixed(2)}. Virtual withdrawal for realism.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <double>{
                      if (currentCash >= 10000) 10000.0,
                      if (currentCash >= 50000) 50000.0,
                      if (currentCash >= 100000) 100000.0,
                      currentCash,
                    }.map((amt) {
                      final label = amt == currentCash
                          ? 'Max (₹${amt.toStringAsFixed(0)})'
                          : '₹${(amt / 1000).toStringAsFixed(0)}K';
                      return ActionChip(
                        backgroundColor: AppColors.surfaceLowest,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        label: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                        onPressed: () {
                          setModalState(() {
                            amountController.text = amt.toStringAsFixed(0);
                            errorMessage = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.bodyLg,
                    onChanged: (val) {
                      final entered = double.tryParse(val);
                      if (entered != null && entered > currentCash) {
                        setModalState(() => errorMessage =
                            'Amount exceeds available cash (₹${currentCash.toStringAsFixed(2)})');
                      } else if (errorMessage != null) {
                        setModalState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Withdraw Amount (INR)',
                      prefixText: '₹ ',
                      prefixStyle: AppTypography.bodyLg.copyWith(color: AppColors.tertiary),
                      errorText: errorMessage,
                      filled: true,
                      fillColor: AppColors.surfaceLowest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_circle_down_outlined, size: 18),
                      label: const Text('Withdraw Virtual Funds'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tertiary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final entered = double.tryParse(amountController.text) ?? 0.0;
                        if (entered <= 0) {
                          setModalState(() => errorMessage = 'Enter a valid amount greater than 0');
                          return;
                        }
                        if (entered > currentCash) {
                          setModalState(() => errorMessage =
                              'Amount exceeds available cash (₹${currentCash.toStringAsFixed(2)})');
                          return;
                        }
                        Navigator.of(ctx).pop();
                        final res =
                            await ref.read(portfolioProvider.notifier).withdrawVirtualFunds(entered);
                        final isSuccess = res['success'] == true;
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSuccess
                                  ? 'Withdrawn ₹${entered.toStringAsFixed(2)} from virtual sandbox funds.'
                                  : (res['message'] as String? ?? 'Withdrawal failed. Check balance or connection.'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final txAsync = ref.watch(walletTransactionsProvider);
          return SafeArea(
            top: false,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Wallet Transaction History', style: AppTypography.headlineSm),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: txAsync.when(
                      data: (txList) {
                        if (txList.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history_outlined, size: 48, color: AppColors.outline),
                                const SizedBox(height: 12),
                                Text('No wallet transactions yet', style: AppTypography.bodyMd),
                                const SizedBox(height: 4),
                                Text(
                                  'Add or withdraw funds to see records here.',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: txList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = txList[index];
                            final isCredit =
                                tx.type == 'CAPITAL_TOPUP' || (tx.type == 'SQUARE_OFF' && tx.amount >= 0);
                            final color = isCredit ? AppColors.secondary : AppColors.tertiary;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                      size: 18,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description.isNotEmpty ? tx.description : tx.type,
                                          style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')} • Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.outline,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${isCredit ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(2)}',
                                    style: AppTypography.numericTable.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
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
            ),
          );
        },
      ),
    );
  }

  void _showResetCapitalModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reset Virtual Sandbox Capital',
                      style: AppTypography.headlineSm.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select starting virtual balance for your paper-trading account:',
                style: AppTypography.bodyMd,
              ),
              const SizedBox(height: 16),
              ...[500000.0, 1000000.0, 2500000.0, 5000000.0].map((amt) {
                final formatted = '₹${(amt / 100000).toStringAsFixed(0)} Lakh';
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: AppColors.surfaceLowest,
                  title: Text(formatted, style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text('Virtual Currency • No Real Money', style: AppTypography.labelSm),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final success = await ref.read(portfolioProvider.notifier).resetCapital(amt);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Sandbox balance reset to $formatted' : 'Reset failed. Check connection.')),
                      );
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final liveQuotes = ref.watch(liveQuotesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Portfolio & Analytics', style: AppTypography.headlineSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Virtual Funds',
            onPressed: _showTopUpModal,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transaction History',
            onPressed: _showTransactionsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Capital',
            onPressed: _showResetCapitalModal,
          ),
        ],
      ),
      body: portfolioAsync.when(
        data: (portfolio) => NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildPortfolioSummary(portfolio),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryBrand,
                  indicatorWeight: 2.5,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.outline,
                  labelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Holdings (Delivery)'),
                    Tab(text: 'Positions (Intraday)'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildHoldingsList(portfolio.holdings, liveQuotes),
              _buildPositionsList(portfolio.holdings, liveQuotes),
            ],
          ),
        ),
        loading: () => const LoadingStateWidget(message: 'Loading active portfolio holdings...'),
        error: (err, _) => ErrorStateWidget(
          title: 'Unable to Load Portfolio',
          message: err.toString(),
          onRetry: () => ref.refresh(portfolioProvider),
        ),
      ),
    );
  }

  Widget _buildPortfolioSummary(PortfolioModel portfolio) {
    final isPos = portfolio.totalPnl >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Account Value',
                  style: AppTypography.labelMd.copyWith(color: AppColors.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Simulated', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${portfolio.totalPortfolioValue.toStringAsFixed(2)}',
            style: AppTypography.numericTicker.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${isPos ? '+' : ''}₹${portfolio.totalPnl.toStringAsFixed(2)} (${portfolio.totalPnlPercent}%)',
                style: AppTypography.numericTable.copyWith(
                  color: isPos ? AppColors.secondary : AppColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Unrealized P&L', style: AppTypography.labelSm),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildMetric('Virtual Cash', '₹${portfolio.availableCash.toStringAsFixed(2)}')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetric('Invested', '₹${portfolio.investedValue.toStringAsFixed(2)}')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetric('Starting Capital', '₹${portfolio.startingCapital.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Add Virtual Funds'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _showTopUpModal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_circle_down_outlined, size: 16),
                  label: const Text('Withdraw'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showWithdrawModal(portfolio.availableCash),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                tooltip: 'Transaction History',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                onPressed: _showTransactionsSheet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt, size: 16, color: AppColors.primary),
              label: Text(
                'View Orders & Positions',
                style: AppTypography.labelMd.copyWith(color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBrand),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.push('/orders'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTypography.numericTable.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color ?? AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingsList(List<HoldingModel> holdings, Map<String, LiveQuote> liveQuotes) {
    if (holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No active simulated holdings', style: AppTypography.bodyMd),
            const SizedBox(height: 6),
            Text('Place paper orders in the Trade ticket to build your portfolio.', style: AppTypography.labelSm),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: holdings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final h = holdings[index];
        final symKey = h.symbol.toUpperCase();
        final isCrypto = symKey.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => symKey.contains(c));
        final currency = (isCrypto || h.exchange == 'US') ? '\$' : '₹';

        final liveQuote = liveQuotes[symKey];
        final ltp = (liveQuote != null && liveQuote.price > 0) ? liveQuote.price : h.ltp;
        final invested = h.quantity * h.averageBuyPrice;
        final currentVal = h.quantity * ltp;
        final pnl = currentVal - invested;
        final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
        final isPos = pnl >= 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    h.symbol,
                    style: AppTypography.headlineSm.copyWith(fontSize: 14),
                  ),
                  Text('(${h.quantity} Lot)', style: AppTypography.labelSm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'LIVE',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Text(
                    '${isPos ? '+' : ''}$currency${pnl.toStringAsFixed(2)} (${pnlPct.toStringAsFixed(2)}%)',
                    style: AppTypography.numericTable.copyWith(
                      color: isPos ? AppColors.secondary : AppColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Text('Avg: $currency${h.averageBuyPrice.toStringAsFixed(2)}', style: AppTypography.labelSm),
                    const SizedBox(width: 12),
                    Text('LTP: $currency${ltp.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      'Cur Val: $currency${currentVal.toStringAsFixed(2)}',
                      style: AppTypography.numericTable.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionsList(List<HoldingModel> holdings, Map<String, LiveQuote> liveQuotes) {
    final displayItems = holdings.isNotEmpty ? holdings : _positions;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: displayItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        if (item is HoldingModel) {
          final symKey = item.symbol.toUpperCase();
          final isCrypto = symKey.contains('/') || ['BTC', 'ETH', 'SOL'].any((c) => symKey.contains(c));
          final currency = (isCrypto || item.exchange == 'US') ? '\$' : '₹';

          final liveQuote = liveQuotes[symKey];
          final ltp = (liveQuote != null && liveQuote.price > 0) ? liveQuote.price : item.ltp;
          final invested = item.quantity * item.averageBuyPrice;
          final currentVal = item.quantity * ltp;
          final pnl = currentVal - invested;
          final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
          final isPos = pnl >= 0;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      item.symbol,
                      style: AppTypography.headlineSm.copyWith(fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBrand.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CNC/MIS',
                        style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.primary),
                      ),
                    ),
                    Text('(${item.quantity} Lot)', style: AppTypography.labelSm),
                    Text(
                      '${isPos ? '+' : ''}$currency${pnl.toStringAsFixed(2)} (${pnlPct.toStringAsFixed(2)}%)',
                      style: AppTypography.numericTable.copyWith(
                        color: isPos ? AppColors.secondary : AppColors.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Text('Avg: $currency${item.averageBuyPrice.toStringAsFixed(2)}', style: AppTypography.labelSm),
                      const SizedBox(width: 12),
                      Text('LTP: $currency${ltp.toStringAsFixed(2)}', style: AppTypography.numericTable.copyWith(fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('Val: $currency${currentVal.toStringAsFixed(2)}', style: AppTypography.labelSm),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final p = item as Map<String, dynamic>;
        final isPos = p['isPos'] as bool;
        return Container(
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
                  Row(
                    children: [
                      Text(p['symbol'] as String, style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p['product'] as String,
                          style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${isPos ? '+' : ''}₹${(p['pnl'] as num).toStringAsFixed(2)} (${p['pnlPct']}%)',
                    style: AppTypography.numericTable.copyWith(
                      color: isPos ? AppColors.secondary : AppColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Avg: ₹${p['avg']}', style: AppTypography.labelSm),
                  Text('LTP: ₹${p['ltp']}', style: AppTypography.numericTable.copyWith(fontSize: 12)),
                  Text('${p['qty']} Qty', style: AppTypography.labelSm),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
