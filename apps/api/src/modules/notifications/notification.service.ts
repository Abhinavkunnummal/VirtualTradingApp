import mongoose from 'mongoose';
import { Notification, INotification, NotificationType } from '../../models/Notification';
import { SocketService } from '../../services/socket.service';

export interface CreateNotificationParams {
  userId: string | mongoose.Types.ObjectId;
  title: string;
  message: string;
  type?: NotificationType;
  data?: Record<string, any>;
}

export class NotificationService {
  static async send(params: CreateNotificationParams): Promise<INotification> {
    const notification = await Notification.create({
      userId: params.userId,
      title: params.title,
      message: params.message,
      type: params.type || 'ORDER_FILL',
      data: params.data || {},
      read: false,
    });

    // Emit live real-time notification to user's isolated socket channel
    SocketService.emitToUser(params.userId.toString(), 'notification', {
      id: notification._id.toString(),
      title: notification.title,
      message: notification.message,
      type: notification.type,
      read: false,
      data: notification.data,
      createdAt: notification.createdAt.toISOString(),
    });

    return notification;
  }

  static async getNotifications(userId: string, limit: number = 50) {
    return Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(Math.min(limit, 100))
      .lean();
  }

  static async getUnreadCount(userId: string): Promise<number> {
    return Notification.countDocuments({ userId, read: false });
  }

  static async markAsRead(userId: string, notificationId: string) {
    return Notification.findOneAndUpdate(
      { _id: notificationId, userId },
      { $set: { read: true } },
      { new: true }
    );
  }

  static async markAllAsRead(userId: string) {
    return Notification.updateMany({ userId, read: false }, { $set: { read: true } });
  }
}
