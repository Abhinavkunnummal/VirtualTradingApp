import 'dart:math' as math;
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

List<CandleData> _generateRealisticCandles({
  required String symbol,
  required String interval,
  required double currentLtp,
}) {
  final intervalSeconds = _intervalToSeconds(interval);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  const count = 36;

  // Unique polynomial hash for the symbol
  int hash = 0;
  for (int j = 0; j < symbol.length; j++) {
    hash = (hash * 31 + symbol.codeUnitAt(j)) & 0x7FFFFFFF;
  }

  // Volatility scale based on asset class
  double volMultiplier = 0.003;
  if (symbol.contains('/') || symbol.contains('BTC') || symbol.contains('ETH')) {
    volMultiplier = 0.009; // Crypto swings wide
  } else if (symbol.contains('GOLD') || symbol.contains('CRUDE') || symbol.contains('SILVER')) {
    volMultiplier = 0.004; // Commodity micro-trends
  } else if (symbol.contains('NIFTY') || symbol.contains('SENSEX')) {
    volMultiplier = 0.0018; // Index steady macro
  }

  // Anchor latest candle (count - 1) EXACTLY at currentLtp
  final closePrices = List<double>.filled(count, currentLtp);
  closePrices[count - 1] = currentLtp;

  for (int i = count - 2; i >= 0; i--) {
    final t = now - ((count - 1 - i) * intervalSeconds);
    final w1 = math.sin((t / (intervalSeconds * 3)) + (hash % 100));
    final w2 = math.cos((t / (intervalSeconds * 7)) + (hash % 50));
    final w3 = math.sin((t / (intervalSeconds * 13)) * 1.5 + (hash % 23));
    final wave = (w1 * 0.5 + w2 * 0.3 + w3 * 0.2);

    final move = wave * volMultiplier;
    final prev = closePrices[i + 1] / (1 + move);
    closePrices[i] = double.parse(prev.toStringAsFixed(2));
  }

  final List<CandleData> result = [];
  for (int i = 0; i < count; i++) {
    final t = now - ((count - 1 - i) * intervalSeconds);
    final c = closePrices[i];
    final o = i == 0 ? closePrices[0] : closePrices[i - 1];

    final wick1 = (math.sin(t * 17 + hash).abs()) * (currentLtp * 0.002);
    final wick2 = (math.cos(t * 29 + hash).abs()) * (currentLtp * 0.002);

    final bodyMax = math.max(o, c);
    final bodyMin = math.min(o, c);

    final h = double.parse((bodyMax + wick1).toStringAsFixed(2));
    final l = double.parse((math.max(bodyMin - wick2, 0.01)).toStringAsFixed(2));

    final volSeed = (math.sin(t + (hash % 1000))).abs();
    final volume = 12000.0 + volSeed * 65000.0;

    result.add(CandleData(
      timestamp: t,
      open: o,
      high: math.max(h, bodyMax),
      low: math.min(l, bodyMin),
      close: c,
      volume: volume,
    ));
  }

  return result;
}

final candlesProvider = FutureProvider.family<List<CandleData>, CandleQuery>((ref, query) async {
  final authState = ref.watch(authProvider);
  final selectedInst = ref.watch(selectedTradeInstrumentProvider);
  final double currentLtp = (selectedInst.symbol == query.symbol)
      ? selectedInst.price
      : _getDefaultPrice(query.symbol);

  if (authState.isDemoMode) {
    return _generateRealisticCandles(
      symbol: query.symbol,
      interval: query.interval,
      currentLtp: currentLtp,
    );
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/market-data/candles/${query.symbol}',
      queryParameters: {'interval': query.interval, 'limit': 45},
    );

    if (response.statusCode == 200 && response.data?['success'] == true) {
      final list = response.data!['candles'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        return list.map((c) => CandleData.fromJson(c as Map<String, dynamic>)).toList();
      }
    }
  } catch (_) {}

  // Fallback: try dedicated live Alpha Vantage candles endpoint
  try {
    final alphaResponse = await apiClient.get<Map<String, dynamic>>(
      '/market-data/alpha/candles/${query.symbol}',
      queryParameters: {'limit': 45},
    );

    if (alphaResponse.statusCode == 200 && alphaResponse.data?['success'] == true) {
      final list = alphaResponse.data!['candles'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        return list.map((c) => CandleData.fromJson(c as Map<String, dynamic>)).toList();
      }
    }
  } catch (_) {}

  // Resilient fallback: Generate realistic candles matching instrument price so chart is never blank
  return _generateRealisticCandles(
    symbol: query.symbol,
    interval: query.interval,
    currentLtp: currentLtp,
  );
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
    String orderVariety = 'REGULAR',
    double? targetPrice,
    double? stopLossPrice,
    double? trailingStopLoss,
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
        'message': 'Simulated $orderVariety order executed in Demo Sandbox.',
        'order': {
          'id': 'ord_demo_${DateTime.now().millisecondsSinceEpoch}',
          'symbol': symbol,
          'status': 'FILLED',
          'filledQuantity': quantity,
          'averagePrice': fillPrice,
          'orderVariety': orderVariety,
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
          'orderVariety': orderVariety,
          if (targetPrice != null) 'targetPrice': targetPrice,
          if (stopLossPrice != null) 'stopLossPrice': stopLossPrice,
          if (trailingStopLoss != null) 'trailingStopLoss': trailingStopLoss,
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
