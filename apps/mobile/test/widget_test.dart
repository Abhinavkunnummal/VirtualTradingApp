import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/main.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/portfolio/presentation/providers/portfolio_provider.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';

void main() {
  testWidgets('TradeVerse AI app renders bottom navigation and dashboard in Demo Mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
          portfolioProvider.overrideWith((ref) => _MockPortfolioNotifier(PortfolioModel.demo())),
        ],
        child: const TradeVerseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Brand
    expect(find.text('Simulated Trader (Demo)'), findsOneWidget);

    // Verify Demo Mode banner & Virtual Capital Card
    expect(find.text('DEMO MODE'), findsOneWidget);
    expect(find.text('Virtual Capital (Simulated)'), findsOneWidget);
    expect(find.text('₹1248750.00'), findsOneWidget);

    // Verify Bottom Navigation Bar Destinations
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Markets'), findsOneWidget);
    expect(find.text('Trade'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);

    // Tap Markets Tab
    await tester.tap(find.text('Markets'));
    await tester.pumpAndSettle();
    expect(find.text('Markets & Discovery'), findsOneWidget);

    // Tap Trade Tab
    await tester.tap(find.text('Trade'));
    await tester.pumpAndSettle();
    expect(find.text('Order Ticket & Execution'), findsOneWidget);

    // Tap Community Tab
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.text('Community & Social Feed'), findsOneWidget);

    // Tap Portfolio Tab
    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio & Analytics'), findsOneWidget);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
