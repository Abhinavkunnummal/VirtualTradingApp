import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, PaperAccount, Order, Notification } from '../src/models';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_news_notifs';

describe('News Feeds & In-App Notifications Integration Tests', () => {
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
    await Notification.deleteMany({});
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    await User.deleteMany({});
    await PaperAccount.deleteMany({});
    await Order.deleteMany({});
    await Notification.deleteMany({});

    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'notif_tester@tradeverse.ai',
      password: 'Password123!',
      displayName: 'Notification Tester',
      startingCapital: 1000000,
    });
    token = reg.body.accessToken;
    userId = reg.body.user.id;
  });

  describe('News Endpoints', () => {
    it('GET /api/v1/news should return curated financial articles with sentiment', async () => {
      const res = await request(app).get('/api/v1/news');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.articles)).toBe(true);
      expect(res.body.articles.length).toBeGreaterThan(0);

      const first = res.body.articles[0];
      expect(first).toHaveProperty('id');
      expect(first).toHaveProperty('title');
      expect(first).toHaveProperty('category');
      expect(first).toHaveProperty('sentiment');
      expect(first).toHaveProperty('sentimentScore');
      expect(first).toHaveProperty('relatedSymbols');
    });

    it('GET /api/v1/news?category=CRYPTO should filter articles by crypto category', async () => {
      const res = await request(app).get('/api/v1/news?category=CRYPTO');

      expect(res.status).toBe(200);
      expect(res.body.articles.every((a: any) => a.category === 'CRYPTO')).toBe(true);
    });

    it('GET /api/v1/news?symbol=RELIANCE should filter articles related to RELIANCE', async () => {
      const res = await request(app).get('/api/v1/news?symbol=RELIANCE');

      expect(res.status).toBe(200);
      expect(res.body.articles.length).toBeGreaterThan(0);
      expect(res.body.articles.every((a: any) => a.relatedSymbols.includes('RELIANCE'))).toBe(true);
    });

    it('GET /api/v1/news/:id should return single article by id', async () => {
      const listRes = await request(app).get('/api/v1/news');
      const articleId = listRes.body.articles[0].id;

      const singleRes = await request(app).get(`/api/v1/news/${articleId}`);
      expect(singleRes.status).toBe(200);
      expect(singleRes.body.article.id).toBe(articleId);
    });
  });

  describe('Notification Endpoints', () => {
    it('should create notification on order execution and retrieve via GET /api/v1/notifications', async () => {
      // Execute a paper order
      await request(app)
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${token}`)
        .send({
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 2,
        });

      // Fetch notifications
      const notifsRes = await request(app)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${token}`);

      expect(notifsRes.status).toBe(200);
      expect(notifsRes.body.notifications.length).toBeGreaterThanOrEqual(1);
      expect(notifsRes.body.unreadCount).toBeGreaterThanOrEqual(1);

      const notif = notifsRes.body.notifications[0];
      expect(notif.read).toBe(false);
      expect(notif.type).toBe('ORDER_FILL');
    });

    it('PATCH /api/v1/notifications/:id/read should mark a single notification as read', async () => {
      const n = await Notification.create({
        userId,
        title: 'Test Notification',
        message: 'This is a test notification message.',
        type: 'ORDER_FILL',
        read: false,
      });

      const patchRes = await request(app)
        .patch(`/api/v1/notifications/${n._id}/read`)
        .set('Authorization', `Bearer ${token}`);

      expect(patchRes.status).toBe(200);

      const refreshed = await Notification.findById(n._id);
      expect(refreshed?.read).toBe(true);
    });

    it('POST /api/v1/notifications/read-all should mark all notifications as read', async () => {
      await Notification.create([
        { userId, title: 'Notif 1', message: 'Msg 1', type: 'ORDER_FILL', read: false },
        { userId, title: 'Notif 2', message: 'Msg 2', type: 'MARKET_ALERT', read: false },
      ]);

      const countBefore = await Notification.countDocuments({ userId, read: false });
      expect(countBefore).toBe(2);

      const res = await request(app)
        .post('/api/v1/notifications/read-all')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);

      const countAfter = await Notification.countDocuments({ userId, read: false });
      expect(countAfter).toBe(0);
    });
  });
});
