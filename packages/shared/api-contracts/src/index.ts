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
export type CandleInterval = '1m' | '5m' | '15m' | '1h' | '1d' | '1w';
export type LedgerEntryType =
  | 'CAPITAL_INIT'
  | 'CAPITAL_RESET'
  | 'MARGIN_RESERVE'
  | 'MARGIN_RELEASE'
  | 'TRADE_FILL'
  | 'FEE_DEDUCTION';

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

export interface Quote {
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
  bid: number;
  ask: number;
  currency: string;
  status: DataFreshness;
  timestamp: string;
}

export interface Candle {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface MarketStatus {
  exchange: ExchangeType;
  isOpen: boolean;
  session: 'REGULAR' | 'PRE_MARKET' | 'POST_MARKET' | 'CLOSED' | '24_7';
  timezone: string;
  serverTime: string;
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
  reservedMargin: number;
  totalPortfolioValue: number;
  totalPnl: number;
  totalPnlPercent: number;
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
  paperAccountId: string;
  symbol: string;
  exchange: ExchangeType;
  side: OrderSide;
  orderType: OrderType;
  product: ProductType;
  quantity: number;
  filledQuantity: number;
  limitPrice?: number;
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

export interface ExecutionRecord {
  id: string;
  orderId: string;
  userId: string;
  paperAccountId: string;
  symbol: string;
  exchange: ExchangeType;
  side: OrderSide;
  executionPrice: number;
  executedQuantity: number;
  fees: number;
  slippage: number;
  isSimulated: boolean;
  priceSource: string;
  timestamp: string;
}

export interface LedgerEntry {
  id: string;
  userId: string;
  paperAccountId: string;
  orderId?: string;
  type: LedgerEntryType;
  amount: number;
  balanceAfter: number;
  description: string;
  timestamp: string;
}

// ==========================================
// Zod Validation Schemas
// ==========================================
export const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  displayName: z.string().min(2),
  startingCapital: z.number().min(10000).max(100000000).default(1000000),
});

export const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const SubmitOrderSchema = z.object({
  symbol: z.string().min(1).trim().toUpperCase(),
  exchange: z.enum(['NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).default('NSE'),
  side: z.enum(['BUY', 'SELL']),
  orderType: z.enum(['MARKET', 'LIMIT', 'SL', 'SL_M']),
  product: z.enum(['CNC', 'MIS']).default('CNC'),
  quantity: z.number().int().positive('Quantity must be at least 1'),
  limitPrice: z.number().positive().optional(),
  triggerPrice: z.number().positive().optional(),
  idempotencyKey: z.string().optional(),
});

export const CancelOrderSchema = z.object({
  reason: z.string().optional(),
});

export const CandlesQuerySchema = z.object({
  interval: z.enum(['1m', '5m', '15m', '1h', '1d', '1w']).default('15m'),
  limit: z.coerce.number().int().min(1).max(500).default(100),
});

export const AiAnalysisRequestSchema = z.object({
  symbol: z.string().min(1),
  prompt: z.string().min(3),
});

export const ExplainConceptSchema = z.object({
  concept: z.string().min(2).max(100).trim(),
  context: z.string().max(500).optional(),
});

export const TradeRiskAnalysisSchema = z.object({
  symbol: z.string().min(1).trim().toUpperCase(),
  exchange: z.enum(['NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).default('NSE'),
  side: z.enum(['BUY', 'SELL']),
  orderType: z.enum(['MARKET', 'LIMIT', 'SL', 'SL_M']),
  product: z.enum(['CNC', 'MIS']).default('CNC'),
  quantity: z.number().int().positive('Quantity must be positive'),
  price: z.number().positive('Price must be positive'),
});

export interface ExplainConceptResponse {
  concept: string;
  simpleExplanation: string;
  keyTakeaways: string[];
  bullishScenario?: string;
  bearishScenario?: string;
  riskFactors: string[];
  isAiGenerated: true;
  disclaimer: string;
}

export interface TradeRiskAnalysisResponse {
  symbol: string;
  turnover: number;
  estimatedMargin: number;
  estimatedFees: {
    brokerage: number;
    stt: number;
    exchangeFee: number;
    gst: number;
    totalFees: number;
  };
  slippageAssumption: string;
  downsideRisk: string;
  bullishScenario: string;
  bearishScenario: string;
  riskScore: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  summary: string;
  isAiGenerated: true;
  disclaimer: string;
}

export interface PortfolioReviewResponse {
  totalValue: number;
  holdingsCount: number;
  concentrationRisk: {
    topAsset: string;
    topAssetWeight: number;
    isConcentrated: boolean;
    advice: string;
  };
  assetClassDistribution: Record<string, number>;
  volatilityAssessment: 'CONSERVATIVE' | 'MODERATE' | 'AGGRESSIVE';
  recommendations: string[];
  isAiGenerated: true;
  disclaimer: string;
}

export interface NewsArticle {
  id: string;
  title: string;
  source: string;
  category: string;
  summary: string;
  sentiment: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
  publishedAt: string;
  disclaimer: string;
}

export interface NewsSummaryResponse {
  marketMood: string;
  articles: NewsArticle[];
  isAiGenerated: true;
  disclaimer: string;
}

// ==========================================
// Community & Messaging
// ==========================================
export interface CommunityRoom {
  id: string;
  roomId: string;
  name: string;
  description: string;
  category: 'GENERAL' | 'EQUITIES' | 'COMMODITIES' | 'CRYPTO' | 'AI_INSIGHTS';
  symbol?: string;
  memberCount: number;
  isPrivate: boolean;
}

export interface CommunityMessage {
  id: string;
  roomId: string;
  userId: string;
  authorName: string;
  content: string;
  type: 'CHAT' | 'EDUCATIONAL' | 'AI_SUMMARY' | 'SYSTEM';
  tradeTag?: string;
  sentiment?: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
  likesCount: number;
  isAiGenerated: boolean;
  createdAt: string;
}

export const CreatePostSchema = z.object({
  title: z.string().min(3).max(150),
  content: z.string().min(10).max(2000),
  symbolTag: z.string().optional(),
});

export const CreateMessageSchema = z.object({
  content: z.string().min(1).max(1000).trim(),
  type: z.enum(['CHAT', 'EDUCATIONAL', 'AI_SUMMARY']).default('CHAT'),
  tradeTag: z.string().max(100).optional(),
  sentiment: z.enum(['BULLISH', 'BEARISH', 'NEUTRAL']).optional(),
});

export const SendMessageSchema = z.object({
  roomId: z.string().min(1),
  content: z.string().min(1).max(1000),
});
