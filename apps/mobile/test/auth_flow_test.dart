import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/main.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';

void main() {
  testWidgets('Unauthenticated user is redirected to LoginScreen and can explore in Demo Mode',
      (WidgetTester tester) async {
    final authNotifier = _TestAuthNotifier(AuthState.unauthenticated());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => authNotifier),
        ],
        child: const TradeVerseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Login Screen appears
    expect(find.text('Log In to Account'), findsOneWidget);
    expect(find.text('Explore in Demo Mode'), findsOneWidget);

    // Test form validation
    await tester.tap(find.text('Log In to Account'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email'), findsOneWidget);

    // Enter invalid email
    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.tap(find.text('Log In to Account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    // Tap Explore in Demo Mode
    await tester.tap(find.text('Explore in Demo Mode'));
    await tester.pumpAndSettle();

    // Verify user entered dashboard with Demo Mode banner
    expect(find.text('DEMO MODE'), findsOneWidget);
    expect(find.text('Simulated Ticker Stream'), findsOneWidget);
  });
}

class _TestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuthNotifier(super.state);

  @override
  Future<void> enableDemoMode() async {
    state = AuthState.demoMode();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
