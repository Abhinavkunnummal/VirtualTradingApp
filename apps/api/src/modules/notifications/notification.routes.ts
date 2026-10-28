import express, { Response } from 'express';
import { requireAuth, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { NotificationService } from './notification.service';

export const notificationRouter = express.Router();

// GET /api/v1/notifications
notificationRouter.get('/', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 50;
    const notifications = await NotificationService.getNotifications(req.user!.userId, limit);
    const unreadCount = await NotificationService.getUnreadCount(req.user!.userId);

    return res.status(200).json({
      success: true,
      unreadCount,
      notifications: notifications.map((n: any) => ({
        id: n._id.toString(),
        title: n.title,
        message: n.message,
        type: n.type,
        read: n.read,
        data: n.data,
        createdAt: n.createdAt,
      })),
    });
  } catch (err) {
    return next(err);
  }
});

// GET /api/v1/notifications/unread-count
notificationRouter.get('/unread-count', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const unreadCount = await NotificationService.getUnreadCount(req.user!.userId);
    return res.status(200).json({ success: true, unreadCount });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/v1/notifications/:id/read
notificationRouter.patch('/:id/read', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    const updated = await NotificationService.markAsRead(req.user!.userId, req.params.id as string);
    if (!updated) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    return res.status(200).json({ success: true, message: 'Notification marked as read' });
  } catch (err) {
    return next(err);
  }
});

// POST /api/v1/notifications/read-all
notificationRouter.post('/read-all', requireAuth, async (req: AuthenticatedRequest, res: Response, next) => {
  try {
    await NotificationService.markAllAsRead(req.user!.userId);
    return res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (err) {
    return next(err);
  }
});
