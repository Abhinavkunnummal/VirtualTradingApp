import request from 'supertest';
import { createApp } from '../src/app';
import { validateEnvironment } from '../src/config';

describe('Health and API Base Endpoints', () => {
  const app = createApp();

  it('GET /health should return 200 with healthy status, database and provider telemetry', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body.version).toBe('1.0.0');
    expect(res.body.database).toBeDefined();
    expect(res.body.database.status).toBeDefined();
    expect(res.body.providers).toBeDefined();
    expect(res.body.providers.binance).toBe('connected');
    expect(res.body.providers.angelOne).toBeDefined();
    expect(res.body.providers.finnhub).toBeDefined();
    expect(res.body.services.paperEngine).toBe('active');
  });

  it('GET /api/v1/status should return 200 with online status', async () => {
    const res = await request(app).get('/api/v1/status');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('online');
  });

  it('validateEnvironment should return valid report and never leak secrets', () => {
    const report = validateEnvironment();
    expect(report.isValid).toBe(true);
    expect(Array.isArray(report.missing)).toBe(true);
    expect(Array.isArray(report.warnings)).toBe(true);
  });
});
