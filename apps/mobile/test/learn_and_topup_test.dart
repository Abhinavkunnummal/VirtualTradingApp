import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/portfolio_screen.dart';
import 'package:tradeverse_mobile/features/learn/presentation/learn_screen.dart';

void main() {
  group('Learn Trading with AI & Virtual Funds Top-Up Tests', () {
    testWidgets('LearnScreen renders all 8 curriculum modules and executes quiz',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          ],
          child: const MaterialApp(
            home: LearnScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify App Bar & Modules
      expect(find.text('Learn Trading with AI'), findsOneWidget);
      expect(find.text('Market Basics & How Exchanges Work'), findsOneWidget);
      expect(find.text('Candlestick Anatomy & Patterns'), findsOneWidget);
      expect(find.text('Order Types & Precision Execution'), findsOneWidget);
      expect(find.text('Support, Resistance & Trendlines'), findsOneWidget);
      expect(find.text('Technical Indicators (RSI, EMAs, MACD)'), findsOneWidget);
      expect(find.text('Risk-to-Reward Ratio & Position Sizing'), findsOneWidget);
      expect(find.text('Stop-Loss Discipline & Psychology'), findsOneWidget);
      expect(find.text('Simulated Paper Trading Mastery'), findsOneWidget);

      // 2. Open Module Detail Sheet
      await tester.tap(find.text('Candlestick Anatomy & Patterns'));
      await tester.pumpAndSettle();

      expect(find.text('Learning Objectives'), findsOneWidget);
      expect(find.text('Key Takeaways'), findsOneWidget);
      expect(find.text('Take Module Quiz'), findsOneWidget);

      // 3. Open Module Quiz
      await tester.tap(find.text('Take Module Quiz'));
      await tester.pumpAndSettle();

      expect(find.textContaining('What does a long lower wick on a candle typically indicate?'), findsOneWidget);

      // Select correct option B
      await tester.tap(find.text('Price rejection where buyers stepped in and absorbed lower selling'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();

      expect(find.text('Correct! Well Done.'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      // Verify module has completion checkmark
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // 4. Test AI Tutor dialog
      final tutorFab = find.byType(FloatingActionButton);
      expect(tutorFab, findsOneWidget);
      await tester.tap(tutorFab);
      await tester.pumpAndSettle();

      expect(find.text('AI Trading Tutor'), findsOneWidget);
      expect(find.text('Your AI tutor is ready.'), findsOneWidget);
    });

    testWidgets('PortfolioScreen displays Add Virtual Funds modal and increments balance',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
            portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
          ],
          child: const MaterialApp(
            home: PortfolioScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Portfolio & Analytics title
      expect(find.text('Portfolio & Analytics'), findsOneWidget);
      expect(find.text('Add Virtual Funds'), findsOneWidget);

      // Tap Add Virtual Funds
      await tester.tap(find.text('Add Virtual Funds'));
      await tester.pumpAndSettle();

      expect(find.text('Add Virtual Practice Funds'), findsOneWidget);
      expect(find.text('Credit Virtual Funds'), findsOneWidget);

      // Credit Funds
      await tester.tap(find.text('Credit Virtual Funds'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Credited ₹100000 in virtual sandbox funds.'), findsOneWidget);
    });
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
  Future<bool> topUpVirtualFunds(double amount) async {
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
