import express, { Response } from 'express';
import { z } from 'zod';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { Watchlist } from '../../models';

export const watchlistRouter = express.Router();

const CreateWatchlistSchema = z.object({
  name: z.string().min(1, 'Watchlist name is required').max(50),
  instruments: z.array(z.string()).default([]),
});

const AddSymbolSchema = z.object({
  symbol: z.string().min(1, 'Symbol is required'),
});

// GET /api/v1/watchlists
watchlistRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const watchlists = await Watchlist.find({ userId: req.user!.userId }).sort({ isDefault: -1, createdAt: 1 });

    return res.status(200).json({
      success: true,
      watchlists: watchlists.map((w) => ({
        id: w._id.toString(),
        name: w.name,
        instruments: w.instruments,
        isDefault: w.isDefault,
        createdAt: w.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/watchlists
watchlistRouter.post('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { name, instruments } = CreateWatchlistSchema.parse(req.body);

    const existing = await Watchlist.findOne({ userId: req.user!.userId, name });
    if (existing) {
      return res.status(409).json({ success: false, message: 'A watchlist with this name already exists.' });
    }

    const watchlist = await Watchlist.create({
      userId: req.user!.userId,
      name,
      instruments,
      isDefault: false,
    });

    return res.status(201).json({
      success: true,
      watchlist: {
        id: watchlist._id.toString(),
        name: watchlist.name,
        instruments: watchlist.instruments,
        isDefault: watchlist.isDefault,
      },
    });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/v1/watchlists/:id
watchlistRouter.delete('/:id', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const watchlist = await Watchlist.findOne({
      _id: req.params.id,
      userId: req.user!.userId,
    });

    if (!watchlist) {
      return res.status(404).json({ success: false, message: 'Watchlist not found or access denied.' });
    }

    if (watchlist.isDefault) {
      return res.status(400).json({ success: false, message: 'Cannot delete the default watchlist.' });
    }

    await Watchlist.deleteOne({ _id: watchlist._id });

    return res.status(200).json({
      success: true,
      message: 'Watchlist deleted successfully.',
    });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/watchlists/:id/symbols
watchlistRouter.post('/:id/symbols', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const { symbol } = AddSymbolSchema.parse(req.body);

    const watchlist = await Watchlist.findOneAndUpdate(
      { _id: req.params.id, userId: req.user!.userId },
      { $addToSet: { instruments: symbol.toUpperCase() } },
      { new: true }
    );

    if (!watchlist) {
      return res.status(404).json({ success: false, message: 'Watchlist not found.' });
    }

    return res.status(200).json({
      success: true,
      watchlist: {
        id: watchlist._id.toString(),
        instruments: watchlist.instruments,
      },
    });
  } catch (err) {
    return next(err);
  }
});
