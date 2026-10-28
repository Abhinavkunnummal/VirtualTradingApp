import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { User, CommunityRoom, CommunityMessage } from '../src/models';
import { AuthService } from '../src/services/auth.service';

const app = createApp();

describe('Phase 7: Community & Discussion Rooms Integration Tests', () => {
  let user1Token: string;
  let user1Id: string;
  let user2Token: string;
  let user2Id: string;
  let testRoomId = 'room:general';

  beforeAll(async () => {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/tradeverse_test';
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(mongoUri);
    }

    await User.deleteMany({ email: { $in: ['comm_user1@example.com', 'comm_user2@example.com'] } });
    await CommunityMessage.deleteMany({});

    // Register User 1
    const reg1 = await AuthService.registerUser({
      email: 'comm_user1@example.com',
      password: 'StrongPassword123!',
      displayName: 'Trader Vikram',
      startingCapital: 1000000,
    });
    user1Token = reg1.accessToken;
    user1Id = reg1.user.id;

    // Register User 2
    const reg2 = await AuthService.registerUser({
      email: 'comm_user2@example.com',
      password: 'StrongPassword123!',
      displayName: 'Quant Priya',
      startingCapital: 1000000,
    });
    user2Token = reg2.accessToken;
    user2Id = reg2.user.id;
  });

  afterAll(async () => {
    await User.deleteMany({ email: { $in: ['comm_user1@example.com', 'comm_user2@example.com'] } });
    await CommunityMessage.deleteMany({});
    await mongoose.disconnect();
  });

  describe('GET /api/v1/community/rooms', () => {
    it('seeds and returns default discussion rooms', async () => {
      const res = await request(app).get('/api/v1/community/rooms');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.rooms.length).toBeGreaterThanOrEqual(4);

      const roomIds = res.body.rooms.map((r: any) => r.roomId);
      expect(roomIds).toContain('room:general');
      expect(roomIds).toContain('room:nifty');
      expect(roomIds).toContain('room:crypto');
    });
  });

  describe('POST /api/v1/community/rooms/:roomId/messages', () => {
    it('rejects unauthenticated message posting', async () => {
      const res = await request(app)
        .post(`/api/v1/community/rooms/${testRoomId}/messages`)
        .send({ content: 'Unauthenticated message' });

      expect(res.status).toBe(401);
    });

    it('allows authenticated user to post message with trade tag and sentiment', async () => {
      const res = await request(app)
        .post(`/api/v1/community/rooms/${testRoomId}/messages`)
        .set('Authorization', `Bearer ${user1Token}`)
        .send({
          content: 'RELIANCE closed above 20 EMA with expanding volume. Looking for continuation toward ₹3020.',
          type: 'EDUCATIONAL',
          tradeTag: 'PAPER BUY • RELIANCE',
          sentiment: 'BULLISH',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.content).toContain('RELIANCE closed above 20 EMA');
      expect(res.body.data.authorName).toBe('Trader Vikram');
      expect(res.body.data.sentiment).toBe('BULLISH');
      expect(res.body.data.tradeTag).toBe('PAPER BUY • RELIANCE');
    });

    it('sanitizes malicious script tags in message content', async () => {
      const res = await request(app)
        .post(`/api/v1/community/rooms/${testRoomId}/messages`)
        .set('Authorization', `Bearer ${user2Token}`)
        .send({
          content: 'Test content <script>alert("xss")</script> valid text',
          type: 'CHAT',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.content).not.toContain('<script>');
      expect(res.body.data.content).toContain('valid text');
    });
  });

  describe('GET /api/v1/community/rooms/:roomId/messages', () => {
    it('retrieves paginated message history for a room in chronological order', async () => {
      const res = await request(app)
        .get(`/api/v1/community/rooms/${testRoomId}/messages?limit=10`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.messages.length).toBeGreaterThanOrEqual(2);
      expect(res.body.roomId).toBe(testRoomId);
    });
  });

  describe('DELETE /api/v1/community/messages/:id (Ownership Enforcement)', () => {
    let createdMsgId: string;

    beforeEach(async () => {
      const msg = await CommunityMessage.create({
        roomId: testRoomId,
        userId: new mongoose.Types.ObjectId(user1Id),
        authorName: 'Trader Vikram',
        content: 'Temporary message to delete',
        type: 'CHAT',
      });
      createdMsgId = msg._id.toString();
    });

    it('prevents another user from deleting messages they do not own', async () => {
      const res = await request(app)
        .delete(`/api/v1/community/messages/${createdMsgId}`)
        .set('Authorization', `Bearer ${user2Token}`);

      expect(res.status).toBe(403);
      expect(res.body.message).toContain('Unauthorized');
    });

    it('allows author to delete their own message', async () => {
      const res = await request(app)
        .delete(`/api/v1/community/messages/${createdMsgId}`)
        .set('Authorization', `Bearer ${user1Token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const check = await CommunityMessage.findById(createdMsgId);
      expect(check).toBeNull();
    });
  });
});
