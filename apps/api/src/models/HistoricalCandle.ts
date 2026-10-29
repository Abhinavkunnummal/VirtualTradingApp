import mongoose, { Schema, Document } from 'mongoose';

export interface IHistoricalCandle extends Document {
  symbol: string;
  exchange: string;
  interval: string;
  timestamp: number; // Unix timestamp in seconds
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  source: 'ALPHA_VANTAGE' | 'SIMULATOR' | 'HYBRID' | 'EXCHANGE';
  isSimulated: boolean;
  createdAt: Date;
}

const HistoricalCandleSchema = new Schema<IHistoricalCandle>(
  {
    symbol: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
      index: true,
    },
    exchange: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    interval: {
      type: String,
      required: true,
      index: true,
    },
    timestamp: {
      type: Number,
      required: true,
      index: true,
    },
    open: {
      type: Number,
      required: true,
    },
    high: {
      type: Number,
      required: true,
    },
    low: {
      type: Number,
      required: true,
    },
    close: {
      type: Number,
      required: true,
    },
    volume: {
      type: Number,
      required: true,
      default: 0,
    },
    source: {
      type: String,
      enum: ['ALPHA_VANTAGE', 'SIMULATOR', 'HYBRID', 'EXCHANGE'],
      default: 'SIMULATOR',
    },
    isSimulated: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index ensuring idempotency and preventing duplicate ticks for the same candle bar
HistoricalCandleSchema.index({ symbol: 1, interval: 1, timestamp: 1 }, { unique: true });
// Range query index for fast timestamp bounded queries
HistoricalCandleSchema.index({ symbol: 1, interval: 1, timestamp: -1 });

export const HistoricalCandle =
  mongoose.models.HistoricalCandle ||
  mongoose.model<IHistoricalCandle>('HistoricalCandle', HistoricalCandleSchema);
