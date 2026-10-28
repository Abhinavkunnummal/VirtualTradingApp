import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/markets/domain/market_models.dart';
import 'package:tradeverse_mobile/features/markets/domain/news_models.dart';
import 'package:tradeverse_mobile/features/markets/presentation/markets_screen.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/markets_provider.dart';
import 'package:tradeverse_mobile/features/markets/presentation/providers/news_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/trade_screen.dart';
import 'package:tradeverse_mobile/features/home/presentation/home_dashboard_screen.dart';
import 'package:tradeverse_mobile/features/notifications/domain/notification_models.dart';
import 'package:tradeverse_mobile/features/notifications/presentation/providers/notification_provider.dart';

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

class _MockNotificationNotifier extends StateNotifier<AsyncValue<List<AppNotification>>>
    implements NotificationNotifier {
  _MockNotificationNotifier(List<AppNotification> items) : super(AsyncValue.data(items));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('TradeScreen displays Order Variety selector and shows Cover & Bracket controls',
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

    // 1. Verify Order Variety choices exist
    expect(find.text('Order Variety'), findsOneWidget);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Cover (CO)'), findsOneWidget);
    expect(find.text('Bracket (BO)'), findsOneWidget);

    // 2. Tap Cover (CO) -> Should show Cover Stop-Loss Trigger input
    await tester.tap(find.text('Cover (CO)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cover Stop-Loss Trigger'), findsOneWidget);

    // 3. Tap Bracket (BO) -> Should show Target Profit, Stop-Loss, and Trailing SL
    await tester.tap(find.text('Bracket (BO)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Target Profit Price'), findsOneWidget);
    expect(find.textContaining('Stop-Loss Trigger Price'), findsOneWidget);
    expect(find.text('Trailing Stop-Loss'), findsOneWidget);
  });

  testWidgets('MarketsScreen displays Live News Feed tab with articles and sentiment pills',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testNews = [
      NewsArticle(
        id: 'news-test-1',
        title: 'Reliance Retail Expands Omnichannel Footprint',
        summary: 'Consumer footfall up 18% YoY in quarterly reports.',
        category: 'EQUITY',
        sentiment: 'BULLISH',
        sentimentScore: 0.78,
        impact: 'HIGH',
        relatedSymbols: const ['RELIANCE', 'NIFTY 50'],
        source: 'TradeVerse Wire',
        publishedAt: DateTime.now(),
        readTimeMinutes: 2,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketOverviewProvider.overrideWith((ref) => Future.value(const [
                InstrumentModel(
                  symbol: 'RELIANCE',
                  name: 'Reliance Industries',
                  exchange: 'NSE',
                  category: 'EQUITY',
                  price: 2945.50,
                  change: 18.40,
                  changePercent: 0.63,
                  isPositive: true,
                  isSimulated: true,
                ),
              ])),
          newsProvider.overrideWith((ref) => Future.value(testNews)),
        ],
        child: const MaterialApp(
          home: MarketsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab exists
    expect(find.text('Live News Feed'), findsOneWidget);

    // Tap Live News Feed tab
    await tester.tap(find.text('Live News Feed'));
    await tester.pumpAndSettle();

    // Verify News article and sentiment rendered
    expect(find.text('Reliance Retail Expands Omnichannel Footprint'), findsOneWidget);
    expect(find.text('BULLISH'), findsOneWidget);
    expect(find.text('TradeVerse Wire'), findsOneWidget);
  });

  testWidgets('HomeDashboardScreen notification bell opens notifications modal sheet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testNotifs = [
      AppNotification(
        id: 'notif-test-1',
        title: 'Order Filled: BUY 10 RELIANCE',
        message: 'Executed @ ₹2,580.45. Paper order filled successfully.',
        type: 'ORDER_FILL',
        read: false,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
          notificationsProvider.overrideWith((ref) => _MockNotificationNotifier(testNotifs)),
        ],
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and tap notification bell icon
    final bellFinder = find.byIcon(Icons.notifications_none);
    expect(bellFinder, findsOneWidget);

    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    // Verify notifications bottom sheet appeared
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(find.textContaining('Order Filled'), findsWidgets);
  });
}
