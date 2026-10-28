import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, RefreshSession, PaperAccount, Watchlist } from '../src/models';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_auth';

describe('Auth & User Registration Integration Tests', () => {
  const app = createApp();

  beforeAll(async () => {
    await mongoose.connect(TEST_DB_URI);
  });

  afterAll(async () => {
    await User.deleteMany({});
    await RefreshSession.deleteMany({});
    await PaperAccount.deleteMany({});
    await Watchlist.deleteMany({});
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    await User.deleteMany({});
    await RefreshSession.deleteMany({});
    await PaperAccount.deleteMany({});
    await Watchlist.deleteMany({});
  });

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user, create paper account, and return tokens', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'trader1@tradeverse.ai',
          password: 'Password123!',
          displayName: 'Arjun Trader',
          startingCapital: 1000000,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user.email).toBe('trader1@tradeverse.ai');
      expect(res.body.user.displayName).toBe('Arjun Trader');

      // Verify DB persistence
      const user = await User.findOne({ email: 'trader1@tradeverse.ai' });
      expect(user).not.toBeNull();
      expect(user?.passwordHash).not.toBe('Password123!'); // Hashed

      // Verify paper account was automatically created
      const paperAccount = await PaperAccount.findOne({ userId: user?._id });
      expect(paperAccount).not.toBeNull();
      expect(paperAccount?.availableCash).toBe(1000000);
      expect(paperAccount?.isSimulated).toBe(true);

      // Verify default watchlist
      const watchlist = await Watchlist.findOne({ userId: user?._id });
      expect(watchlist).not.toBeNull();
      expect(watchlist?.name).toBe('Default Watchlist');
    });

    it('should reject registration if email already exists', async () => {
      await request(app).post('/api/v1/auth/register').send({
        email: 'duplicate@tradeverse.ai',
        password: 'Password123!',
        displayName: 'User One',
      });

      const res = await request(app).post('/api/v1/auth/register').send({
        email: 'duplicate@tradeverse.ai',
        password: 'Password456!',
        displayName: 'User Two',
      });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
    });

    it('should reject registration with invalid password or email format', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        email: 'not-an-email',
        password: 'short',
        displayName: 'A',
      });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.errors).toBeDefined();
    });
  });

  describe('POST /api/v1/auth/login', () => {
    beforeEach(async () => {
      await request(app).post('/api/v1/auth/register').send({
        email: 'login_test@tradeverse.ai',
        password: 'SecretPassword99!',
        displayName: 'Login User',
      });
    });

    it('should successfully login and return tokens', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'login_test@tradeverse.ai',
        password: 'SecretPassword99!',
      });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user.email).toBe('login_test@tradeverse.ai');
    });

    it('should fail with 401 when password is wrong', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'login_test@tradeverse.ai',
        password: 'WrongPassword!',
      });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Invalid email or password.');
    });

    it('should fail with 401 when email does not exist', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'nonexistent@tradeverse.ai',
        password: 'AnyPassword!',
      });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toBe('Invalid email or password.');
    });
  });

  describe('Token Refresh and Session Lifecycle', () => {
    it('should rotate refresh token and revoke prior session', async () => {
      const reg = await request(app).post('/api/v1/auth/register').send({
        email: 'refresh_test@tradeverse.ai',
        password: 'Password123!',
        displayName: 'Refresher',
      });

      const initialRefresh = reg.body.refreshToken;

      // Refresh
      const refreshRes = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: initialRefresh,
      });

      expect(refreshRes.status).toBe(200);
      expect(refreshRes.body.accessToken).toBeDefined();
      expect(refreshRes.body.refreshToken).toBeDefined();
      expect(refreshRes.body.refreshToken).not.toBe(initialRefresh); // Rotated

      // Old refresh token must be rejected
      const retryOld = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: initialRefresh,
      });
      expect(retryOld.status).toBe(401);
    });

    it('should revoke session on logout', async () => {
      const reg = await request(app).post('/api/v1/auth/register').send({
        email: 'logout_test@tradeverse.ai',
        password: 'Password123!',
        displayName: 'Logouter',
      });

      const refreshToken = reg.body.refreshToken;

      const logoutRes = await request(app).post('/api/v1/auth/logout').send({
        refreshToken,
      });
      expect(logoutRes.status).toBe(200);

      // Attempting to refresh with logged-out token should fail
      const refreshRes = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken,
      });
      expect(refreshRes.status).toBe(401);
    });
  });

  describe('GET /api/v1/auth/me', () => {
    it('should return 401 when unauthenticated', async () => {
      const res = await request(app).get('/api/v1/auth/me');
      expect(res.status).toBe(401);
    });

    it('should return user profile when authenticated with valid Bearer token', async () => {
      const reg = await request(app).post('/api/v1/auth/register').send({
        email: 'me_test@tradeverse.ai',
        password: 'Password123!',
        displayName: 'Me User',
      });

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${reg.body.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user.email).toBe('me_test@tradeverse.ai');
      expect(res.body.user.displayName).toBe('Me User');
    });
  });
});
