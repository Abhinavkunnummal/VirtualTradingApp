import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/auth/presentation/login_screen.dart';
import 'package:tradeverse_mobile/features/auth/presentation/register_screen.dart';
import 'package:tradeverse_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/markets_screen.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/portfolio_screen.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trade_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trading_view_chart_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/community/presentation/community_screen.dart';
import 'package:tradeverse_mobile/features/learn/presentation/learn_screen.dart';

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

class _TestViewPadding implements ViewPadding {
  @override
  final double bottom;
  @override
  final double left;
  @override
  final double right;
  @override
  final double top;

  const _TestViewPadding({this.bottom = 0.0, this.left = 0.0, this.right = 0.0, this.top = 0.0});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const Size compactScreenSize = Size(320, 568); // Small screen: iPhone SE / 320x568

  void setCompactScreen(WidgetTester tester) {
    tester.view.physicalSize = compactScreenSize;
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
    marketOverviewProvider.overrideWith((ref) => AsyncValue.data(MarketOverviewModel.demo().instruments)),
  ];

  Widget buildTestApp(Widget home, {List<Override>? overrides}) {
    return ProviderScope(
      overrides: overrides ?? defaultOverrides,
      child: MaterialApp(
        home: home,
      ),
    );
  }

  group('RenderFlex Overflow Guard Tests at 320x568 Compact Size', () {
    testWidgets('LoginScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
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

      expect(tester.takeException(), isNull);
      expect(find.text('Log In to Account'), findsOneWidget);
      expect(find.byKey(const ValueKey('login_retry_button')), findsOneWidget);

      // Simulate keyboard open (260px inset)
      tester.view.viewInsets = const _TestViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('RegisterScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
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

      expect(tester.takeException(), isNull);
      expect(find.text('Create Sandbox Account'), findsOneWidget);

      // Simulate keyboard open
      tester.view.viewInsets = const _TestViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeDashboardScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const HomeDashboardScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Simulated Ticker Stream'), findsOneWidget);
    });

    testWidgets('MarketsScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const MarketsScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('All Assets'), findsOneWidget);
    });

    testWidgets('TradeScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const TradeScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Order Ticket & Execution'), findsOneWidget);
    });

    testWidgets('TradingViewChartScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const TradingViewChartScreen(instrument: testInstrument)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('BTC/USDT'), findsWidgets);

      // Open quick order modal and verify no overflow
      await tester.tap(find.textContaining('BUY \$77645.00'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm BUY Order'), findsOneWidget);
    });

    testWidgets('PortfolioScreen renders at 320x568 and modals open without overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const PortfolioScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Total Account Value'), findsOneWidget);

      // Open Top Up Modal
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Credit Virtual Funds'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Open Reset Capital Modal
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reset Virtual Sandbox Capital'), findsOneWidget);
    });

    testWidgets('CommunityScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const CommunityScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Trading Floor Rooms'), findsOneWidget);
    });

    testWidgets('LearnScreen renders at 320x568 without RenderFlex overflow', (tester) async {
      setCompactScreen(tester);
      addTearDown(() => resetScreen(tester));

      await tester.pumpWidget(buildTestApp(const LearnScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Learn Trading with AI'), findsOneWidget);
    });
  });
}
