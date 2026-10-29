import express, { Request, Response } from 'express';
import { MarketDataService, CandleInterval, HistoryRange, Candle } from './marketData.service';
import { AlphaVantageService } from './alphaVantage.service';
import { TechnicalIndicatorService, TechnicalIndicators } from './indicators';

export const marketDataRouter = express.Router();

// GET /api/v1/market/instruments/search or /api/v1/market-data/instruments/search
marketDataRouter.get('/instruments/search', async (req: Request, res: Response) => {
  const query = (((req.query.q || req.query.query || req.query.keywords) as string) || '').trim();
  if (!query) {
    const defaultList = MarketDataService.getAllInstruments().slice(0, 25);
    return res.status(200).json({
      success: true,
      count: defaultList.length,
      instruments: defaultList,
    });
  }

  // 1. Search local instrument master
  const localMatches = MarketDataService.getAllInstruments({ query });

  // 2. Search Alpha Vantage if configured
  let globalMatches: any[] = [];
  try {
    if (AlphaVantageService.isConfigured()) {
      const avResults = await AlphaVantageService.searchSymbols(query);
      globalMatches = avResults.map((r) => ({
        symbol: r.symbol,
        name: r.name,
        exchange: r.region || 'US',
        category: r.type === 'Crypto' ? 'CRYPTO' : 'EQUITY',
        currency: r.currency || 'USD',
        isSimulated: false,
        source: 'ALPHA_VANTAGE',
      }));
    }
  } catch {
    // Non-fatal if Alpha Vantage is down
  }

  // Deduplicate by symbol
  const seen = new Set<string>();
  const combined = [];
  for (const item of [...localMatches, ...globalMatches]) {
    const key = item.symbol.toUpperCase();
    if (!seen.has(key)) {
      seen.add(key);
      combined.push(item);
    }
  }

  return res.status(200).json({
    success: true,
    count: combined.length,
    instruments: combined,
  });
});

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

// GET /api/v1/market/instruments/:id
marketDataRouter.get('/instruments/:id', (req: Request, res: Response) => {
  const symbol = req.params.id as string;
  const meta = MarketDataService.getInstrument(symbol);
  if (meta) {
    return res.status(200).json({
      success: true,
      instrument: meta,
    });
  }

  return res.status(404).json({
    success: false,
    message: `Instrument "${symbol}" not found in market master.`,
  });
});

// Handler for single quote resolution
const handleQuoteRequest = async (symbol: string, res: Response) => {
  const quote = MarketDataService.getQuote(symbol);
  if (quote) {
    return res.status(200).json({
      success: true,
      quote,
    });
  }

  // If not in local instrument master, check Alpha Vantage
  const isCrypto = symbol.includes('/') || ['BTC', 'ETH', 'SOL', 'USDT'].includes(symbol.toUpperCase());
  const liveQuote = isCrypto
    ? await AlphaVantageService.fetchCryptoRate(symbol.split('/')[0], symbol.split('/')[1] || 'USD')
    : await AlphaVantageService.fetchGlobalQuote(symbol);

  if (liveQuote) {
    return res.status(200).json({
      success: true,
      quote: liveQuote,
    });
  }

  return res.status(404).json({
    success: false,
    message: `Instrument "${symbol}" not found in supported market master or live feed.`,
  });
};

// GET /api/v1/market-data/quote/:symbol
marketDataRouter.get('/quote/:symbol', async (req: Request, res: Response) => {
  return handleQuoteRequest(req.params.symbol as string, res);
});

