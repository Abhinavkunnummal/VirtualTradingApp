import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeverse_mobile/features/portfolio/domain/portfolio_models.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/candlestick_chart_view.dart';
import 'package:tradeverse_mobile/features/trade/presentation/widgets/chart_js_bridge.dart';

void main() {
  group('ChartJsBridge Unit Tests', () {
    test('buildSetCandlesCall formats JSON candles and symbol properly', () {
      final candles = [
        CandleData(
          timestamp: 1700000000,
          open: 100.0,
          high: 110.0,
          low: 95.0,
          close: 105.0,
          volume: 1500.0,
        ),
      ];

      final jsCall = ChartJsBridge.buildSetCandlesCall(
        candles,
        symbol: 'BTC/USDT',
        isDelayed: true,
      );

      expect(jsCall.startsWith('window.setCandles('), isTrue);
      expect(jsCall.contains('window.setSymbol(\'BTC/USDT\')'), isTrue);
      expect(jsCall.contains('window.setDelayedBadge(true)'), isTrue);
      expect(jsCall.contains('"time":1700000000'), isTrue);
      expect(jsCall.contains('"open":100.0'), isTrue);
    });

    test('buildUpdateCandleCall produces valid JSON parameter string', () {
      final tick = {
        'symbol': 'BTC/USDT',
        'time': 1700000060,
        'open': 105.0,
        'high': 108.0,
        'low': 104.0,
        'close': 107.5,
        'volume': 200.0,
      };

      final jsCall = ChartJsBridge.buildUpdateCandleCall(tick);
      expect(jsCall.startsWith('window.updateCandle('), isTrue);
      expect(jsCall.contains('"close":107.5'), isTrue);
      expect(jsCall.contains('"time":1700000060'), isTrue);
    });

    test('buildSetPositionLinesCall uses real stopLoss and targetPrice from position data (not hardcoded 2%/4%)', () {
      const holdingWithTargets = HoldingModel(
        id: 'hold_custom_1',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        quantity: 50,
        averageBuyPrice: 2880.00,
        ltp: 2945.50,
        investedValue: 144000.00,
        currentValue: 147275.00,
        unrealizedPnl: 3275.00,
        unrealizedPnlPercent: 2.27,
        stopLoss: 2750.00, // Custom real SL
        targetPrice: 3120.00, // Custom real Target
      );

      final jsCall = ChartJsBridge.buildSetPositionLinesCall(
        entryPrice: holdingWithTargets.averageBuyPrice,
        quantity: holdingWithTargets.quantity,
        isBuy: true,
        currency: '₹',
        stopLoss: holdingWithTargets.stopLoss,
        targetPrice: holdingWithTargets.targetPrice,
      );

      // Extract JSON inside window.setPositionLines(...)
      final startIdx = jsCall.indexOf('(') + 1;
      final endIdx = jsCall.lastIndexOf(')');
      final jsonStr = jsCall.substring(startIdx, endIdx);
      final Map<String, dynamic> parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['entryPrice'], equals(2880.00));
      expect(parsed['quantity'], equals(50));
      expect(parsed['isBuy'], isTrue);
      expect(parsed['currency'], equals('₹'));
      // Proves values match the real position data, not 2880 * 0.98 (2822.4) or 2880 * 1.04 (2995.2)
      expect(parsed['slPrice'], equals(2750.00));
      expect(parsed['targetPrice'], equals(3120.00));
      expect(parsed['slPrice'], isNot(equals(2880.00 * 0.98)));
      expect(parsed['targetPrice'], isNot(equals(2880.00 * 1.04)));
    });

    test('buildSetPositionLinesCall omits slPrice and targetPrice when position has none (draws only entry line)', () {
      const plainHolding = HoldingModel(
        id: 'hold_plain',
        symbol: 'TCS',
        exchange: 'NSE',
        quantity: 10,
        averageBuyPrice: 4100.00,
        ltp: 4120.00,
        investedValue: 41000.00,
        currentValue: 41200.00,
        unrealizedPnl: 200.00,
        unrealizedPnlPercent: 0.49,
        stopLoss: null,
        targetPrice: null,
      );

      final jsCall = ChartJsBridge.buildSetPositionLinesCall(
        entryPrice: plainHolding.averageBuyPrice,
        quantity: plainHolding.quantity,
        isBuy: true,
        currency: '₹',
        stopLoss: plainHolding.stopLoss,
        targetPrice: plainHolding.targetPrice,
      );

      final startIdx = jsCall.indexOf('(') + 1;
      final endIdx = jsCall.lastIndexOf(')');
      final jsonStr = jsCall.substring(startIdx, endIdx);
      final Map<String, dynamic> parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['entryPrice'], equals(4100.00));
      expect(parsed['quantity'], equals(10));
      expect(parsed.containsKey('slPrice'), isFalse);
      expect(parsed.containsKey('targetPrice'), isFalse);
    });

    test('bridge methods produce expected function calls', () {
      expect(ChartJsBridge.buildClearPositionLinesCall(), equals('window.clearPositionLines();'));
      expect(ChartJsBridge.buildSetChartTypeCall('line'), equals('window.setChartType(\'line\');'));
      expect(ChartJsBridge.buildSetDelayedBadgeCall(false), equals('window.setDelayedBadge(false);'));
      expect(ChartJsBridge.buildSetThemeCall('dark'), equals('window.setTheme(\'dark\');'));
      expect(ChartJsBridge.buildRemoveIndicatorCall('rsi_14'), equals('window.removeIndicator(\'rsi_14\');'));
      expect(ChartJsBridge.buildSetDrawingModeCall('trend_line'), equals('window.setDrawingMode(\'trend_line\');'));
      expect(ChartJsBridge.buildClearDrawingsCall(), equals('window.clearDrawings();'));
      expect(ChartJsBridge.buildUndoDrawingCall(), equals('window.undoDrawing();'));
    });
  });
}
