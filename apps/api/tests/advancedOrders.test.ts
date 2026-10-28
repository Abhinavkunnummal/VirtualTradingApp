import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Order, Execution, Holding, LedgerEntry, Notification } from '../src/models';
import { PaperTradingEngine } from '../src/modules/orders/paperEngine.service';
import { MarketDataService } from '../src/modules/market-data/marketData.service';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_advanced_orders';

describe('Advanced Order Types (Cover, Bracket, Trailing Stop-Loss, OCO)', () => {
  const app = createApp();
  let token: string;
  let userId: string;

  beforeAll(async () => {
    await mongoose.connect(TEST_DB_URI);
  });

  afterAll(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Order.deleteMany({});
    await Execution.deleteMany({});
    await Holding.deleteMany({});
    await LedgerEntry.deleteMany({});
    await Notification.deleteMany({});
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Order.deleteMany({});
    await Execution.deleteMany({});
    await Holding.deleteMany({});
    await LedgerEntry.deleteMany({});
    await Notification.deleteMany({});

    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'advanced_trader@tradeverse.ai',
      password: 'Password123!',
      displayName: 'Advanced Trader',
      startingCapital: 1000000,
    });
    token = reg.body.accessToken;
    userId = reg.body.user.id;
  });

  describe('Cover Orders (CO)', () => {
    it('should reject a Cover Order if stopLossPrice is missing', async () => {
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 5,
          orderVariety: 'COVER',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/Cover order requires a mandatory stop-loss/i);
    });

    it('should reject a BUY Cover Order if stopLossPrice >= entry price', async () => {
      const quote = MarketDataService.getQuote('RELIANCE')!;
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 5,
          orderVariety: 'COVER',
          stopLossPrice: quote.price + 50,
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/must be lower than entry price/i);
    });

    it('should execute BUY Cover Order and spawn pending Stop-Loss leg', async () => {
      const quote = MarketDataService.getQuote('RELIANCE')!;
      const stopPrice = quote.price - 40;

      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 5,
          orderVariety: 'COVER',
          stopLossPrice: stopPrice,
        });

      expect(res.status).toBe(201);
      expect(res.body.order.status).toBe('FILLED');
      expect(res.body.order.orderVariety).toBe('COVER');
      expect(res.body.childLegs).toHaveLength(1);
      expect(res.body.childLegs[0].bracketLegType).toBe('STOP_LOSS');
      expect(res.body.childLegs[0].side).toBe('SELL');
      expect(res.body.childLegs[0].triggerPrice).toBe(stopPrice);
      expect(res.body.childLegs[0].status).toBe('PENDING');

      // Verify notification created
      const notifs = await Notification.find({ userId });
      expect(notifs.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('Bracket Orders (BO) & OCO Logic', () => {
    it('should reject Bracket Order missing target or stop loss', async () => {
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'TCS',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 2,
          orderVariety: 'BRACKET',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/Bracket order requires both targetPrice and stopLossPrice/i);
    });

    it('should execute Bracket Order entry and create Target and SL pending legs', async () => {
      const quote = MarketDataService.getQuote('TCS')!;
      const target = quote.price + 80;
      const stop = quote.price - 40;

      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'TCS',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 4,
          orderVariety: 'BRACKET',
          targetPrice: target,
          stopLossPrice: stop,
          trailingStopLoss: 10,
        });

      expect(res.status).toBe(201);
      expect(res.body.order.status).toBe('FILLED');
      expect(res.body.childLegs).toHaveLength(2);

      const targetLeg = res.body.childLegs.find((l: any) => l.bracketLegType === 'TARGET');
      const slLeg = res.body.childLegs.find((l: any) => l.bracketLegType === 'STOP_LOSS');

      expect(targetLeg).toBeDefined();
      expect(targetLeg.limitPrice).toBe(target);
      expect(targetLeg.status).toBe('PENDING');

      expect(slLeg).toBeDefined();
      expect(slLeg.triggerPrice).toBe(stop);
      expect(slLeg.trailingStopLoss).toBe(10);
      expect(slLeg.status).toBe('PENDING');
    });

    it('should cancel Stop-Loss sibling when Target leg fills (OCO behavior)', async () => {
      const quote = MarketDataService.getQuote('HDFCBANK')!;
      const entryPrice = quote.price;
      const target = entryPrice + 50;
      const stop = entryPrice - 30;

      const orderRes = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'HDFCBANK',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 10,
          orderVariety: 'BRACKET',
          targetPrice: target,
          stopLossPrice: stop,
        });

      expect(orderRes.status).toBe(201);
      const parentOrderId = orderRes.body.order.id;

      const legsBefore = await Order.find({ parentOrderId });
      expect(legsBefore).toHaveLength(2);

      // Simulate market price jumping to target price
      const highQuote = {
        ...quote,
        price: target + 5,
        bid: target + 4,
        ask: target + 6,
      };

      await PaperTradingEngine.evaluateOpenOrders('HDFCBANK', highQuote);

      const targetLegAfter = await Order.findOne({ parentOrderId, bracketLegType: 'TARGET' });
      const slLegAfter = await Order.findOne({ parentOrderId, bracketLegType: 'STOP_LOSS' });

      expect(targetLegAfter?.status).toBe('FILLED');
      expect(slLegAfter?.status).toBe('CANCELLED');
      expect(slLegAfter?.rejectionReason).toMatch(/OCO/i);

      // Check OCO notification
      const ocoNotif = await Notification.findOne({ userId, type: 'BRACKET_OCO' });
      expect(ocoNotif).toBeDefined();
    });
  });

  describe('Trailing Stop-Loss Ratcheting', () => {
    it('should ratchet triggerPrice upwards as market price rises favorably', async () => {
      const quote = MarketDataService.getQuote('RELIANCE')!;
      const entryPrice = quote.price;
      const initialSL = entryPrice - 50;
      const trailingStep = 15;

      const orderRes = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'MIS',
          quantity: 2,
          orderVariety: 'BRACKET',
          targetPrice: entryPrice + 200,
          stopLossPrice: initialSL,
          trailingStopLoss: trailingStep,
        });

      const parentOrderId = orderRes.body.order.id;
      const slLeg = await Order.findOne({ parentOrderId, bracketLegType: 'STOP_LOSS' });
      expect(slLeg?.triggerPrice).toBe(initialSL);

      // Simulate market price rising by 35 points (two 15-point steps)
      const favorableQuote = {
        ...quote,
        price: entryPrice + 35,
        bid: entryPrice + 34,
        ask: entryPrice + 36,
      };

      await PaperTradingEngine.evaluateOpenOrders('RELIANCE', favorableQuote);

      const slLegRatcheted = await Order.findOne({ parentOrderId, bracketLegType: 'STOP_LOSS' });
      // Ratchet should increase triggerPrice by 2 * 15 = 30 points
      expect(slLegRatcheted?.triggerPrice).toBe(initialSL + 30);
    });
  });
});