// GET /api/v1/market/quotes/:id
marketDataRouter.get('/quotes/:id', async (req: Request, res: Response) => {
  return handleQuoteRequest(req.params.id as string, res);
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

// Handler for candles request
const handleCandlesRequest = async (req: Request, res: Response) => {
  const symbol = (req.params.symbol || req.params.id) as string;
  const interval = (req.query.interval as CandleInterval) || '15m';
  const range = req.query.range as HistoryRange | undefined;
  const from = req.query.from ? parseInt(req.query.from as string, 10) : undefined;
  const to = req.query.to ? parseInt(req.query.to as string, 10) : undefined;
  const limit = req.query.limit ? Math.min(Math.max(parseInt(req.query.limit as string, 10), 5), 1500) : undefined;
  const includeIndicators = req.query.indicators === 'true';

  // 1. If in local instrument master, return comprehensive historical data
  const meta = MarketDataService.getInstrument(symbol);
  if (meta) {
    const result = MarketDataService.getHistoricalData(symbol, interval, {
      limit,
      range,
      from,
      to,
      includeIndicators,
    });
    if (result) {
      return res.status(200).json({
        success: true,
        ...result,
        latestQuote: result.latestQuote,
      });
    }
  }

  // 2. If not in local master or Alpha Vantage requested, check Alpha Vantage based on interval
  if (AlphaVantageService.isConfigured()) {
    let liveCandles: Candle[] | null = null;
    let avStatus: 'LIVE' | 'HISTORICAL' = 'LIVE';

    if (interval === '1w') {
      liveCandles = await AlphaVantageService.fetchWeeklyCandles(symbol, limit || 260);
      avStatus = 'HISTORICAL';
    } else if (interval === '1mo') {
      liveCandles = await AlphaVantageService.fetchMonthlyCandles(symbol, limit || 60);
      avStatus = 'HISTORICAL';
    } else if (interval === '1d') {
      const outputsize =
        range === '5Y' || range === '3Y' || range === '1Y' || range === 'ALL' || (limit && limit > 100)
          ? 'full'
          : 'compact';
      liveCandles = await AlphaVantageService.fetchDailyCandles(symbol, limit || 1260, outputsize);
    } else {
      liveCandles = await AlphaVantageService.fetchIntradayCandles(symbol, interval, limit || 100);
    }

    if (liveCandles && liveCandles.length > 0) {
      let indicators: TechnicalIndicators | undefined;
      if (includeIndicators) {
        indicators = TechnicalIndicatorService.calculateAll(liveCandles);
      }

      return res.status(200).json({
        success: true,
        symbol: symbol.toUpperCase(),
        exchange: 'GLOBAL',
        interval,
        currency: 'USD',
        status: avStatus,
        provider: 'Alpha Vantage Global Market Feed',
        actualRange: `${new Date(liveCandles[0].timestamp * 1000).toISOString().split('T')[0]} to ${new Date(liveCandles[liveCandles.length - 1].timestamp * 1000).toISOString().split('T')[0]}`,
        count: liveCandles.length,
        from: liveCandles[0].timestamp,
        to: liveCandles[liveCandles.length - 1].timestamp,
        candles: liveCandles,
        indicators,
      });
    }
  }

  return res.status(404).json({
    success: false,
    message: `Instrument "${symbol}" not found in market master or Alpha Vantage.`,
  });
};

// GET /api/v1/market-data/candles/:symbol
marketDataRouter.get('/candles/:symbol', handleCandlesRequest);

// GET /api/v1/market/candles/:id
marketDataRouter.get('/candles/:id', handleCandlesRequest);

// GET /api/v1/market-data/status & GET /api/v1/market/status
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
    features: ['GLOBAL_QUOTE', 'CURRENCY_EXCHANGE_RATE', 'TIME_SERIES_DAILY', 'TIME_SERIES_WEEKLY', 'TIME_SERIES_MONTHLY', 'TIME_SERIES_INTRADAY', 'SYMBOL_SEARCH'],
  });
});

// GET /api/v1/market-data/alpha/search
marketDataRouter.get('/alpha/search', async (req: Request, res: Response) => {
  const query = (((req.query.keywords || req.query.query || req.query.q) as string) || '').trim();
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
  const limit = Math.min(Math.max(parseInt((req.query.limit as string) || '60', 10), 5), 1260);

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
