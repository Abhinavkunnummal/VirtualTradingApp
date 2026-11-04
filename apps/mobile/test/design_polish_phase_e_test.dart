import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/core/theme/app_typography.dart';
import 'package:tradeverse_mobile/core/widgets/app_shimmer.dart';
import 'package:tradeverse_mobile/core/widgets/empty_state_view.dart';

void main() {
  group('Phase E - Theme & Typography Verification', () {
    test('Zerodha & Groww dark mode color palette constants are configured', () {
      expect(AppColors.background, const Color(0xFF121418));
      expect(AppColors.surfaceContainer, const Color(0xFF1A1D24));
      expect(AppColors.borderSubtle, const Color(0xFF262A33));
      expect(AppColors.kiteGreen, const Color(0xFF089981));
      expect(AppColors.kiteRed, const Color(0xFFF23645));
      expect(AppColors.zerodhaBlue, const Color(0xFF2962FF));
    });

    test('Numeric typography styles contain tabular figures feature', () {
      final tabularFeature = FontFeature.tabularFigures();
      expect(AppTypography.numericTicker.fontFeatures, contains(tabularFeature));
      expect(AppTypography.numericTable.fontFeatures, contains(tabularFeature));
      expect(AppTypography.numericHeadline.fontFeatures, contains(tabularFeature));
      expect(AppTypography.numericSubhead.fontFeatures, contains(tabularFeature));
      expect(AppTypography.numericSmall.fontFeatures, contains(tabularFeature));
    });
  });

  group('Phase E - Shimmer Skeleton Widgets Verification', () {
    testWidgets('WatchlistSkeleton renders requested placeholder rows', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WatchlistSkeleton(count: 4),
          ),
        ),
      );
      expect(find.byType(WatchlistSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('HoldingsSkeleton renders requested card placeholders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HoldingsSkeleton(count: 3),
          ),
        ),
      );
      expect(find.byType(HoldingsSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('OrdersSkeleton renders requested order card placeholders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrdersSkeleton(count: 3),
          ),
        ),
      );
      expect(find.byType(OrdersSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('ChartSkeleton renders candlestick bar placeholders and OHLC bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChartSkeleton(),
          ),
        ),
      );
      expect(find.byType(ChartSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });

  group('Phase E - EmptyStateView Verification', () {
    testWidgets('EmptyStateView renders title, message, and responds to action button', (WidgetTester tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No Instruments Found',
              message: 'Check your search query or clear the active filter.',
              actionLabel: 'Show All Assets',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No Instruments Found'), findsOneWidget);
      expect(find.text('Check your search query or clear the active filter.'), findsOneWidget);
      expect(find.text('Show All Assets'), findsOneWidget);

      await tester.tap(find.text('Show All Assets'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });
  });
}
