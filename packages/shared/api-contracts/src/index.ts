import { z } from 'zod';

// ==========================================
// Enums & Literals
// ==========================================
export type ExchangeType = 'NSE' | 'BSE' | 'MCX' | 'US' | 'CRYPTO';
export type AssetCategory = 'EQUITY' | 'INDEX' | 'COMMODITY' | 'CRYPTO' | 'DERIVATIVE';
export type OrderSide = 'BUY' | 'SELL';
export type OrderType = 'MARKET' | 'LIMIT' | 'SL' | 'SL_M';
export type ProductType = 'CNC' | 'MIS'; // CNC = Delivery, MIS = Intraday (5x leverage)
export type OrderStatus = 'PENDING' | 'FILLED' | 'REJECTED' | 'CANCELLED';
export type DataFreshness = 'LIVE' | 'DELAYED' | 'SIMULATED';

// ==========================================
// Instrument & Market Data Models
// ==========================================
export interface Instrument {
  symbol: string;
  name: string;
  exchange: ExchangeType;
  category: AssetCategory;
  currency: string;
  tickSize: number;
  lotSize: number;
  description?: string;
}

export interface TickerSnapshot {
  symbol: string;
  name: string;
  exchange: ExchangeType;
  price: number;
  change: number;
  changePercent: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  currency: string;
  status: DataFreshness;
  timestamp: string;
}

// ==========================================
// Virtual Account & Portfolio Models
// ==========================================
export interface VirtualAccount {
  id: string;
  userId: string;
  accountName: string;
  currency: string;
  startingCapital: number;
  cashBalance: number;
  investedExposure: number;
  totalPortfolioValue: number;
  totalPnl: number;
  totalPnlPercent: number;
  todaysPnl: number;
  todaysPnlPercent: number;
  isSimulated: true;
  updatedAt: string;
}

export interface Holding {
  id: string;
  virtualAccountId: string;
  symbol: string;
  exchange: ExchangeType;
  quantity: number;
  averageBuyPrice: number;
  currentPrice: number;
  investedValue: number;
  currentValue: number;
  unrealizedPnl: number;
  unrealizedPnlPercent: number;
}

export interface Position {
  id: string;
  virtualAccountId: string;
  symbol: string;
  exchange: ExchangeType;
  side: OrderSide;
  product: ProductType;
  quantity: number;
  entryPrice: number;
  currentPrice: number;
  pnl: number;
  pnlPercent: number;
  leverage: number;
}

// ==========================================
// Orders & Execution Models
// ==========================================
export interface PaperOrder {
  id: string;
  userId: string;
  virtualAccountId: string;
  symbol: string;
  exchange: ExchangeType;
  side: OrderSide;
  orderType: OrderType;
  product: ProductType;
  quantity: number;
  filledQuantity: number;
  price?: number;
  triggerPrice?: number;
  averagePrice?: number;
  status: OrderStatus;
  slippage: number;
  brokerage: number;
  taxesAndCharges: number;
  totalCost: number;
  rejectionReason?: string;
  idempotencyKey?: string;
  createdAt: string;
  updatedAt: string;
}

// ==========================================
// Zod Validation Schemas
// ==========================================
export const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(2),
  initialVirtualCapital: z.number().min(10000).max(100000000).default(1000000),
});

export const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const SubmitOrderSchema = z.object({
  symbol: z.string().min(1),
  exchange: z.enum(['NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).default('NSE'),
  side: z.enum(['BUY', 'SELL']),
  orderType: z.enum(['MARKET', 'LIMIT', 'SL', 'SL_M']),
  product: z.enum(['CNC', 'MIS']).default('CNC'),
  quantity: z.number().int().positive(),
  price: z.number().positive().optional(),
  triggerPrice: z.number().positive().optional(),
  idempotencyKey: z.string().optional(),
});

export const AiAnalysisRequestSchema = z.object({
  symbol: z.string().min(1),
  prompt: z.string().min(3),
});

export const CreatePostSchema = z.object({
  title: z.string().min(3).max(150),
  content: z.string().min(10).max(2000),
  symbolTag: z.string().optional(),
});

export const SendMessageSchema = z.object({
  roomId: z.string().min(1),
  content: z.string().min(1).max(1000),
});
