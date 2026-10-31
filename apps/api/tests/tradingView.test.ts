import request from 'supertest';
import { createApp } from '../src/app';
import { resolveTradingViewSymbol } from '../src/modules/market-data/tradingView.routes';

describe('TradingView & Account Manager Routes', () => {
  const app = createApp();

  describe('resolveTradingViewSymbol', () => {
    it('maps Indian stocks and indices to NSE or BSE correctly', () => {
      expect(resolveTradingViewSymbol('NIFTY 50')).toBe('NSE:NIFTY');
      expect(resolveTradingViewSymbol('SENSEX')).toBe('BSE:SENSEX');
      expect(resolveTradingViewSymbol('RELIANCE')).toBe('NSE:RELIANCE');
      expect(resolveTradingViewSymbol('TCS')).toBe('NSE:TCS');
      expect(resolveTradingViewSymbol('ADANIENT')).toBe('NSE:ADANIENT');
    });

    it('maps Crypto symbols to BINANCE pairs', () => {
      expect(resolveTradingViewSymbol('BTC/USDT')).toBe('BINANCE:BTCUSDT');
      expect(resolveTradingViewSymbol('BTC')).toBe('BINANCE:BTCUSDT');
      expect(resolveTradingViewSymbol('ETH')).toBe('BINANCE:ETHUSDT');
      expect(resolveTradingViewSymbol('SOL')).toBe('BINANCE:SOLUSDT');
    });

    it('maps US equities to NASDAQ / NYSE', () => {
      expect(resolveTradingViewSymbol('AAPL')).toBe('NASDAQ:AAPL');
      expect(resolveTradingViewSymbol('TSLA')).toBe('NASDAQ:TSLA');
      expect(resolveTradingViewSymbol('NVDA')).toBe('NASDAQ:NVDA');
    });

    it('maps Commodities to MCX or TVC', () => {
      expect(resolveTradingViewSymbol('GOLD')).toBe('MCX:GOLD1!');
      expect(resolveTradingViewSymbol('CRUDEOIL')).toBe('MCX:CRUDEOIL1!');
    });
  });

  describe('GET /tradingview', () => {
    it('serves the interactive TradingView chart and Account Manager terminal', async () => {
      const res = await request(app).get('/tradingview');
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/html');
      expect(res.text).toContain('TradingView.widget');
      expect(res.text).toContain('Account Manager');
      expect(res.text).toContain('triggerCustomPageUpdate');
      expect(res.text).toContain('activeChart().setSymbol');
    });

    it('serves chart with symbol query parameter', async () => {
      const res = await request(app).get('/tradingview?symbol=BTC');
      expect(res.status).toBe(200);
      expect(res.text).toContain('BINANCE:BTCUSDT');
    });
  });

  describe('GET /api/v1/market-data/tradingview/symbol/:symbol', () => {
    it('returns JSON with resolved TradingView symbol and configuration', async () => {
      const res = await request(app).get('/api/v1/market-data/tradingview/symbol/RELIANCE');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.tradingViewSymbol).toBe('NSE:RELIANCE');
      expect(res.body.data.widgetUrl).toContain('/tradingview?symbol=RELIANCE');
    });
  });
});
