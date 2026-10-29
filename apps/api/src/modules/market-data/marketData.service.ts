import { TechnicalIndicatorService, TechnicalIndicators } from './indicators';

export type ExchangeType = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
export type AssetCategory = 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'DERIVATIVE';
export type CandleInterval = '1m' | '5m' | '15m' | '30m' | '1h' | '4h' | '1d' | '1w' | '1mo';
export type HistoryRange = '1D' | '1W' | '1M' | '3M' | '6M' | '1Y' | '3Y' | '5Y' | 'ALL';

export interface MarketQuote {
  symbol: string;
  name: string;
  exchange: ExchangeType;
  category: AssetCategory;
  price: number;
  change: number;
  changePercent: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  bid: number;
  ask: number;
  currency: string;
  status: 'SIMULATED' | 'DELAYED' | 'LIVE' | 'HISTORICAL' | 'HYBRID';
  timestamp: string;
}

export interface Candle {
  timestamp: number; // Unix timestamp in seconds
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface HistoricalDataResult {
  symbol: string;
  name: string;
  exchange: ExchangeType;
  category: AssetCategory;
  currency: string;
  interval: CandleInterval;
  requestedRange?: HistoryRange;
  actualRange: string;
  from: number;
  to: number;
  count: number;
  status: 'SIMULATED' | 'LIVE' | 'HISTORICAL' | 'HYBRID' | 'DELAYED';
  provider: string;
  retentionNotice?: string;
  candles: Candle[];
  indicators?: TechnicalIndicators;
  latestQuote?: MarketQuote;
}

export interface InstrumentMeta {
  symbol: string;
  name: string;
  exchange: ExchangeType;
  category: AssetCategory;
  basePrice: number;
  currency: string;
  lotSize: number;
  tickSize: number;
  volatility: number;
}

export interface IMarketDataProvider {
  getInstrument(symbol: string): InstrumentMeta | undefined;
  getAllInstruments(filter?: { exchange?: string; category?: string; query?: string }): InstrumentMeta[];
  getQuote(symbol: string): MarketQuote | null;
  getQuotes(symbols: string[]): MarketQuote[];
  getCandles(symbol: string, interval?: CandleInterval, limit?: number): Candle[];
  getHistoricalData(
    symbol: string,
    interval?: CandleInterval,
    options?: {
      limit?: number;
      range?: HistoryRange;
      from?: number;
      to?: number;
      includeIndicators?: boolean;
    }
  ): HistoricalDataResult | null;
}


export class MarketDataService {
  private static instruments: InstrumentMeta[] = [
    // NSE Equities & Indices
    { symbol: 'NIFTY 50', name: 'Nifty 50 Index', exchange: 'NSE', category: 'INDEX', basePrice: 24852.15, currency: 'INR', lotSize: 50, tickSize: 0.05, volatility: 0.008 },
    { symbol: 'SENSEX', name: 'BSE Sensex Index', exchange: 'BSE', category: 'INDEX', basePrice: 81420.30, currency: 'INR', lotSize: 10, tickSize: 0.05, volatility: 0.008 },
    { symbol: 'RELIANCE', name: 'Reliance Industries Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 2945.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.012 },
    { symbol: 'HDFCBANK', name: 'HDFC Bank Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1720.80, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.010 },
    { symbol: 'TCS', name: 'Tata Consultancy Services', exchange: 'NSE', category: 'EQUITY', basePrice: 4120.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.011 },
    { symbol: 'INFY', name: 'Infosys Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1885.20, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.013 },
    { symbol: 'ICICIBANK', name: 'ICICI Bank Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 1260.40, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.011 },
    { symbol: 'SBIN', name: 'State Bank of India', exchange: 'NSE', category: 'EQUITY', basePrice: 815.75, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.014 },
    { symbol: 'TATAMOTORS', name: 'Tata Motors Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 960.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.016 },

    // MCX Commodities
    { symbol: 'GOLD 1KG', name: 'MCX Gold Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 78450.00, currency: 'INR', lotSize: 1, tickSize: 1.0, volatility: 0.006 },
    { symbol: 'SILVER 30KG', name: 'MCX Silver Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 94200.00, currency: 'INR', lotSize: 30, tickSize: 1.0, volatility: 0.015 },
    { symbol: 'CRUDEOIL', name: 'Crude Oil 100 BBL', exchange: 'MCX', category: 'COMMODITY', basePrice: 6120.00, currency: 'INR', lotSize: 100, tickSize: 1.0, volatility: 0.022 },
    { symbol: 'NATURALGAS', name: 'Natural Gas Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 245.80, currency: 'INR', lotSize: 1250, tickSize: 0.1, volatility: 0.025 },

    // Crypto 24/7
    { symbol: 'BTC/USDT', name: 'Bitcoin 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 67420.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.028 },
    { symbol: 'ETH/USDT', name: 'Ethereum 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 2540.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.032 },
    { symbol: 'SOL/USDT', name: 'Solana 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 178.50, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.040 },

    // US Equities
    { symbol: 'NVDA', name: 'NVIDIA Corporation', exchange: 'US', category: 'EQUITY', basePrice: 141.54, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.025 },
    { symbol: 'AAPL', name: 'Apple Inc.', exchange: 'US', category: 'EQUITY', basePrice: 231.41, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.012 },
    { symbol: 'MSFT', name: 'Microsoft Corporation', exchange: 'US', category: 'EQUITY', basePrice: 428.15, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.011 },
    { symbol: 'SPY', name: 'SPDR S&P 500 ETF', exchange: 'US', category: 'INDEX', basePrice: 586.46, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.007 },
  ];

  static getInstrument(symbol: string): InstrumentMeta | undefined {
    const clean = symbol.trim().toUpperCase();
    return this.instruments.find((i) => i.symbol === clean);
  }

  static getAllInstruments(filter?: { exchange?: string; category?: string; query?: string }) {
    let list = this.instruments;
    if (filter?.exchange) {
      list = list.filter((i) => i.exchange === filter.exchange);
    }
    if (filter?.category) {
      list = list.filter((i) => i.category === filter.category);
    }
    if (filter?.query) {
      const q = filter.query.toLowerCase();
      list = list.filter((i) => i.symbol.toLowerCase().includes(q) || i.name.toLowerCase().includes(q));
    }
    return list;
  }

  static getQuote(symbol: string): MarketQuote | null {
    const meta = this.getInstrument(symbol);
    if (!meta) return null;

    // Deterministic simulation tick based on timestamp
    const now = Date.now();
    const cycle = (now / 10000) % (2 * Math.PI);
    const noise = Math.sin(cycle * (meta.symbol.charCodeAt(0) % 5 + 1)) * meta.volatility;

    const currentPrice = parseFloat((meta.basePrice * (1 + noise)).toFixed(meta.tickSize < 0.1 ? 2 : 1));
    const openPrice = meta.basePrice;
    const change = parseFloat((currentPrice - openPrice).toFixed(2));
    const changePercent = parseFloat(((change / openPrice) * 100).toFixed(2));

    const spread = meta.tickSize * 2;
    const bid = parseFloat((currentPrice - spread / 2).toFixed(2));
    const ask = parseFloat((currentPrice + spread / 2).toFixed(2));

    const high = parseFloat((Math.max(currentPrice, openPrice) * 1.008).toFixed(2));
    const low = parseFloat((Math.min(currentPrice, openPrice) * 0.992).toFixed(2));

    return {
      symbol: meta.symbol,
      name: meta.name,
      exchange: meta.exchange,
      category: meta.category,
      price: currentPrice,
      change,
      changePercent,
      open: openPrice,
      high,
      low,
      close: currentPrice,
      volume: Math.floor(100000 + Math.abs(noise) * 500000),
      bid,
      ask,
      currency: meta.currency,
      status: 'SIMULATED',
      timestamp: new Date().toISOString(),
    };
  }

  static getQuotes(symbols: string[]): MarketQuote[] {
    return symbols
      .map((s) => this.getQuote(s))
      .filter((q): q is MarketQuote => q !== null);
  }

  /**
   * Aggregates sub-period candles into target timeframe candles
   * strictly adhering to standard financial OHLCV aggregation:
   * - Open = first candle's open
   * - High = highest high across the aggregated period
   * - Low = lowest low across the aggregated period
   * - Close = last candle's close
   * - Volume = sum of all volumes
   */
  static aggregateCandles(
    baseCandles: Candle[],
    targetIntervalSeconds: number
  ): Candle[] {
    if (!baseCandles || baseCandles.length === 0) return [];

    // Ensure chronological order
    const sorted = [...baseCandles].sort((a, b) => a.timestamp - b.timestamp);

    const buckets = new Map<number, Candle[]>();
    for (const c of sorted) {
      const bucketTime = c.timestamp - (c.timestamp % targetIntervalSeconds);
      let bucket = buckets.get(bucketTime);
      if (!bucket) {
        bucket = [];
        buckets.set(bucketTime, bucket);
      }
      bucket.push(c);
    }

    const aggregated: Candle[] = [];
    const sortedBucketTimes = Array.from(buckets.keys()).sort((a, b) => a - b);

    for (const bucketTime of sortedBucketTimes) {
      const group = buckets.get(bucketTime)!;
      if (group.length === 0) continue;

      const open = group[0].open;
      const high = Math.max(...group.map((c) => c.high));
      const low = Math.min(...group.map((c) => c.low));
      const close = group[group.length - 1].close;
      const volume = group.reduce((sum, c) => sum + c.volume, 0);

      aggregated.push({
        timestamp: bucketTime,
        open: parseFloat(open.toFixed(2)),
        high: parseFloat(high.toFixed(2)),
        low: parseFloat(low.toFixed(2)),
        close: parseFloat(close.toFixed(2)),
        volume: Math.round(volume),
      });
    }

    return aggregated;
  }

  private static getSymbolHash(symbol: string): number {
    let hash = 0;
    for (let i = 0; i < symbol.length; i++) {
      hash = (hash * 31 + symbol.charCodeAt(i)) >>> 0;
    }
    return hash;
  }

  private static generateRawCandles(
    meta: InstrumentMeta,
    stepSeconds: number,
    count: number,
    endSeconds: number,
    anchorQuote?: MarketQuote | null
  ): Candle[] {
    const candles: Candle[] = [];
    const hash = this.getSymbolHash(meta.symbol);
    const quote = anchorQuote !== undefined ? anchorQuote : this.getQuote(meta.symbol);
    const targetClose = quote ? quote.price : meta.basePrice;

    // Determine category characteristics for realistic asset movements
    let categoryMultiplier = 1.0;
    if (meta.category === 'CRYPTO') categoryMultiplier = 2.2;
    else if (meta.category === 'COMMODITY') categoryMultiplier = 1.3;
    else if (meta.category === 'INDEX') categoryMultiplier = 0.55;

    const baseVolatility = meta.volatility * categoryMultiplier;

    // Anchor latest candle close to targetClose, then calculate historical ticks backwards
    const closePrices: number[] = new Array(count);
    closePrices[count - 1] = targetClose;

    for (let i = count - 2; i >= 0; i--) {
      const candleTime = endSeconds - (count - 1 - i) * stepSeconds;
      const w1 = Math.sin((candleTime / (stepSeconds * 3)) + (hash % 100));
      const w2 = Math.cos((candleTime / (stepSeconds * 7)) + (hash % 50));
      const w3 = Math.sin((candleTime / (stepSeconds * 13)) * 1.5 + (hash % 23));
      const wave = (w1 * 0.5 + w2 * 0.3 + w3 * 0.2);

      const changePct = wave * baseVolatility * (stepSeconds >= 3600 ? 1.4 : 0.8);
      const prev = closePrices[i + 1] / (1 + changePct);
      closePrices[i] = parseFloat(prev.toFixed(meta.tickSize < 0.1 ? 2 : 1));
    }

    for (let i = 0; i < count; i++) {
      const candleTime = endSeconds - (count - 1 - i) * stepSeconds;
      const c = closePrices[i];
      const prevC = i === 0 ? closePrices[0] : closePrices[i - 1];
      const o = prevC;

      const wickSeed1 = Math.abs(Math.sin(candleTime * 17 + hash)) * 0.003 * categoryMultiplier;
      const wickSeed2 = Math.abs(Math.cos(candleTime * 29 + hash)) * 0.003 * categoryMultiplier;

      const bodyMax = Math.max(o, c);
      const bodyMin = Math.min(o, c);

      const h = parseFloat((bodyMax * (1 + wickSeed1)).toFixed(meta.tickSize < 0.1 ? 2 : 1));
      const l = parseFloat((Math.max(bodyMin * (1 - wickSeed2), meta.tickSize)).toFixed(meta.tickSize < 0.1 ? 2 : 1));

      const volSeed = Math.abs(Math.sin(candleTime + (hash % 1000)));
      const vol = Math.floor(10000 + volSeed * 80000 * (meta.category === 'INDEX' ? 8 : 1));

      candles.push({
        timestamp: candleTime,
        open: o,
        high: Math.max(h, bodyMax),
        low: Math.min(l, bodyMin),
        close: c,
        volume: vol,
      });
    }

    return candles;
  }

  static getRangeBounds(range: HistoryRange, nowSeconds: number): { from: number; to: number } {
    let seconds = 86400;
    switch (range) {
      case '1D':
        seconds = 86400;
        break;
      case '1W':
        seconds = 7 * 86400;
        break;
      case '1M':
        seconds = 30 * 86400;
        break;
      case '3M':
        seconds = 90 * 86400;
        break;
      case '6M':
        seconds = 180 * 86400;
        break;
      case '1Y':
        seconds = 365 * 86400;
        break;
      case '3Y':
        seconds = 3 * 365 * 86400;
        break;
      case '5Y':
        seconds = 5 * 365 * 86400;
        break;
      case 'ALL':
        seconds = 5 * 365 * 86400;
        break;
      default:
        seconds = 30 * 86400;
    }
    return {
      from: nowSeconds - seconds,
      to: nowSeconds,
    };
  }

  static getMaxRetentionSeconds(interval: CandleInterval): number {
    switch (interval) {
      case '1m':
        return 7 * 86400; // 7 days max for 1m
      case '5m':
        return 30 * 86400; // 30 days max for 5m
      case '15m':
      case '30m':
        return 90 * 86400; // 90 days max for 15m/30m
      case '1h':
      case '4h':
        return 365 * 86400; // 1 year max for 1h/4h
      case '1d':
      case '1w':
      case '1mo':
      default:
        return 5 * 365 * 86400; // 5 full years for daily, weekly, monthly
    }
  }

  static getCandles(
    symbol: string,
    interval: CandleInterval = '15m',
    limit: number = 60,
    range?: HistoryRange,
    from?: number,
    to?: number,
    anchorQuote?: MarketQuote | null
  ): Candle[] {
    const meta = this.getInstrument(symbol);
    if (!meta) return [];

    const intervalSecondsMap: Record<CandleInterval, number> = {
      '1m': 60,
      '5m': 300,
      '15m': 900,
      '30m': 1800,
      '1h': 3600,
      '4h': 14400,
      '1d': 86400,
      '1w': 604800,
      '1mo': 2592000,
    };

    const targetSeconds = intervalSecondsMap[interval] || 900;
    const nowSeconds = Math.floor(Date.now() / 1000);
    const endSeconds = to ? to - (to % targetSeconds) : nowSeconds - (nowSeconds % targetSeconds);

    let candleCount = limit;
    if (range) {
      const bounds = this.getRangeBounds(range, endSeconds);
      const span = bounds.to - bounds.from;
      candleCount = Math.min(Math.max(Math.ceil(span / targetSeconds), 10), 1300);
    } else if (from) {
      const span = Math.max(endSeconds - from, targetSeconds);
      candleCount = Math.min(Math.max(Math.ceil(span / targetSeconds), 5), 1300);
    }

    // Direct generation for 1m, 1mo, or long histories
    if (interval === '1m' || interval === '1mo' || candleCount > 120 || interval === '1d' || interval === '1w') {
      return this.generateRawCandles(meta, targetSeconds, candleCount, endSeconds, anchorQuote);
    }

    // Sub-period aggregation for refined intraday bars
    let subIntervalSeconds = 60;
    let factor = 5;

    if (interval === '5m') {
      subIntervalSeconds = 60;
      factor = 5;
    } else if (interval === '15m') {
      subIntervalSeconds = 300;
      factor = 3;
    } else if (interval === '30m') {
      subIntervalSeconds = 900;
      factor = 2;
    } else if (interval === '1h') {
      subIntervalSeconds = 900;
      factor = 4;
    } else if (interval === '4h') {
      subIntervalSeconds = 3600;
      factor = 4;
    }

    const rawCandles = this.generateRawCandles(
      meta,
      subIntervalSeconds,
      candleCount * factor,
      endSeconds + targetSeconds - subIntervalSeconds,
      anchorQuote
    );
    const aggregated = this.aggregateCandles(rawCandles, targetSeconds);
    return aggregated.slice(-candleCount);
  }

  static getHistoricalData(
    symbol: string,
    interval: CandleInterval = '15m',
    options?: {
      limit?: number;
      range?: HistoryRange;
      from?: number;
      to?: number;
      includeIndicators?: boolean;
    }
  ): HistoricalDataResult | null {
    const meta = this.getInstrument(symbol);
    if (!meta) return null;

    const intervalSecondsMap: Record<CandleInterval, number> = {
      '1m': 60,
      '5m': 300,
      '15m': 900,
      '30m': 1800,
      '1h': 3600,
      '4h': 14400,
      '1d': 86400,
      '1w': 604800,
      '1mo': 2592000,
    };
    const targetSeconds = intervalSecondsMap[interval] || 900;
    const nowSeconds = Math.floor(Date.now() / 1000);

    let to = options?.to || nowSeconds;
    let from = options?.from;
    let retentionNotice: string | undefined;

    if (options?.range) {
      const bounds = this.getRangeBounds(options.range, to);
      from = bounds.from;
      to = bounds.to;
    } else if (!from) {
      const defaultCount = options?.limit || 60;
      from = to - defaultCount * targetSeconds;
    }

    // Apply retention window constraint for intraday intervals
    const maxRetention = this.getMaxRetentionSeconds(interval);
    if (to - from > maxRetention) {
      retentionNotice = `${interval} candles have an intraday retention limit of ${Math.round(maxRetention / 86400)} days. Displaying longest available intraday window. Switch to 1D/1W/1M or a daily/weekly interval for 5-year views.`;
      from = Math.max(from, to - maxRetention);
    }

    const calculatedLimit = Math.min(Math.max(Math.ceil((to - from) / targetSeconds), 10), 1300);
    const finalLimit = options?.limit ? Math.min(options.limit, calculatedLimit) : calculatedLimit;

    const quote = this.getQuote(symbol);
    const candles = this.getCandles(symbol, interval, finalLimit, options?.range, from, to, quote);

    let indicators: TechnicalIndicators | undefined;
    if (options?.includeIndicators) {
      indicators = TechnicalIndicatorService.calculateAll(candles);
    }

    const actualRange =
      candles.length > 0
        ? `${new Date(candles[0].timestamp * 1000).toISOString().split('T')[0]} to ${new Date(candles[candles.length - 1].timestamp * 1000).toISOString().split('T')[0]}`
        : 'No data';

    return {
      symbol: meta.symbol,
      name: meta.name,
      exchange: meta.exchange,
      category: meta.category,
      currency: meta.currency,
      interval,
      requestedRange: options?.range,
      actualRange,
      from: candles.length > 0 ? candles[0].timestamp : from,
      to: candles.length > 0 ? candles[candles.length - 1].timestamp : to,
      count: candles.length,
      status: 'SIMULATED',
      provider: 'TradeVerse Synthetic Market Engine (Deterministic)',
      retentionNotice,
      candles,
      indicators,
      latestQuote: quote || undefined,
    };
  }

  static getMarketStatus() {
    const now = new Date();
    // UTC Hour
    const utcHours = now.getUTCHours();
    const utcDay = now.getUTCDay();

    // Indian market: 9:15 AM IST to 3:30 PM IST (3:45 UTC to 10:00 UTC), Mon-Fri
    const isWeekday = utcDay >= 1 && utcDay <= 5;
    const isNSEOpen = isWeekday && utcHours >= 3 && utcHours < 10;
    // MCX: 9:00 AM IST to 11:30 PM IST (3:30 UTC to 18:00 UTC), Mon-Fri
    const isMCXOpen = isWeekday && utcHours >= 3 && utcHours < 18;
    // US: 9:30 AM EDT to 4:00 PM EDT (13:30 UTC to 20:00 UTC), Mon-Fri
    const isUSOpen = isWeekday && utcHours >= 13 && utcHours < 20;

    return {
      exchanges: [
        { exchange: 'NSE', isOpen: isNSEOpen, session: isNSEOpen ? 'REGULAR' : 'CLOSED', timezone: 'Asia/Kolkata' },
        { exchange: 'BSE', isOpen: isNSEOpen, session: isNSEOpen ? 'REGULAR' : 'CLOSED', timezone: 'Asia/Kolkata' },
        { exchange: 'MCX', isOpen: isMCXOpen, session: isMCXOpen ? 'REGULAR' : 'CLOSED', timezone: 'Asia/Kolkata' },
        { exchange: 'US', isOpen: isUSOpen, session: isUSOpen ? 'REGULAR' : 'CLOSED', timezone: 'America/New_York' },
        { exchange: 'CRYPTO', isOpen: true, session: '24_7', timezone: 'UTC' },
      ],
      serverTime: now.toISOString(),
      disclaimer: 'Paper Trading Market Status. Timings reflect exchange matching hours.',
    };
  }
}
