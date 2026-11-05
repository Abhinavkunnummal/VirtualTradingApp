import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/core/widgets/app_shimmer.dart';
import 'package:tradeverse_mobile/core/widgets/empty_state_view.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/recent_searches_service.dart';
import 'package:tradeverse_mobile/features/markets/domain/news_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/news_provider.dart';
import 'package:tradeverse_mobile/shared/widgets/instrument_row_tile.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const List<String> _filters = [
    'All Assets',
    'NSE',
    'BSE',
    'Crypto',
    'US',
    'Indices',
    'ETFs',
    'Commodities',
    'Mutual Funds',
    'IPOs',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
        if (value.trim().length >= 2) {
          ref.read(recentSearchesProvider.notifier).addSearch(value.trim());
        }
      }
    });
  }

  void _selectSearchTerm(String term) {
    HapticFeedback.selectionClick();
    _searchController.text = term;
    ref.read(searchQueryProvider.notifier).state = term;
    ref.read(recentSearchesProvider.notifier).addSearch(term);
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(instrumentSearchResultsProvider);
    final selectedFilter = ref.watch(searchFilterProvider);
    final recentSearches = ref.watch(recentSearchesProvider);
    final isOffline = ref.watch(isOfflineFallbackActiveProvider);
    final hasSearchText = _searchController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !hasSearchText,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasSearchText) {
          _searchController.clear();
          ref.read(searchQueryProvider.notifier).state = '';
          setState(() {});
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Markets & Discovery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
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
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              // 250ms Debounced Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search 500+ NSE, BSE, Crypto, US, ETFs...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              // Main Navigation Tabs (Discovery vs News)
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primaryBrand,
                indicatorWeight: 2.5,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.outline,
                labelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'All Assets'),
                  Tab(text: 'Live News Feed'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Fast Filtered Search & Discovery
            _buildDiscoveryTab(
              context,
              searchResultsAsync: searchResultsAsync,
              selectedFilter: selectedFilter,
              recentSearches: recentSearches,
              isOffline: isOffline,
            ),
            // Tab 2: Market News Feed
            _buildLiveNewsView(context),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDiscoveryTab(
    BuildContext context, {
    required AsyncValue<List<InstrumentModel>> searchResultsAsync,
    required String selectedFilter,
    required List<String> recentSearches,
    required bool isOffline,
  }) {
    return Column(
      children: [
        if (isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              border: const Border(
                bottom: BorderSide(color: AppColors.warning, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline, limited list — Showing cached instruments. Connect to backend for full catalog.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Horizontal Filter Chips Bar (All Assets, NSE, BSE, Crypto, US, Indices, ETFs)
        Container(
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLowest,
            border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = selectedFilter == filter || (selectedFilter == 'All' && filter == 'All Assets');

              return ChoiceChip(
                label: Text(
                  filter,
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
                    HapticFeedback.selectionClick();
                    ref.read(searchFilterProvider.notifier).state = filter == 'All Assets' ? 'All' : filter;
                  }
                },
              );
            },
          ),
        ),

        // Recent Searches Ribbon (visible when search input is empty)
        if (_searchController.text.trim().isEmpty && recentSearches.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 14, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text(
                          'Recent Searches',
                          style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(recentSearchesProvider.notifier).clearAll();
                      },
                      child: Text(
                        'Clear all',
                        style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: recentSearches.map((term) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.north_west, size: 12, color: AppColors.outline),
                          label: Text(term, style: AppTypography.labelSm.copyWith(fontSize: 11, color: AppColors.onSurface)),
                          backgroundColor: AppColors.surfaceContainer,
                          side: const BorderSide(color: AppColors.borderSubtle),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () => _selectSearchTerm(term),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

        // Instruments Results List
        Expanded(
          child: searchResultsAsync.when(
            data: (instruments) => _buildAssetList(context, instruments),
            loading: () => const WatchlistSkeleton(count: 6),
            error: (err, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load market data', style: AppTypography.bodyLg),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.refresh(instrumentSearchResultsProvider),
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

  Widget _buildAssetList(BuildContext context, List<InstrumentModel> instruments) {
    if (instruments.isEmpty) {
      final q = _searchController.text.trim();
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: q.isEmpty ? 'No Instruments Found' : 'No Matches for "$q"',
        message: q.isEmpty
            ? 'Try selecting a different asset category or clearing the active filter.'
            : 'Check for typos or try searching by stock ticker, company name, or ISIN.',
        actionLabel: q.isNotEmpty ? 'Clear Search' : 'Show All Assets',
        onAction: () {
          HapticFeedback.lightImpact();
          _searchController.clear();
          ref.read(searchQueryProvider.notifier).state = '';
          ref.read(searchFilterProvider.notifier).state = 'All';
          setState(() {});
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(instrumentSearchResultsProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        itemCount: instruments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = instruments[index];
          final currency = item.currency == 'USD' || item.category == 'US' || item.category == 'CRYPTO' ? '\$' : '₹';
          final live = ref.watch(liveQuoteForSymbolProvider(item.symbol));
          final displayPrice = (live != null && live.price > 0) ? live.price : item.price;
          final displayChange = live != null ? live.change : item.change;
          final displayPct = live != null ? live.changePercent : item.changePercent;

          return InstrumentRowTile(
            key: ValueKey('market_tile_${item.symbol}'),
            symbol: item.symbol,
            name: item.name,
            exchange: item.exchange,
            category: item.category,
            price: displayPrice,
            change: displayChange,
            changePercent: displayPct,
            lotSize: item.lotSize,
            tickSize: item.tickSize,
            currency: currency,
            showSparkline: true,
            showTradeButton: true,
            tradeButtonKey: ValueKey('order_btn_${item.symbol}'),
            onTap: () {
              ref.read(liveQuotesProvider.notifier).trackSymbol(item.symbol);
              ref.read(selectedTradeInstrumentProvider.notifier).state = item;
              ref.read(recentSearchesProvider.notifier).addSearch(item.symbol);
              context.push('/tradingview-pro');
            },
            onTradeTap: () {
              ref.read(liveQuotesProvider.notifier).trackSymbol(item.symbol);
              ref.read(selectedTradeInstrumentProvider.notifier).state = item;
              ref.read(recentSearchesProvider.notifier).addSearch(item.symbol);
              context.go('/trade');
            },
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
                    HapticFeedback.selectionClick();
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
                return EmptyStateView(
                  icon: Icons.newspaper_outlined,
                  title: 'No Market News',
                  message: 'No news updates currently available in $selectedCategory feed.',
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
            loading: () => const OrdersSkeleton(count: 4),
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
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
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
              ),
              const SizedBox(width: 8),
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
