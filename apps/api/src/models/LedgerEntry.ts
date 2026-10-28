import mongoose, { Schema, Document } from 'mongoose';

export type LedgerType =
  | 'CAPITAL_INIT'
  | 'CAPITAL_RESET'
  | 'CAPITAL_TOPUP'
  | 'MARGIN_RESERVE'
  | 'MARGIN_RELEASE'
  | 'TRADE_FILL'
  | 'FEE_DEDUCTION';

export interface ILedgerEntry extends Document {
  userId: mongoose.Types.ObjectId;
  paperAccountId: mongoose.Types.ObjectId;
  orderId?: mongoose.Types.ObjectId;
  type: LedgerType;
  amount: number;
  balanceAfter: number;
  description: string;
  timestamp: Date;
  createdAt: Date;
}

const LedgerEntrySchema = new Schema<ILedgerEntry>(
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
    orderId: {
      type: Schema.Types.ObjectId,
      ref: 'Order',
      default: null,
      index: true,
    },
    type: {
      type: String,
      enum: [
        'CAPITAL_INIT',
        'CAPITAL_RESET',
        'CAPITAL_TOPUP',
        'MARGIN_RESERVE',
        'MARGIN_RELEASE',
        'TRADE_FILL',
        'FEE_DEDUCTION',
      ],
      required: true,
      index: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    balanceAfter: {
      type: Number,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  }
);

export const LedgerEntry =
  mongoose.models.LedgerEntry || mongoose.model<ILedgerEntry>('LedgerEntry', LedgerEntrySchema);
