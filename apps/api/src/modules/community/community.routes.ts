import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { CommunityService } from './community.service';
import { requireAuth } from '../../middleware/auth.middleware';
import { User } from '../../models';

export const communityRouter = Router();

const PostMessageSchema = z.object({
  content: z.string().min(1).max(1000).trim(),
  type: z.enum(['CHAT', 'EDUCATIONAL', 'AI_SUMMARY', 'SYSTEM']).default('CHAT'),
  tradeTag: z.string().max(100).optional(),
  sentiment: z.enum(['BULLISH', 'BEARISH', 'NEUTRAL']).optional(),
  isAiGenerated: z.boolean().default(false),
});

/**
 * GET /api/v1/community/rooms
 * List all available public discussion channels
 */
communityRouter.get('/rooms', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rooms = await CommunityService.getRooms();
    res.status(200).json({
      success: true,
      count: rooms.length,
      rooms,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/community/rooms/:roomId/messages
 * Retrieve paginated message history for a room
 */
communityRouter.get('/rooms/:roomId/messages', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const roomId = req.params.roomId as string;
    const limit = parseInt(req.query.limit as string) || 50;
    const before = req.query.before as string | undefined;

    const messages = await CommunityService.getRoomMessages(roomId, limit, before);
    res.status(200).json({
      success: true,
      roomId,
      count: messages.length,
      messages,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/community/rooms/:roomId/messages
 * Post a new message into a discussion room (Requires Authentication)
 */
communityRouter.post(
  '/rooms/:roomId/messages',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const roomId = req.params.roomId as string;
      const parsed = PostMessageSchema.parse(req.body);

      const userId = (req as any).user.userId;
      const user = await User.findById(userId);
      const authorName = user?.displayName || (req as any).user?.email?.split('@')[0] || 'Trader';

      const message = await CommunityService.createMessage({
        roomId,
        userId,
        authorName,
        content: parsed.content,
        type: parsed.type,
        tradeTag: parsed.tradeTag,
        sentiment: parsed.sentiment,
        isAiGenerated: parsed.isAiGenerated,
      });

      res.status(201).json({
        success: true,
        message: 'Message posted successfully.',
        data: message,
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/v1/community/messages/:id
 * Delete a user's own message (Enforces Author Ownership)
 */
communityRouter.delete(
  '/messages/:id',
  requireAuth,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const messageId = req.params.id as string;
      const userId = (req as any).user.userId;
      await CommunityService.deleteMessage(userId, messageId);

      res.status(200).json({
        success: true,
        message: 'Message deleted successfully.',
      });
    } catch (error) {
      if ((error as Error).message.includes('Unauthorized')) {
        res.status(403).json({ success: false, message: (error as Error).message });
      } else if ((error as Error).message.includes('not found')) {
        res.status(404).json({ success: false, message: (error as Error).message });
      } else {
        next(error);
      }
    }
  }
);
