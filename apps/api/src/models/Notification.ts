import mongoose, { Schema, Document } from 'mongoose';

export type NotificationType =
  | 'ORDER_FILL'
  | 'ORDER_CANCEL'
  | 'BRACKET_OCO'
  | 'TRAILING_STOP'
  | 'MARGIN_CALL'
  | 'TOPUP'
  | 'MARKET_ALERT'
  | 'AI_INSIGHT';

export interface INotification extends Document {
  userId: mongoose.Types.ObjectId;
  title: string;
  message: string;
  type: NotificationType;
  read: boolean;
  data?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

const NotificationSchema = new Schema<INotification>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },
    type: {
      type: String,
      enum: [
        'ORDER_FILL',
        'ORDER_CANCEL',
        'BRACKET_OCO',
        'TRAILING_STOP',
        'MARGIN_CALL',
        'TOPUP',
        'MARKET_ALERT',
        'AI_INSIGHT',
      ],
      default: 'ORDER_FILL',
      index: true,
    },
    read: {
      type: Boolean,
      default: false,
      index: true,
    },
    data: {
      type: Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
  }
);

export const Notification =
  mongoose.models.Notification || mongoose.model<INotification>('Notification', NotificationSchema);
