import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _allInstruments = [
    {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'exchange': 'NSE', 'cat': 'EQUITY', 'price': 2945.50, 'change': 18.40, 'pct': 0.63, 'isPos': true},
    {'symbol': 'TCS', 'name': 'Tata Consultancy Services', 'exchange': 'NSE', 'cat': 'EQUITY', 'price': 4120.00, 'change': -24.50, 'pct': -0.59, 'isPos': false},
    {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd.', 'exchange': 'NSE', 'cat': 'EQUITY', 'price': 1720.80, 'change': 12.10, 'pct': 0.71, 'isPos': true},
    {'symbol': 'INFY', 'name': 'Infosys Limited', 'exchange': 'NSE', 'cat': 'EQUITY', 'price': 1885.20, 'change': 15.30, 'pct': 0.82, 'isPos': true},
    {'symbol': 'GOLD 1KG', 'name': 'MCX Gold Futures', 'exchange': 'MCX', 'cat': 'COMMODITY', 'price': 78450.00, 'change': 420.00, 'pct': 0.55, 'isPos': true},
    {'symbol': 'CRUDEOIL', 'name': 'Crude Oil 100 BBL', 'exchange': 'MCX', 'cat': 'COMMODITY', 'price': 6120.00, 'change': -85.00, 'pct': -1.37, 'isPos': false},
    {'symbol': 'BTC/USDT', 'name': 'Bitcoin 24/7 Simulator', 'exchange': 'CRYPTO', 'cat': 'CRYPTO', 'price': 67420.00, 'change': 2140.00, 'pct': 3.28, 'isPos': true},
    {'symbol': 'ETH/USDT', 'name': 'Ethereum 24/7 Simulator', 'exchange': 'CRYPTO', 'cat': 'CRYPTO', 'price': 2540.00, 'change': 68.00, 'pct': 2.75, 'isPos': true},
    {'symbol': 'NVDA', 'name': 'NVIDIA Corp', 'exchange': 'US', 'cat': 'US', 'price': 141.54, 'change': 4.20, 'pct': 3.06, 'isPos': true},
    {'symbol': 'AAPL', 'name': 'Apple Inc', 'exchange': 'US', 'cat': 'US', 'price': 231.41, 'change': -1.15, 'pct': -0.49, 'isPos': false},
  ];

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Markets & Discovery', style: AppTypography.headlineSm),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssetList(null),
          _buildAssetList('EQUITY'),
          _buildAssetList('COMMODITY'),
          _buildAssetList('CRYPTO'),
          _buildAssetList('US'),
        ],
      ),
    );
  }

  Widget _buildAssetList(String? categoryFilter) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _allInstruments.where((item) {
      final matchesCategory = categoryFilter == null || item['cat'] == categoryFilter;
      final matchesQuery = query.isEmpty ||
          (item['symbol'] as String).toLowerCase().contains(query) ||
          (item['name'] as String).toLowerCase().contains(query);
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isPos = item['isPos'] as bool;
        final symbol = item['symbol'] as String;
        final currency = item['cat'] == 'US' || item['cat'] == 'CRYPTO' ? '\$' : '₹';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            onTap: () => context.go('/trade'),
            title: Row(
              children: [
                Text(symbol, style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['exchange'] as String,
                    style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline),
                  ),
                ),
              ],
            ),
            subtitle: Text(item['name'] as String, style: AppTypography.bodyMd.copyWith(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currency${item['price']}',
                  style: AppTypography.numericTable.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPos ? '+' : ''}${item['change']} (${item['pct']}%)',
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
    );
  }
}
