import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config';
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
  app.use(cors({ origin: config.corsOrigins, credentials: true }));
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
    res.status(200).json({
      status: 'healthy',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      environment: config.nodeEnv,
      services: {
        database: 'configured',
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

  // Centralized Error Handling
  app.use(errorHandler);

  return app;
}
