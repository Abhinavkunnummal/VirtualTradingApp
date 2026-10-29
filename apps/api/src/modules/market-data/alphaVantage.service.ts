import { config } from '../../config';
import { MarketQuote, Candle } from './marketData.service';

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

export interface AlphaSymbolSearchResult {
  symbol: string;
  name: string;
  type: string;
  region: string;
  marketOpen: string;
  marketClose: string;
  timezone: string;
  currency: string;
  matchScore: number;
}

export class AlphaVantageService {
  private static readonly BASE_URL = 'https://www.alphavantage.co/query';
  private static cache = new Map<string, CacheEntry<unknown>>();

  // Cache durations in milliseconds
  private static readonly TTL_QUOTE = 60 * 1000; // 1 minute
  private static readonly TTL_CANDLES = 15 * 60 * 1000; // 15 minutes
  private static readonly TTL_SEARCH = 60 * 60 * 1000; // 1 hour

  private static overrideApiKey: string | null = null;

  public static setApiKeyForTesting(key: string | null): void {
    this.overrideApiKey = key;
  }

  private static get apiKey(): string {
    return this.overrideApiKey ?? (config.alphaVantageApiKey || (config.isTest ? 'TEST_ALPHA_VANTAGE_KEY' : ''));
  }

  public static isConfigured(): boolean {
    return Boolean(this.apiKey && this.apiKey.length > 5);
  }

  private static getFromCache<T>(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return entry.data as T;
  }

