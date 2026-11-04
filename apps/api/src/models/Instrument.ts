import mongoose, { Schema, Document } from 'mongoose';

export type AssetClass =
  | 'EQUITY'
  | 'INDEX'
  | 'COMMODITY'
  | 'CRYPTO'
  | 'DERIVATIVE'
  | 'ETF'
  | 'MUTUAL_FUND'
  | 'IPO';

export type Exchange = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO' | 'AMFI' | 'GLOBAL';
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
  basePrice?: number;
  isin?: string;
  segment?: string;
  tradingStatus: TradingStatus;
  aliases?: string[];
  popularity?: number;
  nav?: number;
  fundHouse?: string;
  schemeCode?: string;
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
      trim: true,
      uppercase: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    assetClass: {
      type: String,
      enum: ['EQUITY', 'INDEX', 'COMMODITY', 'CRYPTO', 'DERIVATIVE', 'ETF', 'MUTUAL_FUND', 'IPO'],
      required: true,
      index: true,
    },
    exchange: {
      type: String,
      enum: ['NSE', 'BSE', 'MCX', 'US', 'CRYPTO', 'AMFI', 'GLOBAL'],
      required: true,
      index: true,
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
    basePrice: {
      type: Number,
      default: 100.0,
    },
    isin: {
      type: String,
      sparse: true,
      index: true,
      trim: true,
      uppercase: true,
    },
    segment: {
      type: String,
      default: 'EQ',
      trim: true,
    },
    tradingStatus: {
      type: String,
      enum: ['ACTIVE', 'HALTED', 'CLOSED'],
      default: 'ACTIVE',
    },
    aliases: {
      type: [String],
      default: [],
      index: true,
    },
    popularity: {
      type: Number,
      default: 0,
      index: true,
    },
    nav: {
      type: Number,
    },
    fundHouse: {
      type: String,
      trim: true,
    },
    schemeCode: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound and text indexes for rapid search
InstrumentSchema.index({ exchange: 1, symbol: 1 });
InstrumentSchema.index(
  { symbol: 'text', displayName: 'text' },
  { weights: { symbol: 10, displayName: 5 }, name: 'symbol_name_text_idx' }
);

export const Instrument =
  mongoose.models.Instrument || mongoose.model<IInstrument>('Instrument', InstrumentSchema);
