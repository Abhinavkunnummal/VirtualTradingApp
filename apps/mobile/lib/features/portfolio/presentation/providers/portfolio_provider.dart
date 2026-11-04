import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/constants/api_constants.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/core/network/live_ticker_service.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';

final paperAccountProvider = FutureProvider<PaperAccountModel>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.isDemoMode) {
    return const PaperAccountModel(
      id: 'demo_acc_01',
      accountName: 'Sandbox v2.4 (Demo Mode)',
      baseCurrency: 'INR',
      startingCapital: 1000000.0,
      availableCash: 425000.0,
      reservedMargin: 0.0,
      isSimulated: true,
      disclaimer: 'Explicit Demo Sandbox • Fictional Funds',
    );
  }

  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>>(ApiConstants.paperAccount);
  if (response.statusCode == 200 && response.data?['success'] == true) {
    return PaperAccountModel.fromJson(response.data!['account'] as Map<String, dynamic>);
  }
  throw Exception('Failed to load virtual paper account');
});

final portfolioProvider = StateNotifierProvider<PortfolioNotifier, AsyncValue<PortfolioModel>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authState = ref.watch(authProvider);
  return PortfolioNotifier(apiClient: apiClient, isDemo: authState.isDemoMode);
});

class PortfolioNotifier extends StateNotifier<AsyncValue<PortfolioModel>> {
  final ApiClient apiClient;
  final bool isDemo;

  PortfolioNotifier({required this.apiClient, required this.isDemo})
      : super(const AsyncValue.loading()) {
    fetchPortfolio();
  }

