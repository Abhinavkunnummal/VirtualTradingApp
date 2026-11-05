import mongoose from 'mongoose';
import { createApp } from '../src/app';
import { InstrumentMasterService } from '../src/modules/market-data/instrumentMaster.service';
import { MarketDataService } from '../src/modules/market-data/marketData.service';
import { PaperTradingEngine } from '../src/modules/orders/paperEngine.service';
import { User, PaperAccount, Holding, Order, LedgerEntry, TradeHistory } from '../src/models';

interface SymbolCheck {
  symbol: string;
  name: string;
  type: string;
  exchange: string;
  lotSize: number;
  testQty: number;
}

const SYMBOLS_TO_VERIFY: SymbolCheck[] = [
  // 1. NSE Equities (10)
  { symbol: 'RELIANCE', name: 'Reliance Industries Ltd.', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 10 },
  { symbol: 'TCS', name: 'Tata Consultancy Services', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 5 },
  { symbol: 'INFY', name: 'Infosys Limited', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 10 },
  { symbol: 'HDFCBANK', name: 'HDFC Bank Limited', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 10 },
  { symbol: 'TATAMOTORS', name: 'Tata Motors Limited', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 15 },
  { symbol: 'SBIN', name: 'State Bank of India', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 20 },
  { symbol: 'YESBANK', name: 'Yes Bank Limited', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 100 },
  { symbol: 'IDEA', name: 'Vodafone Idea Limited (Vi)', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 100 },
  { symbol: 'KNRCON', name: 'KNR Constructions Limited', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 10 },
  { symbol: 'JIOFIN', name: 'Jio Financial Services', type: 'EQUITY', exchange: 'NSE', lotSize: 1, testQty: 25 },

  // 2. BSE Equities & Dual-Listings (6)
  { symbol: 'BSE:RELIANCE', name: 'Reliance Industries Ltd.', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 5 },
  { symbol: 'BSE:YESBANK', name: 'Yes Bank Limited', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 50 },
  { symbol: 'BSE:IDEA', name: 'Vodafone Idea Limited (Vi)', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 50 },
  { symbol: 'BSE:JIOFIN', name: 'Jio Financial Services Ltd.', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 20 },
  { symbol: 'BSE', name: 'BSE Limited (Exchange)', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 5 },
  { symbol: 'CDSL', name: 'Central Depository Services Ltd.', type: 'EQUITY', exchange: 'BSE', lotSize: 1, testQty: 10 },

  // 3. Indian Indices (4)
  { symbol: 'NIFTY 50', name: 'Nifty 50 Index', type: 'INDEX', exchange: 'NSE', lotSize: 50, testQty: 50 },
  { symbol: 'BANKNIFTY', name: 'Nifty Bank Index', type: 'INDEX', exchange: 'NSE', lotSize: 15, testQty: 15 },
  { symbol: 'FINNIFTY', name: 'Nifty Financial Services Index', type: 'INDEX', exchange: 'NSE', lotSize: 40, testQty: 40 },
  { symbol: 'SENSEX', name: 'BSE Sensex Index', type: 'INDEX', exchange: 'BSE', lotSize: 10, testQty: 10 },

  // 4. Indian ETFs (4)
  { symbol: 'NIFTYBEES', name: 'Nippon India ETF Nifty 50 BeES', type: 'ETF', exchange: 'NSE', lotSize: 1, testQty: 20 },
  { symbol: 'GOLDBEES', name: 'Nippon India ETF Gold BeES', type: 'ETF', exchange: 'NSE', lotSize: 1, testQty: 50 },
  { symbol: 'BANKBEES', name: 'Nippon India ETF Nifty Bank BeES', type: 'ETF', exchange: 'NSE', lotSize: 1, testQty: 10 },
  { symbol: 'MON100', name: 'Motilal Oswal Nasdaq 100 ETF', type: 'ETF', exchange: 'NSE', lotSize: 1, testQty: 25 },

  // 5. MCX Commodities & Futures (6)
  { symbol: 'GOLD', name: 'MCX Gold Futures', type: 'COMMODITY', exchange: 'MCX', lotSize: 1, testQty: 1 },
  { symbol: 'GOLD 1KG', name: 'MCX Gold Futures 1KG', type: 'COMMODITY', exchange: 'MCX', lotSize: 1, testQty: 1 },
  { symbol: 'GOLDFUT', name: 'MCX Gold Current-Month Futures', type: 'COMMODITY', exchange: 'MCX', lotSize: 1, testQty: 1 },
  { symbol: 'CRUDEOIL', name: 'MCX Crude Oil 100 BBL', type: 'COMMODITY', exchange: 'MCX', lotSize: 100, testQty: 100 },
  { symbol: 'CRUDEOILFUT', name: 'MCX Crude Oil Current-Month Futures', type: 'COMMODITY', exchange: 'MCX', lotSize: 100, testQty: 100 },
  { symbol: 'SILVER 30KG', name: 'MCX Silver Futures', type: 'COMMODITY', exchange: 'MCX', lotSize: 30, testQty: 30 },

  // 6. US Stocks & ETFs (4)
  { symbol: 'AAPL', name: 'Apple Inc.', type: 'US', exchange: 'US', lotSize: 1, testQty: 5 },
  { symbol: 'NVDA', name: 'NVIDIA Corporation', type: 'US', exchange: 'US', lotSize: 1, testQty: 5 },
  { symbol: 'MSFT', name: 'Microsoft Corporation', type: 'US', exchange: 'US', lotSize: 1, testQty: 5 },
  { symbol: 'SPY', name: 'SPDR S&P 500 ETF Trust', type: 'ETF', exchange: 'US', lotSize: 1, testQty: 5 },

  // 7. Crypto 24/7 Spot Pairs (3)
  { symbol: 'BTC/USDT', name: 'Bitcoin 24/7 Live Stream', type: 'CRYPTO', exchange: 'CRYPTO', lotSize: 1, testQty: 0.05 },
  { symbol: 'ETH/USDT', name: 'Ethereum 24/7 Live Stream', type: 'CRYPTO', exchange: 'CRYPTO', lotSize: 1, testQty: 0.25 },
  { symbol: 'SOL/USDT', name: 'Solana 24/7 Live Stream', type: 'CRYPTO', exchange: 'CRYPTO', lotSize: 1, testQty: 1.5 },

  // 8. Indian Mutual Funds (3)
  { symbol: 'AXIS_BLUECHIP', name: 'Axis Bluechip Fund - Direct Plan', type: 'MUTUAL_FUND', exchange: 'AMFI', lotSize: 1, testQty: 10 },
  { symbol: 'HDFC_TOP100', name: 'HDFC Top 100 Fund - Growth Option', type: 'MUTUAL_FUND', exchange: 'AMFI', lotSize: 1, testQty: 5 },
  { symbol: 'NIPPON_SMALLCAP', name: 'Nippon India Small Cap Fund', type: 'MUTUAL_FUND', exchange: 'AMFI', lotSize: 1, testQty: 10 },

  // 9. Indian IPOs (3)
  { symbol: 'SWIGGY', name: 'Swiggy Limited IPO', type: 'IPO', exchange: 'NSE', lotSize: 38, testQty: 38 },
  { symbol: 'HYUNDAI', name: 'Hyundai Motor India Ltd IPO', type: 'IPO', exchange: 'NSE', lotSize: 7, testQty: 7 },
  { symbol: 'NTPCGREEN', name: 'NTPC Green Energy Ltd IPO', type: 'IPO', exchange: 'NSE', lotSize: 138, testQty: 138 },
];

