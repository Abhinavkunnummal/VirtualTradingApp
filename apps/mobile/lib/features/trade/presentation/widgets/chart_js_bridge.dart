import 'dart:convert';
import 'candlestick_chart_view.dart';

/// Pure Dart bridge helper that builds JavaScript execution strings for the
/// TradingView Lightweight Charts WebView container.
class ChartJsBridge {
  const ChartJsBridge._();

  /// Build JS call to set full historical candle dataset
  static String buildSetCandlesCall(
    List<CandleData> candles, {
    required String symbol,
    bool isDelayed = false,
  }) {
    final candlesJson = jsonEncode(candles.map((c) => c.toJson()).toList());
    return 'window.setCandles($candlesJson); window.setSymbol(\'$symbol\'); window.setDelayedBadge($isDelayed);';
  }

  /// Build JS call to update forming candle with live tick
  static String buildUpdateCandleCall(Map<String, dynamic> tickData) {
    final jsonStr = jsonEncode(tickData);
    return 'window.updateCandle($jsonStr);';
  }

  /// Build JS call to draw entry line and optional SL & Target lines
  /// from real position/order data. If stopLoss or targetPrice are null or <= 0,
  /// they are omitted so that only the entry line is drawn.
  static String buildSetPositionLinesCall({
    required double entryPrice,
    required int quantity,
    required bool isBuy,
    required String currency,
    double? stopLoss,
    double? targetPrice,
  }) {
    final Map<String, dynamic> posData = {
      'entryPrice': entryPrice,
      'quantity': quantity,
      'isBuy': isBuy,
      'currency': currency,
    };

    if (stopLoss != null && stopLoss > 0) {
      posData['slPrice'] = stopLoss;
    }
    if (targetPrice != null && targetPrice > 0) {
      posData['targetPrice'] = targetPrice;
    }

    return 'window.setPositionLines(${jsonEncode(posData)});';
  }

  /// Build JS call to clear all position lines
  static String buildClearPositionLinesCall() {
    return 'window.clearPositionLines();';
  }

  /// Build JS call to toggle auto AI analysis (Support/Resistance & Candlestick Patterns)
  static String buildSetAutoAnalysisCall(bool enabled) {
    return 'window.setAutoAnalysis($enabled);';
  }

  /// Build JS call to change chart type ('candles', 'heikin_ashi', 'line', 'area', 'bars')
  static String buildSetChartTypeCall(String type) {
    return 'window.setChartType(\'$type\');';
  }

  /// Build JS call to toggle DELAYED feed badge
  static String buildSetDelayedBadgeCall(bool isDelayed) {
    return 'window.setDelayedBadge($isDelayed);';
  }

  /// Build JS call to toggle theme ('dark' or 'light')
  static String buildSetThemeCall(String theme) {
    return 'window.setTheme(\'$theme\');';
  }

  /// Build JS call to set full active indicators list with periods & styles
  static String buildSetIndicatorsCall(List<Map<String, dynamic>> indicators) {
    return 'window.setIndicators(${jsonEncode(indicators)});';
  }

  /// Build JS call to add or update an indicator (SMA, EMA, BB, VWAP, RSI, MACD)
  static String buildAddIndicatorCall(Map<String, dynamic> indicator) {
    return 'window.addIndicator(${jsonEncode(indicator)});';
  }

  /// Build JS call to remove an indicator by ID
  static String buildRemoveIndicatorCall(String id) {
    return 'window.removeIndicator(\'$id\');';
  }

  /// Build JS call to remove all indicators
  static String buildRemoveAllIndicatorsCall() {
    return 'window.removeAllIndicators();';
  }

  /// Build JS call to set drawing mode ('trend_line', 'horizontal_line', 'rectangle', 'fibonacci', 'text_note', 'cursor')
  static String buildSetDrawingModeCall(String tool) {
    return 'window.setDrawingMode(\'$tool\');';
  }

  /// Build JS call to restore persisted drawings
  static String buildSetDrawingsCall(List<Map<String, dynamic>> drawings) {
    return 'window.setDrawings(${jsonEncode(drawings)});';
  }

  /// Build JS call to clear all drawings
  static String buildClearDrawingsCall() {
    return 'window.clearDrawings();';
  }

  /// Build JS call to undo last drawing action
  static String buildUndoDrawingCall() {
    return 'window.undoDrawing();';
  }
}
