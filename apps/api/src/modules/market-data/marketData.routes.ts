import express, { Request, Response } from 'express';
import { MarketDataService, CandleInterval } from './marketData.service';
import { AlphaVantageService } from './alphaVantage.service';

export const marketDataRouter = express.Router();

// GET /api/v1/market-data/instruments
marketDataRouter.get('/instruments', (req: Request, res: Response) => {
  const { exchange, category, query } = req.query as {
    exchange?: string;
    category?: string;
    query?: string;
  };

  const list = MarketDataService.getAllInstruments({ exchange, category, query });
  return res.status(200).json({
    success: true,
    count: list.length,
    instruments: list.map((i) => ({
      symbol: i.symbol,
      name: i.name,
      exchange: i.exchange,
      category: i.category,
      basePrice: i.basePrice,
      currency: i.currency,
      lotSize: i.lotSize,
      tickSize: i.tickSize,
    })),
  });
});

// GET /api/v1/market-data/quote/:symbol
marketDataRouter.get('/quote/:symbol', (req: Request, res: Response) => {
  const symbol = req.params.symbol as string;
  const quote = MarketDataService.getQuote(symbol);
  if (!quote) {
    return res.status(404).json({
      success: false,
      message: `Instrument "${symbol}" not found in supported market master.`,
    });
  }
  return res.status(200).json({
    success: true,
    quote,
  });
});

// GET /api/v1/market-data/quotes
marketDataRouter.get('/quotes', (req: Request, res: Response) => {
  const rawSymbols = (req.query.symbols as string) || '';
  if (!rawSymbols) {
    return res.status(400).json({
      success: false,
      message: 'symbols query parameter required (e.g. ?symbols=RELIANCE,TCS,BTC/USDT)',
    });
  }

  const symbols = rawSymbols.split(',').map((s) => s.trim());
  const quotes = MarketDataService.getQuotes(symbols);

  return res.status(200).json({
    success: true,
    count: quotes.length,
    quotes,
  });
});

// GET /api/v1/market-data/candles/:symbol
marketDataRouter.get('/candles/:symbol', (req: Request, res: Response) => {
  const symbol = req.params.symbol as string;
  const interval = (req.query.interval as CandleInterval) || '15m';
  const limit = Math.min(Math.max(parseInt((req.query.limit as string) || '60', 10), 5), 300);

  const meta = MarketDataService.getInstrument(symbol);
  if (!meta) {
    return res.status(404).json({
      success: false,
      message: `Instrument "${symbol}" not found.`,
    });
  }

  const candles = MarketDataService.getCandles(symbol, interval, limit);
  const quote = MarketDataService.getQuote(symbol);

  return res.status(200).json({
    success: true,
    symbol: meta.symbol,
    exchange: meta.exchange,
    interval,
    currency: meta.currency,
    status: 'SIMULATED',
    latestQuote: quote,
    candles,
  });
});

// GET /api/v1/market-data/status
marketDataRouter.get('/status', (req: Request, res: Response) => {
  const status = MarketDataService.getMarketStatus();
  return res.status(200).json({
    success: true,
    ...status,
  });
});

// GET /api/v1/market-data/alpha/status
marketDataRouter.get('/alpha/status', (_req: Request, res: Response) => {
  return res.status(200).json({
    success: true,
    configured: AlphaVantageService.isConfigured(),
    provider: 'Alpha Vantage',
    features: ['GLOBAL_QUOTE', 'CURRENCY_EXCHANGE_RATE', 'TIME_SERIES_DAILY', 'SYMBOL_SEARCH'],
  });
});

// GET /api/v1/market-data/alpha/search
marketDataRouter.get('/alpha/search', async (req: Request, res: Response) => {
  const query = ((req.query.keywords || req.query.query || req.query.q) as string || '').trim();
  if (!query) {
    return res.status(400).json({
      success: false,
      message: 'Query parameter required (e.g. ?keywords=AAPL or ?query=IBM)',
    });
  }

  const results = await AlphaVantageService.searchSymbols(query);
  return res.status(200).json({
    success: true,
    count: results.length,
    provider: 'Alpha Vantage',
    results,
  });
});

// GET /api/v1/market-data/alpha/quote/:symbol
marketDataRouter.get('/alpha/quote/:symbol', async (req: Request, res: Response) => {
  const symbol = req.params.symbol as string;
  const isCrypto = symbol.includes('/') || ['BTC', 'ETH', 'SOL', 'USDT'].includes(symbol.toUpperCase());

  let liveQuote = null;
  if (isCrypto) {
    const parts = symbol.toUpperCase().split('/');
    const from = parts[0];
    const to = parts[1] || 'USD';
    liveQuote = await AlphaVantageService.fetchCryptoRate(from, to);
  } else {
    liveQuote = await AlphaVantageService.fetchGlobalQuote(symbol);
  }

  if (liveQuote) {
    return res.status(200).json({
      success: true,
      provider: 'Alpha Vantage',
      quote: liveQuote,
    });
  }

  // Graceful fallback to internal simulated quote if instrument exists in master
  const simulated = MarketDataService.getQuote(symbol);
  if (simulated) {
    return res.status(200).json({
      success: true,
      provider: 'Internal Simulator (Fallback)',
      quote: simulated,
    });
  }

  return res.status(404).json({
    success: false,
    message: `Quote for "${symbol}" could not be retrieved from Alpha Vantage or local master.`,
  });
});

// GET /api/v1/market-data/alpha/candles/:symbol
marketDataRouter.get('/alpha/candles/:symbol', async (req: Request, res: Response) => {
  const symbol = req.params.symbol as string;
  const limit = Math.min(Math.max(parseInt((req.query.limit as string) || '60', 10), 5), 100);

  const liveCandles = await AlphaVantageService.fetchDailyCandles(symbol, limit);
  if (liveCandles && liveCandles.length > 0) {
    return res.status(200).json({
      success: true,
      symbol: symbol.toUpperCase(),
      interval: '1d',
      provider: 'Alpha Vantage',
      status: 'LIVE',
      candles: liveCandles,
    });
  }

  // Fallback to internal candle generator if instrument exists in local master
  const meta = MarketDataService.getInstrument(symbol);
  if (meta) {
    const candles = MarketDataService.getCandles(symbol, '1d', limit);
    return res.status(200).json({
      success: true,
      symbol: meta.symbol,
      interval: '1d',
      provider: 'Internal Simulator (Fallback)',
      status: 'SIMULATED',
      candles,
    });
  }

  return res.status(404).json({
    success: false,
    message: `Candles for "${symbol}" not found on Alpha Vantage or local simulator.`,
  });
});
