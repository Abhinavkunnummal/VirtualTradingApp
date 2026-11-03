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
  'BAJFINANCE': { yf: 'BAJFINANCE.NS', category: 'EQUITY', exchange: 'NSE', name: 'Bajaj Finance Limited' },
  'BHARTIARTL': { yf: 'BHARTIARTL.NS', category: 'EQUITY', exchange: 'NSE', name: 'Bharti Airtel Limited' },
  'ITC': { yf: 'ITC.NS', category: 'EQUITY', exchange: 'NSE', name: 'ITC Limited' },
  'LT': { yf: 'LT.NS', category: 'EQUITY', exchange: 'NSE', name: 'Larsen & Toubro Ltd.' },
  'HINDUNILVR': { yf: 'HINDUNILVR.NS', category: 'EQUITY', exchange: 'NSE', name: 'Hindustan Unilever Ltd.' },
  'KOTAKBANK': { yf: 'KOTAKBANK.NS', category: 'EQUITY', exchange: 'NSE', name: 'Kotak Mahindra Bank' },
  'MARUTI': { yf: 'MARUTI.NS', category: 'EQUITY', exchange: 'NSE', name: 'Maruti Suzuki India Ltd.' },
  'SUNPHARMA': { yf: 'SUNPHARMA.NS', category: 'EQUITY', exchange: 'NSE', name: 'Sun Pharmaceutical Industries' },
  'WIPRO': { yf: 'WIPRO.NS', category: 'EQUITY', exchange: 'NSE', name: 'Wipro Limited' },
  'TITAN': { yf: 'TITAN.NS', category: 'EQUITY', exchange: 'NSE', name: 'Titan Company Limited' },
  'TATASTEEL': { yf: 'TATASTEEL.NS', category: 'EQUITY', exchange: 'NSE', name: 'Tata Steel Limited' },
  'AXISBANK': { yf: 'AXISBANK.NS', category: 'EQUITY', exchange: 'NSE', name: 'Axis Bank Limited' },
  'ZOMATO': { yf: 'ZOMATO.NS', category: 'EQUITY', exchange: 'NSE', name: 'Zomato Limited' },
  'JIOFIN': { yf: 'JIOFIN.NS', category: 'EQUITY', exchange: 'NSE', name: 'Jio Financial Services' },

  // Adani Group Equities
  'ADANIENT': { yf: 'ADANIENT.NS', category: 'EQUITY', exchange: 'NSE', name: 'Adani Enterprises Ltd.' },
  'ADANIPORTS': { yf: 'ADANIPORTS.NS', category: 'EQUITY', exchange: 'NSE', name: 'Adani Ports and SEZ Ltd.' },
  'ADANIGREEN': { yf: 'ADANIGREEN.NS', category: 'EQUITY', exchange: 'NSE', name: 'Adani Green Energy Ltd.' },
  'ATGL': { yf: 'ATGL.NS', category: 'EQUITY', exchange: 'NSE', name: 'Adani Total Gas Ltd.' },
  'ADANIPOWER': { yf: 'ADANIPOWER.NS', category: 'EQUITY', exchange: 'NSE', name: 'Adani Power Ltd.' },
  'AMBUJACEM': { yf: 'AMBUJACEM.NS', category: 'EQUITY', exchange: 'NSE', name: 'Ambuja Cements Ltd.' },

  // Indian Indices
  'NIFTY 50': { yf: '^NSEI', category: 'INDEX', exchange: 'NSE', name: 'Nifty 50 Index' },
  'BANKNIFTY': { yf: '^NSEBANK', category: 'INDEX', exchange: 'NSE', name: 'Nifty Bank Index' },
  'FINNIFTY': { yf: 'NIFTY_FIN_SERVICE.NS', category: 'INDEX', exchange: 'NSE', name: 'Nifty Financial Services' },
  'SENSEX': { yf: '^BSESN', category: 'INDEX', exchange: 'BSE', name: 'BSE Sensex Index' },

  // MCX Commodities
  'GOLD 1KG': { yf: 'GC=F', category: 'COMMODITY', exchange: 'MCX', name: 'MCX Gold Futures' },
  'SILVER 30KG': { yf: 'SI=F', category: 'COMMODITY', exchange: 'MCX', name: 'MCX Silver Futures' },
  'CRUDEOIL': { yf: 'CL=F', category: 'COMMODITY', exchange: 'MCX', name: 'Crude Oil Futures' },
  'NATURALGAS': { yf: 'NG=F', category: 'COMMODITY', exchange: 'MCX', name: 'Natural Gas Futures' },

  // Crypto 24/7
  'BTC/USDT': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'BTC': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'BTCUSDT': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'BTCUSD': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'BTC/USD': { yf: 'BTC-USD', twelve: 'BTC/USD', finnhub: 'BINANCE:BTCUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Bitcoin 24/7' },
  'ETH/USDT': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'ETH': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'ETHUSDT': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'ETHUSD': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'ETH/USD': { yf: 'ETH-USD', twelve: 'ETH/USD', finnhub: 'BINANCE:ETHUSDT', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ethereum 24/7' },
  'SOL/USDT': { yf: 'SOL-USD', twelve: 'SOL/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Solana 24/7' },
  'SOL': { yf: 'SOL-USD', twelve: 'SOL/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Solana 24/7' },
  'SOLUSDT': { yf: 'SOL-USD', twelve: 'SOL/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Solana 24/7' },
  'DOGE/USDT': { yf: 'DOGE-USD', twelve: 'DOGE/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Dogecoin 24/7' },
  'DOGE': { yf: 'DOGE-USD', twelve: 'DOGE/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Dogecoin 24/7' },
  'DOGEUSDT': { yf: 'DOGE-USD', twelve: 'DOGE/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Dogecoin 24/7' },
  'BNB/USDT': { yf: 'BNB-USD', twelve: 'BNB/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Binance Coin 24/7' },
  'BNB': { yf: 'BNB-USD', twelve: 'BNB/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Binance Coin 24/7' },
  'BNBUSDT': { yf: 'BNB-USD', twelve: 'BNB/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Binance Coin 24/7' },
  'XRP': { yf: 'XRP-USD', twelve: 'XRP/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ripple 24/7' },
  'XRP/USDT': { yf: 'XRP-USD', twelve: 'XRP/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ripple 24/7' },
  'XRPUSDT': { yf: 'XRP-USD', twelve: 'XRP/USD', category: 'CRYPTO', exchange: 'CRYPTO', name: 'Ripple 24/7' },

  // US Equities
  'AAPL': { yf: 'AAPL', twelve: 'AAPL', finnhub: 'AAPL', category: 'EQUITY', exchange: 'US', name: 'Apple Inc.' },
  'NVDA': { yf: 'NVDA', twelve: 'NVDA', finnhub: 'NVDA', category: 'EQUITY', exchange: 'US', name: 'NVIDIA Corporation' },
  'MSFT': { yf: 'MSFT', twelve: 'MSFT', finnhub: 'MSFT', category: 'EQUITY', exchange: 'US', name: 'Microsoft Corporation' },
  'TSLA': { yf: 'TSLA', twelve: 'TSLA', finnhub: 'TSLA', category: 'EQUITY', exchange: 'US', name: 'Tesla Inc.' },
  'GOOGL': { yf: 'GOOGL', twelve: 'GOOGL', finnhub: 'GOOGL', category: 'EQUITY', exchange: 'US', name: 'Alphabet Inc. Class A' },
  'AMZN': { yf: 'AMZN', twelve: 'AMZN', finnhub: 'AMZN', category: 'EQUITY', exchange: 'US', name: 'Amazon.com Inc.' },
  'META': { yf: 'META', twelve: 'META', finnhub: 'META', category: 'EQUITY', exchange: 'US', name: 'Meta Platforms Inc.' },
  'NFLX': { yf: 'NFLX', twelve: 'NFLX', finnhub: 'NFLX', category: 'EQUITY', exchange: 'US', name: 'Netflix Inc.' },
  'AMD': { yf: 'AMD', twelve: 'AMD', finnhub: 'AMD', category: 'EQUITY', exchange: 'US', name: 'Advanced Micro Devices' },
  'COIN': { yf: 'COIN', twelve: 'COIN', finnhub: 'COIN', category: 'EQUITY', exchange: 'US', name: 'Coinbase Global Inc.' },
  'SPY': { yf: 'SPY', twelve: 'SPY', finnhub: 'SPY', category: 'INDEX', exchange: 'US', name: 'SPDR S&P 500 ETF' },
};

