import mongoose, { Schema, Document } from 'mongoose';

export interface ITradeHistory extends Document {
  userId: mongoose.Types.ObjectId;
  paperAccountId: mongoose.Types.ObjectId;
  symbol: string;
  exchange: string;
  product: 'CNC' | 'MIS';
  side: 'BUY' | 'SELL';
  quantity: number;
  entryPrice: number;
  exitPrice: number;
  realizedPnl: number;
  realizedPnlPercent: number;
  fees: number;
  closedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const TradeHistorySchema = new Schema<ITradeHistory>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    paperAccountId: {
      type: Schema.Types.ObjectId,
      ref: 'PaperAccount',
      required: true,
      index: true,
    },
    symbol: {
      type: String,
      required: true,
      index: true,
    },
    exchange: {
      type: String,
      required: true,
    },
    product: {
      type: String,
      enum: ['CNC', 'MIS'],
      default: 'CNC',
    },
    side: {
      type: String,
      enum: ['BUY', 'SELL'],
      default: 'BUY',
    },
    quantity: {
      type: Number,
      required: true,
    },
    entryPrice: {
      type: Number,
      required: true,
    },
    exitPrice: {
      type: Number,
      required: true,
    },
    realizedPnl: {
      type: Number,
      required: true,
    },
    realizedPnlPercent: {
      type: Number,
      required: true,
    },
    fees: {
      type: Number,
      default: 0,
    },
    closedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

export const TradeHistory =
  mongoose.models.TradeHistory || mongoose.model<ITradeHistory>('TradeHistory', TradeHistorySchema);