  private static setInCache<T>(key: string, data: T, ttlMs: number): void {
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + ttlMs,
    });
  }

  /**
   * Fetch Real-Time Global Quote from Alpha Vantage (GLOBAL_QUOTE)
   */
  public static async fetchGlobalQuote(symbol: string): Promise<Partial<MarketQuote> | null> {
    if (!this.isConfigured()) return null;

    const cacheKey = `quote:${symbol.toUpperCase()}`;
    const cached = this.getFromCache<Partial<MarketQuote>>(cacheKey);
    if (cached) return cached;

    try {
      const url = `${this.BASE_URL}?function=GLOBAL_QUOTE&symbol=${encodeURIComponent(symbol)}&apikey=${this.apiKey}`;
      const response = await fetch(url, { signal: AbortSignal.timeout(6000) });
      if (!response.ok) return null;

      const data = (await response.json()) as Record<string, any>;
      if (data?.Note || data?.Information) {
        return null;
      }

      const quote = data['Global Quote'];
      if (!quote || !quote['05. price']) return null;

      const price = parseFloat(quote['05. price']);
      const change = parseFloat(quote['09. change'] || '0');
      const changePercentRaw = quote['10. change percent'] || '0%';
      const changePercent = parseFloat(changePercentRaw.replace('%', ''));

      const result: Partial<MarketQuote> = {
        symbol: quote['01. symbol'] || symbol,
        price,
        open: parseFloat(quote['02. open'] || `${price}`),
        high: parseFloat(quote['03. high'] || `${price}`),
        low: parseFloat(quote['04. low'] || `${price}`),
        close: parseFloat(quote['08. previous close'] || `${price}`),
        volume: parseInt(quote['06. volume'] || '0', 10),
        change,
        changePercent,
        bid: parseFloat((price * 0.9998).toFixed(2)),
        ask: parseFloat((price * 1.0002).toFixed(2)),
        status: 'LIVE',
        timestamp: new Date().toISOString(),
      };

      this.setInCache(cacheKey, result, this.TTL_QUOTE);
      return result;
    } catch {
      return null;
    }
  }

  /**
   * Fetch Real-Time Crypto Exchange Rate (CURRENCY_EXCHANGE_RATE)
   */
  public static async fetchCryptoRate(fromCurrency: string, toCurrency = 'USD'): Promise<Partial<MarketQuote> | null> {
    if (!this.isConfigured()) return null;

    const cacheKey = `crypto:${fromCurrency.toUpperCase()}:${toCurrency.toUpperCase()}`;
    const cached = this.getFromCache<Partial<MarketQuote>>(cacheKey);
    if (cached) return cached;

    try {
      const url = `${this.BASE_URL}?function=CURRENCY_EXCHANGE_RATE&from_currency=${encodeURIComponent(fromCurrency)}&to_currency=${encodeURIComponent(toCurrency)}&apikey=${this.apiKey}`;
      const response = await fetch(url, { signal: AbortSignal.timeout(6000) });
      if (!response.ok) return null;

      const data = (await response.json()) as Record<string, any>;
      if (data?.Note || data?.Information) return null;

      const rateObj = data['Realtime Currency Exchange Rate'];
      if (!rateObj || !rateObj['5. Exchange Rate']) return null;

      const price = parseFloat(rateObj['5. Exchange Rate']);
      const bid = parseFloat(rateObj['8. Bid Price'] || `${price * 0.9998}`);
      const ask = parseFloat(rateObj['9. Ask Price'] || `${price * 1.0002}`);

      const result: Partial<MarketQuote> = {
        symbol: `${fromCurrency}/${toCurrency}`,
        price,
        bid,
        ask,
        status: 'LIVE',
        timestamp: new Date().toISOString(),
      };

      this.setInCache(cacheKey, result, this.TTL_QUOTE);
      return result;
    } catch {
      return null;
    }
  }

  /**
   * Fetch Daily Historical Candles (TIME_SERIES_DAILY)
   */
  public static async fetchDailyCandles(symbol: string, limit = 60): Promise<Candle[] | null> {
    if (!this.isConfigured()) return null;

    const cacheKey = `candles:daily:${symbol.toUpperCase()}:${limit}`;
    const cached = this.getFromCache<Candle[]>(cacheKey);
    if (cached) return cached;

    try {
      const url = `${this.BASE_URL}?function=TIME_SERIES_DAILY&symbol=${encodeURIComponent(symbol)}&apikey=${this.apiKey}`;
      const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!response.ok) return null;

      const data = (await response.json()) as Record<string, any>;
      if (data?.Note || data?.Information) return null;

      const timeSeries = data['Time Series (Daily)'];
      if (!timeSeries || typeof timeSeries !== 'object') return null;

      const entries = Object.entries(timeSeries);
      const candles: Candle[] = [];

      for (const [dateStr, values] of entries.slice(0, limit)) {
        const v = values as Record<string, string>;
        const timestamp = Math.floor(new Date(dateStr).getTime() / 1000);
        candles.push({
          timestamp,
          open: parseFloat(v['1. open']),
          high: parseFloat(v['2. high']),
          low: parseFloat(v['3. low']),
          close: parseFloat(v['4. close']),
          volume: parseInt(v['5. volume'] || '0', 10),
        });
      }

      candles.sort((a, b) => a.timestamp - b.timestamp);

      this.setInCache(cacheKey, candles, this.TTL_CANDLES);
      return candles;
    } catch {
      return null;
    }
  }

  /**
   * Search Global Tickers & Equities (SYMBOL_SEARCH)
   */
  public static async searchSymbols(keywords: string): Promise<AlphaSymbolSearchResult[]> {
    if (!this.isConfigured() || !keywords.trim()) return [];

    const cacheKey = `search:${keywords.trim().toLowerCase()}`;
    const cached = this.getFromCache<AlphaSymbolSearchResult[]>(cacheKey);
    if (cached) return cached;

    try {
      const url = `${this.BASE_URL}?function=SYMBOL_SEARCH&keywords=${encodeURIComponent(keywords)}&apikey=${this.apiKey}`;
      const response = await fetch(url, { signal: AbortSignal.timeout(6000) });
      if (!response.ok) return [];

      const data = (await response.json()) as Record<string, any>;
      if (data?.Note || data?.Information) return [];

      const matches = data?.bestMatches || [];
      if (!Array.isArray(matches)) return [];

      const results: AlphaSymbolSearchResult[] = matches.map((m: Record<string, string>) => ({
        symbol: m['1. symbol'] || '',
        name: m['2. name'] || '',
        type: m['3. type'] || '',
        region: m['4. region'] || '',
        marketOpen: m['5. marketOpen'] || '',
        marketClose: m['6. marketClose'] || '',
        timezone: m['7. timezone'] || '',
        currency: m['8. currency'] || '',
        matchScore: parseFloat(m['9. matchScore'] || '0'),
      }));

      this.setInCache(cacheKey, results, this.TTL_SEARCH);
      return results;
    } catch {
      return [];
    }
  }

  /**
   * Clear cache (useful for testing and hot reloads)
   */
  public static clearCache(): void {
    this.cache.clear();
    this.overrideApiKey = null;
  }
}
