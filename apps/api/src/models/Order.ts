import mongoose, { Schema, Document } from 'mongoose';

export type OrderSide = 'BUY' | 'SELL';
export type OrderType = 'MARKET' | 'LIMIT' | 'SL' | 'SL_M';
export type ProductType = 'CNC' | 'MIS';
export type OrderStatus = 'PENDING' | 'FILLED' | 'REJECTED' | 'CANCELLED';

export interface IOrder extends Document {
  userId: mongoose.Types.ObjectId;
  paperAccountId: mongoose.Types.ObjectId;
  instrumentId: string;
  symbol: string;
  exchange: string;
  side: OrderSide;
  orderType: OrderType;
  product: ProductType;
  quantity: number;
  filledQuantity: number;
  limitPrice?: number;
  triggerPrice?: number;
  averagePrice?: number;
  status: OrderStatus;
  rejectionReason?: string;
  idempotencyKey?: string;
  createdAt: Date;
  updatedAt: Date;
}

const OrderSchema = new Schema<IOrder>(
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
    side: {
      type: String,
      enum: ['BUY', 'SELL'],
      required: true,
    },
    orderType: {
      type: String,
      enum: ['MARKET', 'LIMIT', 'SL', 'SL_M'],
      required: true,
    },
    product: {
      type: String,
      enum: ['CNC', 'MIS'],
      required: true,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
    },
    filledQuantity: {
      type: Number,
      default: 0,
    },
    limitPrice: {
      type: Number,
      default: null,
    },
    triggerPrice: {
      type: Number,
      default: null,
    },
    averagePrice: {
      type: Number,
      default: null,
    },
    status: {
      type: String,
      enum: ['PENDING', 'FILLED', 'REJECTED', 'CANCELLED'],
      default: 'PENDING',
      index: true,
    },
    rejectionReason: {
      type: String,
      default: null,
    },
    idempotencyKey: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

export const Order = mongoose.models.Order || mongoose.model<IOrder>('Order', OrderSchema);
