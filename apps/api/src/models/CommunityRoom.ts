import mongoose, { Document, Schema } from 'mongoose';

export interface ICommunityRoom extends Document {
  roomId: string;
  name: string;
  description: string;
  category: 'GENERAL' | 'EQUITIES' | 'COMMODITIES' | 'CRYPTO' | 'AI_INSIGHTS';
  symbol?: string;
  memberCount: number;
  isPrivate: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const CommunityRoomSchema = new Schema<ICommunityRoom>(
  {
    roomId: {
      type: String,
      required: true,
      unique: true,
      index: true,
      trim: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    category: {
      type: String,
      enum: ['GENERAL', 'EQUITIES', 'COMMODITIES', 'CRYPTO', 'AI_INSIGHTS'],
      default: 'GENERAL',
    },
    symbol: {
      type: String,
      uppercase: true,
      trim: true,
    },
    memberCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    isPrivate: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export const CommunityRoom = mongoose.model<ICommunityRoom>('CommunityRoom', CommunityRoomSchema);
