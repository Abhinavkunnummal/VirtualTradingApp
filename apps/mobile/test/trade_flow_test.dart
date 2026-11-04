import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trade_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/order_confirmation_sheet.dart';

void main() {
  testWidgets('TradeScreen renders candlestick chart, responds to product & order types, and executes order',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
          selectedTradeInstrumentProvider.overrideWith((ref) => const InstrumentModel(
                symbol: 'RELIANCE',
                name: 'Reliance Industries Ltd.',
                exchange: 'NSE',
                category: 'EQUITY',
                price: 2945.50,
                change: 18.40,
                changePercent: 0.63,
                isPositive: true,
                isSimulated: true,
              )),
        ],
        child: const MaterialApp(
          home: TradeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Title & Instrument
    expect(find.text('Order Ticket & Execution'), findsOneWidget);
    expect(find.text('RELIANCE'), findsWidgets);
    expect(find.text('Reliance Industries Ltd.'), findsOneWidget);

    // 2. Verify Candlestick Chart with SIMULATED badge
    expect(find.byType(CandlestickChartView), findsOneWidget);
    expect(find.textContaining('SIMULATED'), findsWidgets);

    // 3. Verify Product Selection (CNC vs MIS)
    expect(find.text('Delivery (CNC)'), findsOneWidget);
    expect(find.text('Intraday (MIS)'), findsOneWidget);

    // Tap Intraday (MIS)
    await tester.tap(find.text('Intraday (MIS)'));
    await tester.pumpAndSettle();

    // 4. Verify Execution Modes
    expect(find.text('MARKET'), findsOneWidget);
    expect(find.text('LIMIT'), findsOneWidget);
    expect(find.text('SL'), findsOneWidget);
    expect(find.text('SL_M'), findsOneWidget);

    // 5. Verify Margin Breakdown
    expect(find.text('Required Margin'), findsOneWidget);
    expect(find.text('Simulated Brokerage'), findsOneWidget);

    // 6. Test Placing Simulated Order
    final buyButton = find.text('Place Simulated BUY Order');
    expect(buyButton, findsOneWidget);
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    // Verify confirmation sheet
    expect(find.byType(OrderConfirmationSheet), findsOneWidget);
    expect(find.text('Order Executed Successfully'), findsOneWidget);

    // Close Dialog / Sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 7. Verify Order History Bottom Sheet
    final historyIcon = find.byIcon(Icons.receipt_long_outlined);
    expect(historyIcon, findsOneWidget);
    await tester.tap(historyIcon);
    await tester.pumpAndSettle();

    expect(find.text('Simulated Order Book'), findsOneWidget);
  });
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPortfolioNotifier extends StateNotifier<AsyncValue<PortfolioModel>> implements PortfolioNotifier {
  _MockPortfolioNotifier(PortfolioModel model) : super(AsyncValue.data(model));

  @override
  void addHolding({
    required String symbol,
    required String exchange,
    required int quantity,
    required double buyPrice,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
