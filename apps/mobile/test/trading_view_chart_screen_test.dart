import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trading_view_chart_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPortfolioNotifier extends StateNotifier<AsyncValue<PortfolioModel>> implements PortfolioNotifier {
  _MockPortfolioNotifier(PortfolioModel model) : super(AsyncValue.data(model));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testInstrument = InstrumentModel(
    symbol: 'BTC/USDT',
    name: 'Bitcoin',
    exchange: 'BINANCE',
    category: 'CRYPTO',
    price: 77645.0,
    change: 1250.0,
    changePercent: 1.63,
    isPositive: true,
    isSimulated: true,
  );

  const holdingInstrument = InstrumentModel(
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

  Widget createWidget({InstrumentModel? instrument}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
        portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
        selectedTradeInstrumentProvider.overrideWith((ref) => instrument ?? testInstrument),
      ],
      child: MaterialApp(
        home: TradingViewChartScreen(instrument: instrument ?? testInstrument),
      ),
    );
  }

  group('TradingViewChartScreen Widget Tests', () {
    testWidgets('renders header, symbol, exchange, canvas fallback, and buy/sell dock', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // 1. Verify Header info
      expect(find.text('BTC/USDT'), findsOneWidget);
      expect(find.text('BINANCE'), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);

      // 2. Fallback canvas chart is active in test environment
      expect(find.byType(CandlestickChartView), findsOneWidget);

      // 3. Quick Action Dock with BUY / SELL buttons
      expect(find.textContaining('BUY \$77645.00'), findsOneWidget);
      expect(find.textContaining('SELL \$77645.00'), findsOneWidget);
    });

    testWidgets('allows switching timeframe intervals (1m, 5m, 15m, 1h, 1d)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Timeframe buttons exist in pro toolbar
      expect(find.text('1M'), findsWidgets);
      expect(find.text('5M'), findsWidgets);
      expect(find.text('15M'), findsWidgets);
      expect(find.text('1H'), findsWidgets);
      expect(find.text('1D'), findsWidgets);

      // Tap 5M timeframe
      await tester.tap(find.text('5M').first);
      await tester.pumpAndSettle();

      // Tap 1H timeframe
      await tester.tap(find.text('1H').first);
      await tester.pumpAndSettle();
    });

    testWidgets('allows switching chart types via toolbar icons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Check chart type icons exist
      expect(find.byIcon(Icons.candlestick_chart), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
      expect(find.byIcon(Icons.area_chart), findsOneWidget);
      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);

      // Tap line chart icon
      await tester.tap(find.byIcon(Icons.show_chart));
      await tester.pumpAndSettle();

      // Tap area chart icon
      await tester.tap(find.byIcon(Icons.area_chart));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping BUY opens QuickOrderSheet, allows product and lot adjustments, and executes order', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap BUY button
      await tester.tap(find.textContaining('BUY \$77645.00'));
      await tester.pumpAndSettle();

      // Order sheet opens
      expect(find.text('REAL-TIME PRICE'), findsOneWidget);
      expect(find.text('INTRADAY (MIS)'), findsOneWidget);
      expect(find.text('DELIVERY (CNC)'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // default quantity 10 lots

      // Increase quantity to 11
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);

      // Switch to DELIVERY (CNC)
      await tester.tap(find.text('DELIVERY (CNC)'));
      await tester.pumpAndSettle();

      // Confirm order execution
      final confirmBtn = find.text('Confirm BUY Order');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify success snackbar
      expect(find.textContaining('BUY Booked Successfully!'), findsOneWidget);
    });

    testWidgets('renders OPEN POSITION and LIVE P&L ribbon when holding exists for instrument', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pass RELIANCE which is present in PortfolioModel.demo()
      await tester.pumpWidget(createWidget(instrument: holdingInstrument));
      await tester.pumpAndSettle();

      // Open Position ribbon should appear
      expect(find.textContaining('OPEN POSITION: 150 LOTS'), findsOneWidget);
      expect(find.text('LIVE P&L'), findsOneWidget);
      expect(find.textContaining('Avg Entry: ₹2880.00'), findsOneWidget);
    });

    testWidgets('toggles between Lightweight Chart and Canvas Chart via appbar action icon', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Initially in canvas chart in test environment, icon shows web switch
      expect(find.byIcon(Icons.web), findsOneWidget);

      // Tap toggle icon to switch mode
      await tester.tap(find.byIcon(Icons.web));
      await tester.pumpAndSettle();

      // Icon should now be brush (canvas switcher)
      expect(find.byIcon(Icons.brush), findsOneWidget);
    });
  });
}
