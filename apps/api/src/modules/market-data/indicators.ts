import { Candle } from './marketData.service';

export interface IndicatorPoint {
  timestamp: number;
  value: number | null;
}

export interface MacdPoint {
  timestamp: number;
  macd: number | null;
  signal: number | null;
  histogram: number | null;
}

export interface TechnicalIndicators {
  sma20?: IndicatorPoint[];
  sma50?: IndicatorPoint[];
  ema20?: IndicatorPoint[];
  rsi14?: IndicatorPoint[];
  macd?: MacdPoint[];
}

export class TechnicalIndicatorService {
  /**
   * Calculate Simple Moving Average (SMA) for period N.
   */
  static calculateSMA(candles: Candle[], period: number): IndicatorPoint[] {
    if (!candles || candles.length === 0) return [];
    const result: IndicatorPoint[] = [];

    for (let i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        result.push({ timestamp: candles[i].timestamp, value: null });
        continue;
      }

      let sum = 0;
      for (let j = 0; j < period; j++) {
        sum += candles[i - j].close;
      }
      const sma = parseFloat((sum / period).toFixed(2));
      result.push({ timestamp: candles[i].timestamp, value: sma });
    }

    return result;
  }

  /**
   * Calculate Exponential Moving Average (EMA) for period N.
   */
  static calculateEMA(candles: Candle[], period: number): IndicatorPoint[] {
    if (!candles || candles.length === 0) return [];
    const result: IndicatorPoint[] = [];
    const k = 2 / (period + 1);
    let prevEma: number | null = null;

    for (let i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        result.push({ timestamp: candles[i].timestamp, value: null });
        continue;
      }

      if (prevEma === null) {
        // Initialize with SMA
        let sum = 0;
        for (let j = 0; j < period; j++) {
          sum += candles[i - j].close;
        }
        prevEma = sum / period;
        result.push({ timestamp: candles[i].timestamp, value: parseFloat(prevEma.toFixed(2)) });
      } else {
        const ema: number = candles[i].close * k + prevEma * (1 - k);
        prevEma = ema;
        result.push({ timestamp: candles[i].timestamp, value: parseFloat(ema.toFixed(2)) });
      }
    }

    return result;
  }

  /**
   * Calculate Wilder's Relative Strength Index (RSI) for period (default 14).
   */
  static calculateRSI(candles: Candle[], period = 14): IndicatorPoint[] {
    if (!candles || candles.length === 0) return [];
    const result: IndicatorPoint[] = [];

    if (candles.length <= period) {
      return candles.map((c) => ({ timestamp: c.timestamp, value: null }));
    }

    let avgGain = 0;
    let avgLoss = 0;

    // First period changes
    for (let i = 1; i <= period; i++) {
      const change = candles[i].close - candles[i - 1].close;
      if (change > 0) avgGain += change;
      else avgLoss += Math.abs(change);
    }

    avgGain /= period;
    avgLoss /= period;

    for (let i = 0; i < candles.length; i++) {
      if (i < period) {
        result.push({ timestamp: candles[i].timestamp, value: null });
        continue;
      }

      if (i > period) {
        const change = candles[i].close - candles[i - 1].close;
        const gain = change > 0 ? change : 0;
        const loss = change < 0 ? Math.abs(change) : 0;

        avgGain = (avgGain * (period - 1) + gain) / period;
        avgLoss = (avgLoss * (period - 1) + loss) / period;
      }

      if (avgLoss === 0) {
        result.push({ timestamp: candles[i].timestamp, value: 100 });
      } else {
        const rs = avgGain / avgLoss;
        const rsi = 100 - 100 / (1 + rs);
        result.push({ timestamp: candles[i].timestamp, value: parseFloat(rsi.toFixed(2)) });
      }
    }

    return result;
  }

  /**
   * Calculate Moving Average Convergence Divergence (MACD 12, 26, 9).
   */
  static calculateMACD(
    candles: Candle[],
    fastPeriod = 12,
    slowPeriod = 26,
    signalPeriod = 9
  ): MacdPoint[] {
    if (!candles || candles.length === 0) return [];

    const fastEma = this.calculateEMA(candles, fastPeriod);
    const slowEma = this.calculateEMA(candles, slowPeriod);

    // Calculate MACD Line = Fast EMA - Slow EMA
    const macdLine: (number | null)[] = [];
    for (let i = 0; i < candles.length; i++) {
      const f = fastEma[i]?.value;
      const s = slowEma[i]?.value;
      if (f !== null && s !== null && f !== undefined && s !== undefined) {
        macdLine.push(parseFloat((f - s).toFixed(4)));
      } else {
        macdLine.push(null);
      }
    }

    // Calculate Signal Line = EMA(signalPeriod) of MACD Line
    const kSignal = 2 / (signalPeriod + 1);
    let prevSignal: number | null = null;
    const signalLine: (number | null)[] = new Array(candles.length).fill(null);

    // Find the first index where macdLine has enough valid points
    let validStart = -1;
    for (let i = 0; i < macdLine.length; i++) {
      if (macdLine[i] !== null) {
        if (validStart === -1) validStart = i;
        if (i - validStart >= signalPeriod - 1) {
          if (prevSignal === null) {
            let sum = 0;
            for (let j = 0; j < signalPeriod; j++) {
              sum += macdLine[i - j]!;
            }
            prevSignal = sum / signalPeriod;
            signalLine[i] = parseFloat(prevSignal.toFixed(4));
          } else {
            const sig: number = macdLine[i]! * kSignal + prevSignal * (1 - kSignal);
            prevSignal = sig;
            signalLine[i] = parseFloat(sig.toFixed(4));
          }
        }
      }
    }

    const result: MacdPoint[] = [];
    for (let i = 0; i < candles.length; i++) {
      const m = macdLine[i];
      const s = signalLine[i];
      const h = m !== null && s !== null ? parseFloat((m - s).toFixed(4)) : null;

      result.push({
        timestamp: candles[i].timestamp,
        macd: m,
        signal: s,
        histogram: h,
      });
    }

    return result;
  }

  /**
   * Calculate all standard technical indicators for a candle series.
   */
  static calculateAll(candles: Candle[]): TechnicalIndicators {
    return {
      sma20: this.calculateSMA(candles, 20),
      sma50: this.calculateSMA(candles, 50),
      ema20: this.calculateEMA(candles, 20),
      rsi14: this.calculateRSI(candles, 14),
      macd: this.calculateMACD(candles, 12, 26, 9),
    };
  }
}
