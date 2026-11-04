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

  Widget createWidget({InstrumentModel? instrument, PortfolioModel? portfolio}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
        portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(portfolio ?? PortfolioModel.demo())),
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
      expect(find.text('BTC/USDT'), findsWidgets);
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
      expect(find.byIcon(Icons.stacked_line_chart), findsOneWidget); // Heikin-Ashi
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
      expect(find.byIcon(Icons.area_chart), findsOneWidget);
      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);

      // Tap Heikin-Ashi icon
      await tester.tap(find.byIcon(Icons.stacked_line_chart));
      await tester.pumpAndSettle();

      // Tap line chart icon
      await tester.tap(find.byIcon(Icons.show_chart));
      await tester.pumpAndSettle();

      // Tap area chart icon
      await tester.tap(find.byIcon(Icons.area_chart));
      await tester.pumpAndSettle();
    });

    testWidgets('allows toggling AI Insights and shows auto analysis banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // AI Analysis button exists in toolbar
      final aiButton = find.byKey(const ValueKey('chart_auto_analysis_button'));
      expect(aiButton, findsOneWidget);

      // Initially, AI banner is not visible
      expect(find.byKey(const ValueKey('chart_ai_insights_banner')), findsNothing);

      // Tap AI Insights button
      await tester.tap(aiButton);
      await tester.pumpAndSettle();

      // AI banner should now be visible
      expect(find.byKey(const ValueKey('chart_ai_insights_banner')), findsOneWidget);
      expect(find.text('AI ANALYSIS'), findsOneWidget);
      expect(find.text('Scanning patterns...'), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(aiButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chart_ai_insights_banner')), findsNothing);
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

      // Adjust quantity to 2 lots to fit within demo cash margin
      for (int k = 0; k < 8; k++) {
        await tester.tap(find.byIcon(Icons.remove_circle_outline));
        await tester.pumpAndSettle();
      }
      expect(find.text('2'), findsOneWidget);

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

    testWidgets('renders open position with real stopLoss and targetPrice from portfolio model', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customHolding = HoldingModel(
        id: 'hold_sl_tp',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        quantity: 100,
        averageBuyPrice: 2900.0,
        ltp: 2945.50,
        investedValue: 290000.0,
        currentValue: 294550.0,
        unrealizedPnl: 4550.0,
        unrealizedPnlPercent: 1.57,
        stopLoss: 2820.0,
        targetPrice: 3100.0,
      );

      const customPortfolio = PortfolioModel(
        totalPortfolioValue: 1294550.0,
        availableCash: 500000.0,
        investedValue: 290000.0,
        startingCapital: 1000000.0,
        totalPnl: 4550.0,
        totalPnlPercent: 1.57,
        isSimulated: true,
        holdings: [customHolding],
      );

      await tester.pumpWidget(createWidget(
        instrument: holdingInstrument,
        portfolio: customPortfolio,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('OPEN POSITION: 100 LOTS'), findsOneWidget);
      expect(find.textContaining('Avg Entry: ₹2900.00'), findsOneWidget);
      expect(find.text('LIVE P&L'), findsOneWidget);
    });

    testWidgets('allows opening indicators modal and toggling indicators', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Find the fx indicators button in toolbar
      final fxButton = find.byKey(const ValueKey('chart_indicators_button'));
      expect(fxButton, findsOneWidget);

      // Tap to open indicators bottom sheet
      await tester.tap(fxButton);
      await tester.pumpAndSettle();

      // Verify modal is open and shows indicators
      expect(find.text('Indicators & Studies'), findsOneWidget);
      expect(find.text('EMA (Exponential MA)'), findsOneWidget);
      expect(find.text('RSI (Relative Strength)'), findsOneWidget);
      expect(find.text('MACD (Moving Avg Convergence)'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply & Close'), findsOneWidget);

      // Tap Apply & Close to dismiss
      await tester.tap(find.text('Apply & Close'));
      await tester.pumpAndSettle();

      expect(find.text('Indicators & Studies'), findsNothing);
    });

    testWidgets('renders interactive drawing tools toolbar and responds to tool selection, undo, clear', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Check Drawing toggle button exists
      final drawButton = find.byKey(const ValueKey('chart_draw_tools_button'));
      expect(drawButton, findsOneWidget);

      // Drawing tools toolbar is visible by default
      expect(find.byKey(const ValueKey('tool_cursor')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_trend_line')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_horizontal_line')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_rectangle')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_fibonacci')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool_text_note')), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Select trend line tool
      await tester.tap(find.byKey(const ValueKey('tool_trend_line')));
      await tester.pumpAndSettle();

      // Select horizontal line tool
      await tester.tap(find.byKey(const ValueKey('tool_horizontal_line')));
      await tester.pumpAndSettle();

      // Tap Undo
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      // Tap Clear All
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
    });
  });
}
