import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/auth/presentation/login_screen.dart';
import 'package:tradeverse_mobile/features/auth/presentation/register_screen.dart';
import 'package:tradeverse_mobile/features/shell/splash_screen.dart';
import 'package:tradeverse_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/markets_screen.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/portfolio_screen.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trade_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trading_view_chart_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/orders_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/order_confirmation_sheet.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/indicators_bottom_sheet.dart';
import 'package:tradeverse_mobile/features/trade/domain/chart_indicator_config.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/community/presentation/community_screen.dart';
import 'package:tradeverse_mobile/features/learn/presentation/learn_screen.dart';
import 'package:tradeverse_mobile/shared/widgets/error_state_widget.dart';

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
  const List<Size> testScreenSizes = [
    Size(320, 568), // Compact: iPhone SE
    Size(360, 640), // Android small
    Size(411, 891), // Android standard Pixel
    Size(640, 360), // Landscape mode
  ];

  void setScreenDimensions(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
  }

  void resetScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  }

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

  final defaultOverrides = [
    authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
    portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
    selectedTradeInstrumentProvider.overrideWith((ref) => testInstrument),
    marketOverviewProvider.overrideWith((ref) => Future.value([testInstrument])),
    orderHistoryProvider.overrideWith((ref) => Future.value([
      {
        'id': 'ord-test-1',
        'symbol': 'BTC/USDT',
        'side': 'BUY',
        'orderType': 'MARKET',
        'product': 'MIS',
        'quantity': 1,
        'averagePrice': 77645.0,
        'status': 'FILLED',
        'exchange': 'BINANCE',
      }
    ])),
  ];

  Widget buildTestApp(Widget home, {List<Override>? overrides, double textScale = 1.3}) {
    return ProviderScope(
      overrides: overrides ?? defaultOverrides,
      child: MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: home,
      ),
    );
  }

  void expectNoOverflow(WidgetTester tester) {
    final err = tester.takeException();
    if (err != null) {
      debugPrint('ASSERTION_FAILURE_FOUND: $err');
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERROR_DETAILS: ${err.toStringDeep()}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG_NODE: ${d.toStringDeep()}');
        }
      }
    }
    expect(err, isNull, reason: 'Expected zero layout overflows or exceptions, but got: $err');
  }

  group('Exhaustive Multi-Device Layout Overflow Tests with 1.3x TextScale & Keyboard Insets', () {
    for (final size in testScreenSizes) {
      final sizeName = '${size.width.toInt()}x${size.height.toInt()}${size.width > size.height ? " (Landscape)" : ""}';

      testWidgets('SplashScreen renders at $sizeName with zero overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const SplashScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        expect(find.text('TradeVerse AI'), findsOneWidget);
      });

      testWidgets('LoginScreen renders at $sizeName and with simulated keyboard', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(
          buildTestApp(
            const LoginScreen(),
            overrides: [
              authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.unauthenticated('Invalid credentials'))),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        // Keyboard open simulation (300px inset)
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('RegisterScreen renders at $sizeName and with simulated keyboard', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(
          buildTestApp(
            const RegisterScreen(),
            overrides: [
              authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.unauthenticated())),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('HomeDashboardScreen renders at $sizeName without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const HomeDashboardScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('MarketsScreen renders at $sizeName without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const MarketsScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('TradeScreen renders at $sizeName and handles keyboard', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const TradeScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('OrdersScreen renders at $sizeName across all tabs without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const OrdersScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        // Switch to Orders tab
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        // Switch to History tab
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('PortfolioScreen renders at $sizeName and modals open without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const PortfolioScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        // Top Up Modal
        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('TradingViewChartScreen renders at $sizeName and modals open cleanly', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const TradingViewChartScreen(instrument: testInstrument)));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);

        // Open quick order modal
        final buyBtn = find.textContaining('BUY \$77645.00');
        if (buyBtn.evaluate().isNotEmpty) {
          await tester.tap(buyBtn.first);
          await tester.pumpAndSettle();
          expectNoOverflow(tester);

          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expectNoOverflow(tester);
          tester.view.resetViewInsets();
        }
      });

      testWidgets('CommunityScreen renders at $sizeName without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const CommunityScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('LearnScreen renders at $sizeName without overflow', (tester) async {
        setScreenDimensions(tester, size);
        addTearDown(() => resetScreen(tester));

        await tester.pumpWidget(buildTestApp(const LearnScreen()));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }

    testWidgets('OrderConfirmationSheet renders for Buy and Square-Off without overflow', (tester) async {
      setScreenDimensions(tester, const Size(360, 640));
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            body: OrderConfirmationSheet(
              symbol: 'RELIANCE',
              exchange: 'NSE',
              side: 'SELL',
              orderType: 'MARKET',
              product: 'MIS',
              quantity: 25,
              price: 2950.0,
              realizedPnl: 1250.0,
              realizedPnlPercent: 1.72,
              isExit: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });

    testWidgets('IndicatorsBottomSheet renders without overflow in constrained modal', (tester) async {
      setScreenDimensions(tester, const Size(360, 640));
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: IndicatorsBottomSheet(
              indicators: ChartIndicatorConfig.defaultIndicators(),
              onChanged: (_) {},
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });

    testWidgets('Specific Regression: ErrorStateWidget inside 210px chart height NEVER produces 53px overflow', (tester) async {
      setScreenDimensions(tester, const Size(360, 640));
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: SizedBox(
              height: 210.0, // Historical chart height that caused 53px overflow
              child: ErrorStateWidget(
                title: 'Chart Unavailable',
                message: 'Failed to fetch historical candles from provider: 429 Too Many Requests.',
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
    });
  });
}
