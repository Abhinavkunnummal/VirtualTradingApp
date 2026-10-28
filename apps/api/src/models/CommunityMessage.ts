import mongoose, { Document, Schema } from 'mongoose';

export interface ICommunityMessage extends Document {
  roomId: string;
  userId: mongoose.Types.ObjectId;
  authorName: string;
  content: string;
  type: 'CHAT' | 'EDUCATIONAL' | 'AI_SUMMARY' | 'SYSTEM';
  tradeTag?: string;
  sentiment?: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
  likesCount: number;
  isAiGenerated: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const CommunityMessageSchema = new Schema<ICommunityMessage>(
  {
    roomId: {
      type: String,
      required: true,
      index: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    authorName: {
      type: String,
      required: true,
      trim: true,
    },
    content: {
      type: String,
      required: true,
      maxlength: 1000,
      trim: true,
    },
    type: {
      type: String,
      enum: ['CHAT', 'EDUCATIONAL', 'AI_SUMMARY', 'SYSTEM'],
      default: 'CHAT',
    },
    tradeTag: {
      type: String,
      maxlength: 100,
    },
    sentiment: {
      type: String,
      enum: ['BULLISH', 'BEARISH', 'NEUTRAL'],
    },
    likesCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    isAiGenerated: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

CommunityMessageSchema.index({ roomId: 1, createdAt: -1 });

export const CommunityMessage = mongoose.model<ICommunityMessage>('CommunityMessage', CommunityMessageSchema);
