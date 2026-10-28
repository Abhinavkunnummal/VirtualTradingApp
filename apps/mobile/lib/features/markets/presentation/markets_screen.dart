import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketsAsync = ref.watch(marketOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Markets & Discovery', style: AppTypography.headlineSm),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 12, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  'SIMULATED',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search NSE, BSE, MCX, US, Crypto...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
              // Category Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primaryBrand,
                indicatorWeight: 2.5,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.outline,
                labelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'All Assets'),
                  Tab(text: 'NSE/BSE Equities'),
                  Tab(text: 'MCX Commodities'),
                  Tab(text: 'Crypto 24/7'),
                  Tab(text: 'US Stocks'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: marketsAsync.when(
        data: (instruments) => TabBarView(
          controller: _tabController,
          children: [
            _buildAssetList(instruments, null),
            _buildAssetList(instruments, 'EQUITY'),
            _buildAssetList(instruments, 'COMMODITY'),
            _buildAssetList(instruments, 'CRYPTO'),
            _buildAssetList(instruments, 'US'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load market data', style: AppTypography.bodyLg),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(marketOverviewProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetList(List<InstrumentModel> allInstruments, String? categoryFilter) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = allInstruments.where((item) {
      final matchesCategory = categoryFilter == null || item.category == categoryFilter;
      final matchesQuery = query.isEmpty ||
          item.symbol.toLowerCase().contains(query) ||
          item.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No instruments found matching "$query"', style: AppTypography.bodyMd),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketOverviewProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final isPos = item.isPositive;
          final currency = item.category == 'US' || item.category == 'CRYPTO' ? '\$' : '₹';

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              onTap: () {
                ref.read(selectedTradeInstrumentProvider.notifier).state = item;
                context.go('/trade');
              },
              title: Row(
                children: [
                  Text(item.symbol, style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.exchange,
                      style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                    ),
                  ),
                ],
              ),
              subtitle: Text(item.name, style: AppTypography.bodyMd.copyWith(fontSize: 12)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${item.price.toStringAsFixed(2)}',
                    style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isPos ? '+' : ''}${item.change.toStringAsFixed(2)} (${item.changePercent.toStringAsFixed(2)}%)',
                    style: AppTypography.numericTable.copyWith(
                      color: isPos ? AppColors.secondary : AppColors.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}
