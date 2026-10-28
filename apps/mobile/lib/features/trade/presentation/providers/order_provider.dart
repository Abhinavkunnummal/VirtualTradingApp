import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';

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

final candlesProvider = FutureProvider.family<List<CandleData>, String>((ref, symbol) async {
  final interval = ref.watch(selectedCandleIntervalProvider);
  final authState = ref.watch(authProvider);

  if (authState.isDemoMode) {
    // Return deterministic demo candles
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<CandleData> demoCandles = [];
    double base = 2940.0;
    for (int i = 30; i >= 0; i--) {
      final t = now - (i * 900);
      final change = (i % 3 == 0) ? -6.0 : 8.0;
      final o = base;
      final c = base + change;
      final h = (o > c ? o : c) + 4.0;
      final l = (o < c ? o : c) - 3.0;
      demoCandles.add(CandleData(
        timestamp: t,
        open: o,
        high: h,
        low: l,
        close: c,
        volume: 25000 + (i * 1200).toDouble(),
      ));
      base = c;
    }
    return demoCandles;
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/market-data/candles/$symbol',
      queryParameters: {'interval': interval, 'limit': 45},
    );

    if (response.statusCode == 200 && response.data?['success'] == true) {
      final list = response.data!['candles'] as List<dynamic>? ?? [];
      return list.map((c) => CandleData.fromJson(c as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return const [];
});

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
