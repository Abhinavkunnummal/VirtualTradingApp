import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import rateLimit from 'express-rate-limit';
import { AiAssistantService } from './ai.service';
import { requireAuth } from '../../middleware/auth.middleware';

export const aiRouter = Router();

// Dedicated rate limiting for AI endpoints to prevent abusive querying
const aiRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // 30 requests per minute
  message: {
    success: false,
    message: 'AI Assistant rate limit reached. Please wait a moment before sending another inquiry.',
  },
});

aiRouter.use(aiRateLimiter);

const ExplainSchema = z.object({
  concept: z.string().min(2).max(200).trim(),
  context: z.string().max(500).optional(),
});

const TradeRiskSchema = z.object({
  symbol: z.string().min(1).trim().toUpperCase(),
  exchange: z.enum(['NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).default('NSE'),
  side: z.enum(['BUY', 'SELL']),
  orderType: z.enum(['MARKET', 'LIMIT', 'SL', 'SL_M']),
  product: z.enum(['CNC', 'MIS']).default('CNC'),
  quantity: z.number().int().positive('Quantity must be greater than 0'),
  price: z.number().positive('Price must be greater than 0'),
});

/**
 * POST /api/v1/ai/explain
 * Explains market terminology, indicators, order types, and candlestick patterns.
 */
aiRouter.post('/explain', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const parsed = ExplainSchema.parse(req.body);
    const result = await AiAssistantService.explainConcept(parsed.concept, parsed.context);
    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    if ((error as Error).message.includes('Prompt security violation')) {
      res.status(400).json({
        success: false,
        message: (error as Error).message,
        isBlocked: true,
      });
    } else {
      next(error);
    }
  }
});

/**
 * POST /api/v1/ai/trade-risk
 * Pre-trade risk review: fees, margin, slippage, and downside scenarios.
 */
aiRouter.post('/trade-risk', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const parsed = TradeRiskSchema.parse(req.body);
    const result = AiAssistantService.evaluateTradeRisk(parsed);
    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/ai/portfolio-review
 * Evaluates authenticated user's portfolio concentration, diversification, and volatility.
 */
aiRouter.get('/portfolio-review', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = (req as any).user.userId;
    const review = await AiAssistantService.reviewPortfolio(userId);
    res.status(200).json({
      success: true,
      data: review,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/ai/news-summary
 * Curated news feed with sentiment analysis and source citations.
 */
aiRouter.get('/news-summary', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const news = AiAssistantService.getCuratedNews();
    res.status(200).json({
      success: true,
      marketMood: 'MODERATELY_BULLISH',
      count: news.length,
      articles: news,
      disclaimer: 'Curated financial news summaries for educational simulation only.',
    });
  } catch (error) {
    next(error);
  }
});
