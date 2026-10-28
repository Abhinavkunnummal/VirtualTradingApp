import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Holding, Watchlist } from '../src/models';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_paper';

describe('Paper Account, Portfolio & Watchlist Tests', () => {
  const app = createApp();
  let token1: string;
  let userId1: string;
  let token2: string;

  beforeAll(async () => {
    await mongoose.connect(TEST_DB_URI);
  });

  afterAll(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Holding.deleteMany({});
    await Watchlist.deleteMany({});
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Holding.deleteMany({});
    await Watchlist.deleteMany({});

    // Register User 1
    const reg1 = await request(app).post('/api/v1/auth/register').send({
      email: 'user1@tradeverse.ai',
      password: 'Password123!',
      displayName: 'User One',
      startingCapital: 1000000,
    });
    token1 = reg1.body.accessToken;
    userId1 = reg1.body.user.id;

    // Register User 2
    const reg2 = await request(app).post('/api/v1/auth/register').send({
      email: 'user2@tradeverse.ai',
      password: 'Password123!',
      displayName: 'User Two',
      startingCapital: 500000,
    });
    token2 = reg2.body.accessToken;
  });

  describe('GET /api/v1/paper-account', () => {
    it('should return the authenticated user paper account', async () => {
      const res = await request(app)
        .get('/api/v1/paper-account')
        .set('Authorization', `Bearer ${token1}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.account.startingCapital).toBe(1000000);
      expect(res.body.account.availableCash).toBe(1000000);
      expect(res.body.account.isSimulated).toBe(true);
      expect(res.body.account.disclaimer).toBeDefined();
    });
  });

  describe('POST /api/v1/paper-account/reset', () => {
    it('should reset paper account balance and clear holdings', async () => {
      // Add a dummy holding first
      const account = await PaperAccount.findOne({ userId: userId1 });
      await Holding.create({
        userId: userId1,
        paperAccountId: account!._id,
        instrumentId: 'NSE:RELIANCE',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        quantity: 10,
        averageCost: 2900,
      });

      const res = await request(app)
        .post('/api/v1/paper-account/reset')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          startingCapital: 2500000,
          resetPortfolio: true,
        });

      expect(res.status).toBe(200);
      expect(res.body.account.startingCapital).toBe(2500000);
      expect(res.body.account.availableCash).toBe(2500000);

      // Verify holdings cleared
      const holdings = await Holding.find({ userId: userId1 });
      expect(holdings.length).toBe(0);
    });
  });

  describe('GET /api/v1/portfolio', () => {
    it('should calculate portfolio values and P&L accurately', async () => {
      const account = await PaperAccount.findOne({ userId: userId1 });
      await Holding.create({
        userId: userId1,
        paperAccountId: account!._id,
        instrumentId: 'NSE:RELIANCE',
        symbol: 'RELIANCE',
        exchange: 'NSE',
        quantity: 10,
        averageCost: 2900, // Invested = 29,000, LTP = 2,945.50, Current = 29,455, P&L = +455
      });

      const res = await request(app)
        .get('/api/v1/portfolio')
        .set('Authorization', `Bearer ${token1}`);

      expect(res.status).toBe(200);
      expect(res.body.portfolio.availableCash).toBe(1000000);
      expect(res.body.portfolio.holdings.length).toBe(1);
      expect(res.body.portfolio.holdings[0].symbol).toBe('RELIANCE');
      expect(res.body.portfolio.holdings[0].unrealizedPnl).toBe(455);
      expect(res.body.portfolio.isSimulated).toBe(true);
    });
  });

  describe('Watchlists CRUD', () => {
    it('should list default watchlist and allow creating custom watchlists', async () => {
      const listRes = await request(app)
        .get('/api/v1/watchlists')
        .set('Authorization', `Bearer ${token1}`);

      expect(listRes.status).toBe(200);
      expect(listRes.body.watchlists.length).toBe(1);
      expect(listRes.body.watchlists[0].name).toBe('Default Watchlist');

      // Create Custom Watchlist
      const createRes = await request(app)
        .post('/api/v1/watchlists')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Tech Stocks',
          instruments: ['TCS', 'INFY'],
        });

      expect(createRes.status).toBe(201);
      expect(createRes.body.watchlist.name).toBe('Tech Stocks');
      const customId = createRes.body.watchlist.id;

      // Add symbol
      const addRes = await request(app)
        .post(`/api/v1/watchlists/${customId}/symbols`)
        .set('Authorization', `Bearer ${token1}`)
        .send({ symbol: 'WIPRO' });

      expect(addRes.status).toBe(200);
      expect(addRes.body.watchlist.instruments).toContain('WIPRO');

      // User 2 cannot delete User 1 watchlist (Ownership check)
      const unauthDelete = await request(app)
        .delete(`/api/v1/watchlists/${customId}`)
        .set('Authorization', `Bearer ${token2}`);

      expect(unauthDelete.status).toBe(404);

      // User 1 can delete custom watchlist
      const deleteRes = await request(app)
        .delete(`/api/v1/watchlists/${customId}`)
        .set('Authorization', `Bearer ${token1}`);

      expect(deleteRes.status).toBe(200);
    });
  });
});
