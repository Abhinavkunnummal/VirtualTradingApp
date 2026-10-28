import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../domain/market_models.dart';

final marketOverviewProvider = FutureProvider<List<InstrumentModel>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isDemoMode) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.get('/market-data/quotes');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['quotes'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          return list.map((q) => InstrumentModel.fromJson(q as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Fallback to baseline demo instruments if backend unreachable
    }
  }

  // Demo baseline instruments (explicitly labelled)
  return const [
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
      price: 67420.00,
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
    final response = await apiClient.get(ApiConstants.watchlists);
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['watchlists'] as List<dynamic>? ?? [];
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
