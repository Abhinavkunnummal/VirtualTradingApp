import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/community/presentation/community_screen.dart';
import 'package:tradeverse_mobile/features/community/presentation/providers/community_provider.dart';
import 'package:tradeverse_mobile/features/ai/presentation/providers/ai_provider.dart';

void main() {
  testWidgets('CommunityScreen displays Discussion Rooms, posts messages, and renders AI Assistant tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(AuthState.demoMode())),
        ],
        child: const MaterialApp(
          home: CommunityScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify App Bar and Tabs
    expect(find.text('Community & Social Feed'), findsOneWidget);
    expect(find.text('Trading Floor Rooms'), findsOneWidget);
    expect(find.text('AI Assistant & News'), findsOneWidget);

    // 2. Verify Room Chips
    expect(find.textContaining('Live Trading Floor'), findsOneWidget);
    expect(find.textContaining('NIFTY & Equities Desk'), findsOneWidget);

    // 3. Verify Message Feed
    expect(find.text('Vikram Mehra'), findsOneWidget);
    expect(find.text('PAPER BUY • RELIANCE'), findsOneWidget);
    expect(find.text('BULLISH'), findsWidgets);

    // 4. Test Floating Action Button to Compose
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('Share Paper Setup or Idea'), findsOneWidget);
    expect(find.text('Post to Channel'), findsOneWidget);

    // Close compose sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 5. Switch to AI Assistant & News Tab
    await tester.tap(find.text('AI Assistant & News'));
    await tester.pumpAndSettle();

    // 6. Verify AI Assistant Prompting Chips
    expect(find.text('Ask TradeVerse AI Assistant'), findsOneWidget);
    expect(find.text('RSI Momentum'), findsOneWidget);
    expect(find.text('Stop-Loss Order'), findsOneWidget);
    expect(find.text('Bullish Engulfing'), findsOneWidget);
    expect(find.text('MIS Intraday Leverage'), findsOneWidget);

    // 7. Verify AI-generated explanation card & disclaimers
    expect(find.text('AI-GENERATED'), findsOneWidget);
    expect(find.textContaining('Educational use only'), findsWidgets);

    // 8. Verify Portfolio Risk Review card
    expect(find.text('Portfolio Risk & Concentration Review'), findsOneWidget);

    // 9. Verify Curated News Pulse
    expect(find.text('Curated Market News Pulse'), findsOneWidget);
    expect(find.textContaining('RBI Monetary Policy'), findsOneWidget);
  });
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
