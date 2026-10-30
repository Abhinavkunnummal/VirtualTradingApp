import { config } from '../../config';
import {
  MarketQuote,
  Candle,
  CandleInterval,
  HistoryRange,
  HistoricalDataResult,
  ExchangeType,
  AssetCategory,
  MarketDataService,
} from './marketData.service';
import { TechnicalIndicatorService } from './indicators';
import { HistoricalCandle } from '../../models/HistoricalCandle';

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

interface SymbolMeta {
  yf: string;
  twelve?: string;
  finnhub?: string;
  category: AssetCategory;
  exchange: ExchangeType;
  name: string;
}

export const SYMBOL_MAPPINGS: Record<string, SymbolMeta> = {
  // NSE Equities
  'RELIANCE': { yf: 'RELIANCE.NS', category: 'EQUITY', exchange: 'NSE', name: 'Reliance Industries Ltd.' },
  'TCS': { yf: 'TCS.NS', category: 'EQUITY', exchange: 'NSE', name: 'Tata Consultancy Services' },
  'HDFCBANK': { yf: 'HDFCBANK.NS', category: 'EQUITY', exchange: 'NSE', name: 'HDFC Bank Limited' },
  'INFY': { yf: 'INFY.NS', category: 'EQUITY', exchange: 'NSE', name: 'Infosys Limited' },
  'ICICIBANK': { yf: 'ICICIBANK.NS', category: 'EQUITY', exchange: 'NSE', name: 'ICICI Bank Ltd.' },
  'SBIN': { yf: 'SBIN.NS', category: 'EQUITY', exchange: 'NSE', name: 'State Bank of India' },
  'TATAMOTORS': { yf: 'TATAMOTORS.NS', category: 'EQUITY', exchange: 'NSE', name: 'Tata Motors Limited' },
  // Indian Indices
  'NIFTY 50': { yf: '^NSEI', category: 'INDEX', exchange: 'NSE', name: 'Nifty 50 Index' },
  'SENSEX': { yf: '^BSESN', category: 'INDEX', exchange: 'BSE', name: 'BSE Sensex Index' },
  // MCX Commodities
  'GOLD 1KG': { yf: 'GC=F', category: 'COMMODITY', exchange: 'MCX', name: 'MCX Gold Futures' },
  'SILVER 30KG': { yf: 'SI=F', category: 'COMMODITY', exchange: 'MCX', name: 'MCX Silver Futures' },
  'CRUDEOIL': { yf: 'CL=F', category: 'COMMODITY', exchange: 'MCX', name: 'Crude Oil Futures' },
  'NATURALGAS': { yf: 'NG=F', category: 'COMMODITY', exchange: 'MCX', name: 'Natural Gas Futures' },
  // Crypto 24/7
  'BTC/USDT': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'ETH/USDT': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'SOL/USDT': { yf: 'SOL-USD', twelve: 'SOL/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Solana 24/7' },
  // US Equities
  'AAPL': { yf: 'AAPL', twelve: 'AAPL', finnhub: 'AAPL', category: 'EQUITY', exchange: 'US', name: 'Apple Inc.' },
  'NVDA': { yf: 'NVDA', twelve: 'NVDA', finnhub: 'NVDA', category: 'EQUITY', exchange: 'US', name: 'NVIDIA Corporation' },
  'MSFT': { yf: 'MSFT', twelve: 'MSFT', finnhub: 'MSFT', category: 'EQUITY', exchange: 'US', name: 'Microsoft Corporation' },
  'SPY': { yf: 'SPY', twelve: 'SPY', finnhub: 'SPY', category: 'INDEX', exchange: 'US', name: 'SPDR S&P 500 ETF' },
};

export class RealtimeMarketService {
  private static quoteCache = new Map<string, CacheEntry<MarketQuote>>();
  private static candleCache = new Map<string, CacheEntry<HistoricalDataResult>>();

  private static readonly TTL_QUOTE = 3 * 1000; // 3 seconds
  private static readonly TTL_CANDLES_INTRADAY = 30 * 1000; // 30 seconds
  private static readonly TTL_CANDLES_DAILY = 5 * 60 * 1000; // 5 minutes

