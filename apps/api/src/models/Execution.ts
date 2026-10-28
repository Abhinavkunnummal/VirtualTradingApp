import mongoose, { Schema, Document } from 'mongoose';

export interface IExecution extends Document {
  orderId: mongoose.Types.ObjectId;
  userId: mongoose.Types.ObjectId;
  paperAccountId: mongoose.Types.ObjectId;
  executionPrice: number;
  executedQuantity: number;
  fees: number;
  slippage: number;
  isSimulated: boolean;
  priceSource: string;
  timestamp: Date;
  createdAt: Date;
  updatedAt: Date;
}

const ExecutionSchema = new Schema<IExecution>(
  {
    orderId: {
      type: Schema.Types.ObjectId,
      ref: 'Order',
      required: true,
      index: true,
    },
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
    executionPrice: {
      type: Number,
      required: true,
    },
    executedQuantity: {
      type: Number,
      required: true,
    },
    fees: {
      type: Number,
      required: true,
      default: 20.00,
    },
    slippage: {
      type: Number,
      default: 0.05,
    },
    isSimulated: {
      type: Boolean,
      default: true,
    },
    priceSource: {
      type: String,
      default: 'SIMULATED_TICK_ENGINE',
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

export const Execution =
  mongoose.models.Execution || mongoose.model<IExecution>('Execution', ExecutionSchema);
