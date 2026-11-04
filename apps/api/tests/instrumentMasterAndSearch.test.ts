import request from 'supertest';
import { createApp } from '../src/app';
import { InstrumentMasterService, CURATED_INSTRUMENTS } from '../src/modules/market-data/instrumentMaster.service';
import { RealtimeMarketService } from '../src/modules/market-data/realtimeMarket.service';

const app = createApp();

describe('Phase B: Instrument Master & Advanced Search Endpoints', () => {
  beforeAll(async () => {
    await InstrumentMasterService.init();
  });

  describe('1. Ingestion & Normalization', () => {
    it('should normalize raw Angel One / Upstox / NSE instrument records correctly', () => {
      const rawNse = {
        symbol: 'TATACHEM-EQ',
        name: 'Tata Chemicals Limited',
        exchange: 'NSE',
        lot_size: '1',
        tick_size: '0.05',
        price: '1050.25',
        isin: 'INE092A01019',
        segment: 'EQ',
      };

      const normalized = InstrumentMasterService.normalizeRawRecord(rawNse);
      expect(normalized).toBeDefined();
      expect(normalized?.symbol).toBe('TATACHEM');
      expect(normalized?.displayName).toBe('Tata Chemicals Limited');
      expect(normalized?.exchange).toBe('NSE');
      expect(normalized?.assetClass).toBe('EQUITY');
      expect(normalized?.lotSize).toBe(1);
      expect(normalized?.tickSize).toBe(0.05);
      expect(normalized?.isin).toBe('INE092A01019');
    });

    it('should identify ETFs and Indices from raw records', () => {
      const rawEtf = {
        symbol: 'SETFNIF50',
        name: 'SBI Nifty 50 ETF',
        exchange: 'NSE',
        lot_size: '1',
        tick_size: '0.01',
      };
      const normEtf = InstrumentMasterService.normalizeRawRecord(rawEtf);
      expect(normEtf?.assetClass).toBe('ETF');

      const rawIndex = {
        symbol: 'NIFTY 50',
        name: 'Nifty 50 Index',
        exchange: 'NSE',
        lot_size: '50',
      };
      const normIndex = InstrumentMasterService.normalizeRawRecord(rawIndex);
      expect(normIndex?.assetClass).toBe('INDEX');
      expect(normIndex?.lotSize).toBe(50);
    });

    it('should normalize crypto and US equity instruments', () => {
      const rawCrypto = {
        symbol: 'ETH/USDT',
        name: 'Ethereum 24/7 Simulator',
        exchange: 'CRYPTO',
        tick_size: '0.01',
      };
      const normCrypto = InstrumentMasterService.normalizeRawRecord(rawCrypto);
      expect(normCrypto?.exchange).toBe('CRYPTO');
      expect(normCrypto?.assetClass).toBe('CRYPTO');
      expect(normCrypto?.quoteCurrency).toBe('USD');

      const rawUs = {
        symbol: 'NVDA',
        name: 'NVIDIA Corp',
        exchange: 'NASDAQ',
        tick_size: '0.01',
      };
      const normUs = InstrumentMasterService.normalizeRawRecord(rawUs);
      expect(normUs?.exchange).toBe('US');
      expect(normUs?.assetClass).toBe('EQUITY');
      expect(normUs?.quoteCurrency).toBe('USD');
    });
  });

  describe('2. Server-side Search & Pagination', () => {
    it('should return paginated default instruments when query is empty', async () => {
      const res = await request(app).get('/api/v1/market/instruments/search?limit=10&page=1');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.instruments.length).toBeLessThanOrEqual(10);
      expect(res.body.page).toBe(1);
      expect(res.body.limit).toBe(10);
      expect(res.body.total).toBeGreaterThan(0);
    });

    it('should perform fast prefix match search on symbol', async () => {
      const res = await request(app).get('/api/v1/market/instruments/search?q=REL');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      const symbols = res.body.instruments.map((i: any) => i.symbol);
      expect(symbols).toContain('RELIANCE');
    });

    it('should search by company/asset name substring', async () => {
      const res = await request(app).get('/api/v1/market/instruments/search?q=Consultancy');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      const symbols = res.body.instruments.map((i: any) => i.symbol);
      expect(symbols).toContain('TCS');
    });

    it('should handle typo and phonetic normalization (e.g. adhani -> adani)', async () => {
      const res = await request(app).get('/api/v1/market/instruments/search?q=adhani');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      const symbols = res.body.instruments.map((i: any) => i.symbol);
      expect(symbols.some((s: string) => s.startsWith('ADANI'))).toBe(true);
    });

    it('should filter by exchange (NSE, BSE, CRYPTO, US)', async () => {
      const nseRes = await request(app).get('/api/v1/market/instruments/search?exchange=NSE&limit=50');
      expect(nseRes.status).toBe(200);
      expect(nseRes.body.instruments.every((i: any) => i.exchange === 'NSE')).toBe(true);

      const cryptoRes = await request(app).get('/api/v1/market/instruments/search?exchange=CRYPTO');
      expect(cryptoRes.status).toBe(200);
      expect(cryptoRes.body.instruments.every((i: any) => i.exchange === 'CRYPTO')).toBe(true);
      expect(cryptoRes.body.instruments.some((i: any) => i.symbol === 'BTC/USDT')).toBe(true);

      const usRes = await request(app).get('/api/v1/market/instruments/search?exchange=US');
      expect(usRes.status).toBe(200);
      expect(usRes.body.instruments.every((i: any) => i.exchange === 'US')).toBe(true);
      expect(usRes.body.instruments.some((i: any) => i.symbol === 'AAPL')).toBe(true);
    });

    it('should filter by category (ETF, INDEX, EQUITY)', async () => {
      const etfRes = await request(app).get('/api/v1/market/instruments/search?category=ETF');
      expect(etfRes.status).toBe(200);
      expect(etfRes.body.instruments.every((i: any) => i.category === 'ETF')).toBe(true);
      expect(etfRes.body.instruments.some((i: any) => i.symbol === 'NIFTYBEES')).toBe(true);

      const indexRes = await request(app).get('/api/v1/market/instruments/search?category=INDEX');
      expect(indexRes.status).toBe(200);
      expect(indexRes.body.instruments.every((i: any) => i.category === 'INDEX')).toBe(true);
      expect(indexRes.body.instruments.some((i: any) => i.symbol === 'NIFTY 50')).toBe(true);
    });

    it('should return lot size and tick size in search results', async () => {
      const res = await request(app).get('/api/v1/market/instruments/search?q=NIFTY');
      expect(res.status).toBe(200);
      const nifty = res.body.instruments.find((i: any) => i.symbol === 'NIFTY 50');
      expect(nifty).toBeDefined();
      expect(nifty.lotSize).toBe(50);
      expect(nifty.tickSize).toBe(0.05);
    });

    it('should trigger manual sync via POST /api/v1/market-data/instruments/sync', async () => {
      const res = await request(app).post('/api/v1/market-data/instruments/sync');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.count).toBeGreaterThan(0);
    });
  });

  describe('3. Phase F1: Precision Search, Target Scrips, Aliases & Dual Listings', () => {
    it('should find YES BANK via alias and full name', async () => {
      const resName = await request(app).get('/api/instruments/search?q=yes%20bank');
      expect(resName.status).toBe(200);
      expect(resName.body.success).toBe(true);
      const symbols = resName.body.instruments.map((i: any) => i.symbol);
      expect(symbols).toContain('YESBANK');

      const resSym = await request(app).get('/api/instruments/search?q=YESBANK');
      expect(resSym.status).toBe(200);
      expect(resSym.body.instruments[0].symbol).toBe('YESBANK');
    });

    it('should find VODAFONE IDEA via alias "vi" and never rank unrelated companies (AMD, CDSL, TCS) above it', async () => {
      const resVi = await request(app).get('/api/instruments/search?q=vi');
      expect(resVi.status).toBe(200);
      expect(resVi.body.success).toBe(true);
      expect(resVi.body.instruments.length).toBeGreaterThan(0);

      // Top result MUST be IDEA (Vodafone Idea Limited)
      const topInstrument = resVi.body.instruments[0];
      expect(topInstrument.symbol).toBe('IDEA');
      expect(topInstrument.name).toContain('Vodafone Idea');

      // Unrelated stocks like AMD, CDSL, TCS containing 'vi' in middle of name must NOT be returned or ranked above IDEA
      const symbols = resVi.body.instruments.map((i: any) => i.symbol);
      expect(symbols.slice(0, 2)).toContain('IDEA');
      expect(symbols).not.toContain('AMD');
      expect(symbols).not.toContain('CDSL');
      expect(symbols).not.toContain('TCS');

      // Also verify searching full name "vodafone idea"
      const resFull = await request(app).get('/api/instruments/search?q=vodafone%20idea');
      expect(resFull.body.instruments[0].symbol).toBe('IDEA');
    });

    it('should find KNR CONSTRUCTIONS via alias "knr" and full name', async () => {
      const resKnr = await request(app).get('/api/instruments/search?q=knr');
      expect(resKnr.status).toBe(200);
      expect(resKnr.body.success).toBe(true);
      const symbols = resKnr.body.instruments.map((i: any) => i.symbol);
      expect(symbols).toContain('KNRCON');

      const resFull = await request(app).get('/api/instruments/search?q=knr%20constructions');
      expect(resFull.body.instruments[0].symbol).toBe('KNRCON');
    });

    it('should find JIO FINANCIAL SERVICES on both NSE and BSE with exchange badges', async () => {
      const resJio = await request(app).get('/api/instruments/search?q=jio');
      expect(resJio.status).toBe(200);
      expect(resJio.body.success).toBe(true);
      const jioEntries = resJio.body.instruments.filter((i: any) => i.symbol === 'JIOFIN');
      expect(jioEntries.length).toBeGreaterThanOrEqual(2);

      const exchanges = jioEntries.map((i: any) => i.exchange);
      expect(exchanges).toContain('NSE');
      expect(exchanges).toContain('BSE');
    });

    it('should find dual-listed RELIANCE on both NSE and BSE', async () => {
      const res = await request(app).get('/api/instruments/search?q=RELIANCE');
      expect(res.status).toBe(200);
      const relianceEntries = res.body.instruments.filter((i: any) => i.symbol === 'RELIANCE');
      expect(relianceEntries.length).toBeGreaterThanOrEqual(2);
      const exchanges = relianceEntries.map((i: any) => i.exchange);
      expect(exchanges).toContain('NSE');
      expect(exchanges).toContain('BSE');
    });

    it('should find TATA MOTORS via alias "tata motors"', async () => {
      const res = await request(app).get('/api/instruments/search?q=tata%20motors');
      expect(res.status).toBe(200);
      const symbols = res.body.instruments.map((i: any) => i.symbol);
      expect(symbols).toContain('TATAMOTORS');
    });

    it('should find US stocks (AAPL) and Crypto (BTC)', async () => {
      const resAapl = await request(app).get('/api/instruments/search?q=AAPL');
      expect(resAapl.status).toBe(200);
      expect(resAapl.body.instruments[0].symbol).toBe('AAPL');
      expect(resAapl.body.instruments[0].exchange).toBe('US');

      const resBtc = await request(app).get('/api/instruments/search?q=BTC');
      expect(resBtc.status).toBe(200);
      expect(resBtc.body.instruments.some((i: any) => i.symbol === 'BTC/USDT')).toBe(true);
    });

    it('should find Mutual Funds by name and filter by type=Mutual Fund with NAV and fund house', async () => {
      const resName = await request(app).get('/api/instruments/search?q=Axis%20Bluechip');
      expect(resName.status).toBe(200);
      expect(resName.body.success).toBe(true);
      expect(resName.body.instruments.length).toBeGreaterThan(0);
      expect(resName.body.instruments[0].name).toContain('Axis Bluechip');
      expect(resName.body.instruments[0].category).toBe('MUTUAL_FUND');
      expect(resName.body.instruments[0].nav).toBeDefined();

      const resFilter = await request(app).get('/api/instruments/search?type=Mutual%20Fund');
      expect(resFilter.status).toBe(200);
      expect(resFilter.body.instruments.length).toBeGreaterThan(0);
      expect(resFilter.body.instruments.every((i: any) => i.category === 'MUTUAL_FUND')).toBe(true);
    });

    it('should support pagination with cursor and limit', async () => {
      const res = await request(app).get('/api/instruments/search?limit=5&cursor=1');
      expect(res.status).toBe(200);
      expect(res.body.instruments.length).toBeLessThanOrEqual(5);
      expect(res.body.page).toBe(1);
      expect(res.body.limit).toBe(5);
      expect(res.body.totalPages).toBeGreaterThan(1);
    });
  });

  describe('4. Dynamic Indian & US Stock Candle Resolution', () => {
    it('should dynamically resolve newly added Indian stock mappings to Yahoo Finance .NS', () => {
      const mapping = RealtimeMarketService.getMapping('BEL');
      expect(mapping).toBeDefined();
      expect(mapping.exchange).toBe('NSE');
      expect(mapping.yf).toBe('BEL.NS');
    });

    it('should resolve Indian ETFs to Yahoo Finance .NS', () => {
      const mapping = RealtimeMarketService.getMapping('NIFTYBEES');
      expect(mapping).toBeDefined();
      expect(mapping.exchange).toBe('NSE');
      expect(mapping.yf).toBe('NIFTYBEES.NS');
    });

    it('should serve candles for any Indian stock with delayed indicator', async () => {
      const res = await request(app).get('/api/market/candles?symbol=BEL&interval=15m&limit=10&source=simulated');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.symbol).toBe('BEL');
      expect(res.body.candles.length).toBeGreaterThan(0);
    });
  });
});
