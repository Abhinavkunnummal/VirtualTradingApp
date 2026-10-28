import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Order, Execution, Holding, LedgerEntry } from '../src/models';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_engine';

describe('Virtual Trading Engine Integration Tests (Phase 4)', () => {
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
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Order.deleteMany({});
    await Execution.deleteMany({});
    await Holding.deleteMany({});
    await LedgerEntry.deleteMany({});

    // Register user with ₹10,00,000 initial capital
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'trader_engine@tradeverse.ai',
      password: 'Password123!',
      displayName: 'Engine Tester',
      startingCapital: 1000000,
    });
    token = reg.body.accessToken;
    userId = reg.body.user.id;
  });

  describe('Market Order Execution', () => {
    it('should execute MARKET BUY order immediately, deduct cash and create holding', async () => {
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 10,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.order.status).toBe('FILLED');
      expect(res.body.order.filledQuantity).toBe(10);
      expect(res.body.execution).not.toBeNull();
      expect(res.body.execution.isSimulated).toBe(true);
      expect(res.body.execution.fees).toBeGreaterThan(0);

      // Verify cash balance deducted in PaperAccount
      const account = await PaperAccount.findOne({ userId });
      expect(account!.availableCash).toBeLessThan(1000000);

      // Verify holding created
      const holding = await Holding.findOne({ userId, symbol: 'RELIANCE' });
      expect(holding).not.toBeNull();
      expect(holding!.quantity).toBe(10);

      // Verify auditable ledger entry recorded
      const ledger = await LedgerEntry.find({ userId });
      expect(ledger.length).toBeGreaterThan(0);
      expect(ledger.some((l) => l.type === 'TRADE_FILL')).toBe(true);
    });

    it('should reject order when user has insufficient virtual margin', async () => {
      // Attempting to buy 5,000 shares of RELIANCE (~₹1.47 Crore) with ₹10 Lakh balance
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 5000,
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Insufficient virtual margin');
    });

    it('should reject delivery SELL if user does not own sufficient shares', async () => {
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'TCS',
          exchange: 'NSE',
          side: 'SELL',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 10,
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Insufficient holdings');
    });
  });

  describe('Pending Limit Orders & Cancellation', () => {
    it('should place distant LIMIT order into PENDING status and reserve margin', async () => {
      // Place BUY limit order at ₹2,500 (well below current ~₹2,945 LTP)
      const res = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'LIMIT',
          product: 'CNC',
          quantity: 10,
          limitPrice: 2500,
        });

      expect(res.status).toBe(201);
      expect(res.body.order.status).toBe('PENDING');
      expect(res.body.execution).toBeNull();

      // Check PaperAccount reservedMargin
      const account = await PaperAccount.findOne({ userId });
      expect(account!.reservedMargin).toBeGreaterThan(0);
      expect(account!.availableCash).toBeLessThan(1000000);

      const orderId = res.body.order.id;

      // Cancel the pending order
      const cancelRes = await request(app)
        .post(`/api/v1/orders/${orderId}/cancel`)
        .set('Authorization', `Bearer ${token}`);

      expect(cancelRes.status).toBe(200);
      expect(cancelRes.body.order.status).toBe('CANCELLED');

      // Verify reserved margin was released back to cash
      const accountAfter = await PaperAccount.findOne({ userId });
      expect(accountAfter!.reservedMargin).toBe(0);
      expect(accountAfter!.availableCash).toBe(1000000);

      // Verify Ledger recorded MARGIN_RELEASE
      const releaseEntry = await LedgerEntry.findOne({ userId, type: 'MARGIN_RELEASE' });
      expect(releaseEntry).not.toBeNull();
    });
  });

  describe('Idempotency & Auditable Ledger', () => {
    it('should handle idempotency key gracefully without duplicate fills or charges', async () => {
      const idempotencyKey = 'unique-tx-key-12345';

      const firstCall = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'INFY',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 10,
          idempotencyKey,
        });

      expect(firstCall.status).toBe(201);
      const firstOrderId = firstCall.body.order.id;

      const secondCall = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'INFY',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 10,
          idempotencyKey,
        });

      expect(secondCall.status).toBe(201);
      expect(secondCall.body.order.id).toBe(firstOrderId);
      expect(secondCall.body.message).toContain('Idempotent');

      // Verify only 1 order and 1 holding created
      const orderCount = await Order.countDocuments({ userId });
      expect(orderCount).toBe(1);

      const holding = await Holding.findOne({ userId, symbol: 'INFY' });
      expect(holding!.quantity).toBe(10);
    });

    it('should retrieve executions and ledger history', async () => {
      // Execute 1 trade
      await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'HDFCBANK',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 5,
        });

      const execRes = await request(app)
        .get('/api/v1/orders/executions/history')
        .set('Authorization', `Bearer ${token}`);

      expect(execRes.status).toBe(200);
      expect(execRes.body.executions.length).toBe(1);

      const ledgerRes = await request(app)
        .get('/api/v1/orders/account/ledger')
        .set('Authorization', `Bearer ${token}`);

      expect(ledgerRes.status).toBe(200);
      expect(ledgerRes.body.entries.length).toBeGreaterThan(0);
    });
  });
});
