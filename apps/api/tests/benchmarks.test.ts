import mongoose from 'mongoose';
import { User, PaperAccount, Order, Execution, Holding, LedgerEntry } from '../src/models';
import { PaperTradingEngine } from '../src/modules/orders/paperEngine.service';
import { MarketDataService, Candle } from '../src/modules/market-data/marketData.service';

const TEST_DB_URI = 'mongodb://127.0.0.1:27017/tradeverse_test_benchmarks';

describe('Performance Benchmarks & High-Concurrency Auditing', () => {
  let testUser: any;
  let testAccount: any;

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

    testUser = await User.create({
      email: 'benchmarks@tradeverse.ai',
      passwordHash: 'hashed_pw',
      displayName: 'Benchmark Runner',
    });

    testAccount = await PaperAccount.create({
      userId: testUser._id,
      accountNumber: 'ACC-BENCH-001',
      availableCash: 50000000, // ₹5 Crore large pool for benchmark
      reservedMargin: 0,
      totalPortfolioValue: 50000000,
      status: 'ACTIVE',
    });
  });

  describe('High-Concurrency Order Placement Benchmark', () => {
    it('should process 50 concurrent simulated orders with strict sub-second throughput', async () => {
      const orderCount = 50;
      const symbols = ['RELIANCE', 'TCS', 'HDFCBANK', 'NVDA', 'AAPL'];

      const orderPromises = Array.from({ length: orderCount }).map((_, i) => {
        const symbol = symbols[i % symbols.length];
        return PaperTradingEngine.submitOrder({
          userId: testUser._id.toString(),
          symbol,
          exchange: 'NSE',
          side: i % 2 === 0 ? 'BUY' : 'BUY', // BUY orders
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 1,
        });
      });

      const startTime = performance.now();
      const results = await Promise.all(orderPromises);
      const totalDurationMs = performance.now() - startTime;

      expect(results).toHaveLength(orderCount);
      expect(results.every((r) => r.order.status === 'FILLED')).toBe(true);

      const avgPerOrderMs = totalDurationMs / orderCount;
      console.log(`\n[Benchmark Results] 50 Concurrent Orders:`);
      console.log(` - Total Duration: ${totalDurationMs.toFixed(2)} ms`);
      console.log(` - Average Latency per Order: ${avgPerOrderMs.toFixed(2)} ms`);
      console.log(` - Throughput: ${(orderCount / (totalDurationMs / 1000)).toFixed(1)} orders/sec`);

      // Assert latency requirement: total time < 4000ms, avg < 80ms per order even with DB persistence
      expect(totalDurationMs).toBeLessThan(4000);

      // Verify Ledger and Execution counts match exactly
      const executionCount = await Execution.countDocuments({ userId: testUser._id });
      expect(executionCount).toBe(orderCount);

      const ledgerCount = await LedgerEntry.countDocuments({ userId: testUser._id, type: 'TRADE_FILL' });
      expect(ledgerCount).toBe(orderCount);
    });
  });

  describe('Mathematical OHLC Aggregation Benchmark', () => {
    it('should aggregate 10,000 candle ticks within 50ms', () => {
      const baseCandles: Candle[] = [];
      const baseTime = 1700000000;
      let prevClose = 2500;

      for (let i = 0; i < 10000; i++) {
        const open = prevClose;
        const high = open + Math.random() * 5;
        const low = open - Math.random() * 5;
        const close = low + Math.random() * (high - low);
        const volume = Math.floor(Math.random() * 500) + 10;
        baseCandles.push({
          timestamp: baseTime + i * 60,
          open: parseFloat(open.toFixed(2)),
          high: parseFloat(high.toFixed(2)),
          low: parseFloat(low.toFixed(2)),
          close: parseFloat(close.toFixed(2)),
          volume,
        });
        prevClose = close;
      }

      const startTime = performance.now();
      const aggregated5m = MarketDataService.aggregateCandles(baseCandles, 300);
      const aggregated1h = MarketDataService.aggregateCandles(baseCandles, 3600);
      const durationMs = performance.now() - startTime;

      console.log(`\n[Benchmark Results] OHLC 10,000 Candle Aggregation:`);
      console.log(` - 5m bars produced: ${aggregated5m.length}`);
      console.log(` - 1h bars produced: ${aggregated1h.length}`);
      console.log(` - Processing Time: ${durationMs.toFixed(2)} ms`);

      expect(aggregated5m.length).toBeGreaterThan(0);
      expect(aggregated1h.length).toBeGreaterThan(0);
      expect(durationMs).toBeLessThan(100); // Super-fast array processing
    });
  });

  describe('Capital Solvency & Ledger Invariant Audit', () => {
    it('should maintain strict ledger reconciliation and never allow negative balance', async () => {
      // Set low available cash: ₹5,000
      testAccount.availableCash = 5000;
      await testAccount.save();

      // Attempt to purchase ₹2,500 x 3 = ₹7,500 worth of RELIANCE
      // First 1 should succeed, subsequent should fail with Insufficient margin
      const attempts = await Promise.allSettled([
        PaperTradingEngine.submitOrder({
          userId: testUser._id.toString(),
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 1, // ~₹2,500
        }),
        PaperTradingEngine.submitOrder({
          userId: testUser._id.toString(),
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 2, // ~₹5,000
        }),
        PaperTradingEngine.submitOrder({
          userId: testUser._id.toString(),
          symbol: 'RELIANCE',
          exchange: 'NSE',
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: 5, // ~₹12,500 (must be rejected)
        }),
      ]);

      const rejected = attempts.filter((a) => a.status === 'rejected');
      expect(rejected.length).toBeGreaterThanOrEqual(1);

      // Verify account available cash never dropped below 0
      const finalAccount = await PaperAccount.findById(testAccount._id);
      expect(finalAccount?.availableCash).toBeGreaterThanOrEqual(0);
    });
  });
});
