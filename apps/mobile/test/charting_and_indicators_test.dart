import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/chart_indicators.dart';

void main() {
  group('ChartIndicatorCalculator Unit Tests', () {
    final List<CandleData> sampleCandles = List.generate(
      35,
      (i) => CandleData(
        timestamp: 1700000000 + i * 86400,
        open: 100.0 + i,
        high: 105.0 + i,
        low: 95.0 + i,
        close: 100.0 + i,
        volume: 5000.0 + i * 100,
      ),
    );

    test('calculateSMA handles warm-up and produces valid moving average', () {
      final sma = ChartIndicatorCalculator.calculateSMA(sampleCandles, 5);
      expect(sma.length, equals(35));
      expect(sma[0], isNull);
      expect(sma[3], isNull);
      // Index 4 average of 100, 101, 102, 103, 104 = 102.0
      expect(sma[4], equals(102.0));
    });

    test('calculateEMA produces smooth exponential values', () {
      final ema = ChartIndicatorCalculator.calculateEMA(sampleCandles, 5);
      expect(ema.length, equals(35));
      expect(ema[0], isNull);
      expect(ema[4], isNotNull);
      expect(ema[10]!, greaterThan(ema[5]!));
    });

    test('calculateRSI bounded between 0 and 100', () {
      final rsi = ChartIndicatorCalculator.calculateRSI(sampleCandles, 14);
      expect(rsi.length, equals(35));
      expect(rsi[0], isNull);
      for (int i = 14; i < rsi.length; i++) {
        expect(rsi[i], isNotNull);
        expect(rsi[i]!, greaterThanOrEqualTo(0.0));
        expect(rsi[i]!, lessThanOrEqualTo(100.0));
      }
    });

    test('calculateMACD produces macd line, signal line, and histogram', () {
      final macd = ChartIndicatorCalculator.calculateMACD(sampleCandles, 12, 26, 9);
      expect(macd.containsKey('macd'), isTrue);
      expect(macd.containsKey('signal'), isTrue);
      expect(macd.containsKey('histogram'), isTrue);
      expect(macd['macd']!.length, equals(35));
    });
  });

  group('CandlestickChartView Widget Tests', () {
    testWidgets('renders range chips, interval chips, and indicator toggles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final List<CandleData> testCandles = List.generate(
        40,
        (i) => CandleData(
          timestamp: 1700000000 + i * 3600,
          open: 2900.0 + i,
          high: 2920.0 + i,
          low: 2890.0 + i,
          close: 2910.0 + i,
          volume: 25000.0,
        ),
      );

      String currentInterval = '15m';
      String currentRange = '1D';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CandlestickChartView(
                symbol: 'RELIANCE',
                candles: testCandles,
                currentPrice: 2945.50,
                selectedInterval: currentInterval,
                onIntervalChanged: (inv) => setState(() => currentInterval = inv),
                selectedRange: currentRange,
                onRangeChanged: (rng) => setState(() => currentRange = rng),
                status: 'SIMULATED',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Header & Status pill
      expect(find.text('RELIANCE'), findsOneWidget);
      expect(find.textContaining('SIMULATED'), findsWidgets);

      // 2. Verify Range Selector Chips by Key
      expect(find.byKey(const ValueKey('range_1D')), findsOneWidget);
      expect(find.byKey(const ValueKey('range_1W')), findsOneWidget);
      expect(find.byKey(const ValueKey('range_1M')), findsOneWidget);
      expect(find.byKey(const ValueKey('range_1Y')), findsOneWidget);
      expect(find.byKey(const ValueKey('range_5Y')), findsOneWidget);
      expect(find.byKey(const ValueKey('range_ALL')), findsOneWidget);

      // 3. Verify Interval Selector Chips by Key
      expect(find.byKey(const ValueKey('interval_1m')), findsOneWidget);
      expect(find.byKey(const ValueKey('interval_5m')), findsOneWidget);
      expect(find.byKey(const ValueKey('interval_15m')), findsOneWidget);
      expect(find.byKey(const ValueKey('interval_1d')), findsOneWidget);
      expect(find.byKey(const ValueKey('interval_1w')), findsOneWidget);
      expect(find.byKey(const ValueKey('interval_1M')), findsOneWidget);

      // 4. Verify Technical Indicator Chips by Key
      expect(find.byKey(const ValueKey('indicator_SMA(20)')), findsOneWidget);
      expect(find.byKey(const ValueKey('indicator_EMA(20)')), findsOneWidget);
      expect(find.byKey(const ValueKey('indicator_RSI(14)')), findsOneWidget);
      expect(find.byKey(const ValueKey('indicator_MACD')), findsOneWidget);

      // 5. Test toggling SMA(20) indicator
      await tester.tap(find.byKey(const ValueKey('indicator_SMA(20)')));
      await tester.pumpAndSettle();

      // 6. Test toggling RSI(14) oscillator panel
      await tester.tap(find.byKey(const ValueKey('indicator_RSI(14)')));
      await tester.pumpAndSettle();

      // 7. Test tapping 5Y range chip
      await tester.tap(find.byKey(const ValueKey('range_5Y')));
      await tester.pumpAndSettle();
      expect(currentRange, equals('5Y'));

      // 8. Test tapping 1d interval chip
      await tester.tap(find.byKey(const ValueKey('interval_1d')));
      await tester.pumpAndSettle();
      expect(currentInterval, equals('1d'));

      // 9. Test panning and double-tap reset gesture on chart
      final chartFinder = find.byType(CustomPaint).first;
      await tester.drag(chartFinder, const Offset(-50, 0));
      await tester.pumpAndSettle();

      await tester.tap(chartFinder);
      await tester.pumpAndSettle();

      // Double-tap to reset
      await tester.tap(chartFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(chartFinder);
      await tester.pumpAndSettle();
    });
  });
}
