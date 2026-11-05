import { TechnicalIndicatorService, TechnicalIndicators } from './indicators';

export type ExchangeType = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
export type AssetCategory = 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'DERIVATIVE';
export type CandleInterval = '1m' | '5m' | '15m' | '30m' | '1h' | '4h' | '1d' | '1w' | '1mo' | '1M';
export type HistoryRange = '1D' | '5D' | '1W' | '1M' | '3M' | '6M' | '1Y' | '3Y' | '5Y' | 'MAX' | 'ALL';

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
  rangeNotice?: string;
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
    { symbol: 'BANKNIFTY', name: 'Nifty Bank Index', exchange: 'NSE', category: 'INDEX', basePrice: 51820.00, currency: 'INR', lotSize: 15, tickSize: 0.05, volatility: 0.010 },
    { symbol: 'FINNIFTY', name: 'Nifty Financial Services', exchange: 'NSE', category: 'INDEX', basePrice: 23450.00, currency: 'INR', lotSize: 40, tickSize: 0.05, volatility: 0.009 },
    { symbol: 'SENSEX', name: 'BSE Sensex Index', exchange: 'BSE', category: 'INDEX', basePrice: 81420.30, currency: 'INR', lotSize: 10, tickSize: 0.05, volatility: 0.008 },
    { symbol: 'RELIANCE', name: 'Reliance Industries Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 2945.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.012 },
    { symbol: 'HDFCBANK', name: 'HDFC Bank Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1720.80, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.010 },
    { symbol: 'TCS', name: 'Tata Consultancy Services', exchange: 'NSE', category: 'EQUITY', basePrice: 4120.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.011 },
    { symbol: 'INFY', name: 'Infosys Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1885.20, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.013 },
    { symbol: 'ICICIBANK', name: 'ICICI Bank Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 1260.40, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.011 },
    { symbol: 'SBIN', name: 'State Bank of India', exchange: 'NSE', category: 'EQUITY', basePrice: 815.75, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.014 },
    { symbol: 'TATAMOTORS', name: 'Tata Motors Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 960.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.016 },
    { symbol: 'BAJFINANCE', name: 'Bajaj Finance Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 6850.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.015 },
    { symbol: 'BHARTIARTL', name: 'Bharti Airtel Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1680.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.012 },
    { symbol: 'ITC', name: 'ITC Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 485.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.009 },
    { symbol: 'LT', name: 'Larsen & Toubro Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 3560.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.013 },
    { symbol: 'HINDUNILVR', name: 'Hindustan Unilever Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 2420.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.008 },
    { symbol: 'KOTAKBANK', name: 'Kotak Mahindra Bank', exchange: 'NSE', category: 'EQUITY', basePrice: 1780.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.011 },
    { symbol: 'MARUTI', name: 'Maruti Suzuki India Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 11450.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.014 },
    { symbol: 'SUNPHARMA', name: 'Sun Pharmaceutical Industries', exchange: 'NSE', category: 'EQUITY', basePrice: 1820.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.012 },
    { symbol: 'WIPRO', name: 'Wipro Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 540.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.013 },
    { symbol: 'TITAN', name: 'Titan Company Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 3320.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.014 },
    { symbol: 'TATASTEEL', name: 'Tata Steel Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 152.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.018 },
    { symbol: 'AXISBANK', name: 'Axis Bank Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 1180.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.012 },
    { symbol: 'ZOMATO', name: 'Zomato Limited', exchange: 'NSE', category: 'EQUITY', basePrice: 265.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.024 },
    { symbol: 'JIOFIN', name: 'Jio Financial Services', exchange: 'NSE', category: 'EQUITY', basePrice: 320.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.019 },

    // Adani Group Equities (Matches "Adani", "Adhani", "ADANIENT", etc.)
    { symbol: 'ADANIENT', name: 'Adani Enterprises Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 2840.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.022 },
    { symbol: 'ADANIPORTS', name: 'Adani Ports and SEZ Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 1360.50, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.018 },
    { symbol: 'ADANIGREEN', name: 'Adani Green Energy Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 1580.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.025 },
    { symbol: 'ATGL', name: 'Adani Total Gas Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 720.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.023 },
    { symbol: 'ADANIPOWER', name: 'Adani Power Ltd.', exchange: 'NSE', category: 'EQUITY', basePrice: 590.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.024 },
    { symbol: 'AMBUJACEM', name: 'Ambuja Cements Ltd. (Adani)', exchange: 'NSE', category: 'EQUITY', basePrice: 560.00, currency: 'INR', lotSize: 1, tickSize: 0.05, volatility: 0.015 },

    // MCX Commodities
    { symbol: 'GOLD 1KG', name: 'MCX Gold Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 78450.00, currency: 'INR', lotSize: 1, tickSize: 1.0, volatility: 0.006 },
    { symbol: 'SILVER 30KG', name: 'MCX Silver Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 94200.00, currency: 'INR', lotSize: 30, tickSize: 1.0, volatility: 0.015 },
    { symbol: 'CRUDEOIL', name: 'Crude Oil 100 BBL', exchange: 'MCX', category: 'COMMODITY', basePrice: 6120.00, currency: 'INR', lotSize: 100, tickSize: 1.0, volatility: 0.022 },
    { symbol: 'NATURALGAS', name: 'Natural Gas Futures', exchange: 'MCX', category: 'COMMODITY', basePrice: 245.80, currency: 'INR', lotSize: 1250, tickSize: 0.1, volatility: 0.025 },

    // Crypto 24/7
    { symbol: 'BTC/USDT', name: 'Bitcoin 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 77568.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.028 },
    { symbol: 'ETH/USDT', name: 'Ethereum 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 2540.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.032 },
    { symbol: 'SOL/USDT', name: 'Solana 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 178.50, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.040 },
    { symbol: 'DOGE/USDT', name: 'Dogecoin 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 0.165, currency: 'USD', lotSize: 1, tickSize: 0.0001, volatility: 0.045 },
    { symbol: 'BNB/USDT', name: 'Binance Coin 24/7 Simulator', exchange: 'CRYPTO', category: 'CRYPTO', basePrice: 595.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.026 },

    // US Equities
    { symbol: 'NVDA', name: 'NVIDIA Corporation', exchange: 'US', category: 'EQUITY', basePrice: 141.54, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.025 },
    { symbol: 'AAPL', name: 'Apple Inc.', exchange: 'US', category: 'EQUITY', basePrice: 231.41, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.012 },
    { symbol: 'MSFT', name: 'Microsoft Corporation', exchange: 'US', category: 'EQUITY', basePrice: 428.15, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.011 },
    { symbol: 'TSLA', name: 'Tesla Inc.', exchange: 'US', category: 'EQUITY', basePrice: 258.40, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.028 },
    { symbol: 'GOOGL', name: 'Alphabet Inc. Class A', exchange: 'US', category: 'EQUITY', basePrice: 172.50, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.014 },
    { symbol: 'AMZN', name: 'Amazon.com Inc.', exchange: 'US', category: 'EQUITY', basePrice: 188.20, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.016 },
    { symbol: 'META', name: 'Meta Platforms Inc.', exchange: 'US', category: 'EQUITY', basePrice: 582.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.020 },
    { symbol: 'NFLX', name: 'Netflix Inc.', exchange: 'US', category: 'EQUITY', basePrice: 760.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.022 },
    { symbol: 'AMD', name: 'Advanced Micro Devices', exchange: 'US', category: 'EQUITY', basePrice: 155.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.026 },
    { symbol: 'COIN', name: 'Coinbase Global Inc.', exchange: 'US', category: 'EQUITY', basePrice: 215.00, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.038 },
    { symbol: 'SPY', name: 'SPDR S&P 500 ETF', exchange: 'US', category: 'INDEX', basePrice: 586.46, currency: 'USD', lotSize: 1, tickSize: 0.01, volatility: 0.007 },
  ];

  static getInstrument(symbol: string): InstrumentMeta | undefined {
    const clean = symbol.trim().toUpperCase();
    const found = this.instruments.find((i) => i.symbol === clean);
    if (found) return found;

    try {
      // Lazy lookup from InstrumentMasterService
      const { InstrumentMasterService } = require('./instrumentMaster.service');
      const master = InstrumentMasterService.getInstrument(clean);
      if (master) {
        return {
          symbol: master.symbol,
          name: master.displayName,
          exchange: master.exchange,
          category: (master.assetClass === 'ETF' ? 'EQUITY' : master.assetClass) as AssetCategory,
          basePrice: master.basePrice || 100.0,
          currency: master.quoteCurrency,
          lotSize: master.lotSize,
          tickSize: master.tickSize,
          volatility: 0.015,
        };
      }
    } catch {
      // Fallback
    }

    return undefined;
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
      const rawQ = filter.query.toLowerCase().trim();
      const normQ = rawQ.replace(/dh/g, 'd'); // Handles 'adhani' -> 'adani'
      list = list.filter((i) => {
        const sym = i.symbol.toLowerCase();
        const nm = i.name.toLowerCase();
        return (
          sym.includes(rawQ) ||
          nm.includes(rawQ) ||
          sym.includes(normQ) ||
          nm.includes(normQ)
        );
      });
    }
    return list;
  }

  static getQuote(symbol: string): MarketQuote | null {
    const meta = this.getInstrument(symbol) || {
      symbol: symbol.toUpperCase(),
      name: symbol.toUpperCase(),
      exchange: (symbol.includes('/') || symbol === 'BTC' || symbol === 'ETH' ? 'CRYPTO' : 'NSE') as ExchangeType,
      category: 'EQUITY' as AssetCategory,
      basePrice: 100.0,
      currency: symbol.includes('/') ? 'USD' : 'INR',
      lotSize: 1,
      tickSize: 0.05,
      volatility: 0.012,
    };

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
      case '5D':
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
      case 'MAX':
      case 'ALL':
        seconds = 10 * 365 * 86400;
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
    const meta = this.getInstrument(symbol) || {
      symbol: symbol.toUpperCase(),
      name: symbol.toUpperCase(),
      exchange: (symbol.includes('/') || symbol === 'BTC' || symbol === 'ETH' ? 'CRYPTO' : 'NSE') as ExchangeType,
      category: 'EQUITY' as AssetCategory,
      basePrice: 100.0,
      currency: symbol.includes('/') ? 'USD' : 'INR',
      lotSize: 1,
      tickSize: 0.05,
      volatility: 0.012,
    };

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
      '1M': 2592000,
    };

    const targetSeconds = intervalSecondsMap[interval] || 900;
    const nowSeconds = Math.floor(Date.now() / 1000);
    const endSeconds = to ? to - (to % targetSeconds) : nowSeconds - (nowSeconds % targetSeconds);

    let candleCount = limit;
    if (range) {
      const bounds = this.getRangeBounds(range, endSeconds);
      const span = bounds.to - bounds.from;
      candleCount = Math.min(Math.max(Math.ceil(span / targetSeconds), 10), 5000);
    } else if (from) {
      const span = Math.max(endSeconds - from, targetSeconds);
      candleCount = Math.min(Math.max(Math.ceil(span / targetSeconds), 5), 5000);
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
    const meta = this.getInstrument(symbol) || {
      symbol: symbol.toUpperCase(),
      name: symbol.toUpperCase(),
      exchange: (symbol.includes('/') || symbol === 'BTC' || symbol === 'ETH' ? 'CRYPTO' : 'NSE') as ExchangeType,
      category: 'EQUITY' as AssetCategory,
      basePrice: 100.0,
      currency: symbol.includes('/') ? 'USD' : 'INR',
      lotSize: 1,
      tickSize: 0.05,
      volatility: 0.012,
    };

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
      '1M': 2592000,
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

    const calculatedLimit = Math.min(Math.max(Math.ceil((to - from) / targetSeconds), 10), 5000);
    const finalLimit = options?.limit ? Math.min(options.limit, calculatedLimit) : calculatedLimit;

    const quote = this.getQuote(symbol);
    const rawCandles = this.getCandles(symbol, interval, finalLimit, options?.range, from, to, quote);
    const candles = (options?.limit && !options?.range) ? rawCandles.slice(-options.limit) : rawCandles;

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

    // 1. Calculate IST Time (UTC + 5 hours 30 mins)
    const istOffsetMs = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + istOffsetMs);
    const istDay = istDate.getUTCDay(); // 0: Sun, 6: Sat
    const istMinutes = istDate.getUTCHours() * 60 + istDate.getUTCMinutes();
    const isIndianWeekday = istDay >= 1 && istDay <= 5;

    // Standard NSE/BSE Sessions: Pre-open 09:00-09:15 (540-555m), Regular 09:15-15:30 (555-930m), Post 15:30-16:00 (930-960m)
    let nseSession: 'PRE_OPEN' | 'REGULAR' | 'POST_CLOSE' | 'CLOSED' = 'CLOSED';
    let isNSEOpen = false;

    if (isIndianWeekday) {
      if (istMinutes >= 540 && istMinutes < 555) {
        nseSession = 'PRE_OPEN';
        isNSEOpen = true; // Pre-open auction accepting orders
      } else if (istMinutes >= 555 && istMinutes < 930) {
        nseSession = 'REGULAR';
        isNSEOpen = true;
      } else if (istMinutes >= 930 && istMinutes < 960) {
        nseSession = 'POST_CLOSE';
        isNSEOpen = false;
      }
    }

    // MCX: 09:00 AM to 11:30 PM IST (540 to 1410m), Mon-Fri
    let mcxSession: 'REGULAR' | 'CLOSED' = 'CLOSED';
    let isMCXOpen = false;
    if (isIndianWeekday && istMinutes >= 540 && istMinutes < 1410) {
      mcxSession = 'REGULAR';
      isMCXOpen = true;
    }

    // 2. Calculate US Eastern Time (UTC - 5h standard, UTC - 4h DST)
    // Approximate with UTC - 4 / - 5
    const utcHours = now.getUTCHours();
    const utcMinutes = now.getUTCMinutes();
    const totalUtcMinutes = utcHours * 60 + utcMinutes;
    const utcDay = now.getUTCDay();
    const isUsWeekday = utcDay >= 1 && utcDay <= 5;

    // US Regular matching: 13:30 UTC to 20:00 UTC (9:30 AM to 4:00 PM EST)
    let usSession: 'PRE_MARKET' | 'REGULAR' | 'AFTER_HOURS' | 'CLOSED' = 'CLOSED';
    let isUSOpen = false;

    if (isUsWeekday) {
      if (totalUtcMinutes >= 480 && totalUtcMinutes < 810) {
        usSession = 'PRE_MARKET';
      } else if (totalUtcMinutes >= 810 && totalUtcMinutes < 1200) {
        usSession = 'REGULAR';
        isUSOpen = true;
      } else if (totalUtcMinutes >= 1200 && totalUtcMinutes < 1440) {
        usSession = 'AFTER_HOURS';
      }
    }

    return {
      exchanges: [
        {
          exchange: 'NSE',
          isOpen: isNSEOpen,
          session: nseSession,
          timezone: 'Asia/Kolkata',
          tradingHours: '09:15 - 15:30 IST',
          preOpenHours: '09:00 - 09:15 IST',
        },
        {
          exchange: 'BSE',
          isOpen: isNSEOpen,
          session: nseSession,
          timezone: 'Asia/Kolkata',
          tradingHours: '09:15 - 15:30 IST',
          preOpenHours: '09:00 - 09:15 IST',
        },
        {
          exchange: 'MCX',
          isOpen: isMCXOpen,
          session: mcxSession,
          timezone: 'Asia/Kolkata',
          tradingHours: '09:00 - 23:30 IST',
        },
        {
          exchange: 'US',
          isOpen: isUSOpen,
          session: usSession,
          timezone: 'America/New_York',
          tradingHours: '09:30 - 16:00 EST',
        },
        {
          exchange: 'CRYPTO',
          isOpen: true,
          session: '24_7',
          timezone: 'UTC',
          tradingHours: '24/7/365 Continuous',
        },
      ],
      serverTime: now.toISOString(),
      disclaimer: 'Market status reflects live exchange matching sessions and trading calendars.',
    };
  }
}
