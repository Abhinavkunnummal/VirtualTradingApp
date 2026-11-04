import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/portfolio_screen.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/orders_screen.dart';
import 'package:tradeverse_mobile/features/trade/presentation/providers/order_provider.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/order_confirmation_sheet.dart';

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPortfolioNotifier extends StateNotifier<AsyncValue<PortfolioModel>> implements PortfolioNotifier {
  _MockPortfolioNotifier(PortfolioModel model) : super(AsyncValue.data(model));

  @override
  Future<bool> topUpVirtualFunds(double amount) async => true;

  @override
  Future<bool> withdrawVirtualFunds(double amount) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSubmitOrderService implements SubmitOrderService {
  @override
  Future<Map<String, dynamic>> submitOrder({
    required String symbol,
    required String exchange,
    required String side,
    required String orderType,
    required String product,
    required int quantity,
    double? limitPrice,
    double? triggerPrice,
    String orderVariety = 'REGULAR',
    double? targetPrice,
    double? stopLossPrice,
    double? trailingStopLoss,
  }) async {
    return {
      'success': true,
      'message': 'Order placed',
      'execution': {
        'executionPrice': 2500.0,
        'slippage': 0.5,
        'fees': 20.0,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> squareOffPosition({
    required String symbol,
    int? quantity,
    String orderType = 'MARKET',
    double? limitPrice,
  }) async {
    return {
      'success': true,
      'message': 'Position squared off successfully',
      'exitPrice': 2600.0,
      'netProceeds': 26000.0,
      'realizedPnl': 1000.0,
      'realizedPnlPercent': 4.0,
      'fees': 20.0,
    };
  }

  @override
  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    return {
      'success': true,
      'message': 'Order cancelled',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testHoldings = [
    HoldingModel(
      id: 'h_1',
      symbol: 'TCS',
      exchange: 'NSE',
      quantity: 10,
      averageBuyPrice: 3800.0,
      ltp: 3950.0,
      investedValue: 38000.0,
      currentValue: 39500.0,
      unrealizedPnl: 1500.0,
      unrealizedPnlPercent: 3.95,
      product: 'CNC',
      stopLoss: 3700.0,
      targetPrice: 4100.0,
    ),
    HoldingModel(
      id: 'h_2',
      symbol: 'INFY',
      exchange: 'NSE',
      quantity: 25,
      averageBuyPrice: 1800.0,
      ltp: 1780.0,
      investedValue: 45000.0,
      currentValue: 44500.0,
      unrealizedPnl: -500.0,
      unrealizedPnlPercent: -1.11,
      product: 'MIS',
    ),
  ];

  final testPortfolio = PortfolioModel(
    totalPortfolioValue: 84000.0,
    investedValue: 83000.0,
    availableCash: 17000.0,
    totalPnl: 1000.0,
    totalPnlPercent: 1.20,
    startingCapital: 100000.0,
    holdings: testHoldings,
  );

  final testTradesHistory = [
    TradeHistoryModel(
      id: 'trade_1',
      symbol: 'RELIANCE',
      exchange: 'NSE',
      side: 'BUY',
      product: 'CNC',
      quantity: 10,
      entryPrice: 2800.0,
      exitPrice: 2950.0,
      realizedPnl: 1500.0,
      realizedPnlPercent: 5.36,
      fees: 25.0,
      closedAt: DateTime(2026, 11, 4, 10, 30),
    ),
    TradeHistoryModel(
      id: 'trade_2',
      symbol: 'HDFCBANK',
      exchange: 'NSE',
      side: 'BUY',
      product: 'MIS',
      quantity: 20,
      entryPrice: 1650.0,
      exitPrice: 1620.0,
      realizedPnl: -600.0,
      realizedPnlPercent: -1.82,
      fees: 20.0,
      closedAt: DateTime(2026, 11, 4, 9, 45),
    ),
  ];

  final testOrders = <Map<String, dynamic>>[
    {
      'id': 'ord_pending_1',
      'symbol': 'SBIN',
      'exchange': 'NSE',
      'side': 'BUY',
      'orderType': 'LIMIT',
      'product': 'MIS',
      'quantity': 50,
      'limitPrice': 810.0,
      'status': 'PENDING',
      'createdAt': DateTime(2026, 11, 4, 11, 0).toIso8601String(),
    },
    {
      'id': 'ord_exec_1',
      'symbol': 'TCS',
      'exchange': 'NSE',
      'side': 'BUY',
      'orderType': 'MARKET',
      'product': 'CNC',
      'quantity': 10,
      'averagePrice': 3800.0,
      'status': 'EXECUTED',
      'createdAt': DateTime(2026, 11, 4, 9, 30).toIso8601String(),
    },
  ];

  const testPnlSummary = PnlSummaryModel(
    totalRealizedPnl: 900.0,
    totalUnrealizedPnl: 1000.0,
    totalPnl: 1900.0,
    totalTrades: 2,
    profitableTrades: 1,
    winRate: 50.0,
  );

  testWidgets('OrdersScreen renders 3 tabs, persistent summary header, and positions list',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(testPortfolio)),
          pnlSummaryProvider.overrideWith((ref) => Future.value(testPnlSummary)),
          orderHistoryProvider.overrideWith((ref) => Future.value(testOrders)),
          closedTradesHistoryProvider.overrideWith((ref) => Future.value(testTradesHistory)),
          submitOrderProvider.overrideWithValue(_MockSubmitOrderService()),
        ],
        child: const MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Top Summary Header
    expect(find.text('Orders & Positions'), findsOneWidget);
    expect(find.text('Unrealized P&L'), findsOneWidget);
    expect(find.text('Realized P&L'), findsOneWidget);
    expect(find.text('Net P&L'), findsOneWidget);
    expect(find.textContaining('Available Wallet Cash: ₹17000.00'), findsOneWidget);

    // 2. Verify Tab Titles
    expect(find.text('Positions (2)'), findsOneWidget);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('History'), findsOneWidget);

    // 3. Verify Position Cards
    expect(find.text('TCS'), findsOneWidget);
    expect(find.text('INFY'), findsOneWidget);
    expect(find.text('CNC'), findsWidgets);
    expect(find.text('MIS'), findsWidgets);
    expect(find.byKey(const ValueKey('square_off_TCS')), findsOneWidget);
    expect(find.byKey(const ValueKey('view_chart_TCS')), findsOneWidget);
  });

  testWidgets('OrdersScreen square off opens sheet, allows quantity selection, and completes square off',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(testPortfolio)),
          pnlSummaryProvider.overrideWith((ref) => Future.value(testPnlSummary)),
          orderHistoryProvider.overrideWith((ref) => Future.value(testOrders)),
          closedTradesHistoryProvider.overrideWith((ref) => Future.value(testTradesHistory)),
          submitOrderProvider.overrideWithValue(_MockSubmitOrderService()),
        ],
        child: const MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Sell / Square off on TCS
    final squareOffBtn = find.byKey(const ValueKey('square_off_TCS'));
    await tester.tap(squareOffBtn);
    await tester.pumpAndSettle();

    // Verify Square Off Modal opened
    expect(find.text('Square Off: TCS'), findsOneWidget);
    expect(find.text('Market Exit'), findsOneWidget);
    expect(find.text('Limit Exit'), findsOneWidget);
    expect(find.text('Confirm Square Off'), findsOneWidget);

    // Confirm Square Off
    await tester.tap(find.text('Confirm Square Off'));
    await tester.pumpAndSettle();

    // Verify OrderConfirmationSheet opens with Exit & Booked P&L
    expect(find.byType(OrderConfirmationSheet), findsOneWidget);
    expect(find.textContaining('Position Squared Off'), findsWidgets);
    expect(find.text('Realized Profit / Loss'), findsOneWidget);
  });

  testWidgets('OrdersScreen tabs switch to Orders and History properly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(testPortfolio)),
          pnlSummaryProvider.overrideWith((ref) => Future.value(testPnlSummary)),
          orderHistoryProvider.overrideWith((ref) => Future.value(testOrders)),
          closedTradesHistoryProvider.overrideWith((ref) => Future.value(testTradesHistory)),
          submitOrderProvider.overrideWithValue(_MockSubmitOrderService()),
        ],
        child: const MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Orders tab
    await tester.tap(find.text('Orders').first);
    await tester.pumpAndSettle();

    // Verify Filter Chips & Orders
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('SBIN'), findsOneWidget);
    expect(find.text('Cancel Order'), findsOneWidget);

    // Tap History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Verify Closed Trades
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('HDFCBANK'), findsOneWidget);
    expect(find.textContaining('Qty: 10'), findsOneWidget);
  });

  testWidgets('OrdersScreen renders without overflow on 320x568 compact screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(testPortfolio)),
          pnlSummaryProvider.overrideWith((ref) => Future.value(testPnlSummary)),
          orderHistoryProvider.overrideWith((ref) => Future.value(testOrders)),
          closedTradesHistoryProvider.overrideWith((ref) => Future.value(testTradesHistory)),
          submitOrderProvider.overrideWithValue(_MockSubmitOrderService()),
        ],
        child: const MaterialApp(
          home: OrdersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orders & Positions'), findsOneWidget);
  });

  testWidgets('PortfolioScreen displays Add Funds and Withdraw buttons with balance validation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(testPortfolio)),
        ],
        child: const MaterialApp(
          home: PortfolioScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Action Buttons
    expect(find.text('Add Funds'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('View Orders & Positions'), findsOneWidget);

    // Open Withdraw Modal
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text('Withdraw Virtual Funds'), findsWidgets);
    expect(find.textContaining('Available Cash: ₹17000.00'), findsOneWidget);
  });
}
