import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/news_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/news_provider.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
          preferredSize: const Size.fromHeight(112),
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
                  Tab(text: 'Live News Feed'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketsTab(marketsAsync, null),
          _buildMarketsTab(marketsAsync, 'EQUITY'),
          _buildMarketsTab(marketsAsync, 'COMMODITY'),
          _buildMarketsTab(marketsAsync, 'CRYPTO'),
          _buildMarketsTab(marketsAsync, 'US'),
          _buildLiveNewsView(context),
        ],
      ),
    );
  }

  Widget _buildMarketsTab(AsyncValue<List<InstrumentModel>> marketsAsync, String? categoryFilter) {
    return marketsAsync.when(
      data: (instruments) => _buildAssetList(instruments, categoryFilter),
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
    );
  }

  Widget _buildAssetList(List<InstrumentModel> allInstruments, String? categoryFilter) {
    final rawQ = _searchController.text.toLowerCase().trim();
    final normQ = rawQ.replaceAll('adhani', 'adani');
    final filtered = allInstruments.where((item) {
      final matchesCategory = categoryFilter == null
          ? true
          : (categoryFilter == 'EQUITY'
              ? (item.category == 'EQUITY' || item.category == 'INDEX')
              : item.category == categoryFilter);
      final sym = item.symbol.toLowerCase();
      final nm = item.name.toLowerCase();
      final matchesQuery = rawQ.isEmpty ||
          sym.contains(rawQ) ||
          nm.contains(rawQ) ||
          sym.contains(normQ) ||
          nm.contains(normQ);
      return matchesCategory && matchesQuery;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No instruments found matching "$rawQ"', style: AppTypography.bodyMd),
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
                ref.read(liveQuotesProvider.notifier).trackSymbol(item.symbol);
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final live = ref.watch(liveQuoteForSymbolProvider(item.symbol));
                      final displayPrice = (live != null && live.price > 0) ? live.price : item.price;
                      final displayChange = live != null ? live.change : item.change;
                      final displayPct = live != null ? live.changePercent : item.changePercent;
                      final itemIsPos = displayChange >= 0;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currency${displayPrice.toStringAsFixed(2)}',
                            style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${itemIsPos ? '+' : ''}${displayChange.toStringAsFixed(2)} (${displayPct.toStringAsFixed(2)}%)',
                            style: AppTypography.numericTable.copyWith(
                              color: itemIsPos ? AppColors.secondary : AppColors.tertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    key: ValueKey('tv_chart_btn_${item.symbol}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      ref.read(liveQuotesProvider.notifier).trackSymbol(item.symbol);
                      ref.read(selectedTradeInstrumentProvider.notifier).state = item;
                      context.push('/tradingview-pro');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.zerodhaBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.zerodhaBlue.withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.show_chart, color: AppColors.zerodhaBlue, size: 18),
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

  Widget _buildLiveNewsView(BuildContext context) {
    final selectedCategory = ref.watch(newsCategoryProvider);
    final newsAsync = ref.watch(newsProvider);

    const categories = [
      {'label': 'All Feeds', 'value': 'ALL'},
      {'label': 'Equities', 'value': 'EQUITY'},
      {'label': 'Crypto', 'value': 'CRYPTO'},
      {'label': 'Commodities', 'value': 'COMMODITY'},
      {'label': 'Macro Economy', 'value': 'MACRO'},
    ];

    return Column(
      children: [
        // Category Filter Chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = selectedCategory == cat['value'];

              return ChoiceChip(
                label: Text(
                  cat['label']!,
                  style: AppTypography.labelSm.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.outline,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryBrand.withOpacity(0.2),
                backgroundColor: AppColors.surfaceContainer,
                side: BorderSide(
                  color: isSelected ? AppColors.primaryBrand : AppColors.borderSubtle,
                ),
                onSelected: (val) {
                  if (val) {
                    ref.read(newsCategoryProvider.notifier).state = cat['value']!;
                  }
                },
              );
            },
          ),
        ),
        // News Feed List
        Expanded(
          child: newsAsync.when(
            data: (articles) {
              if (articles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.newspaper, size: 48, color: AppColors.outline),
                      const SizedBox(height: 12),
                      Text('No articles available for $selectedCategory', style: AppTypography.bodyMd),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(newsProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return _buildNewsCard(context, article);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load news feed', style: AppTypography.bodyMd),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.refresh(newsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsArticle article) {
    Color sentimentColor;
    IconData sentimentIcon;

    switch (article.sentiment.toUpperCase()) {
      case 'BULLISH':
        sentimentColor = AppColors.secondary;
        sentimentIcon = Icons.trending_up;
        break;
      case 'BEARISH':
        sentimentColor = AppColors.tertiary;
        sentimentIcon = Icons.trending_down;
        break;
      default:
        sentimentColor = AppColors.outline;
        sentimentIcon = Icons.horizontal_rule;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                article.source,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sentimentIcon, size: 12, color: sentimentColor),
                    const SizedBox(width: 4),
                    Text(
                      article.sentiment,
                      style: AppTypography.labelSm.copyWith(
                        color: sentimentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: AppTypography.bodyLg.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Wrap(
                spacing: 6,
                children: article.relatedSymbols.map((sym) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      sym,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text(
                '${article.readTimeMinutes} min read',
                style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