export class RealtimeMarketService {
  private static quoteCache = new Map<string, CacheEntry<MarketQuote>>();
  private static candleCache = new Map<string, CacheEntry<HistoricalDataResult>>();

  private static readonly TTL_QUOTE = 1000; // 1 second for live real-time tickers
  private static readonly TTL_CANDLES_INTRADAY = 15 * 1000; // 15 seconds
  private static readonly TTL_CANDLES_DAILY = 5 * 60 * 1000; // 5 minutes

  /**
   * Canonicalize any ticker format (e.g., BTCUSDT, BTC/USDT, btc-usdt, btc_usdt, BTC)
   * through SYMBOL_MAPPINGS into its canonical instrument symbol representation.
   */
  public static canonicalizeSymbol(rawSymbol: string): string {
    if (!rawSymbol || typeof rawSymbol !== 'string') return '';
    const upper = rawSymbol.trim().toUpperCase();

    // 1. Direct match in SYMBOL_MAPPINGS
    const directMeta = SYMBOL_MAPPINGS[upper];

    // Check if it's a crypto symbol
    const isCrypto =
      (directMeta && directMeta.category === 'CRYPTO') ||
      upper.includes('/') ||
      upper.includes('BTC') ||
      upper.includes('ETH') ||
      upper.includes('SOL') ||
      upper.includes('DOGE') ||
      upper.includes('BNB') ||
      upper.includes('XRP');

    if (isCrypto) {
      // Normalize to standard pair format: {COIN}/USDT
      let clean = upper.replace(/[\/\-_]/g, '');
      clean = clean.replace(/USDT$|USD$|BUSD$/, '');
      if (!clean) clean = 'BTC';
      return `${clean}/USDT`;
    }

    // 2. Indian equities with exchange suffixes (e.g. RELIANCE.NS -> RELIANCE)
    if (upper.endsWith('.NS') || upper.endsWith('.BO')) {
      const stripped = upper.replace(/\.(NS|BO)$/, '');
      if (SYMBOL_MAPPINGS[stripped]) return stripped;
    }

    // 3. Indian Index mappings
    if (upper === '^NSEI' || upper === 'NIFTY50' || upper === 'NIFTY 50') return 'NIFTY 50';
    if (upper === '^NSEBANK' || upper === 'BANKNIFTY' || upper === 'BANK NIFTY') return 'BANKNIFTY';
    if (upper === '^BSESN' || upper === 'SENSEX') return 'SENSEX';
    if (upper === 'FINNIFTY' || upper === 'FIN NIFTY') return 'FINNIFTY';

    // 4. Commodities
    if (upper === 'GC=F' || upper === 'GOLD') return 'GOLD 1KG';
    if (upper === 'SI=F' || upper === 'SILVER') return 'SILVER 30KG';
    if (upper === 'CL=F' || upper === 'CRUDE') return 'CRUDEOIL';
    if (upper === 'NG=F' || upper === 'NATURAL GAS') return 'NATURALGAS';

    // 5. If matches any existing mapping key directly
    if (SYMBOL_MAPPINGS[upper]) return upper;

    return upper;
  }

