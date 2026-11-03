import request from 'supertest';
import { createApp } from '../src/app';
import { AlphaVantageService } from '../src/modules/market-data/alphaVantage.service';
import { sharedAlphaVantageBudget } from '../src/modules/market-data/rateLimitBudget';

describe('Alpha Vantage Live Market Data Integration Tests', () => {
  const app = createApp();

  beforeEach(() => {
    AlphaVantageService.clearCache();
    sharedAlphaVantageBudget.reset();
    jest.restoreAllMocks();
  });

  describe('GET /api/v1/market-data/alpha/status', () => {
    it('should report provider details and active feature list', async () => {
      const res = await request(app).get('/api/v1/market-data/alpha/status');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.provider).toBe('Alpha Vantage');
      expect(Array.isArray(res.body.features)).toBe(true);
      expect(res.body.features).toContain('GLOBAL_QUOTE');
      expect(res.body.features).toContain('SYMBOL_SEARCH');
    });
  });

  describe('GET /api/v1/market-data/alpha/search', () => {
    it('should return 400 when search query is empty', async () => {
      const res = await request(app).get('/api/v1/market-data/alpha/search');
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should return parsed symbol search results when API succeeds', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          bestMatches: [
            {
              '1. symbol': 'IBM',
              '2. name': 'International Business Machines Corp',
              '3. type': 'Equity',
              '4. region': 'United States',
              '5. marketOpen': '09:30',
              '6. marketClose': '16:00',
              '7. timezone': 'UTC-04',
              '8. currency': 'USD',
              '9. matchScore': '1.0000',
            },
          ],
        }),
      } as any);

      const res = await request(app).get('/api/v1/market-data/alpha/search?keywords=IBM');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.count).toBe(1);
      expect(res.body.results[0].symbol).toBe('IBM');
      expect(res.body.results[0].name).toContain('International Business Machines');
    });

    it('should utilize in-memory cache for repeated searches without redundant network calls', async () => {
      const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue({
        ok: true,
        json: async () => ({
          bestMatches: [
            {
              '1. symbol': 'AAPL',
              '2. name': 'Apple Inc',
              '3. type': 'Equity',
              '4. region': 'United States',
              '5. marketOpen': '09:30',
              '6. marketClose': '16:00',
              '7. timezone': 'UTC-04',
              '8. currency': 'USD',
              '9. matchScore': '0.95',
            },
          ],
        }),
      } as any);

      // First call: hits network
      await request(app).get('/api/v1/market-data/alpha/search?keywords=AAPL');
      expect(fetchSpy).toHaveBeenCalledTimes(1);

      // Second call: served from in-memory cache
      const cachedRes = await request(app).get('/api/v1/market-data/alpha/search?keywords=AAPL');
      expect(cachedRes.status).toBe(200);
      expect(cachedRes.body.count).toBe(1);
      expect(fetchSpy).toHaveBeenCalledTimes(1); // Still 1 call
    });
  });

  describe('GET /api/v1/market-data/alpha/quote/:symbol', () => {
    it('should return live quote with calculated bid/ask spreads when Alpha Vantage responds', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          'Global Quote': {
            '01. symbol': 'MSFT',
            '02. open': '420.00',
            '03. high': '425.50',
            '04. low': '418.20',
            '05. price': '423.80',
            '06. volume': '18492000',
            '07. latest trading day': '2026-10-28',
            '08. previous close': '419.50',
            '09. change': '4.30',
            '10. change percent': '1.025%',
          },
        }),
      } as any);

      const res = await request(app).get('/api/v1/market-data/alpha/quote/MSFT');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.provider).toBe('Alpha Vantage');
      expect(res.body.quote.symbol).toBe('MSFT');
      expect(res.body.quote.price).toBe(423.8);
      expect(res.body.quote.status).toBe('LIVE');
      expect(res.body.quote.ask).toBeGreaterThan(res.body.quote.bid);
    });

    it('should fall back gracefully to internal simulated quote on network timeout or rate limit', async () => {
      // Simulate rate limit response note
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          Note: 'Thank you for using Alpha Vantage! Our standard API call frequency is 5 calls per minute.',
        }),
      } as any);

      const res = await request(app).get('/api/v1/market-data/alpha/quote/RELIANCE');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.provider).toContain('Internal Simulator (Fallback)');
      expect(res.body.quote.symbol).toBe('RELIANCE');
      expect(res.body.quote.status).toBe('SIMULATED');
    });

    it('should return 404 if instrument does not exist on Alpha Vantage and is not in local master', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          'Global Quote': {},
        }),
      } as any);

      const res = await request(app).get('/api/v1/market-data/alpha/quote/NONEXISTENT_TICKER_999');
      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/market-data/alpha/candles/:symbol', () => {
    it('should parse daily candles into chronologically sorted OHLCV format', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          'Time Series (Daily)': {
            '2026-10-27': {
              '1. open': '150.00',
              '2. high': '155.00',
              '3. low': '149.00',
              '4. close': '153.00',
              '5. volume': '1200000',
            },
            '2026-10-28': {
              '1. open': '153.00',
              '2. high': '158.00',
              '3. low': '152.00',
              '4. close': '157.00',
              '5. volume': '1500000',
            },
          },
        }),
      } as any);

      const res = await request(app).get('/api/v1/market-data/alpha/candles/AAPL?limit=10');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.provider).toBe('Alpha Vantage');
      expect(res.body.status).toBe('LIVE');
      expect(res.body.candles.length).toBe(2);
      expect(res.body.candles[0].timestamp).toBeLessThan(res.body.candles[1].timestamp); // Sorted ascending
    });

    it('should fall back gracefully to local candles when Alpha Vantage returns empty or rate-limited', async () => {
      jest.spyOn(global, 'fetch').mockRejectedValueOnce(new Error('Network error'));

      const res = await request(app).get('/api/v1/market-data/alpha/candles/TCS?limit=10');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.provider).toContain('Internal Simulator (Fallback)');
      expect(res.body.status).toBe('SIMULATED');
      expect(res.body.candles.length).toBe(10);
    });
  });
});