  Future<void> fetchPortfolio() async {
    state = const AsyncValue.loading();
    if (isDemo) {
      state = AsyncValue.data(PortfolioModel.demo());
      return;
    }

    try {
      final response = await apiClient.get<Map<String, dynamic>>(ApiConstants.portfolio);
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final model = PortfolioModel.fromJson(response.data!['portfolio'] as Map<String, dynamic>);
        state = AsyncValue.data(model);
      } else {
        state = AsyncValue.error('Unable to fetch portfolio data', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> resetCapital(double newCapital) async {
    if (isDemo) {
      state = AsyncValue.data(
        PortfolioModel(
          totalPortfolioValue: newCapital,
          availableCash: newCapital,
          investedValue: 0,
          startingCapital: newCapital,
          totalPnl: 0,
          totalPnlPercent: 0,
          isSimulated: true,
          holdings: const [],
        ),
      );
      return true;
    }

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.resetCapital,
        data: {'startingCapital': newCapital, 'resetPortfolio': true},
      );
      if (response.statusCode == 200 && response.data?['success'] == true) {
        await fetchPortfolio();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> topUpVirtualFunds(double amount) async {
    if (isDemo) {
      final current = state.valueOrNull ?? PortfolioModel.demo();
      state = AsyncValue.data(
        PortfolioModel(
          totalPortfolioValue: current.totalPortfolioValue + amount,
          availableCash: current.availableCash + amount,
          investedValue: current.investedValue,
          startingCapital: current.startingCapital,
          totalPnl: current.totalPnl,
          totalPnlPercent: current.totalPnlPercent,
          isSimulated: true,
          holdings: current.holdings,
        ),
      );
      return true;
    }

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/paper-account/top-up',
        data: {
          'amount': amount,
          'idempotencyKey': 'topup_${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      if (response.statusCode == 200 && response.data?['success'] == true) {
        await fetchPortfolio();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> withdrawVirtualFunds(double amount) async {
    if (isDemo) {
      final current = state.valueOrNull ?? PortfolioModel.demo();
      if (current.availableCash < amount) {
        return {'success': false, 'message': 'Insufficient available cash to withdraw.'};
      }
      state = AsyncValue.data(
        PortfolioModel(
          totalPortfolioValue: current.totalPortfolioValue - amount,
          availableCash: current.availableCash - amount,
          investedValue: current.investedValue,
          startingCapital: math.max(0.0, current.startingCapital - amount),
          totalPnl: current.totalPnl,
          totalPnlPercent: current.totalPnlPercent,
          isSimulated: true,
          holdings: current.holdings,
        ),
      );
      return {'success': true, 'message': 'Successfully withdrew virtual funds.'};
    }

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/paper-account/withdraw',
        data: {'amount': amount},
      );
      if (response.statusCode == 200 && response.data?['success'] == true) {
        await fetchPortfolio();
        return {'success': true, 'message': response.data?['message'] ?? 'Withdrawal successful.'};
      }
      return {
        'success': false,
        'message': response.data?['message'] as String? ?? 'Withdrawal failed.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  void squareOffHolding({
    required String symbol,
    int? quantity,
    required double exitPrice,
  }) {
    final current = state.valueOrNull ?? PortfolioModel.demo();
    final existingIndex = current.holdings.indexWhere((h) => h.symbol.toUpperCase() == symbol.toUpperCase());
    if (existingIndex < 0) return;

    final existing = current.holdings[existingIndex];
    final qtyToClose = quantity != null && quantity > 0 ? math.min(quantity, existing.quantity) : existing.quantity;
    final remaining = existing.quantity - qtyToClose;

    List<HoldingModel> newHoldings;
    if (remaining <= 0) {
      newHoldings = List.from(current.holdings)..removeAt(existingIndex);
    } else {
      final invested = remaining * existing.averageBuyPrice;
      final curVal = remaining * exitPrice;
      final pnl = curVal - invested;
      final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
      final updated = HoldingModel(
        id: existing.id,
        symbol: existing.symbol,
        exchange: existing.exchange,
        product: existing.product,
        quantity: remaining,
        averageBuyPrice: existing.averageBuyPrice,
        ltp: exitPrice,
        investedValue: invested,
        currentValue: curVal,
        unrealizedPnl: pnl,
        unrealizedPnlPercent: double.parse(pnlPct.toStringAsFixed(2)),
        stopLoss: existing.stopLoss,
        targetPrice: existing.targetPrice,
      );
      newHoldings = List.from(current.holdings)..[existingIndex] = updated;
    }

    final grossProceeds = qtyToClose * exitPrice;
    final fees = 20.0 + (grossProceeds * 0.001);
    final netProceeds = grossProceeds - fees;
    final newCash = current.availableCash + netProceeds;
    final newInvested = newHoldings.fold<double>(0, (sum, h) => sum + h.investedValue);
    final newCurVal = newHoldings.fold<double>(0, (sum, h) => sum + h.currentValue);
    final totalVal = newCash + newCurVal;
    final totalPnl = totalVal - current.startingCapital;
    final totalPnlPct = current.startingCapital > 0 ? (totalPnl / current.startingCapital) * 100 : 0.0;

    state = AsyncValue.data(
      PortfolioModel(
        totalPortfolioValue: totalVal,
        availableCash: newCash,
        investedValue: newInvested,
        startingCapital: current.startingCapital,
        totalPnl: totalPnl,
        totalPnlPercent: double.parse(totalPnlPct.toStringAsFixed(2)),
        isSimulated: current.isSimulated,
        holdings: newHoldings,
      ),
    );
  }

  void updateWithLiveQuotes(Map<String, LiveQuote> liveQuotes) {
    final current = state.valueOrNull;
    if (current == null || liveQuotes.isEmpty) return;

    bool changed = false;
    double newInvested = 0;
    double newCurrentValue = 0;

    final updatedHoldings = current.holdings.map((h) {
      final symKey = h.symbol.toUpperCase();
      final quote = liveQuotes[symKey];
      final ltp = (quote != null && quote.price > 0) ? quote.price : h.ltp;
      final invested = h.quantity * h.averageBuyPrice;
      final currentVal = h.quantity * ltp;
      final pnl = currentVal - invested;
      final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;

      if ((ltp - h.ltp).abs() > 0.001) changed = true;

      newInvested += invested;
      newCurrentValue += currentVal;

      return HoldingModel(
        id: h.id,
        symbol: h.symbol,
        exchange: h.exchange,
        quantity: h.quantity,
        averageBuyPrice: h.averageBuyPrice,
        ltp: ltp,
        investedValue: invested,
        currentValue: currentVal,
        unrealizedPnl: pnl,
        unrealizedPnlPercent: double.parse(pnlPct.toStringAsFixed(2)),
      );
    }).toList();

    if (changed) {
      final totalVal = current.availableCash + newCurrentValue;
      final totalPnl = totalVal - current.startingCapital;
      final totalPnlPct = current.startingCapital > 0 ? (totalPnl / current.startingCapital) * 100 : 0.0;

      state = AsyncValue.data(
        PortfolioModel(
          totalPortfolioValue: totalVal,
          availableCash: current.availableCash,
          investedValue: newInvested,
          startingCapital: current.startingCapital,
          totalPnl: totalPnl,
          totalPnlPercent: double.parse(totalPnlPct.toStringAsFixed(2)),
          isSimulated: current.isSimulated,
          holdings: updatedHoldings,
        ),
      );
    }
  }

  void addHolding({
    required String symbol,
    required String exchange,
    required int quantity,
    required double buyPrice,
  }) {
    final current = state.valueOrNull ?? PortfolioModel.demo();
    final existingIndex = current.holdings.indexWhere((h) => h.symbol.toUpperCase() == symbol.toUpperCase());

    List<HoldingModel> newHoldings;
    if (existingIndex >= 0) {
      final existing = current.holdings[existingIndex];
      final newQty = existing.quantity + quantity;
      final newAvg = ((existing.quantity * existing.averageBuyPrice) + (quantity * buyPrice)) / newQty;
      final invested = newQty * newAvg;
      final curVal = newQty * buyPrice;
      final pnl = curVal - invested;
      final pnlPct = invested > 0 ? (pnl / invested) * 100 : 0.0;

      final updated = HoldingModel(
        id: existing.id,
        symbol: existing.symbol,
        exchange: existing.exchange,
        quantity: newQty,
        averageBuyPrice: double.parse(newAvg.toStringAsFixed(2)),
        ltp: buyPrice,
        investedValue: invested,
        currentValue: curVal,
        unrealizedPnl: pnl,
        unrealizedPnlPercent: double.parse(pnlPct.toStringAsFixed(2)),
      );
      newHoldings = List.from(current.holdings)..[existingIndex] = updated;
    } else {
      final invested = quantity * buyPrice;
      final curVal = invested;
      final newHolding = HoldingModel(
        id: 'hold_${symbol.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        symbol: symbol,
        exchange: exchange,
        quantity: quantity,
        averageBuyPrice: buyPrice,
        ltp: buyPrice,
        investedValue: invested,
        currentValue: curVal,
        unrealizedPnl: 0.0,
        unrealizedPnlPercent: 0.0,
      );
      newHoldings = [newHolding, ...current.holdings];
    }

    final newInvested = newHoldings.fold<double>(0, (sum, h) => sum + h.investedValue);
    final newCurVal = newHoldings.fold<double>(0, (sum, h) => sum + h.currentValue);
    final totalTurnover = quantity * buyPrice;
    final newCash = math.max(0.0, current.availableCash - totalTurnover);
    final totalVal = newCash + newCurVal;
    final totalPnl = totalVal - current.startingCapital;
    final totalPnlPct = current.startingCapital > 0 ? (totalPnl / current.startingCapital) * 100 : 0.0;

    state = AsyncValue.data(
      PortfolioModel(
        totalPortfolioValue: totalVal,
        availableCash: newCash,
        investedValue: newInvested,
        startingCapital: current.startingCapital,
        totalPnl: totalPnl,
        totalPnlPercent: double.parse(totalPnlPct.toStringAsFixed(2)),
        isSimulated: current.isSimulated,
        holdings: newHoldings,
      ),
    );
  }
}

final walletTransactionsProvider = FutureProvider<List<WalletTransactionModel>>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.isDemoMode) {
    return [
      WalletTransactionModel(
        id: 'tx_demo_1',
        type: 'CAPITAL_TOPUP',
        amount: 500000.0,
        balanceAfter: 500000.0,
        description: 'Virtual practice fund deposit',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WalletTransactionModel(
        id: 'tx_demo_2',
        type: 'TRADE_FILL',
        amount: -75000.0,
        balanceAfter: 425000.0,
        description: 'Bought 1 BTC/USDT',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>('/paper-account/transactions');
    if (response.statusCode == 200 && response.data?['success'] == true) {
      final raw = response.data!['transactions'] as List<dynamic>? ?? [];
      return raw.map((t) => WalletTransactionModel.fromJson(t as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return const [];
});