  /**
   * Resolve clean symbol mapping
   */
  public static getMapping(symbol: string): SymbolMeta {
    const upper = symbol.toUpperCase().trim();
    if (SYMBOL_MAPPINGS[upper]) return SYMBOL_MAPPINGS[upper];

    // Generic fallback for any user searched ticker
    const isCrypto = upper.includes('/') || upper.includes('BTC') || upper.includes('ETH') || upper.includes('SOL') || upper.includes('DOGE') || upper.includes('BNB');
    const isIndian = upper.endsWith('.NS') || upper.endsWith('.BO');
    if (isCrypto) {
      let bSym = upper.replace('/', '').replace('-', '');
      if (!bSym.endsWith('USDT') && !bSym.endsWith('USD') && !bSym.endsWith('BUSD')) {
        bSym = `${bSym}USDT`;
      }
      return {
        yf: `${upper.split('/')[0]}-USD`,
        twelve: `${upper.split('/')[0]}/USD`,
        finnhub: `BINANCE:${bSym}`,
        category: 'CRYPTO',
        exchange: 'CRYPTO',
        name: `${upper} 24/7`,
      };
    }
    return {
      yf: isIndian ? upper : upper.replace('/', '-'),
      category: 'EQUITY',
      exchange: isIndian ? 'NSE' : 'US',
      name: symbol,
    };
  }

  /**
   * Fetch Live Real-Time Quote from Binance, Finnhub, Twelve Data, or Yahoo Finance
   */
  public static async getLiveQuote(symbol: string): Promise<MarketQuote | null> {
    const key = symbol.toUpperCase().trim();
    const cached = this.quoteCache.get(key);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.data;
    }

    const mapping = this.getMapping(key);

