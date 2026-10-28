import request from 'supertest';
import { createApp } from '../src/app';

describe('Market Data & Candlestick Service Tests (Phase 5)', () => {
  const app = createApp();

  describe('GET /api/v1/market-data/instruments', () => {
    it('should list all supported multi-asset instruments', async () => {
      const res = await request(app).get('/api/v1/market-data/instruments');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.count).toBeGreaterThanOrEqual(15);
      expect(res.body.instruments.some((i: any) => i.symbol === 'RELIANCE')).toBe(true);
      expect(res.body.instruments.some((i: any) => i.symbol === 'BTC/USDT')).toBe(true);
      expect(res.body.instruments.some((i: any) => i.symbol === 'GOLD 1KG')).toBe(true);
    });

    it('should filter instruments by exchange and category', async () => {
      const cryptoRes = await request(app).get('/api/v1/market-data/instruments?exchange=CRYPTO');
      expect(cryptoRes.status).toBe(200);
      expect(cryptoRes.body.instruments.every((i: any) => i.exchange === 'CRYPTO')).toBe(true);

      const commodityRes = await request(app).get('/api/v1/market-data/instruments?category=COMMODITY');
      expect(commodityRes.status).toBe(200);
      expect(commodityRes.body.instruments.every((i: any) => i.category === 'COMMODITY')).toBe(true);
    });
  });

  describe('GET /api/v1/market-data/quote/:symbol', () => {
    it('should return simulated quote with bid/ask spread and explicit SIMULATED label', async () => {
      const res = await request(app).get('/api/v1/market-data/quote/RELIANCE');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.quote.symbol).toBe('RELIANCE');
      expect(res.body.quote.status).toBe('SIMULATED');
      expect(res.body.quote.price).toBeGreaterThan(2000);
      expect(res.body.quote.ask).toBeGreaterThanOrEqual(res.body.quote.bid);
    });

    it('should return 404 for unknown instrument', async () => {
      const res = await request(app).get('/api/v1/market-data/quote/UNKNOWN_TICKER');
      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/market-data/quotes (Batch)', () => {
    it('should return quotes for multiple requested symbols', async () => {
      const res = await request(app).get('/api/v1/market-data/quotes?symbols=RELIANCE,TCS,BTC/USDT');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.count).toBe(3);
    });
  });

  describe('GET /api/v1/market-data/candles/:symbol', () => {
    it('should return OHLCV candlestick series with timestamps and intervals', async () => {
      const res = await request(app).get('/api/v1/market-data/candles/RELIANCE?interval=15m&limit=30');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.candles.length).toBe(30);
      expect(res.body.candles[0].timestamp).toBeDefined();
      expect(res.body.candles[0].open).toBeGreaterThan(0);
      expect(res.body.candles[0].high).toBeGreaterThanOrEqual(res.body.candles[0].low);
      expect(res.body.status).toBe('SIMULATED');
    });

    it('should support all requested intervals (1m, 5m, 15m, 1h, 1d, 1w)', async () => {
      const intervals = ['1m', '5m', '15m', '1h', '1d', '1w'];
      for (const interval of intervals) {
        const res = await request(app).get(`/api/v1/market-data/candles/TCS?interval=${interval}&limit=10`);
        expect(res.status).toBe(200);
        expect(res.body.candles.length).toBeGreaterThanOrEqual(1);
        expect(res.body.interval).toBe(interval);
      }
    });

    it('should correctly aggregate OHLCV candles (Open=first, High=max, Low=min, Close=last, Volume=sum)', () => {
      const { MarketDataService } = require('../src/modules/market-data/marketData.service');
      const baseCandles = [
        { timestamp: 1000, open: 100, high: 105, low: 98, close: 102, volume: 500 },
        { timestamp: 1060, open: 102, high: 108, low: 101, close: 106, volume: 700 },
        { timestamp: 1120, open: 106, high: 107, low: 95, close: 99, volume: 800 },
      ];

      // Aggregate all 3 into one 300-second candle bucket starting at 900
      const aggregated = MarketDataService.aggregateCandles(baseCandles, 300);
      expect(aggregated.length).toBe(1);
      expect(aggregated[0].open).toBe(100); // first open
      expect(aggregated[0].high).toBe(108); // highest high across all 3
      expect(aggregated[0].low).toBe(95);   // lowest low across all 3
      expect(aggregated[0].close).toBe(99); // last close
      expect(aggregated[0].volume).toBe(2000); // 500 + 700 + 800
    });
  });

  describe('GET /api/v1/market-data/status', () => {
    it('should return exchange sessions and market operational status', async () => {
      const res = await request(app).get('/api/v1/market-data/status');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.exchanges.length).toBe(5);
      expect(res.body.exchanges.some((e: any) => e.exchange === 'CRYPTO' && e.session === '24_7')).toBe(true);
    });
  });
});