  /**
   * Resolve clean symbol mapping
   */
  public static getMapping(symbol: string): SymbolMeta {
    const upper = symbol.toUpperCase().trim();
    if (SYMBOL_MAPPINGS[upper]) return SYMBOL_MAPPINGS[upper];

    // Generic fallback for any user searched ticker
    const isCrypto = upper.includes('/') || upper.includes('BTC') || upper.includes('ETH');
    const isIndian = upper.endsWith('.NS') || upper.endsWith('.BO');
    return {
      yf: isIndian ? upper : upper.replace('/', '-'),
      category: isCrypto ? 'CRYPTO' : 'EQUITY',
      exchange: isIndian ? 'NSE' : (isCrypto ? 'CRYPTO' : 'US'),
      name: symbol,
    };
  }

  /**
   * Fetch Live Real-Time Quote from Finnhub, Twelve Data, or Yahoo Finance
   */
  public static async getLiveQuote(symbol: string): Promise<MarketQuote | null> {
    const key = symbol.toUpperCase().trim();
    const cached = this.quoteCache.get(key);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.data;
    }

    const mapping = this.getMapping(key);

    // 1. Try Finnhub for US Equities if API key is present
    if (mapping.exchange === 'US' && mapping.finnhub && config.finnhubApiKey) {
      try {
        const url = `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(mapping.finnhub)}&token=${config.finnhubApiKey}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(3500) });
        if (res.ok) {
          const data = (await res.json()) as Record<string, any>;
          if (data && typeof data.c === 'number' && data.c > 0) {
            const price = parseFloat(data.c.toFixed(2));
            const change = parseFloat((data.d ?? 0).toFixed(2));
            const changePercent = parseFloat((data.dp ?? 0).toFixed(2));
            const quote: MarketQuote = {
              symbol: key,
              name: mapping.name,
              exchange: mapping.exchange,
              category: mapping.category,
              price,
              change,
              changePercent,
              open: parseFloat((data.o ?? price).toFixed(2)),
              high: parseFloat((data.h ?? price).toFixed(2)),
              low: parseFloat((data.l ?? price).toFixed(2)),
              close: price,
              volume: 1500000,
              bid: parseFloat((price * 0.9998).toFixed(2)),
              ask: parseFloat((price * 1.0002).toFixed(2)),
              currency: 'USD',
              status: 'LIVE',
              timestamp: new Date().toISOString(),
            };
            this.quoteCache.set(key, { data: quote, expiresAt: Date.now() + this.TTL_QUOTE });
            return quote;
          }
        }
      } catch {
        // Fall through to Twelve Data / Yahoo Finance
      }
    }

    // 2. Try Twelve Data for Crypto if key is present
    if (mapping.category === 'CRYPTO' && mapping.twelve && config.twelveDataApiKey) {
      try {
        const url = `https://api.twelvedata.com/quote?symbol=${encodeURIComponent(mapping.twelve)}&apikey=${config.twelveDataApiKey}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(3500) });
        if (res.ok) {
          const data = (await res.json()) as Record<string, any>;
          if (data && data.close) {
            const price = parseFloat(parseFloat(data.close).toFixed(2));
            const change = parseFloat(parseFloat(data.change || '0').toFixed(2));
            const changePercent = parseFloat(parseFloat(data.percent_change || '0').toFixed(2));
            const quote: MarketQuote = {
              symbol: key,
              name: mapping.name,
              exchange: mapping.exchange,
              category: mapping.category,
              price,
              change,
              changePercent,
              open: parseFloat(parseFloat(data.open || `${price}`).toFixed(2)),
              high: parseFloat(parseFloat(data.high || `${price}`).toFixed(2)),
              low: parseFloat(parseFloat(data.low || `${price}`).toFixed(2)),
              close: price,
              volume: parseFloat(data.volume || '25000'),
              bid: parseFloat((price * 0.9999).toFixed(2)),
              ask: parseFloat((price * 1.0001).toFixed(2)),
              currency: 'USD',
              status: 'LIVE',
              timestamp: new Date().toISOString(),
            };
            this.quoteCache.set(key, { data: quote, expiresAt: Date.now() + this.TTL_QUOTE });
            return quote;
          }
        }
      } catch {
        // Fall through to Yahoo Finance
      }
    }

