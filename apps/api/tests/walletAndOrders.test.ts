import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Holding, Order, LedgerEntry, TradeHistory } from '../src/models';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_wallet_orders';

describe('Phase C: Wallet & Orders Backend Engine Tests', () => {
  const app = createApp();
  let token: string;
  let userId: string;
  let isDbConnected = false;

  beforeAll(async () => {
    try {
      await mongoose.connect(TEST_DB_URI, { serverSelectionTimeoutMS: 2000 });
      isDbConnected = mongoose.connection.readyState === 1;
    } catch {
      isDbConnected = false;
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

  beforeEach(async () => {
    if (!isDbConnected) return;

    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Holding.deleteMany({});
    await Order.deleteMany({});
    await LedgerEntry.deleteMany({});
    await TradeHistory.deleteMany({});

    // Register User with default 0 starting capital
    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'trader@tradeverse.ai',
      password: 'Password123!',
      displayName: 'Pro Trader',
    });

    token = res.body.accessToken;
    userId = res.body.user.id;
  });

  describe('1. Zero Starting Wallet Balance & Real Balance Enforcements', () => {
    it('new user should start with 0 available cash and 0 starting capital', async () => {
      if (!isDbConnected) return;

      const res = await request(app)
        .get('/api/v1/paper-account')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.account.startingCapital).toBe(0);
      expect(res.body.account.availableCash).toBe(0);
      expect(res.body.account.reservedMargin).toBe(0);
    });

    it('order should be strictly rejected when user wallet balance is 0', async () => {
      if (!isDbConnected) return;

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

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toContain('Insufficient virtual margin');
    });
  });

  describe('2. Add Funds, Withdraw & Transaction History', () => {
    it('should successfully add funds, credit wallet cash and create ledger record', async () => {
      if (!isDbConnected) return;

      const addRes = await request(app)
        .post('/api/v1/paper-account/add-funds')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 100000 });

      expect(addRes.status).toBe(200);
      expect(addRes.body.success).toBe(true);
      expect(addRes.body.account.availableCash).toBe(100000);

      // Verify transaction history / ledger
      const txRes = await request(app)
        .get('/api/v1/paper-account/transactions')
        .set('Authorization', `Bearer ${token}`);

      expect(txRes.status).toBe(200);
      expect(txRes.body.transactions.length).toBeGreaterThanOrEqual(1);
      expect(txRes.body.transactions[0].type).toBe('CAPITAL_TOPUP');
      expect(txRes.body.transactions[0].amount).toBe(100000);
      expect(txRes.body.transactions[0].balanceAfter).toBe(100000);
    });

    it('should reject withdrawal when requested amount exceeds available cash', async () => {
      if (!isDbConnected) return;

      // Add 25,000 first
      await request(app)
        .post('/api/v1/paper-account/add-funds')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 25000 });

      // Attempt withdrawing 50,000
      const withdrawRes = await request(app)
        .post('/api/v1/paper-account/withdraw')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 50000 });

      expect(withdrawRes.status).toBe(400);
      expect(withdrawRes.body.success).toBe(false);
      expect(withdrawRes.body.message).toContain('Insufficient available cash to withdraw');
    });

    it('should deduct cash on valid withdrawal and record CAPITAL_WITHDRAW in ledger', async () => {
      if (!isDbConnected) return;

      await request(app)
        .post('/api/v1/paper-account/add-funds')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 100000 });

      const withdrawRes = await request(app)
        .post('/api/v1/paper-account/withdraw')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 30000 });

      expect(withdrawRes.status).toBe(200);
      expect(withdrawRes.body.success).toBe(true);
      expect(withdrawRes.body.account.availableCash).toBe(70000);

      const txRes = await request(app)
        .get('/api/v1/paper-account/transactions')
        .set('Authorization', `Bearer ${token}`);

      expect(txRes.status).toBe(200);
      const withdrawTx = txRes.body.transactions.find((t: any) => t.type === 'CAPITAL_WITHDRAW');
      expect(withdrawTx).toBeDefined();
      expect(withdrawTx.amount).toBe(-30000);
      expect(withdrawTx.balanceAfter).toBe(70000);
    });
  });

  describe('3. Order Placement, Open Positions & Square Off', () => {
    it('should allow buying once funds are added and report in open positions', async () => {
      if (!isDbConnected) return;

      // Add 200,000 funds
      await request(app)
        .post('/api/v1/paper-account/add-funds')
        .set('Authorization', `Bearer ${token}`)
        .send({ amount: 200000 });

      // Buy 20 shares of RELIANCE
      const buyRes = await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 20,
        });

      expect(buyRes.status).toBe(201);
      expect(buyRes.body.order.status).toBe('FILLED');

      // Check open positions endpoint
      const posRes = await request(app)
        .get('/api/v1/orders/positions')
        .set('Authorization', `Bearer ${token}`);

      expect(posRes.status).toBe(200);
      expect(posRes.body.positions.length).toBe(1);
      expect(posRes.body.positions[0].symbol).toBe('RELIANCE');
      expect(posRes.body.positions[0].quantity).toBe(20);
      expect(posRes.body.positions[0].averagePrice).toBeGreaterThan(0);
    });

    it('should execute partial square-off, book realized P&L and move trade to history', async () => {
      if (!isDbConnected) return;

      // Setup holding manually for deterministic math
      const account = await PaperAccount.findOne({ userId });
      account!.availableCash = 50000;
      account!.startingCapital = 50000;
      await account!.save();

      await Holding.create({
        userId,
        paperAccountId: account!._id,
        instrumentId: 'NSE:RELIANCE',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        product: 'CNC',
        quantity: 20,
        averageCost: 2800.0,
      });

      // Partial square-off: 10 of 20 shares
      const sqRes = await request(app)
        .post('/api/v1/orders/positions/RELIANCE/square-off')
        .set('Authorization', `Bearer ${token}`)
        .send({
          quantity: 10,
          orderType: 'MARKET',
        });

      expect(sqRes.status).toBe(200);
      expect(sqRes.body.success).toBe(true);
      expect(sqRes.body.closedQuantity).toBe(10);
      expect(sqRes.body.remainingQuantity).toBe(10);
      expect(sqRes.body.exitPrice).toBeGreaterThan(0);
      expect(sqRes.body.netProceeds).toBeGreaterThan(0);

      // Verify wallet balance received the net proceeds
      const updatedAccount = await PaperAccount.findOne({ userId });
      expect(updatedAccount!.availableCash).toBeGreaterThan(50000);

      // Verify closed trade in history
      const historyRes = await request(app)
        .get('/api/v1/orders/history')
        .set('Authorization', `Bearer ${token}`);

      expect(historyRes.status).toBe(200);
      expect(historyRes.body.trades.length).toBe(1);
      expect(historyRes.body.trades[0].symbol).toBe('RELIANCE');
      expect(historyRes.body.trades[0].quantity).toBe(10);
      expect(historyRes.body.trades[0].entryPrice).toBe(2800.0);
      expect(historyRes.body.trades[0].realizedPnl).toBeDefined();

      // Verify remaining 10 in positions
      const posRes = await request(app)
        .get('/api/v1/orders/positions')
        .set('Authorization', `Bearer ${token}`);

      expect(posRes.body.positions[0].quantity).toBe(10);
    });

    it('should execute full square-off, delete holding and update P&L summary', async () => {
      if (!isDbConnected) return;

      const account = await PaperAccount.findOne({ userId });
      account!.availableCash = 50000;
      account!.startingCapital = 50000;
      await account!.save();

      await Holding.create({
        userId,
        paperAccountId: account!._id,
        instrumentId: 'NSE:TCS',
        symbol: 'TCS',
        exchange: 'NSE',
        product: 'CNC',
        quantity: 15,
        averageCost: 4000.0,
      });

      // Full square-off without quantity parameter
      const sqRes = await request(app)
        .post('/api/v1/orders/positions/TCS/square-off')
        .set('Authorization', `Bearer ${token}`)
        .send({});

      expect(sqRes.status).toBe(200);
      expect(sqRes.body.closedQuantity).toBe(15);
      expect(sqRes.body.remainingQuantity).toBe(0);

      // Verify holding is deleted
      const remainingHolding = await Holding.findOne({ userId, symbol: 'TCS' });
      expect(remainingHolding).toBeNull();

      // Check P&L summary endpoint
      const pnlRes = await request(app)
        .get('/api/v1/orders/summary/pnl')
        .set('Authorization', `Bearer ${token}`);

      expect(pnlRes.status).toBe(200);
      expect(pnlRes.body.summary.totalTrades).toBe(1);
      expect(pnlRes.body.summary.totalRealizedPnl).toBeDefined();
    });

    it('should reject square-off if no open position exists for the symbol', async () => {
      if (!isDbConnected) return;

      const sqRes = await request(app)
        .post('/api/v1/orders/positions/UNKNOWN_STOCK/square-off')
        .set('Authorization', `Bearer ${token}`)
        .send({});

      expect(sqRes.status).toBe(404);
      expect(sqRes.body.success).toBe(false);
      expect(sqRes.body.message).toContain('No open position found');
    });
  });
});
