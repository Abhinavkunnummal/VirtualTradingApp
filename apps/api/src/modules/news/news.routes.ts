import express, { Request, Response } from 'express';
import { NewsService } from './news.service';

export const newsRouter = express.Router();

// GET /api/v1/news
newsRouter.get('/', (req: Request, res: Response) => {
  const { category, symbol, limit } = req.query as {
    category?: string;
    symbol?: string;
    limit?: string;
  };

  const parsedLimit = limit ? parseInt(limit, 10) : 20;
  const articles = NewsService.getNews({
    category,
    symbol,
    limit: isNaN(parsedLimit) ? 20 : parsedLimit,
  });

  return res.status(200).json({
    success: true,
    total: articles.length,
    articles,
  });
});

// GET /api/v1/news/:id
newsRouter.get('/:id', (req: Request, res: Response) => {
  const article = NewsService.getArticleById(req.params.id as string);
  if (!article) {
    return res.status(404).json({ success: false, message: 'News article not found' });
  }

  return res.status(200).json({
    success: true,
    article,
  });
});
