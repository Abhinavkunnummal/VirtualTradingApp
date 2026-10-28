import mongoose, { Schema, Document } from 'mongoose';

export type AssetClass = 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'DERIVATIVE';
export type Exchange = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
export type TradingStatus = 'ACTIVE' | 'HALTED' | 'CLOSED';

export interface IInstrument extends Document {
  instrumentId: string;
  symbol: string;
  displayName: string;
  assetClass: AssetClass;
  exchange: Exchange;
  quoteCurrency: string;
  tickSize: number;
  lotSize: number;
  tradingStatus: TradingStatus;
  createdAt: Date;
  updatedAt: Date;
}

const InstrumentSchema = new Schema<IInstrument>(
  {
    instrumentId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    symbol: {
      type: String,
      required: true,
      index: true,
    },
    displayName: {
      type: String,
      required: true,
    },
    assetClass: {
      type: String,
      enum: ['EQUITY', 'INDEX', 'COMMODITY', 'CRYPTO', 'DERIVATIVE'],
      required: true,
    },
    exchange: {
      type: String,
      enum: ['NSE', 'BSE', 'MCX', 'US', 'CRYPTO'],
      required: true,
    },
    quoteCurrency: {
      type: String,
      default: 'INR',
    },
    tickSize: {
      type: Number,
      default: 0.05,
    },
    lotSize: {
      type: Number,
      default: 1,
    },
    tradingStatus: {
      type: String,
      enum: ['ACTIVE', 'HALTED', 'CLOSED'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

export const Instrument =
  mongoose.models.Instrument || mongoose.model<IInstrument>('Instrument', InstrumentSchema);
