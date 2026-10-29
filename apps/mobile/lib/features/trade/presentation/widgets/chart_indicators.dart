import 'candlestick_chart_view.dart';

class ChartIndicatorCalculator {
  /// Simple Moving Average (SMA)
  static List<double?> calculateSMA(List<CandleData> candles, int period) {
    if (candles.isEmpty) return [];
    final List<double?> result = List.filled(candles.length, null);

    for (int i = period - 1; i < candles.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < period; j++) {
        sum += candles[i - j].close;
      }
      result[i] = sum / period;
    }
    return result;
  }

  /// Exponential Moving Average (EMA)
  static List<double?> calculateEMA(List<CandleData> candles, int period) {
    if (candles.isEmpty) return [];
    final List<double?> result = List.filled(candles.length, null);
    if (candles.length < period) return result;

    final k = 2.0 / (period + 1);

    // Initial SMA
    double sum = 0.0;
    for (int j = 0; j < period; j++) {
      sum += candles[j].close;
    }
    double prevEma = sum / period;
    result[period - 1] = prevEma;

    for (int i = period; i < candles.length; i++) {
      prevEma = candles[i].close * k + prevEma * (1.0 - k);
      result[i] = prevEma;
    }
    return result;
  }

  /// Relative Strength Index (RSI 14)
  static List<double?> calculateRSI(List<CandleData> candles, [int period = 14]) {
    if (candles.length <= period) return List.filled(candles.length, null);
    final List<double?> result = List.filled(candles.length, null);

    double avgGain = 0.0;
    double avgLoss = 0.0;

    for (int i = 1; i <= period; i++) {
      final diff = candles[i].close - candles[i - 1].close;
      if (diff > 0) {
        avgGain += diff;
      } else {
        avgLoss += diff.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    for (int i = period; i < candles.length; i++) {
      if (i > period) {
        final diff = candles[i].close - candles[i - 1].close;
        final gain = diff > 0 ? diff : 0.0;
        final loss = diff < 0 ? diff.abs() : 0.0;

        avgGain = (avgGain * (period - 1) + gain) / period;
        avgLoss = (avgLoss * (period - 1) + loss) / period;
      }

      if (avgLoss == 0) {
        result[i] = 100.0;
      } else {
        final rs = avgGain / avgLoss;
        result[i] = 100.0 - (100.0 / (1.0 + rs));
      }
    }
    return result;
  }

  /// MACD (12, 26, 9)
  static Map<String, List<double?>> calculateMACD(
    List<CandleData> candles, [
    int fast = 12,
    int slow = 26,
    int signal = 9,
  ]) {
    final fastEma = calculateEMA(candles, fast);
    final slowEma = calculateEMA(candles, slow);

    final List<double?> macdLine = List.filled(candles.length, null);
    for (int i = 0; i < candles.length; i++) {
      if (fastEma[i] != null && slowEma[i] != null) {
        macdLine[i] = fastEma[i]! - slowEma[i]!;
      }
    }

    final List<double?> signalLine = List.filled(candles.length, null);
    final kSignal = 2.0 / (signal + 1);

    int startIdx = -1;
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i] != null) {
        if (startIdx == -1) startIdx = i;
        if (i - startIdx == signal - 1) {
          double sum = 0.0;
          for (int j = 0; j < signal; j++) {
            sum += macdLine[i - j]!;
          }
          signalLine[i] = sum / signal;
        } else if (i - startIdx >= signal) {
          final prevSig = signalLine[i - 1]!;
          signalLine[i] = macdLine[i]! * kSignal + prevSig * (1.0 - kSignal);
        }
      }
    }

    final List<double?> histogram = List.filled(candles.length, null);
    for (int i = 0; i < candles.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        histogram[i] = macdLine[i]! - signalLine[i]!;
      }
    }

    return {
      'macd': macdLine,
      'signal': signalLine,
      'histogram': histogram,
    };
  }
}
