import request from 'supertest';
import { createApp } from '../src/app';
import {
  RateLimitBudgetGuard,
  getIntervalSeconds,
  getIntervalStartTime,
  aggregateCandleTick,
  toBinanceSymbol,
  toBinanceStream,
  ChartStreamService,
  ChartCandle,
} from '../src/modules/market-data/chartStream.service';
import { SocketService } from '../src/services/socket.service';

describe('Chart Candles REST & Streaming Unit Tests', () => {
  const app = createApp();

  beforeEach(() => {
    ChartStreamService.resetForTesting();
  });

  afterAll(() => {
    ChartStreamService.resetForTesting();
  });

  describe('RateLimitBudgetGuard', () => {
    it('should allow up to maxPerMinute requests and reject subsequent ones', () => {
      const guard = new RateLimitBudgetGuard(5, 100);
      const now = Date.now();

      for (let i = 0; i < 5; i++) {
        expect(guard.canRequest(now)).toBe(true);
        expect(guard.recordRequest(now)).toBe(true);
      }

      // 6th request within the same minute should be rejected
      expect(guard.canRequest(now)).toBe(false);
      expect(guard.recordRequest(now)).toBe(false);
      expect(guard.getStatus(now).isBudgetExhausted).toBe(true);
    });

    it('should reset minute quota after 60 seconds have elapsed', () => {
      const guard = new RateLimitBudgetGuard(5, 100);
      const t0 = 1700000000000;

      for (let i = 0; i < 5; i++) {
        guard.recordRequest(t0);
      }
      expect(guard.canRequest(t0)).toBe(false);

      // 61 seconds later
      const t1 = t0 + 61000;
      expect(guard.canRequest(t1)).toBe(true);
      expect(guard.recordRequest(t1)).toBe(true);
      expect(guard.getStatus(t1).minuteUsed).toBe(1);
    });

    it('should respect daily limit budget guard', () => {
      const guard = new RateLimitBudgetGuard(50, 3);
      const now = Date.now();

      expect(guard.recordRequest(now)).toBe(true);
      expect(guard.recordRequest(now)).toBe(true);
      expect(guard.recordRequest(now)).toBe(true);

      // Exceeded daily limit
      expect(guard.canRequest(now)).toBe(false);
      expect(guard.recordRequest(now)).toBe(false);
      expect(guard.getStatus(now).dayUsed).toBe(3);
    });
  });

  describe('Candle Interval and Aggregation Logic', () => {
    it('should correctly calculate interval durations in seconds', () => {
      expect(getIntervalSeconds('1m')).toBe(60);
      expect(getIntervalSeconds('5m')).toBe(300);
      expect(getIntervalSeconds('15m')).toBe(900);
      expect(getIntervalSeconds('1h')).toBe(3600);
      expect(getIntervalSeconds('1d')).toBe(86400);
    });

    it('should align timestamps into correct interval bucket start times', () => {
      // 1700000040 is a multiple of 60 (1700000040 % 60 === 0)
      // 1700000075 falls in the minute bucket [1700000040, 1700000100)
      expect(getIntervalStartTime(1700000075, '1m')).toBe(1700000040);
      expect(getIntervalStartTime(1700000075, '1m') % 60).toBe(0);
      expect(getIntervalStartTime(1700000075, '5m') % 300).toBe(0);
      expect(getIntervalStartTime(1700000075, '15m') % 900).toBe(0);
      expect(getIntervalStartTime(1700000075, '1h') % 3600).toBe(0);
    });

    it('should initialize a candle on first tick', () => {
      const nowSec = 1700000010;
      const result = aggregateCandleTick(null, 100, 5, nowSec, '1m');

      expect(result.isNewCandle).toBe(false);
      expect(result.candle.open).toBe(100);
      expect(result.candle.high).toBe(100);
      expect(result.candle.low).toBe(100);
      expect(result.candle.close).toBe(100);
      expect(result.candle.volume).toBe(5);
      expect(result.candle.time).toBe(getIntervalStartTime(nowSec, '1m'));
    });

    it('should update forming candle in-place when ticks arrive within same interval', () => {
      // 1700000040 is an exact minute boundary
      const t0 = 1700000040;
      let { candle } = aggregateCandleTick(null, 100, 10, t0, '1m');

      // Tick 2: price rises to 105 at t0 + 10s (still within [1700000040, 1700000100))
      const tick2 = aggregateCandleTick(candle, 105, 5, t0 + 10, '1m');
      expect(tick2.isNewCandle).toBe(false);
      expect(tick2.candle.open).toBe(100);
      expect(tick2.candle.high).toBe(105);
      expect(tick2.candle.low).toBe(100);
      expect(tick2.candle.close).toBe(105);
      expect(tick2.candle.volume).toBe(15);

      // Tick 3: price dips to 95 at t0 + 20s (still within [1700000040, 1700000100))
      const tick3 = aggregateCandleTick(tick2.candle, 95, 8, t0 + 20, '1m');
      expect(tick3.isNewCandle).toBe(false);
      expect(tick3.candle.open).toBe(100);
      expect(tick3.candle.high).toBe(105);
      expect(tick3.candle.low).toBe(95);
      expect(tick3.candle.close).toBe(95);
      expect(tick3.candle.volume).toBe(23);
    });

    it('should roll over and emit new candle when interval advances', () => {
      // 1700000040 is an exact minute boundary
      const t0 = 1700000040;
      const { candle } = aggregateCandleTick(null, 100, 10, t0, '1m');

      // 65 seconds later (1700000105) -> next minute interval [1700000100, 1700000160)
      const tNext = t0 + 65;
      const nextResult = aggregateCandleTick(candle, 110, 4, tNext, '1m');

      expect(nextResult.isNewCandle).toBe(true);
      expect(nextResult.candle.time).toBe(getIntervalStartTime(tNext, '1m'));
      expect(nextResult.candle.time).toBe(1700000100);
      expect(nextResult.candle.time).toBeGreaterThan(candle.time);
      expect(nextResult.candle.open).toBe(110);
      expect(nextResult.candle.high).toBe(110);
      expect(nextResult.candle.low).toBe(110);
      expect(nextResult.candle.close).toBe(110);
      expect(nextResult.candle.volume).toBe(4);
    });
  });

  describe('Binance Stream and Symbol Mapping Helpers', () => {
    it('should map various crypto symbol formats to Binance lowercase pair', () => {
      expect(toBinanceSymbol('BTC/USDT')).toBe('btcusdt');
      expect(toBinanceSymbol('btc/usdt')).toBe('btcusdt');
      expect(toBinanceSymbol('BTC')).toBe('btcusdt');
      expect(toBinanceSymbol('ETH/USDT')).toBe('ethusdt');
      expect(toBinanceSymbol('SOL/USDT')).toBe('solusdt');
    });

    it('should format stream name matching Binance Kline WebSocket specification', () => {
      expect(toBinanceStream('BTC/USDT', '1m')).toBe('btcusdt@kline_1m');
      expect(toBinanceStream('ETH', '15m')).toBe('ethusdt@kline_15m');
      expect(toBinanceStream('SOL/USDT', '1h')).toBe('solusdt@kline_1h');
    });
  });

  describe('ChartStreamService Room Lifecycle & Event Handling', () => {
    function createMockSocket(id: string) {
      const rooms = new Set<string>();
      const emitted: Array<{ event: string; data: any }> = [];

      return {
        id,
        join: jest.fn((r: string) => rooms.add(r)),
        leave: jest.fn((r: string) => rooms.delete(r)),
        emit: jest.fn((event: string, data: any) => emitted.push({ event, data })),
        rooms,
        emitted,
      } as any;
    }

    it('should manage room subscriptions and unsubscriptions cleanly', () => {
      const socket1 = createMockSocket('sock-1');
      const socket2 = createMockSocket('sock-2');

      // Socket 1 subscribes to BTC/USDT 1m
      ChartStreamService.handleSubscribe(socket1, { symbol: 'BTC/USDT', interval: '1m' });
      expect(socket1.join).toHaveBeenCalledWith('chart:BTC/USDT:1m');
      expect(ChartStreamService.getSubscriberCount('chart:BTC/USDT:1m')).toBe(1);

      // Socket 2 subscribes to same room
      ChartStreamService.handleSubscribe(socket2, { symbol: 'BTC/USDT', interval: '1m' });
      expect(ChartStreamService.getSubscriberCount('chart:BTC/USDT:1m')).toBe(2);

      // Socket 1 unsubscribes
      ChartStreamService.handleUnsubscribe(socket1, { symbol: 'BTC/USDT', interval: '1m' });
      expect(socket1.leave).toHaveBeenCalledWith('chart:BTC/USDT:1m');
      expect(ChartStreamService.getSubscriberCount('chart:BTC/USDT:1m')).toBe(1);

      // Socket 2 disconnects -> room becomes empty
      ChartStreamService.handleDisconnect(socket2);
      expect(ChartStreamService.getSubscriberCount('chart:BTC/USDT:1m')).toBe(0);
    });

    it('should process Binance kline message and route to subscribed rooms', () => {
      const socket = createMockSocket('sock-kline');
      ChartStreamService.handleSubscribe(socket, { symbol: 'BTC/USDT', interval: '1m' });

      // Mock mock IO emitToRoom
      const emitSpy = jest.fn();
      jest.spyOn(SocketService, 'getIO').mockReturnValue({
        to: jest.fn().mockReturnValue({ emit: emitSpy }),
      } as any);

      // Simulate incoming Binance kline
      const klineEvent = {
        e: 'kline',
        s: 'BTCUSDT',
        k: {
          t: 1700000000000,
          o: '77500.00',
          h: '77650.00',
          l: '77480.00',
          c: '77600.00',
          v: '35.42',
          i: '1m',
          x: false,
        },
      };

      ChartStreamService.processBinanceMessage(klineEvent);

      expect(emitSpy).toHaveBeenCalledWith('chart:tick', {
        symbol: 'BTC/USDT',
        interval: '1m',
        time: 1700000000,
        open: 77500,
        high: 77650,
        low: 77480,
        close: 77600,
        volume: 35.42,
        delayed: false,
      });

      const forming = ChartStreamService.getFormingCandle('BTC/USDT', '1m');
      expect(forming).toBeDefined();
      expect(forming?.close).toBe(77600);
    });
  });

  describe('REST Endpoint: GET /api/market/candles', () => {
    it('should return 200 with sorted ascending candles for valid query', async () => {
      const res = await request(app).get('/api/market/candles?symbol=BTC/USDT&interval=15m&limit=10');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.symbol).toBe('BTC/USDT');
      expect(Array.isArray(res.body.candles)).toBe(true);
      expect(res.body.candles.length).toBeGreaterThan(0);

      // Validate lightweight-charts structure: time in seconds, open, high, low, close
      const first = res.body.candles[0];
      expect(typeof first.time).toBe('number');
      expect(typeof first.open).toBe('number');
      expect(typeof first.high).toBe('number');
      expect(typeof first.low).toBe('number');
      expect(typeof first.close).toBe('number');

      // Verify sorted ascending
      for (let i = 1; i < res.body.candles.length; i++) {
        expect(res.body.candles[i].time).toBeGreaterThanOrEqual(res.body.candles[i - 1].time);
      }
    });

    it('should support non-crypto equities (e.g. RELIANCE)', async () => {
      const res = await request(app).get('/api/market/candles?symbol=RELIANCE&interval=15m&limit=5');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.candles.length).toBeGreaterThanOrEqual(1);
    });

    it('should reject requests missing symbol with 400', async () => {
      const res = await request(app).get('/api/market/candles');
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.message).toMatch(/symbol/i);
    });

    it('should reject invalid intervals with 400', async () => {
      const res = await request(app).get('/api/market/candles?symbol=BTC&interval=999xyz');
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