    // 1. Direct Binance Public Spot Feed for 24/7 Crypto (Exact TradingView tick-for-tick price)
    if (mapping.category === 'CRYPTO') {
      try {
        let binanceSymbol = key.replace('/', '').replace('-', '').toUpperCase();
        if (!binanceSymbol.endsWith('USDT') && !binanceSymbol.endsWith('USD') && !binanceSymbol.endsWith('BUSD')) {
          binanceSymbol = `${binanceSymbol}USDT`;
        }
        const url = `https://api.binance.com/api/v3/ticker/24hr?symbol=${binanceSymbol}`;
        const res = await fetch(url, { signal: AbortSignal.timeout(2500) });
        if (res.ok) {
          const data = (await res.json()) as Record<string, any>;
          if (data && data.lastPrice) {
            const price = parseFloat(parseFloat(data.lastPrice).toFixed(2));
            const change = parseFloat(parseFloat(data.priceChange || '0').toFixed(2));
            const changePercent = parseFloat(parseFloat(data.priceChangePercent || '0').toFixed(2));
            const quote: MarketQuote = {
              symbol: key,
              name: mapping.name,
              exchange: mapping.exchange,
              category: mapping.category,
              price,
              change,
              changePercent,
              open: parseFloat(parseFloat(data.openPrice || `${price}`).toFixed(2)),
              high: parseFloat(parseFloat(data.highPrice || `${price}`).toFixed(2)),
              low: parseFloat(parseFloat(data.lowPrice || `${price}`).toFixed(2)),
              close: price,
              volume: parseFloat(parseFloat(data.volume || '1000').toFixed(2)),
              bid: parseFloat(parseFloat(data.bidPrice || `${price * 0.9999}`).toFixed(2)),
              ask: parseFloat(parseFloat(data.askPrice || `${price * 1.0001}`).toFixed(2)),
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

    // 0. Direct Binance Spot Klines for 24/7 Crypto (Exact TradingView tick-for-tick candles)
    if (mapping.category === 'CRYPTO') {
      try {
        let binanceSymbol = key.replace('/', '').replace('-', '').toUpperCase();
        if (!binanceSymbol.endsWith('USDT') && !binanceSymbol.endsWith('USD') && !binanceSymbol.endsWith('BUSD')) {
          binanceSymbol = `${binanceSymbol}USDT`;
        }
        const binanceInterval = this.toBinanceInterval(interval);
        const klinesUrl = `https://api.binance.com/api/v3/klines?symbol=${binanceSymbol}&interval=${binanceInterval}&limit=${limit || 60}`;
        const res = await fetch(klinesUrl, { signal: AbortSignal.timeout(3500) });
        if (res.ok) {
          const rawKlines = (await res.json()) as any[];
          if (Array.isArray(rawKlines) && rawKlines.length > 0) {
            const candles: Candle[] = rawKlines.map((k) => ({
              timestamp: Math.floor(Number(k[0]) / 1000),
              open: parseFloat(parseFloat(k[1]).toFixed(2)),
              high: parseFloat(parseFloat(k[2]).toFixed(2)),
              low: parseFloat(parseFloat(k[3]).toFixed(2)),
              close: parseFloat(parseFloat(k[4]).toFixed(2)),
              volume: parseFloat(parseFloat(k[5]).toFixed(2)),
            }));

            // Exact LTP synchronization with latest forming candle
            const latestQuote = await this.getLiveQuote(key);
            if (latestQuote && candles.length > 0) {
              const last = candles[candles.length - 1];
              last.close = latestQuote.price;
              last.high = Math.max(last.high, latestQuote.price);
              last.low = Math.min(last.low, latestQuote.price);
            }

            let indicators = undefined;
            if (includeIndicators) {
              indicators = TechnicalIndicatorService.calculateAll(candles);
            }

            const fromDate = new Date(candles[0].timestamp * 1000).toISOString().split('T')[0];
            const toDate = new Date(candles[candles.length - 1].timestamp * 1000).toISOString().split('T')[0];

            const resultPayload: HistoricalDataResult = {
              symbol: key,
              name: mapping.name,
              exchange: mapping.exchange,
              category: mapping.category,
              currency: 'USD',
              interval,
              requestedRange: range,
              actualRange: `${fromDate} to ${toDate}`,
              from: candles[0].timestamp,
              to: candles[candles.length - 1].timestamp,
              count: candles.length,
              status: 'LIVE',
              provider: 'TradeVerse Real-Time Feed (Binance Spot Live)',
              candles,
              indicators,
              latestQuote: latestQuote || undefined,
            };

            this.candleCache.set(cacheKey, { data: resultPayload, expiresAt: Date.now() + ttl });
            this.persistCandlesAsync(key, interval, candles).catch(() => {});
            return resultPayload;
          }
        }
      } catch {
        // Fall through to Yahoo Finance
      }
    }

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

  private static toBinanceInterval(interval: CandleInterval): string {
    switch (interval) {
      case '1m': return '1m';
      case '5m': return '5m';
      case '15m': return '15m';
      case '30m': return '30m';
      case '1h': return '1h';
      case '4h': return '4h';
      case '1d': return '1d';
      case '1w': return '1w';
      case '1mo': return '1M';
      default: return '15m';
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