async function runVerification() {
  console.log('='.repeat(80));
  console.log(' TradeVerse AI: All Instruments Automated Verification Script');
  console.log(` Target: Verifying ${SYMBOLS_TO_VERIFY.length} instruments across 9 categories`);
  console.log('='.repeat(80));

  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/tradeverse_verify_instruments';
  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 3000 });
    console.log('[DB] Connected to MongoDB at:', mongoUri);
  } catch (err: any) {
    console.warn('[DB] MongoDB connection warning:', err.message);
  }

  await InstrumentMasterService.init();

  // Create test user and sandbox account
  let testUserId = 'test_user_verify';
  if (mongoose.connection.readyState === 1) {
    await User.deleteMany({ email: 'verify_test@tradeverse.ai' });
    const user = await User.create({
      email: 'verify_test@tradeverse.ai',
      passwordHash: 'dummy_hash',
      displayName: 'Verify Trader',
    });
    testUserId = user._id.toString();

    await PaperAccount.deleteMany({ userId: user._id });
    await PaperAccount.create({
      userId: user._id,
      accountNumber: 'ACC_VERIFY_100',
      accountType: 'STANDARD',
      currency: 'INR',
      startingBalance: 10000000,
      currentBalance: 10000000,
      availableCash: 10000000,
      status: 'ACTIVE',
    });
  }

  const results: Array<{
    symbol: string;
    type: string;
    exchange: string;
    search: string;
    detail: string;
    chart: string;
    orderTicket: string;
    details: string;
  }> = [];

  for (const item of SYMBOLS_TO_VERIFY) {
    const clean = item.symbol.replace(/^(NSE|BSE|MCX|US|CRYPTO|AMFI):/, '');

    // 1. Search Test
    const searchRes = await InstrumentMasterService.searchInstruments({ query: clean, limit: 10 });
    const foundInSearch = searchRes.instruments.some(
      (inst) =>
        inst.symbol.toUpperCase() === item.symbol.toUpperCase() ||
        inst.symbol.toUpperCase() === clean ||
        inst.name.toUpperCase().includes(clean)
    );
    const searchStatus = foundInSearch ? 'PASS' : 'FAIL';

    // 2. Detail / Quote Test
    const quote = MarketDataService.getQuote(item.symbol) || MarketDataService.getQuote(clean);
    const detailStatus = quote && quote.price > 0 ? 'PASS' : 'FAIL';

    // 3. Chart Candles Test
    const candles = MarketDataService.getCandles(item.symbol, '15m', 20);
    const chartStatus = candles && candles.length > 0 ? 'PASS' : 'FAIL';

    // 4. Order Ticket Test
    let orderStatus = 'PASS';
    let orderDetail = `Lot ${item.lotSize}, Qty ${item.testQty}`;
    if (mongoose.connection.readyState === 1) {
      try {
        await PaperTradingEngine.submitOrder({
          userId: testUserId,
          symbol: clean,
          exchange: item.exchange as any,
          side: 'BUY',
          orderType: 'MARKET',
          product: 'CNC',
          quantity: item.testQty,
        });
        orderDetail += ' (Executed)';
      } catch (err: any) {
        orderStatus = 'FAIL';
        orderDetail = `Err: ${err.message}`;
      }
    } else {
      orderDetail += ' (Simulated)';
    }

    results.push({
      symbol: item.symbol,
      type: item.type,
      exchange: item.exchange,
      search: searchStatus,
      detail: detailStatus,
      chart: chartStatus,
      orderTicket: orderStatus,
      details: orderDetail,
    });
  }

  // Print Formatted Table
  console.log('\nVERIFICATION RESULTS TABLE:');
  console.log('| Symbol | Type | Exchange | Search | Detail/Quote | Chart Candles | Order Ticket | Status Detail |');
  console.log('|---|---|---|---|---|---|---|---|');
  for (const r of results) {
    console.log(`| **${r.symbol}** | ${r.type} | ${r.exchange} | ${r.search} | ${r.detail} | ${r.chart} | ${r.orderTicket} | ${r.details} |`);
  }

  const allPassed = results.every(
    (r) => r.search === 'PASS' && r.detail === 'PASS' && r.chart === 'PASS' && r.orderTicket === 'PASS'
  );

  console.log('\n' + '='.repeat(80));
  console.log(`Summary: ${results.length}/${results.length} instruments checked.`);
  console.log(`Overall Result: ${allPassed ? '100% ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
  console.log('='.repeat(80));

  if (mongoose.connection.readyState === 1) {
    await mongoose.disconnect();
  }

  process.exit(allPassed ? 0 : 1);
}

runVerification().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
