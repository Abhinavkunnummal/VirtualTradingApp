import request from 'supertest';
import { createApp } from '../src/app';
import { MarketDataService, Candle } from '../src/modules/market-data/marketData.service';
import { TechnicalIndicatorService } from '../src/modules/market-data/indicators';

const app = createApp();

describe('Phase 2, 3 & 4 — Historical Market Data, 5-Year Ranges & Technical Indicators', () => {
  describe('5-Year Historical Candles & Range Queries', () => {
    it('should generate 5 years of daily candles (~1260 bars) for RELIANCE with valid OHLCV and ascending timestamps', async () => {
      const res = await request(app)
        .get('/api/v1/market/candles/RELIANCE')
        .query({ interval: '1d', range: '5Y' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.symbol).toBe('RELIANCE');
      expect(res.body.interval).toBe('1d');
      expect(res.body.requestedRange).toBe('5Y');
      expect(res.body.status).toBe('SIMULATED');
      expect(res.body.candles.length).toBeGreaterThanOrEqual(1000);

      // Verify strict chronological order and OHLCV integrity across all candles
      const candles: Candle[] = res.body.candles;
      for (let i = 0; i < candles.length; i++) {
        const c = candles[i];
        expect(c.high).toBeGreaterThanOrEqual(c.open);
        expect(c.high).toBeGreaterThanOrEqual(c.close);
        expect(c.low).toBeLessThanOrEqual(c.open);
        expect(c.low).toBeLessThanOrEqual(c.close);
        expect(c.low).toBeGreaterThan(0);
        expect(c.volume).toBeGreaterThanOrEqual(0);

        if (i > 0) {
          expect(c.timestamp).toBeGreaterThan(candles[i - 1].timestamp);
        }
      }

      // Verify the latest candle close matches the quote price with zero drift
      const latestClose = candles[candles.length - 1].close;
      expect(latestClose).toEqual(res.body.latestQuote.price);
    });

    it('should generate 5 years of weekly candles (~260 bars) and monthly candles (~60 bars)', async () => {
      const weeklyRes = await request(app)
        .get('/api/v1/market/candles/TCS')
        .query({ interval: '1w', range: '5Y' });

      expect(weeklyRes.status).toBe(200);
      expect(weeklyRes.body.candles.length).toBeGreaterThanOrEqual(200);

      const monthlyRes = await request(app)
        .get('/api/v1/market/candles/TCS')
        .query({ interval: '1mo', range: '5Y' });

      expect(monthlyRes.status).toBe(200);
      expect(monthlyRes.body.candles.length).toBeGreaterThanOrEqual(50);
    });

    it('should enforce intraday retention limits with a clear retention notice when requesting 5Y on 1m candles', async () => {
      const res = await request(app)
        .get('/api/v1/market/candles/RELIANCE')
        .query({ interval: '1m', range: '5Y' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.retentionNotice).toBeDefined();
      expect(res.body.retentionNotice).toContain('intraday retention limit');
      // Intraday 1m response is bounded and does not flood memory
      expect(res.body.candles.length).toBeLessThanOrEqual(1300);
    });

    it('should support 1D, 1W, 1M, 3M, 6M, 1Y, 3Y, 5Y, and ALL range parameters', async () => {
      const ranges = ['1D', '1W', '1M', '3M', '6M', '1Y', '3Y', '5Y', 'ALL'] as const;
      for (const range of ranges) {
        const res = await request(app)
          .get('/api/v1/market/candles/HDFCBANK')
          .query({ interval: '1d', range });

        expect(res.status).toBe(200);
        expect(res.body.requestedRange).toBe(range);
        expect(res.body.candles.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Technical Indicators (SMA, EMA, RSI, MACD)', () => {
    it('should compute SMA20, SMA50, EMA20, RSI14, and MACD correctly with warm-up periods', async () => {
      const res = await request(app)
        .get('/api/v1/market/candles/RELIANCE')
        .query({ interval: '1d', range: '1Y', indicators: 'true' });

      expect(res.status).toBe(200);
      expect(res.body.indicators).toBeDefined();

      const { sma20, sma50, ema20, rsi14, macd } = res.body.indicators;

      // SMA20 warm-up: first 19 points must be null, 20th point must have a numeric value
      expect(sma20[0].value).toBeNull();
      expect(sma20[18].value).toBeNull();
      expect(typeof sma20[19].value).toBe('number');

      // SMA50 warm-up: first 49 points must be null, 50th point must be numeric
      expect(sma50[0].value).toBeNull();
      expect(sma50[48].value).toBeNull();
      expect(typeof sma50[49].value).toBe('number');

      // EMA20 warm-up
      expect(ema20[0].value).toBeNull();
      expect(typeof ema20[19].value).toBe('number');

      // RSI14: bounded between 0 and 100
      expect(rsi14[0].value).toBeNull();
      for (let i = 14; i < rsi14.length; i++) {
        const rsi = rsi14[i].value;
        if (rsi !== null) {
          expect(rsi).toBeGreaterThanOrEqual(0);
          expect(rsi).toBeLessThanOrEqual(100);
        }
      }

      // MACD: fast(12), slow(26), signal(9)
      expect(macd[0].macd).toBeNull();
      const validMacd = macd.filter((m: any) => m.histogram !== null);
      expect(validMacd.length).toBeGreaterThan(0);
      for (const m of validMacd) {
        expect(typeof m.macd).toBe('number');
        expect(typeof m.signal).toBe('number');
        expect(Math.abs(m.macd! - m.signal! - m.histogram!)).toBeLessThan(0.001);
      }
    });

    it('TechnicalIndicatorService unit calculation formulas', () => {
      const dummyCandles: Candle[] = Array.from({ length: 30 }, (_, i) => ({
        timestamp: 1000 + i * 86400,
        open: 100 + i,
        high: 105 + i,
        low: 95 + i,
        close: 100 + i,
        volume: 1000,
      }));

      const sma = TechnicalIndicatorService.calculateSMA(dummyCandles, 5);
      expect(sma[0].value).toBeNull();
      expect(sma[3].value).toBeNull();
      // Points 0..4 have closes: 100, 101, 102, 103, 104 -> average = 102.0
      expect(sma[4].value).toBe(102.0);

      const rsi = TechnicalIndicatorService.calculateRSI(dummyCandles, 14);
      // Steadily rising prices -> RSI should be 100 (gain with 0 loss)
      expect(rsi[14].value).toBe(100);
    });
  });

  describe('Unified Instrument Search & REST Contract', () => {
    it('GET /api/v1/market/instruments/search returns matched instruments from master', async () => {
      const res = await request(app)
        .get('/api/v1/market/instruments/search')
        .query({ q: 'TCS' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.instruments.some((i: any) => i.symbol === 'TCS')).toBe(true);
    });

    it('GET /api/v1/market/instruments/:id returns specific instrument details', async () => {
      const res = await request(app).get('/api/v1/market/instruments/GOLD%201KG');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.instrument.symbol).toBe('GOLD 1KG');
      expect(res.body.instrument.exchange).toBe('MCX');
    });

    it('GET /api/v1/market/quotes/:id returns latest quote', async () => {
      const res = await request(app).get('/api/v1/market/quotes/BTC%2FUSDT');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.quote.symbol).toBe('BTC/USDT');
      expect(res.body.quote.status).toBe('SIMULATED');
    });

    it('GET /api/v1/market/status returns real exchange status', async () => {
      const res = await request(app).get('/api/v1/market/status');
      expect(res.status).toBe(200);
      expect(res.body.exchanges.length).toBeGreaterThanOrEqual(4);
      expect(res.body.exchanges.some((e: any) => e.exchange === 'CRYPTO')).toBe(true);
    });
  });
});
