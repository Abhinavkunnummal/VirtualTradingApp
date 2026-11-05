import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import mongoose from 'mongoose';
import { config } from './config';
import { AngelOneService } from './modules/market-data/angelOne.service';
import { errorHandler } from './middleware/errorHandler';
import { authRouter } from './modules/auth/auth.routes';
import { paperAccountRouter } from './modules/paper-accounts/paperAccount.routes';
import { portfolioRouter } from './modules/portfolio/portfolio.routes';
import { watchlistRouter } from './modules/watchlists/watchlist.routes';
import { ordersRouter } from './modules/orders/orders.routes';
import { marketDataRouter } from './modules/market-data/marketData.routes';
import { communityRouter } from './modules/community/community.routes';
import { aiRouter } from './modules/ai/ai.routes';
import { newsRouter } from './modules/news/news.routes';
import { notificationRouter } from './modules/notifications/notification.routes';
import { tradingViewRouter } from './modules/market-data/tradingView.routes';

export function createApp(): express.Application {
  const app = express();

  // Security Middleware
  app.use(helmet({ contentSecurityPolicy: false }));

  // Dynamic CORS origin handler supporting "*" and comma-separated domains
  const allowedOrigins = config.corsOrigins === '*'
    ? '*'
    : config.corsOrigins.split(',').map((o) => o.trim());

  app.use(cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins === '*' || (Array.isArray(allowedOrigins) && allowedOrigins.includes(origin))) {
        callback(null, true);
      } else {
        callback(new Error(`CORS origin not allowed: ${origin}`));
      }
    },
    credentials: true,
  }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Global Rate Limiting
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 2000,
    message: { success: false, message: 'Too many requests, please try again later.' },
  });
  app.use(limiter);

  // Health & Monitoring Probes
  app.get('/health', (req, res) => {
    const mongoState = mongoose.connection.readyState;
    const dbStatus = mongoState === 1 ? 'connected' : (mongoState === 2 ? 'connecting' : 'disconnected');

    const angelOneConfigured = AngelOneService.isConfigured();
    const angelOneConnected = AngelOneService.isConnected();
    const angelOneStatus = angelOneConnected ? 'connected' : (angelOneConfigured ? 'connecting' : 'not configured');

    const binanceStatus = 'connected';
    const finnhubStatus = config.finnhubApiKey ? 'connected' : 'delayed';
    const twelveDataStatus = config.twelveDataApiKey ? 'connected' : 'not configured';
    const alphaVantageStatus = config.alphaVantageApiKey ? 'configured' : 'not configured';

    res.status(200).json({
      status: 'healthy',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.nodeEnv,
      database: {
        status: dbStatus,
        name: mongoose.connection.name || 'tradeverse',
      },
      providers: {
        angelOne: angelOneStatus,
        angelOneAuthError: AngelOneService.getLastAuthError(),
        binance: binanceStatus,
        finnhub: finnhubStatus,
        twelveData: twelveDataStatus,
        alphaVantage: alphaVantageStatus,
      },
      services: {
        database: dbStatus,
        paperEngine: 'active',
        marketData: 'active',
      },
    });
  });

  app.get('/health/liveness', (req, res) => {
    res.status(200).json({ status: 'live', uptime: process.uptime() });
  });

  app.get('/health/readiness', (req, res) => {
    res.status(200).json({
      status: 'ready',
      database: 'connected',
      timestamp: new Date().toISOString(),
    });
  });

  // Base API Router (/api/v1)
  const apiV1Router = express.Router();

  apiV1Router.get('/status', (req, res) => {
    res.json({
      name: 'TradeVerse AI Paper Trading API',
      version: '1.0.0',
      status: 'online',
    });
  });

  // Mount Feature Routers
  apiV1Router.use('/auth', authRouter);
  apiV1Router.use('/paper-account', paperAccountRouter);
  apiV1Router.use('/portfolio', portfolioRouter);
  apiV1Router.use('/watchlists', watchlistRouter);
  apiV1Router.use('/orders', ordersRouter);
  apiV1Router.use('/market', marketDataRouter);
  apiV1Router.use('/market-data', marketDataRouter);
  apiV1Router.use('/instruments', marketDataRouter);
  apiV1Router.use('/community', communityRouter);
  apiV1Router.use('/ai', aiRouter);
  apiV1Router.use('/news', newsRouter);
  apiV1Router.use('/notifications', notificationRouter);
  apiV1Router.use('/tradingview', tradingViewRouter);
  apiV1Router.use('/market-data/tradingview', tradingViewRouter);

  // Direct routes for TradingView interactive chart and Account Manager terminal
  app.use('/tradingview', tradingViewRouter);
  app.use('/chart', tradingViewRouter);

  app.use('/api/v1', apiV1Router);
  app.use('/api', apiV1Router);

  // Centralized Error Handling
  app.use(errorHandler);

  return app;
}
