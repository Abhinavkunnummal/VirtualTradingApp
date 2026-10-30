import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import mongoose from 'mongoose';
import { createApp } from './app';
import { config } from './config';
import { SocketService } from './services/socket.service';
import { MarketDataService } from './modules/market-data/marketData.service';
import { RealtimeMarketService } from './modules/market-data/realtimeMarket.service';
import { PaperTradingEngine } from './modules/orders/paperEngine.service';

async function bootstrap() {
  const app = createApp();
  const server = http.createServer(app);

  // Initialize Socket.IO with centralized service
  const io = new SocketIOServer(server, {
    cors: { origin: config.corsOrigins, methods: ['GET', 'POST'] },
  });

  SocketService.init(io);

  // Attempt MongoDB connection if configured
  if (config.mongoUri) {
    try {
      await mongoose.connect(config.mongoUri, { serverSelectionTimeoutMS: 5000 });
      const isAtlas = config.mongoUri.includes('mongodb+srv') || config.mongoUri.includes('.mongodb.net');
      console.log(`Connected to MongoDB ${isAtlas ? 'Atlas (Cloud)' : 'Local'}`);
    } catch (err) {
      console.warn('MongoDB connection warning:', (err as Error).message);
      console.info('Tip: Verify IP address whitelist in MongoDB Atlas Network Access and MONGODB_URI credentials.');
    }
  }

  // Start background real-time ticker broadcaster (1s cycle for tick-by-tick TradingView precision)
  const activeSymbols = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'RELIANCE', 'TCS', 'HDFCBANK', 'NIFTY 50', 'SENSEX', 'GOLD 1KG', 'NVDA', 'AAPL'];
  const tickerInterval = setInterval(async () => {
    for (const sym of activeSymbols) {
      let quote = await RealtimeMarketService.getLiveQuote(sym).catch(() => null);
      if (!quote) {
        quote = MarketDataService.getQuote(sym);
      }
      if (quote) {
        SocketService.emitTickerUpdate(sym, quote);
        const candleTick = {
          symbol: sym,
          timestamp: Math.floor(Date.now() / 1000),
          price: quote.price,
          volume: quote.volume,
          status: quote.status,
        };
        for (const interval of ['1m', '5m', '15m', '1h', '1d']) {
          SocketService.emitCandleUpdate(sym, interval, candleTick);
        }
        try {
          await PaperTradingEngine.evaluateOpenOrders(sym, quote);
        } catch {
          // Keep background ticker loop active
        }
      }
    }
  }, 1000);

  server.listen(config.port, () => {
    console.log(`TradeVerse AI API running on http://localhost:${config.port} (env: ${config.nodeEnv})`);
  });

  const shutdown = async (signal: string) => {
    console.log(`Received ${signal}. Initiating graceful shutdown...`);
    clearInterval(tickerInterval);
    server.close(async () => {
      console.log('HTTP and WebSocket server closed.');
      if (mongoose.connection.readyState !== 0) {
        await mongoose.connection.close();
        console.log('MongoDB connection closed.');
      }
      process.exit(0);
    });

    setTimeout(() => {
      console.error('Forced shutdown due to 10s timeout.');
      process.exit(1);
    }, 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

if (process.env.NODE_ENV !== 'test') {
  bootstrap();
}
