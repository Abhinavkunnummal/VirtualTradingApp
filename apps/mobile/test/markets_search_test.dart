import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/markets_screen.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testInstruments = [
    const InstrumentModel(
      symbol: 'RELIANCE',
      name: 'Reliance Industries Ltd.',
      exchange: 'NSE',
      category: 'EQUITY',
      price: 2945.50,
      change: 18.40,
      changePercent: 0.63,
      isPositive: true,
      lotSize: 1,
      tickSize: 0.05,
    ),
    const InstrumentModel(
      symbol: 'NIFTY 50',
      name: 'Nifty 50 Index',
      exchange: 'NSE',
      category: 'INDEX',
      price: 24852.15,
      change: 178.95,
      changePercent: 0.72,
      isPositive: true,
      lotSize: 50,
      tickSize: 0.05,
    ),
    const InstrumentModel(
      symbol: 'NIFTYBEES',
      name: 'Nippon India ETF Nifty BeES',
      exchange: 'NSE',
      category: 'ETF',
      price: 272.50,
      change: 2.10,
      changePercent: 0.78,
      isPositive: true,
      lotSize: 1,
      tickSize: 0.01,
    ),
    const InstrumentModel(
      symbol: 'SENSEX',
      name: 'BSE Sensex Index',
      exchange: 'BSE',
      category: 'INDEX',
      price: 81420.30,
      change: 524.10,
      changePercent: 0.65,
      isPositive: true,
      lotSize: 10,
      tickSize: 0.05,
    ),
    const InstrumentModel(
      symbol: 'BTC/USDT',
      name: 'Bitcoin 24/7 Simulator',
      exchange: 'CRYPTO',
      category: 'CRYPTO',
      price: 77568.00,
      change: 2140.00,
      changePercent: 3.28,
      isPositive: true,
      lotSize: 1,
      tickSize: 0.01,
      currency: 'USD',
    ),
    const InstrumentModel(
      symbol: 'AAPL',
      name: 'Apple Inc.',
      exchange: 'US',
      category: 'EQUITY',
      price: 231.41,
      change: 2.15,
      changePercent: 0.94,
      isPositive: true,
      lotSize: 1,
      tickSize: 0.01,
      currency: 'USD',
    ),
  ];

  Widget buildTestApp({List<Override>? overrides, Widget? home}) {
    final router = GoRouter(
      initialLocation: '/markets',
      routes: [
        GoRoute(
          path: '/markets',
          builder: (context, state) => home ?? const MarketsScreen(),
        ),
        GoRoute(
          path: '/trade',
          builder: (context, state) => const Scaffold(body: Text('Trade Screen')),
        ),
        GoRoute(
          path: '/tradingview-pro',
          builder: (context, state) => const Scaffold(body: Text('TradingView Pro Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
        marketOverviewProvider.overrideWith((ref) => Future.value(testInstruments)),
        instrumentSearchResultsProvider.overrideWith((ref) {
          final q = ref.watch(searchQueryProvider).toLowerCase().trim();
          final filter = ref.watch(searchFilterProvider);

          return testInstruments.where((item) {
            if (filter == 'NSE' && item.exchange != 'NSE') return false;
            if (filter == 'BSE' && item.exchange != 'BSE') return false;
            if (filter == 'Crypto' && item.category != 'CRYPTO') return false;
            if (filter == 'US' && item.exchange != 'US') return false;
            if (filter == 'Indices' && item.category != 'INDEX') return false;
            if (filter == 'ETFs' && item.category != 'ETF') return false;

            if (q.isEmpty) return true;
            return item.symbol.toLowerCase().contains(q) || item.name.toLowerCase().contains(q);
          }).toList();
        }),
        ...?overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Markets & Discovery Modern Search Tests', () {
    testWidgets('renders search bar and filter chips', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All Assets'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'NSE'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'BSE'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Crypto'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'US'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Indices'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ETFs'), findsOneWidget);
    });

    testWidgets('shows lot size and tick size in instrument tiles', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Lot: 1'), findsWidgets);
      expect(find.text('Tick: ₹0.05'), findsWidgets);
      expect(find.text('RELIANCE'), findsOneWidget);
      expect(find.text('TRADE'), findsWidgets);
    });

    testWidgets('search debounces and filters instruments', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Type into search bar
      await tester.enterText(find.byType(TextField), 'NIFTY');
      // Before 250ms debounce
      await tester.pump(const Duration(milliseconds: 100));
      // After debounce
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('NIFTY 50'), findsOneWidget);
      expect(find.text('NIFTYBEES'), findsOneWidget);
      expect(find.text('AAPL'), findsNothing);
    });

    testWidgets('filter chips filter results correctly', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap Crypto filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'Crypto'));
      await tester.pumpAndSettle();

      expect(find.text('BTC/USDT'), findsOneWidget);
      expect(find.text('RELIANCE'), findsNothing);

      // Tap ETFs filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'ETFs'));
      await tester.pumpAndSettle();

      expect(find.text('NIFTYBEES'), findsOneWidget);
      expect(find.text('BTC/USDT'), findsNothing);
    });

    testWidgets('shows recent searches and clear all works', (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'tradeverse_recent_searches': '["RELIANCE", "NIFTY 50"]',
      });
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsNothing);
    });

    testWidgets('tapping TRADE updates selected instrument', (tester) async {
      InstrumentModel? selected;
      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            instrumentSearchResultsProvider.overrideWith((ref) => testInstruments),
          ],
          home: Consumer(
            builder: (context, ref, _) {
              selected = ref.watch(selectedTradeInstrumentProvider);
              return const MarketsScreen();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap trade button for RELIANCE
      final tradeBtn = find.byKey(const ValueKey('order_btn_RELIANCE'));
      expect(tradeBtn, findsOneWidget);
      await tester.tap(tradeBtn);
      await tester.pumpAndSettle();

      expect(selected?.symbol, 'RELIANCE');
      expect(find.text('Trade Screen'), findsOneWidget);
    });

    testWidgets('Phase F1: offline fallback catalog includes JIOFIN, YESBANK, IDEA, KNRCON and displays offline banner', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fallbackInstruments = await container.read(marketOverviewProvider.future);
      final symbols = fallbackInstruments.map((i) => i.symbol).toList();

      expect(symbols, contains('JIOFIN'));
      expect(symbols, contains('YESBANK'));
      expect(symbols, contains('IDEA'));
      expect(symbols, contains('KNRCON'));

      // Now verify offline banner is displayed when isOfflineFallbackActiveProvider is true
      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            isOfflineFallbackActiveProvider.overrideWith((ref) => true),
            instrumentSearchResultsProvider.overrideWith((ref) => testInstruments),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline, limited list'), findsOneWidget);
    });
  });
}
