import mongoose, { Schema, Document } from 'mongoose';

export interface IHolding extends Document {
  userId: mongoose.Types.ObjectId;
  paperAccountId: mongoose.Types.ObjectId;
  instrumentId: string;
  symbol: string;
  exchange: string;
  product: 'CNC' | 'MIS';
  quantity: number;
  averageCost: number;
  stopLossPrice?: number | null;
  targetPrice?: number | null;
  reservedMargin: number;
  createdAt: Date;
  updatedAt: Date;
}

const HoldingSchema = new Schema<IHolding>(
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
    instrumentId: {
      type: String,
      required: true,
      index: true,
    },
    symbol: {
      type: String,
      required: true,
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
    quantity: {
      type: Number,
      required: true,
      min: 0,
    },
    averageCost: {
      type: Number,
      required: true,
      min: 0,
    },
    stopLossPrice: {
      type: Number,
      default: null,
    },
    targetPrice: {
      type: Number,
      default: null,
    },
    reservedMargin: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

HoldingSchema.index({ paperAccountId: 1, instrumentId: 1 }, { unique: true });

export const Holding = mongoose.models.Holding || mongoose.model<IHolding>('Holding', HoldingSchema);
