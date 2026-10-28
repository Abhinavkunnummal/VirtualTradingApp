import request from 'supertest';
import { createApp } from '../src/app';

describe('Health and API Base Endpoints', () => {
  const app = createApp();

  it('GET /health should return 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.version).toBe('1.0.0');
    expect(res.body.services.paperEngine).toBe('active');
  });

  it('GET /api/v1/status should return 200 with online status', async () => {
    const res = await request(app).get('/api/v1/status');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('online');
  });
});
