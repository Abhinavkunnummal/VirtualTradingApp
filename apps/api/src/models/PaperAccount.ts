import mongoose, { Schema, Document } from 'mongoose';

export type PaperAccountStatus = 'ACTIVE' | 'FROZEN';

export interface IPaperAccount extends Document {
  userId: mongoose.Types.ObjectId;
  accountName: string;
  baseCurrency: string;
  startingCapital: number;
  availableCash: number;
  reservedMargin: number;
  isSimulated: boolean;
  status: PaperAccountStatus;
  createdAt: Date;
  updatedAt: Date;
}

const PaperAccountSchema = new Schema<IPaperAccount>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    accountName: {
      type: String,
      default: 'Sandbox v2.4 (Default)',
    },
    baseCurrency: {
      type: String,
      default: 'INR',
    },
    startingCapital: {
      type: Number,
      required: true,
      default: 1000000,
    },
    availableCash: {
      type: Number,
      required: true,
      default: 1000000,
    },
    reservedMargin: {
      type: Number,
      default: 0,
    },
    isSimulated: {
      type: Boolean,
      default: true,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'FROZEN'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

export const PaperAccount =
  mongoose.models.PaperAccount || mongoose.model<IPaperAccount>('PaperAccount', PaperAccountSchema);
