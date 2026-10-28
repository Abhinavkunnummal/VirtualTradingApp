export type ExchangeType = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
export type AssetCategory = 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'DERIVATIVE';
export type CandleInterval = '1m' | '5m' | '15m' | '1h' | '1d' | '1w';

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
  status: 'SIMULATED' | 'DELAYED' | 'LIVE';
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

interface InstrumentMeta {
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

  static getCandles(symbol: string, interval: CandleInterval = '15m', limit: number = 60): Candle[] {
    const meta = this.getInstrument(symbol);
    if (!meta) return [];

    const intervalSecondsMap: Record<CandleInterval, number> = {
      '1m': 60,
      '5m': 300,
      '15m': 900,
      '1h': 3600,
      '1d': 86400,
      '1w': 604800,
    };

    const stepSeconds = intervalSecondsMap[interval] || 900;
    const nowSeconds = Math.floor(Date.now() / 1000);
    // Align to interval boundary
    const endSeconds = nowSeconds - (nowSeconds % stepSeconds);

    const candles: Candle[] = [];
    let prevClose = meta.basePrice;

    // Generate historical candles deterministically backwards
    for (let i = limit - 1; i >= 0; i--) {
      const candleTime = endSeconds - i * stepSeconds;

      // Seed pseudo-random movement using candleTime
      const seed = Math.sin(candleTime + meta.symbol.length);
      const movePercent = seed * meta.volatility;

      const open = prevClose;
      const close = parseFloat((open * (1 + movePercent)).toFixed(2));
      const wick1 = Math.abs(seed * 0.005);
      const wick2 = Math.abs(Math.cos(candleTime) * 0.005);

      const high = parseFloat((Math.max(open, close) * (1 + wick1)).toFixed(2));
      const low = parseFloat((Math.min(open, close) * (1 - wick2)).toFixed(2));
      const volume = Math.floor(10000 + Math.abs(seed) * 50000);

      candles.push({
        timestamp: candleTime,
        open,
        high,
        low,
        close,
        volume,
      });

      prevClose = close;
    }

    return candles;
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
