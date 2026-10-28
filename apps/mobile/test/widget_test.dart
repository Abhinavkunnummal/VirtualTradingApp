import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/main.dart';

void main() {
  testWidgets('TradeVerse AI app renders bottom navigation and dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TradeVerseApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Brand
    expect(find.text('TradeVerse AI'), findsOneWidget);

    // Verify Virtual Capital Card
    expect(find.text('Virtual Capital (Simulated)'), findsOneWidget);
    expect(find.text('₹12,48,750.00'), findsOneWidget);

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
