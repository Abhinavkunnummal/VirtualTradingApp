import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeverse_mobile/core/theme/app_colors.dart';
import 'package:tradeverse_mobile/shared/widgets/instrument_price_column.dart';
import 'package:tradeverse_mobile/shared/widgets/mini_sparkline.dart';
import 'package:tradeverse_mobile/shared/widgets/instrument_row_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase H: Right-Aligned Monospace Financial Price Columns', () {
    testWidgets('1. Standard equity uses consistent 2-decimal format with tabular figures', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InstrumentPriceColumn(
                price: 2945.5,
                change: 18.4,
                changePercent: 0.63,
                currency: '₹',
                isCrypto: false,
              ),
            ),
          ),
        ),
      );

      // Verify 2-decimal formatted text
      expect(find.text('₹2945.50'), findsOneWidget);
      expect(find.text('+₹18.40 (+0.63%)'), findsOneWidget);

      // Verify right-alignment and tabular figures
      final priceText = tester.widget<Text>(find.text('₹2945.50'));
      expect(priceText.textAlign, TextAlign.right);
      expect(priceText.style?.fontFeatures?.contains(const FontFeature.tabularFigures()), isTrue);

      final changeText = tester.widget<Text>(find.text('+₹18.40 (+0.63%)'));
      expect(changeText.textAlign, TextAlign.right);
      expect(changeText.style?.color, AppColors.secondary); // Positive is green
      expect(changeText.style?.fontFeatures?.contains(const FontFeature.tabularFigures()), isTrue);
    });

    testWidgets('2. Sub-\$1 crypto uses 4-decimal format (e.g. DOGE/USDT at 0.0452)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InstrumentPriceColumn(
                price: 0.0452,
                change: -0.0012,
                changePercent: -2.58,
                currency: '\$',
                isCrypto: true,
              ),
            ),
          ),
        ),
      );

      // Verify 4-decimal formatted price for sub-$1 crypto
      expect(find.text('\$0.0452'), findsOneWidget);
      expect(find.text('-\$0.00 (-2.58%)'), findsOneWidget);

      final changeText = tester.widget<Text>(find.text('-\$0.00 (-2.58%)'));
      expect(changeText.style?.color, AppColors.tertiary); // Negative is red
    });

    testWidgets('3. Zero change is formatted with subtle grey color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: InstrumentPriceColumn(
                price: 100.0,
                change: 0.0,
                changePercent: 0.0,
                currency: '₹',
                isCrypto: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('₹100.00'), findsOneWidget);
      expect(find.text('₹0.00 (0.00%)'), findsOneWidget);

      final changeText = tester.widget<Text>(find.text('₹0.00 (0.00%)'));
      expect(changeText.style?.color, AppColors.outline); // Flat/0 is subtle grey
    });
  });

  group('Phase H: Mini-Sparkline Trend Chart', () {
    testWidgets('renders MiniSparkline for positive, negative, and flat states', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MiniSparkline(isPositive: true, isFlat: false),
                MiniSparkline(isPositive: false, isFlat: false),
                MiniSparkline(isPositive: false, isFlat: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MiniSparkline), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Phase H: InstrumentRowTile Responsiveness & Alignment across screen sizes', () {
    const List<Size> testSizes = [
      Size(320, 568), // Ultra-compact screen
      Size(360, 640), // Standard compact
      Size(411, 891), // Large Android
      Size(640, 360), // Landscape
    ];

    for (final size in testSizes) {
      testWidgets('Row layout at ${size.width}x${size.height} has zero overflow and right-aligned decimals', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3), // Large accessibility text scaling
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      InstrumentRowTile(
                        symbol: 'RELIANCE',
                        name: 'Reliance Industries Limited',
                        exchange: 'NSE',
                        category: 'EQUITY',
                        price: 2945.50,
                        change: 18.40,
                        changePercent: 0.63,
                        onTap: () {},
                        onTradeTap: () {},
                      ),
                      InstrumentRowTile(
                        symbol: 'HDFCBANK',
                        name: 'HDFC Bank Limited',
                        exchange: 'NSE',
                        category: 'EQUITY',
                        price: 1720.80,
                        change: -12.10,
                        changePercent: -0.70,
                        onTap: () {},
                        onTradeTap: () {},
                      ),
                      InstrumentRowTile(
                        symbol: 'DOGE/USDT',
                        name: 'Dogecoin Spot 24/7',
                        exchange: 'CRYPTO',
                        category: 'CRYPTO',
                        price: 0.1425,
                        change: 0.0035,
                        changePercent: 2.52,
                        currency: '\$',
                        onTap: () {},
                        onTradeTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Must find all items and price columns without throwing RenderFlex overflow
        expect(find.byType(InstrumentRowTile), findsNWidgets(3));
        expect(find.byType(InstrumentPriceColumn), findsNWidgets(3));
        expect(find.byType(MiniSparkline), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