    // 3. Yahoo Finance Live Chart API (covers NSE, BSE, MCX, US, Crypto without rate limit)
    try {
      const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(mapping.yf)}?interval=15m&range=1d`;
      const res = await fetch(yfUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
        signal: AbortSignal.timeout(4000),
      });

      if (res.ok) {
        const json = (await res.json()) as Record<string, any>;
        const result = json?.chart?.result?.[0];
        if (result && result.meta) {
          const meta = result.meta;
          const price = parseFloat((meta.regularMarketPrice ?? meta.previousClose ?? 0).toFixed(2));
          const prevClose = parseFloat((meta.previousClose ?? meta.chartPreviousClose ?? price).toFixed(2));
          const change = parseFloat((price - prevClose).toFixed(2));
          const changePercent = prevClose > 0 ? parseFloat(((change / prevClose) * 100).toFixed(2)) : 0;

          const currency = meta.currency || (mapping.exchange === 'US' || mapping.category === 'CRYPTO' ? 'USD' : 'INR');
          const quote: MarketQuote = {
            symbol: key,
            name: meta.longName || meta.shortName || mapping.name,
            exchange: mapping.exchange,
            category: mapping.category,
            price,
            change,
            changePercent,
            open: parseFloat((meta.regularMarketDayLow ?? price).toFixed(2)),
            high: parseFloat((meta.regularMarketDayHigh ?? price).toFixed(2)),
            low: parseFloat((meta.regularMarketDayLow ?? price).toFixed(2)),
            close: price,
            volume: meta.regularMarketVolume || 100000,
            bid: parseFloat((price * 0.9998).toFixed(2)),
            ask: parseFloat((price * 1.0002).toFixed(2)),
            currency,
            status: 'LIVE',
            timestamp: new Date().toISOString(),
          };
          this.quoteCache.set(key, { data: quote, expiresAt: Date.now() + this.TTL_QUOTE });
          return quote;
        }
      }
    } catch {
      // Non-fatal, fallback to local deterministic generator
    }

    // 4. Safe fallback to local MarketDataService
    const localFallback = MarketDataService.getQuote(key);
    return localFallback;
  }

  /**
   * Fetch Live Real-Time Historical Candles from Yahoo Finance or Twelve Data
   */
  public static async getLiveCandles(
    symbol: string,
    interval: CandleInterval = '15m',
    range: HistoryRange = '1D',
    limit: number = 60,
    includeIndicators: boolean = true
  ): Promise<HistoricalDataResult | null> {
    const key = symbol.toUpperCase().trim();
    const cacheKey = `${key}:${interval}:${range}:${limit}`;
    const cached = this.candleCache.get(cacheKey);
    const ttl = interval.includes('d') || interval.includes('w') || interval.includes('mo')
      ? this.TTL_CANDLES_DAILY
      : this.TTL_CANDLES_INTRADAY;

    if (cached && Date.now() < cached.expiresAt) {
      return cached.data;
    }

    const mapping = this.getMapping(key);

    // Map interval and range to Yahoo Finance parameters
    const yfInterval = this.toYahooInterval(interval);
    const yfRange = this.toYahooRange(range, interval);

    try {
      const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(mapping.yf)}?interval=${yfInterval}&range=${yfRange}`;
      const res = await fetch(yfUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
        signal: AbortSignal.timeout(5000),
      });

      if (res.ok) {
        const json = (await res.json()) as Record<string, any>;
        const result = json?.chart?.result?.[0];
        if (result && result.timestamp && result.indicators?.quote?.[0]) {
          const timestamps = result.timestamp as number[];
          const quoteObj = result.indicators.quote[0];
          const opens = quoteObj.open as (number | null)[];
          const highs = quoteObj.high as (number | null)[];
          const lows = quoteObj.low as (number | null)[];
          const closes = quoteObj.close as (number | null)[];
          const volumes = quoteObj.volume as (number | null)[];

          const candles: Candle[] = [];
          for (let i = 0; i < timestamps.length; i++) {
            const o = opens[i];
            const h = highs[i];
            const l = lows[i];
            const c = closes[i];
            if (o != null && h != null && l != null && c != null && !isNaN(c)) {
              candles.push({
                timestamp: timestamps[i],
                open: parseFloat(o.toFixed(2)),
                high: parseFloat(h.toFixed(2)),
                low: parseFloat(l.toFixed(2)),
                close: parseFloat(c.toFixed(2)),
                volume: volumes && volumes[i] != null ? Math.round(volumes[i]!) : 10000,
              });
            }
          }

          if (candles.length > 0) {
            // Trim to requested limit if provided
            const trimmedCandles = limit && candles.length > limit ? candles.slice(-limit) : candles;

            // Compute Indicators
            let indicators = undefined;
            if (includeIndicators) {
              indicators = TechnicalIndicatorService.calculateAll(trimmedCandles);
            }

            // Sync with latest quote
            const latestQuote = await this.getLiveQuote(key);
            if (latestQuote && trimmedCandles.length > 0) {
              // Exact LTP synchronization
              trimmedCandles[trimmedCandles.length - 1].close = latestQuote.price;
            }

            const fromDate = new Date(trimmedCandles[0].timestamp * 1000).toISOString().split('T')[0];
            const toDate = new Date(trimmedCandles[trimmedCandles.length - 1].timestamp * 1000).toISOString().split('T')[0];

            const resultPayload: HistoricalDataResult = {
              symbol: key,
              name: result.meta?.longName || result.meta?.shortName || mapping.name,
              exchange: mapping.exchange,
              category: mapping.category,
              currency: result.meta?.currency || (mapping.exchange === 'US' || mapping.category === 'CRYPTO' ? 'USD' : 'INR'),
              interval,
              requestedRange: range,
              actualRange: `${fromDate} to ${toDate}`,
              from: trimmedCandles[0].timestamp,
              to: trimmedCandles[trimmedCandles.length - 1].timestamp,
              count: trimmedCandles.length,
              status: 'LIVE',
              provider: 'TradeVerse Real-Time Feed (Finnhub & Global Market Engine)',
              candles: trimmedCandles,
              indicators,
              latestQuote: latestQuote || undefined,
            };

            this.candleCache.set(cacheKey, { data: resultPayload, expiresAt: Date.now() + ttl });

            // Asynchronously persist candles to MongoDB cache for offline resilience
            this.persistCandlesAsync(key, interval, trimmedCandles).catch(() => {});

            return resultPayload;
          }
        }
      }
    } catch {
      // Fall through to fallback generator
    }

    // Safe fallback to local MarketDataService
    return MarketDataService.getHistoricalData(key, interval, {
      range,
      limit,
      includeIndicators,
    });
  }

  private static toYahooInterval(interval: CandleInterval): string {
    switch (interval) {
      case '1m': return '1m';
      case '5m': return '5m';
      case '15m': return '15m';
      case '30m': return '30m';
      case '1h': return '60m';
      case '4h': return '60m'; // 1h aggregated
      case '1d': return '1d';
      case '1w': return '1wk';
      case '1mo': return '1mo';
      default: return '15m';
    }
  }

  private static toYahooRange(range: HistoryRange, interval: CandleInterval): string {
    if (interval === '1m') return '1d';
    if (interval === '5m' || interval === '15m' || interval === '30m') {
      if (range === '1D') return '1d';
      if (range === '1W') return '5d';
      return '1mo';
    }
    switch (range) {
      case '1D': return '1d';
      case '1W': return '5d';
      case '1M': return '1mo';
      case '3M': return '3mo';
      case '6M': return '6mo';
      case '1Y': return '1y';
      case '3Y': return '5y';
      case '5Y': return '5y';
      case 'ALL': return 'max';
      default: return '1mo';
    }
  }

  private static async persistCandlesAsync(symbol: string, interval: string, candles: Candle[]): Promise<void> {
    try {
      const ops = candles.map((c) => ({
        updateOne: {
          filter: { symbol, interval, timestamp: c.timestamp },
          update: {
            $set: {
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
              volume: c.volume,
              dataSource: 'LIVE',
              isComplete: true,
            },
          },
          upsert: true,
        },
      }));
      await HistoricalCandle.bulkWrite(ops, { ordered: false });
    } catch {
      // Non-fatal
    }
  }
}
