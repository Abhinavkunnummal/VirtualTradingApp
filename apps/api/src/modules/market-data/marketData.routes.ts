import express, { Request, Response } from 'express';
import { MarketDataService, CandleInterval } from './marketData.service';

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
