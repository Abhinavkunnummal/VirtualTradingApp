import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/loading_state_widget.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../providers/portfolio_provider.dart';
import '../../domain/portfolio_models.dart';

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

  void _showResetCapitalModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reset Virtual Sandbox Capital', style: AppTypography.headlineSm),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Portfolio & Analytics', style: AppTypography.headlineSm),
        actions: [
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
              _buildHoldingsList(portfolio.holdings),
              _buildPositionsList(),
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
              Text('Total Account Value', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
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
          Row(
            children: [
              Text(
                '${isPos ? '+' : ''}₹${portfolio.totalPnl.toStringAsFixed(2)} (${portfolio.totalPnlPercent}%)',
                style: AppTypography.numericTable.copyWith(
                  color: isPos ? AppColors.secondary : AppColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text('Unrealized P&L', style: AppTypography.labelSm),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Virtual Cash', '₹${portfolio.availableCash.toStringAsFixed(2)}'),
              _buildMetric('Invested', '₹${portfolio.investedValue.toStringAsFixed(2)}'),
              _buildMetric('Starting Capital', '₹${portfolio.startingCapital.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.numericTable.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: color ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingsList(List<HoldingModel> holdings) {
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
        final isPos = h.unrealizedPnl >= 0;

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
                      Text(h.symbol, style: AppTypography.headlineSm.copyWith(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('(${h.quantity} Qty)', style: AppTypography.labelSm),
                    ],
                  ),
                  Text(
                    '${isPos ? '+' : ''}₹${h.unrealizedPnl.toStringAsFixed(2)} (${h.unrealizedPnlPercent}%)',
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
                  Text('Avg: ₹${h.averageBuyPrice}', style: AppTypography.labelSm),
                  Text('LTP: ₹${h.ltp}', style: AppTypography.numericTable.copyWith(fontSize: 12)),
                  Text(
                    'Cur Val: ₹${h.currentValue.toStringAsFixed(2)}',
                    style: AppTypography.numericTable.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionsList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _positions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = _positions[index];
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
                    '${isPos ? '+' : ''}₹${p['pnl'].toStringAsFixed(2)} (${p['pnlPct']}%)',
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
                  Text('Qty: ${p['qty']}', style: AppTypography.labelSm),
                  Text('Entry: ₹${p['avg']}', style: AppTypography.numericTable.copyWith(fontSize: 12)),
                  Text('LTP: ₹${p['ltp']}', style: AppTypography.numericTable.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
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
