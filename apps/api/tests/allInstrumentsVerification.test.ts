import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Holding, Order, LedgerEntry, TradeHistory } from '../src/models';
import { InstrumentMasterService } from '../src/modules/market-data/instrumentMaster.service';

const TEST_DB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/tradeverse_test_all_instruments';

export interface InstrumentTestCase {
  symbol: string;
  name: string;
  exchange: 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO' | 'AMFI';
  category: 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'ETF' | 'MUTUAL_FUND' | 'IPO';
  lotSize: number;
  testOrderQuantity: number;
  searchQuery: string;
}

export const SAMPLE_INSTRUMENTS: InstrumentTestCase[] = [
  // 1. NSE Equities (10 symbols)
  { symbol: 'RELIANCE', name: 'Reliance Industries Ltd.', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'reliance' },
  { symbol: 'TCS', name: 'Tata Consultancy Services', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 5, searchQuery: 'tcs' },
  { symbol: 'INFY', name: 'Infosys Limited', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'infy' },
  { symbol: 'HDFCBANK', name: 'HDFC Bank Limited', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'hdfc' },
  { symbol: 'TATAMOTORS', name: 'Tata Motors Limited', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 15, searchQuery: 'tata motors' },
  { symbol: 'SBIN', name: 'State Bank of India', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 20, searchQuery: 'sbi' },
  { symbol: 'YESBANK', name: 'Yes Bank Limited', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 100, searchQuery: 'yes bank' },
  { symbol: 'IDEA', name: 'Vodafone Idea Limited (Vi)', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 100, searchQuery: 'vi' },
  { symbol: 'KNRCON', name: 'KNR Constructions Limited', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'knr' },
  { symbol: 'JIOFIN', name: 'Jio Financial Services', exchange: 'NSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 25, searchQuery: 'jio' },

  // 2. BSE Equities & Dual-Listings (6 symbols)
  { symbol: 'BSE:RELIANCE', name: 'Reliance Industries Ltd.', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 5, searchQuery: 'reliance' },
  { symbol: 'BSE:YESBANK', name: 'Yes Bank Limited', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 50, searchQuery: 'yesbank' },
  { symbol: 'BSE:IDEA', name: 'Vodafone Idea Limited (Vi)', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 50, searchQuery: 'idea' },
  { symbol: 'BSE:JIOFIN', name: 'Jio Financial Services Ltd.', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 20, searchQuery: 'jiofin' },
  { symbol: 'BSE', name: 'BSE Limited (Exchange)', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 5, searchQuery: 'bse' },
  { symbol: 'CDSL', name: 'Central Depository Services Ltd.', exchange: 'BSE', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'cdsl' },

  // 3. Indian Indices (4 symbols)
  { symbol: 'NIFTY 50', name: 'Nifty 50 Index', exchange: 'NSE', category: 'INDEX', lotSize: 50, testOrderQuantity: 50, searchQuery: 'nifty 50' },
  { symbol: 'BANKNIFTY', name: 'Nifty Bank Index', exchange: 'NSE', category: 'INDEX', lotSize: 15, testOrderQuantity: 15, searchQuery: 'banknifty' },
  { symbol: 'FINNIFTY', name: 'Nifty Financial Services Index', exchange: 'NSE', category: 'INDEX', lotSize: 40, testOrderQuantity: 40, searchQuery: 'finnifty' },
  { symbol: 'SENSEX', name: 'BSE Sensex Index', exchange: 'BSE', category: 'INDEX', lotSize: 10, testOrderQuantity: 10, searchQuery: 'sensex' },

  // 4. Indian ETFs (4 symbols)
  { symbol: 'NIFTYBEES', name: 'Nippon India ETF Nifty 50 BeES', exchange: 'NSE', category: 'ETF', lotSize: 1, testOrderQuantity: 20, searchQuery: 'niftybees' },
  { symbol: 'GOLDBEES', name: 'Nippon India ETF Gold BeES', exchange: 'NSE', category: 'ETF', lotSize: 1, testOrderQuantity: 50, searchQuery: 'goldbees' },
  { symbol: 'BANKBEES', name: 'Nippon India ETF Nifty Bank BeES', exchange: 'NSE', category: 'ETF', lotSize: 1, testOrderQuantity: 10, searchQuery: 'bankbees' },
  { symbol: 'MON100', name: 'Motilal Oswal Nasdaq 100 ETF', exchange: 'NSE', category: 'ETF', lotSize: 1, testOrderQuantity: 25, searchQuery: 'mon100' },

  // 5. MCX Commodities & Current-Month Futures Contracts (6 symbols)
  { symbol: 'GOLD', name: 'MCX Gold Futures', exchange: 'MCX', category: 'COMMODITY', lotSize: 1, testOrderQuantity: 1, searchQuery: 'gold' },
  { symbol: 'GOLD 1KG', name: 'MCX Gold Futures 1KG', exchange: 'MCX', category: 'COMMODITY', lotSize: 1, testOrderQuantity: 1, searchQuery: 'gold 1kg' },
  { symbol: 'GOLDFUT', name: 'MCX Gold Current-Month Futures', exchange: 'MCX', category: 'COMMODITY', lotSize: 1, testOrderQuantity: 1, searchQuery: 'gold fut' },
  { symbol: 'CRUDEOIL', name: 'MCX Crude Oil 100 BBL', exchange: 'MCX', category: 'COMMODITY', lotSize: 100, testOrderQuantity: 100, searchQuery: 'crude' },
  { symbol: 'CRUDEOILFUT', name: 'MCX Crude Oil Current-Month Futures', exchange: 'MCX', category: 'COMMODITY', lotSize: 100, testOrderQuantity: 100, searchQuery: 'crude oil fut' },
  { symbol: 'SILVER 30KG', name: 'MCX Silver Futures', exchange: 'MCX', category: 'COMMODITY', lotSize: 30, testOrderQuantity: 30, searchQuery: 'silver' },

  // 6. US Stocks & ETFs (4 symbols)
  { symbol: 'AAPL', name: 'Apple Inc.', exchange: 'US', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'apple' },
  { symbol: 'NVDA', name: 'NVIDIA Corporation', exchange: 'US', category: 'EQUITY', lotSize: 1, testOrderQuantity: 10, searchQuery: 'nvidia' },
  { symbol: 'MSFT', name: 'Microsoft Corporation', exchange: 'US', category: 'EQUITY', lotSize: 1, testOrderQuantity: 5, searchQuery: 'microsoft' },
  { symbol: 'SPY', name: 'SPDR S&P 500 ETF Trust', exchange: 'US', category: 'ETF', lotSize: 1, testOrderQuantity: 5, searchQuery: 'spy' },

  // 7. Crypto 24/7 Spot Pairs (3 symbols)
  { symbol: 'BTC/USDT', name: 'Bitcoin 24/7 Live Stream', exchange: 'CRYPTO', category: 'CRYPTO', lotSize: 1, testOrderQuantity: 0.05, searchQuery: 'btc' },
  { symbol: 'ETH/USDT', name: 'Ethereum 24/7 Live Stream', exchange: 'CRYPTO', category: 'CRYPTO', lotSize: 1, testOrderQuantity: 0.25, searchQuery: 'ethereum' },
  { symbol: 'SOL/USDT', name: 'Solana 24/7 Live Stream', exchange: 'CRYPTO', category: 'CRYPTO', lotSize: 1, testOrderQuantity: 1.5, searchQuery: 'solana' },

  // 8. Indian Mutual Funds (3 symbols)
  { symbol: 'AXIS_BLUECHIP', name: 'Axis Bluechip Fund - Direct Plan', exchange: 'AMFI', category: 'MUTUAL_FUND', lotSize: 1, testOrderQuantity: 10, searchQuery: 'axis bluechip' },
  { symbol: 'HDFC_TOP100', name: 'HDFC Top 100 Fund - Growth Option', exchange: 'AMFI', category: 'MUTUAL_FUND', lotSize: 1, testOrderQuantity: 5, searchQuery: 'hdfc top 100' },
  { symbol: 'NIPPON_SMALLCAP', name: 'Nippon India Small Cap Fund', exchange: 'AMFI', category: 'MUTUAL_FUND', lotSize: 1, testOrderQuantity: 10, searchQuery: 'nippon small cap' },

  // 9. Indian IPOs (3 symbols)
  { symbol: 'SWIGGY', name: 'Swiggy Limited IPO', exchange: 'NSE', category: 'IPO', lotSize: 38, testOrderQuantity: 38, searchQuery: 'swiggy' },
  { symbol: 'HYUNDAI', name: 'Hyundai Motor India Ltd IPO', exchange: 'NSE', category: 'IPO', lotSize: 7, testOrderQuantity: 7, searchQuery: 'hyundai' },
  { symbol: 'NTPCGREEN', name: 'NTPC Green Energy Ltd IPO', exchange: 'NSE', category: 'IPO', lotSize: 138, testOrderQuantity: 138, searchQuery: 'ntpc green' },
];

describe('Item 3 Verification: Commodities, All Stocks, Indices, Crypto, MFs, and IPOs', () => {
  const app = createApp();
  let token: string;
  let isDbConnected = false;

  beforeAll(async () => {
    try {
      await mongoose.connect(TEST_DB_URI, { serverSelectionTimeoutMS: 2000 });
      isDbConnected = mongoose.connection.readyState === 1;
    } catch {
      isDbConnected = false;
    }

    await InstrumentMasterService.init();

    if (isDbConnected) {
      await User.deleteMany({});
      await PaperAccount.deleteMany({});
      await Holding.deleteMany({});
      await Order.deleteMany({});
      await LedgerEntry.deleteMany({});
      await TradeHistory.deleteMany({});

      // Register trader and fund account
      const authRes = await request(app).post('/api/v1/auth/register').send({
        email: 'instrument_trader@tradeverse.ai',
        password: 'Password123!',
        displayName: 'Instrument Tester',
      });
      token = authRes.body.token || authRes.body.accessToken;

      await request(app)
        .post('/api/v1/paper-account/add-funds')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 10000000 });
    }
  });

  afterAll(async () => {
    if (isDbConnected) {
      await User.deleteMany({});
      await PaperAccount.deleteMany({});
      await Holding.deleteMany({});
      await Order.deleteMany({});
      await LedgerEntry.deleteMany({});
      await TradeHistory.deleteMany({});
      await mongoose.disconnect();
    }
  });

  test('Sanity check: sample suite contains at least 30 instruments across 9 categories', () => {
    expect(SAMPLE_INSTRUMENTS.length).toBeGreaterThanOrEqual(30);
    const categories = new Set(SAMPLE_INSTRUMENTS.map((i) => i.category));
    expect(categories.size).toBeGreaterThanOrEqual(7);
  });

  describe('1. Search Verification across all 9 instrument types', () => {
    for (const item of SAMPLE_INSTRUMENTS) {
      it(`should find "${item.symbol}" via search query "${item.searchQuery}"`, async () => {
        const res = await request(app)
          .get('/api/v1/market-data/instruments/search')
          .query({ q: item.searchQuery, limit: 10 });

        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
        expect(Array.isArray(res.body.instruments)).toBe(true);

        const cleanTarget = item.symbol.replace(/^(NSE|BSE|MCX|US|CRYPTO|AMFI):/, '');
        const match = res.body.instruments.find(
          (inst: any) =>
            inst.symbol.toUpperCase() === item.symbol.toUpperCase() ||
            inst.symbol.toUpperCase() === cleanTarget ||
            inst.name.toUpperCase().includes(cleanTarget)
        );
        expect(match).toBeDefined();
        expect(match.lotSize).toBeDefined();
        expect(match.price).toBeGreaterThan(0);
      });
    }
  });

  describe('2. Detail & Quote Verification across all 9 instrument types', () => {
    for (const item of SAMPLE_INSTRUMENTS) {
      it(`should fetch valid quote for "${item.symbol}"`, async () => {
        const encoded = encodeURIComponent(item.symbol);
        const res = await request(app).get(`/api/v1/market-data/quote/${encoded}`);

        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.quote).toBeDefined();
        expect(res.body.quote.price).toBeGreaterThan(0);
        expect(res.body.quote.currency).toBeDefined();
        expect(res.body.quote.status).toBeDefined();
      });
    }
  });

  describe('3. Continuous Candles & Chart Verification (with live / delayed labelling)', () => {
    for (const item of SAMPLE_INSTRUMENTS) {
      it(`should return valid candle stream for "${item.symbol}" without error`, async () => {
        const encoded = encodeURIComponent(item.symbol);
        const res = await request(app)
          .get(`/api/v1/market-data/candles/${encoded}`)
          .query({ interval: '15m', range: '1D', limit: 20 });

        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
        expect(Array.isArray(res.body.candles)).toBe(true);
        expect(res.body.candles.length).toBeGreaterThan(0);

        const first = res.body.candles[0];
        expect(first.timestamp || first.time).toBeDefined();
        expect(first.open).toBeGreaterThan(0);
        expect(first.high).toBeGreaterThanOrEqual(first.low);
        expect(first.close).toBeGreaterThan(0);
      });
    }
  });

  describe('4. Order Ticket Validation & Execution across all instrument types', () => {
    it('should respect lot size for Indices (e.g. NIFTY 50 with lot size 50)', async () => {
      if (!isDbConnected) return;

      // 1. Order with exact lot size 50 succeeds
      const resOk = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'NIFTY 50',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 50,
        });

      expect(resOk.status).toBe(201);
      expect(resOk.body.success).toBe(true);
      expect(resOk.body.order.status).toBe('FILLED');

      // 2. Fractional/invalid quantity for index is rejected
      const resBad = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'NIFTY 50',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 73, // Non-multiple of 50
        });

      expect(resBad.status).toBe(500);
      expect(resBad.body.message).toContain('lot size');
    });

    it('should respect lot size for MCX Commodities (e.g. CRUDEOIL lot size 100)', async () => {
      if (!isDbConnected) return;

      const resOk = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'CRUDEOIL',
          exchange: 'MCX',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 100,
        });

      expect(resOk.status).toBe(201);
      expect(resOk.body.success).toBe(true);
      expect(resOk.body.order.quantity).toBe(100);
    });

    it('should support current-month futures contracts (e.g. GOLDFUT and CRUDEOILFUT)', async () => {
      if (!isDbConnected) return;

      const resFut = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'GOLDFUT',
          exchange: 'MCX',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 1,
        });

      expect(resFut.status).toBe(201);
      expect(resFut.body.success).toBe(true);
    });

    it('should allow fractional quantities for Crypto (e.g. 0.05 BTC/USDT)', async () => {
      if (!isDbConnected) return;

      const resCrypto = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'BTC/USDT',
          exchange: 'CRYPTO',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 0.05,
        });

      expect(resCrypto.status).toBe(201);
      expect(resCrypto.body.success).toBe(true);
      expect(resCrypto.body.order.quantity).toBe(0.05);
    });

    it('should enforce minimum purchase amount for Mutual Funds (₹100 minimum)', async () => {
      if (!isDbConnected) return;

      // 1. Order below ₹100 is rejected
      const resLow = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'AXIS_BLUECHIP',
          exchange: 'AMFI',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 1, // 1 unit * ₹62.45 = ₹62.45 (< ₹100)
        });

      expect(resLow.status).toBe(500);
      expect(resLow.body.message).toContain('Minimum purchase amount for mutual funds');

      // 2. Order meeting minimum purchase (e.g. 10 units * ₹62.45 = ₹624.50 >= ₹100)
      const resOk = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'AXIS_BLUECHIP',
          exchange: 'AMFI',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 10,
        });

      expect(resOk.status).toBe(201);
      expect(resOk.body.success).toBe(true);
      expect(resOk.body.order.quantity).toBe(10);
    });

    it('should execute IPO orders with exact lot size (e.g. SWIGGY lot size 38)', async () => {
      if (!isDbConnected) return;

      const resIpo = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'SWIGGY',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 38,
        });

      expect(resIpo.status).toBe(201);
      expect(resIpo.body.success).toBe(true);
      expect(resIpo.body.order.quantity).toBe(38);
    });

    it('should execute US Stock orders (e.g. AAPL)', async () => {
      if (!isDbConnected) return;

      const resUs = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'AAPL',
          exchange: 'US',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 5,
        });

      expect(resUs.status).toBe(201);
      expect(resUs.body.success).toBe(true);
      expect(resUs.body.order.quantity).toBe(5);
    });
  });
});
