import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/constants/api_constants.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';

final isOfflineFallbackActiveProvider = StateProvider<bool>((ref) => false);

final marketOverviewProvider = FutureProvider<List<InstrumentModel>>((ref) async {
  final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  if (!isTest) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.get<Map<String, dynamic>>('/market-data/quotes');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final list = response.data!['quotes'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          ref.read(isOfflineFallbackActiveProvider.notifier).state = false;
          return list.map((q) => InstrumentModel.fromJson(q as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Fallback to baseline demo instruments if backend unreachable
      ref.read(isOfflineFallbackActiveProvider.notifier).state = true;
    }
  }

  // Demo baseline instruments (explicitly labelled)
  return const [
    InstrumentModel(
      symbol: 'JIOFIN',
      name: 'Jio Financial Services Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 320.00,
      change: 3.50,
      changePercent: 1.11,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'YESBANK',
      name: 'Yes Bank Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 20.45,
      change: 0.35,
      changePercent: 1.74,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'IDEA',
      name: 'Vodafone Idea Limited (Vi)',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 8.45,
      change: 0.15,
      changePercent: 1.81,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'KNRCON',
      name: 'KNR Constructions Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 335.20,
      change: 5.60,
      changePercent: 1.70,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'NIFTY 50',
      name: 'Nifty 50 Index',
      exchange: 'NSE',
      category: 'INDEX',
      price: 24852.15,
      change: 178.95,
      changePercent: 0.72,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'BANKNIFTY',
      name: 'Nifty Bank Index',
      exchange: 'NSE',
      category: 'INDEX',
      price: 51820.00,
      change: 345.50,
      changePercent: 0.67,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'SENSEX',
      name: 'BSE Sensex Index',
      exchange: 'BSE',
      category: 'INDEX',
      price: 81420.30,
      change: 524.10,
      changePercent: 0.65,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'RELIANCE',
      name: 'Reliance Industries Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 2945.50,
      change: 18.40,
      changePercent: 0.63,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1720.80,
      change: 12.10,
      changePercent: 0.71,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 4120.00,
      change: -24.50,
      changePercent: -0.59,
      isPositive: false,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'INFY',
      name: 'Infosys Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1885.20,
      change: 15.30,
      changePercent: 0.82,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ICICIBANK',
      name: 'ICICI Bank Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1260.40,
      change: 8.50,
      changePercent: 0.68,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'SBIN',
      name: 'State Bank of India',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 815.75,
      change: 6.25,
      changePercent: 0.77,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'TATAMOTORS',
      name: 'Tata Motors Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 960.50,
      change: 14.20,
      changePercent: 1.50,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'BAJFINANCE',
      name: 'Bajaj Finance Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 6850.00,
      change: 45.00,
      changePercent: 0.66,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'BHARTIARTL',
      name: 'Bharti Airtel Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1680.00,
      change: 22.00,
      changePercent: 1.33,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ITC',
      name: 'ITC Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 485.50,
      change: 3.20,
      changePercent: 0.66,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'LT',
      name: 'Larsen & Toubro Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 3560.00,
      change: 28.50,
      changePercent: 0.81,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ADANIENT',
      name: 'Adani Enterprises Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 2840.00,
      change: 35.50,
      changePercent: 1.27,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ADANIPORTS',
      name: 'Adani Ports and SEZ Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1360.50,
      change: 18.20,
      changePercent: 1.36,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ADANIGREEN',
      name: 'Adani Green Energy Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 1580.00,
      change: 24.00,
      changePercent: 1.54,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ATGL',
      name: 'Adani Total Gas Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 720.00,
      change: 9.50,
      changePercent: 1.34,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ADANIPOWER',
      name: 'Adani Power Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 590.00,
      change: 11.20,
      changePercent: 1.94,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'AMBUJACEM',
      name: 'Ambuja Cements Ltd. (Adani)',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 560.00,
      change: 6.80,
      changePercent: 1.23,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ZOMATO',
      name: 'Zomato Limited',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 265.00,
      change: 4.50,
      changePercent: 1.73,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'GOLD 1KG',
      name: 'MCX Gold Futures',
      exchange: 'MCX',
      category: 'COMMODITY',
      price: 78450.00,
      change: 420.00,
      changePercent: 0.55,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'SILVER 30KG',
      name: 'MCX Silver Futures',
      exchange: 'MCX',
      category: 'COMMODITY',
      price: 94200.00,
      change: 650.00,
      changePercent: 0.69,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'CRUDEOIL',
      name: 'Crude Oil 100 BBL',
      exchange: 'MCX',
      category: 'COMMODITY',
      price: 6120.00,
      change: -85.00,
      changePercent: -1.37,
      isPositive: false,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'BTC/USDT',
      name: 'Bitcoin 24/7 Simulator',
      exchange: 'CRYPTO',
      category: 'CRYPTO',
      price: 77568.00,
      change: 2140.00,
      changePercent: 3.28,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'ETH/USDT',
      name: 'Ethereum 24/7 Simulator',
      exchange: 'CRYPTO',
      category: 'CRYPTO',
      price: 2540.00,
      change: 68.00,
      changePercent: 2.75,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'SOL/USDT',
      name: 'Solana 24/7 Simulator',
      exchange: 'CRYPTO',
      category: 'CRYPTO',
      price: 178.50,
      change: 6.20,
      changePercent: 3.60,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'NVDA',
      name: 'NVIDIA Corp',
      exchange: 'US',
      category: 'US',
      price: 141.54,
      change: 4.20,
      changePercent: 3.06,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'AAPL',
      name: 'Apple Inc',
      exchange: 'US',
      category: 'US',
      price: 231.41,
      change: -1.15,
      changePercent: -0.49,
      isPositive: false,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'TSLA',
      name: 'Tesla Inc',
      exchange: 'US',
      category: 'US',
      price: 258.40,
      change: 8.50,
      changePercent: 3.40,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'MSFT',
      name: 'Microsoft Corp',
      exchange: 'US',
      category: 'US',
      price: 428.15,
      change: 3.40,
      changePercent: 0.80,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'AMZN',
      name: 'Amazon.com Inc',
      exchange: 'US',
      category: 'US',
      price: 188.20,
      change: 2.60,
      changePercent: 1.40,
      isPositive: true,
      isSimulated: true,
    ),
    InstrumentModel(
      symbol: 'META',
      name: 'Meta Platforms Inc',
      exchange: 'US',
      category: 'US',
      price: 582.00,
      change: 7.80,
      changePercent: 1.36,
      isPositive: true,
      isSimulated: true,
    ),
  ];
});

final watchlistsProvider = FutureProvider<List<WatchlistModel>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.isDemoMode) {
    return const [
      WatchlistModel(
        id: 'wl_demo_01',
        name: 'Default Watchlist',
        instruments: ['RELIANCE', 'HDFCBANK', 'TCS', 'BTC/USDT'],
        isDefault: true,
      ),
    ];
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(ApiConstants.watchlists);
    if (response.statusCode == 200 && response.data?['success'] == true) {
      final list = response.data!['watchlists'] as List<dynamic>? ?? [];
      return list.map((w) => WatchlistModel.fromJson(w as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return const [
    WatchlistModel(
      id: 'wl_fallback',
      name: 'Default Watchlist',
      instruments: ['RELIANCE', 'HDFCBANK', 'TCS', 'BTC/USDT'],
      isDefault: true,
    ),
  ];
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFilterProvider = StateProvider<String>((ref) => 'All');

final instrumentSearchResultsProvider = FutureProvider<List<InstrumentModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final filter = ref.watch(searchFilterProvider);
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  String exchangeParam = 'ALL';
  String categoryParam = 'ALL';

  if (filter == 'NSE') {
    exchangeParam = 'NSE';
  } else if (filter == 'BSE') {
    exchangeParam = 'BSE';
  } else if (filter == 'Crypto') {
    exchangeParam = 'CRYPTO';
  } else if (filter == 'US') {
    exchangeParam = 'US';
  } else if (filter == 'Indices') {
    categoryParam = 'INDEX';
  } else if (filter == 'ETFs') {
    categoryParam = 'ETF';
  }

  if (!isTest) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final endpoint = '/market/instruments/search?q=${Uri.encodeComponent(query)}&exchange=$exchangeParam&category=$categoryParam&limit=60';
      final response = await apiClient.get<Map<String, dynamic>>(endpoint);
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final list = response.data!['instruments'] as List<dynamic>? ?? [];
        ref.read(isOfflineFallbackActiveProvider.notifier).state = false;
        return list.map((item) => InstrumentModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
      ref.read(isOfflineFallbackActiveProvider.notifier).state = true;
    }
  }

  // Fallback in-memory filter
  final overview = await ref.watch(marketOverviewProvider.future);
  final q = query.toLowerCase();
  final nq = q.replaceAll('adhani', 'adani');

  return overview.where((item) {
    if (exchangeParam != 'ALL' && item.exchange.toUpperCase() != exchangeParam) return false;
    if (categoryParam != 'ALL' && item.category.toUpperCase() != categoryParam) return false;
    if (query.isEmpty) return true;

    final sym = item.symbol.toLowerCase();
    final name = item.name.toLowerCase();

    // Check aliases
    if ((q == 'vi' || q == 'vodafone' || q == 'idea') && sym == 'idea') return true;
    if (q == 'knr' && sym == 'knrcon') return true;
    if ((q == 'yes' || q == 'yes bank') && sym == 'yesbank') return true;
    if ((q == 'jio' || q == 'jio financial') && sym == 'jiofin') return true;

    return sym.contains(q) || name.contains(q) || sym.contains(nq) || name.contains(nq);
  }).toList();
});
