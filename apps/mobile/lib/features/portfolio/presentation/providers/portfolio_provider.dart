import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/constants/api_constants.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
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
}
