import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';

class CandleQuery {
  final String symbol;
  final String interval;

  const CandleQuery({required this.symbol, required this.interval});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CandleQuery && other.symbol == symbol && other.interval == interval);

  @override
  int get hashCode => Object.hash(symbol, interval);
}

final selectedTradeInstrumentProvider = StateProvider<InstrumentModel>((ref) {
  return const InstrumentModel(
    symbol: 'RELIANCE',
    name: 'Reliance Industries Ltd.',
    exchange: 'NSE',
    category: 'EQUITY',
    price: 2945.50,
    change: 18.40,
    changePercent: 0.63,
    isPositive: true,
    isSimulated: true,
  );
});

final selectedCandleIntervalProvider = StateProvider<String>((ref) => '15m');

final candlesProvider = FutureProvider.family<List<CandleData>, CandleQuery>((ref, query) async {
  final authState = ref.watch(authProvider);

  if (authState.isDemoMode) {
    // Generate deterministic demo candles scaled to the instrument's price and interval
    final selectedInst = ref.watch(selectedTradeInstrumentProvider);
    final double basePrice = (selectedInst.symbol == query.symbol)
        ? selectedInst.price
        : _getDefaultPrice(query.symbol);

    final intervalSeconds = _intervalToSeconds(query.interval);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<CandleData> demoCandles = [];
    double current = basePrice;

    for (int i = 35; i >= 0; i--) {
      final t = now - (i * intervalSeconds);
      final seed = ((query.symbol.codeUnitAt(0) + i) % 7) - 3;
      final change = (basePrice * 0.003 * seed);
      final o = current;
      final c = (current + change) > 0 ? (current + change) : current;
      final h = (o > c ? o : c) + (basePrice * 0.002);
      final l = (o < c ? o : c) - (basePrice * 0.002);

      demoCandles.add(CandleData(
        timestamp: t,
        open: double.parse(o.toStringAsFixed(2)),
        high: double.parse(h.toStringAsFixed(2)),
        low: double.parse((l > 0 ? l : 0.01).toStringAsFixed(2)),
        close: double.parse(c.toStringAsFixed(2)),
        volume: 15000 + (i * 1100).toDouble(),
      ));
      current = c;
    }
    return demoCandles;
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/market-data/candles/${query.symbol}',
      queryParameters: {'interval': query.interval, 'limit': 45},
    );

    if (response.statusCode == 200 && response.data?['success'] == true) {
      final list = response.data!['candles'] as List<dynamic>? ?? [];
      return list.map((c) => CandleData.fromJson(c as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return const [];
});

int _intervalToSeconds(String interval) {
  switch (interval) {
    case '1m':
      return 60;
    case '5m':
      return 300;
    case '15m':
      return 900;
    case '1h':
      return 3600;
    case '1d':
      return 86400;
    case '1w':
      return 604800;
    default:
      return 900;
  }
}

double _getDefaultPrice(String symbol) {
  switch (symbol.toUpperCase()) {
    case 'BTC/USDT':
      return 67420.0;
    case 'ETH/USDT':
      return 2540.0;
    case 'TCS':
      return 4120.0;
    case 'HDFCBANK':
      return 1720.80;
    case 'GOLD 1KG':
      return 78450.0;
    case 'NVDA':
      return 141.54;
    case 'NIFTY 50':
      return 24852.15;
    default:
      return 2945.50;
  }
}

final orderHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.isDemoMode) {
    return [
      {
        'id': 'ord_demo_1',
        'symbol': 'RELIANCE',
        'side': 'BUY',
        'orderType': 'MARKET',
        'product': 'CNC',
        'quantity': 10,
        'averagePrice': 2945.50,
        'status': 'FILLED',
        'createdAt': DateTime.now().toIso8601String(),
      }
    ];
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>('/orders');
    if (response.statusCode == 200 && response.data?['success'] == true) {
      return (response.data!['orders'] as List<dynamic>? ?? [])
          .map((o) => o as Map<String, dynamic>)
          .toList();
    }
  } catch (_) {}

  return const [];
});

final submitOrderProvider = Provider<SubmitOrderService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final isDemo = ref.watch(authProvider).isDemoMode;
  return SubmitOrderService(apiClient: apiClient, isDemo: isDemo, ref: ref);
});

class SubmitOrderService {
  final ApiClient apiClient;
  final bool isDemo;
  final Ref ref;

  SubmitOrderService({required this.apiClient, required this.isDemo, required this.ref});

  Future<Map<String, dynamic>> submitOrder({
    required String symbol,
    required String exchange,
    required String side,
    required String orderType,
    required String product,
    required int quantity,
    double? limitPrice,
    double? triggerPrice,
  }) async {
    if (isDemo) {
      // Demo execution simulation
      final fillPrice = limitPrice ?? 2945.50;
      final turnover = fillPrice * quantity;
      const brokerage = 20.0;
      final taxes = turnover * 0.001;

      // Refresh portfolio in UI
      ref.invalidate(portfolioProvider);
      ref.invalidate(orderHistoryProvider);

      return {
        'success': true,
        'message': 'Simulated order executed in Demo Sandbox.',
        'order': {
          'id': 'ord_demo_${DateTime.now().millisecondsSinceEpoch}',
          'symbol': symbol,
          'status': 'FILLED',
          'filledQuantity': quantity,
          'averagePrice': fillPrice,
        },
        'execution': {
          'executionPrice': fillPrice,
          'fees': brokerage + taxes,
          'slippage': 0.05,
          'isSimulated': true,
        },
      };
    }

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/orders',
        data: {
          'symbol': symbol,
          'exchange': exchange,
          'side': side,
          'orderType': orderType,
          'product': product,
          'quantity': quantity,
          if (limitPrice != null) 'limitPrice': limitPrice,
          if (triggerPrice != null) 'triggerPrice': triggerPrice,
          'idempotencyKey': 'app_${DateTime.now().millisecondsSinceEpoch}_$symbol',
        },
      );

      if (response.statusCode == 201 && response.data?['success'] == true) {
        ref.invalidate(portfolioProvider);
        ref.invalidate(orderHistoryProvider);
        return response.data!;
      } else {
        return {
          'success': false,
          'message': response.data?['message'] as String? ?? 'Order execution failed.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
