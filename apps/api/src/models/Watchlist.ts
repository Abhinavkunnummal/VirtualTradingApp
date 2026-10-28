import mongoose, { Schema, Document } from 'mongoose';

export interface IWatchlist extends Document {
  userId: mongoose.Types.ObjectId;
  name: string;
  instruments: string[];
  isDefault: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const WatchlistSchema = new Schema<IWatchlist>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    instruments: {
      type: [String],
      default: ['RELIANCE', 'HDFCBANK', 'TCS', 'BTC/USDT'],
    },
    isDefault: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

WatchlistSchema.index({ userId: 1, name: 1 }, { unique: true });

export const Watchlist =
  mongoose.models.Watchlist || mongoose.model<IWatchlist>('Watchlist', WatchlistSchema);
