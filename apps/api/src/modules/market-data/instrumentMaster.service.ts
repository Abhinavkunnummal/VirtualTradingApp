import mongoose from 'mongoose';
import { z } from 'zod';
import { Instrument, IInstrument, AssetClass, Exchange } from '../../models/Instrument';
import { MarketQuote, CandleInterval, Candle, MarketDataService } from './marketData.service';

export const InstrumentSearchQuerySchema = z.object({
  q: z.string().optional().default(''),
  query: z.string().optional(),
  keywords: z.string().optional(),
  type: z.string().optional().default('ALL'),
  category: z.string().optional().default('ALL'),
  exchange: z.string().optional().default('ALL'),
  page: z.coerce.number().int().min(1).default(1),
  cursor: z.coerce.number().int().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

export type InstrumentSearchQuery = z.infer<typeof InstrumentSearchQuerySchema>;

export interface SearchOptions {
  query?: string;
  type?: string;
  category?: string;
  exchange?: string;
  page?: number;
  cursor?: number;
  limit?: number;
}

export interface SearchResult {
  success: boolean;
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  instruments: Array<{
    symbol: string;
    name: string;
    exchange: Exchange;
    category: AssetClass;
    segment?: string;
    isin?: string;
    lotSize: number;
    tickSize: number;
    price: number;
    basePrice: number;
    change: number;
    changePercent: number;
    isPositive: boolean;
    currency: string;
    isSimulated: boolean;
    nav?: number;
    fundHouse?: string;
    schemeCode?: string;
  }>;
}

export interface NormalizedInstrument {
  instrumentId: string;
  symbol: string;
  displayName: string;
  assetClass: AssetClass;
  exchange: Exchange;
  quoteCurrency: string;
  tickSize: number;
  lotSize: number;
  basePrice: number;
  isin?: string;
  segment: string;
  tradingStatus: 'ACTIVE' | 'HALTED' | 'CLOSED';
  aliases?: string[];
  popularity?: number;
  nav?: number;
  fundHouse?: string;
  schemeCode?: string;
}

/**
 * Hardcoded official public sources with optional environment variable overrides.
 */
export const DEFAULT_DATA_SOURCES = {
  NSE_EQUITY_URL: process.env.NSE_EQUITY_URL || 'https://archives.nseindia.com/content/equities/EQUITY_L.csv',
  NASDAQ_TRADER_URL: process.env.NASDAQ_TRADER_URL || 'https://www.nasdaqtrader.com/dynamic/symdir/nasdaqtraded.txt',
  BINANCE_INFO_URL: process.env.BINANCE_INFO_URL || 'https://api.binance.com/api/v3/exchangeInfo?permissions=SPOT',
  AMFI_NAV_URL: process.env.AMFI_NAV_URL || 'https://www.amfiindia.com/spages/NAVAll.txt',
  BROKER_MASTER_URL: process.env.BROKER_MASTER_URL || process.env.INSTRUMENT_MASTER_URL || '',
};

/**
 * Common search alias & colloquial mapping dictionary.
 */
export const ALIAS_MAP: Record<string, string[]> = {
  vi: ['IDEA'],
  vodafone: ['IDEA'],
  idea: ['IDEA'],
  'vodafone idea': ['IDEA'],
  knr: ['KNRCON'],
  'knr constructions': ['KNRCON'],
  knrcon: ['KNRCON'],
  yes: ['YESBANK'],
  'yes bank': ['YESBANK'],
  yesbank: ['YESBANK'],
  jio: ['JIOFIN'],
  'jio financial': ['JIOFIN'],
  'jio financial services': ['JIOFIN'],
  jiofin: ['JIOFIN'],
  reliance: ['RELIANCE'],
  ril: ['RELIANCE'],
  tcs: ['TCS'],
  'tata motors': ['TATAMOTORS'],
  tatamotors: ['TATAMOTORS'],
  sbi: ['SBIN'],
  'state bank': ['SBIN'],
  'state bank of india': ['SBIN'],
  hdfc: ['HDFCBANK'],
  'hdfc bank': ['HDFCBANK'],
  icici: ['ICICIBANK'],
  'icici bank': ['ICICIBANK'],
  kotak: ['KOTAKBANK'],
  'kotak bank': ['KOTAKBANK'],
  airtel: ['BHARTIARTL'],
  bharti: ['BHARTIARTL'],
  lt: ['LT'],
  'l&t': ['LT'],
  larsen: ['LT'],
  btc: ['BTC/USDT', 'BTCUSDT'],
  bitcoin: ['BTC/USDT', 'BTCUSDT'],
  eth: ['ETH/USDT', 'ETHUSDT'],
  ethereum: ['ETH/USDT', 'ETHUSDT'],
  sol: ['SOL/USDT', 'SOLUSDT'],
  solana: ['SOL/USDT', 'SOLUSDT'],
  doge: ['DOGE/USDT', 'DOGEUSDT'],
  dogecoin: ['DOGE/USDT', 'DOGEUSDT'],
  apple: ['AAPL'],
  aapl: ['AAPL'],
  nvidia: ['NVDA'],
  nvda: ['NVDA'],
  google: ['GOOGL', 'GOOG'],
  microsoft: ['MSFT'],
  msft: ['MSFT'],
  tesla: ['TSLA'],
  tsla: ['TSLA'],
  amazon: ['AMZN'],
  amzn: ['AMZN'],
  meta: ['META'],
  facebook: ['META'],
  netflix: ['NFLX'],
  // Commodities & Futures
  gold: ['GOLD', 'GOLD 1KG', 'GOLDFUT'],
  'gold 1kg': ['GOLD 1KG', 'GOLD'],
  'gold fut': ['GOLDFUT'],
  silver: ['SILVER', 'SILVER 30KG', 'SILVERFUT'],
  'silver 30kg': ['SILVER 30KG', 'SILVER'],
  'silver fut': ['SILVERFUT'],
  crude: ['CRUDEOIL', 'CRUDEOILFUT'],
  crudeoil: ['CRUDEOIL', 'CRUDEOILFUT'],
  'crude oil': ['CRUDEOIL', 'CRUDEOILFUT'],
  'crude oil fut': ['CRUDEOILFUT'],
  naturalgas: ['NATURALGAS', 'NATGASFUT'],
  'natural gas': ['NATURALGAS', 'NATGASFUT'],
  natgas: ['NATURALGAS', 'NATGASFUT'],
  // Indian IPOs
  swiggy: ['SWIGGY'],
  'swiggy ipo': ['SWIGGY'],
  hyundai: ['HYUNDAI'],
  'hyundai ipo': ['HYUNDAI'],
  ntpcgreen: ['NTPCGREEN'],
  'ntpc green': ['NTPCGREEN'],
  ipo: ['SWIGGY', 'HYUNDAI', 'NTPCGREEN'],
  // Mutual Funds
  axis_bluechip: ['AXIS_BLUECHIP', '120465'],
  'axis bluechip': ['AXIS_BLUECHIP', '120465'],
  hdfc_top100: ['HDFC_TOP100', '101206'],
  'hdfc top 100': ['HDFC_TOP100', '101206'],
  nippon_smallcap: ['NIPPON_SMALLCAP', '118989'],
  'nippon small cap': ['NIPPON_SMALLCAP', '118989'],
  sbi_contra: ['SBI_CONTRA', '100377'],
  'sbi contra': ['SBI_CONTRA', '100377'],
  '120465': ['AXIS_BLUECHIP'],
  '101206': ['HDFC_TOP100'],
  '118989': ['NIPPON_SMALLCAP'],
  '100377': ['SBI_CONTRA'],
  mf: ['AXIS_BLUECHIP', 'HDFC_TOP100', 'NIPPON_SMALLCAP', 'SBI_CONTRA'],
  'mutual fund': ['AXIS_BLUECHIP', 'HDFC_TOP100', 'NIPPON_SMALLCAP', 'SBI_CONTRA'],
};

/**
 * Curated master baseline with dual-listings, major indices, ETFs, commodities, crypto, US, and MFs.
 */
export const CURATED_INSTRUMENTS: NormalizedInstrument[] = [
  // --- Indian Indices ---
  { instrumentId: 'NSE:NIFTY 50', symbol: 'NIFTY 50', displayName: 'Nifty 50 Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 50, basePrice: 24852.15, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 1000 },
  { instrumentId: 'NSE:BANKNIFTY', symbol: 'BANKNIFTY', displayName: 'Nifty Bank Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 15, basePrice: 51820.00, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 950 },
  { instrumentId: 'NSE:FINNIFTY', symbol: 'FINNIFTY', displayName: 'Nifty Financial Services Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 40, basePrice: 23450.00, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 800 },
  { instrumentId: 'NSE:MIDCPNIFTY', symbol: 'MIDCPNIFTY', displayName: 'Nifty Midcap Select Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 75, basePrice: 12840.00, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 750 },
  { instrumentId: 'BSE:SENSEX', symbol: 'SENSEX', displayName: 'BSE Sensex Index', assetClass: 'INDEX', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 10, basePrice: 81420.30, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 980 },
  { instrumentId: 'BSE:BANKEX', symbol: 'BANKEX', displayName: 'BSE Bankex Index', assetClass: 'INDEX', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 15, basePrice: 58920.00, segment: 'INDICES', tradingStatus: 'ACTIVE', popularity: 700 },

  // --- Indian ETFs ---
  { instrumentId: 'NSE:NIFTYBEES', symbol: 'NIFTYBEES', displayName: 'Nippon India ETF Nifty 50 BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 272.50, isin: 'INF204KB14I2', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 600 },
  { instrumentId: 'NSE:BANKBEES', symbol: 'BANKBEES', displayName: 'Nippon India ETF Nifty Bank BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 535.10, isin: 'INF204KB1476', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 580 },
  { instrumentId: 'NSE:GOLDBEES', symbol: 'GOLDBEES', displayName: 'Nippon India ETF Gold BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 65.40, isin: 'INF204KB17I9', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 550 },
  { instrumentId: 'NSE:SILVERBEES', symbol: 'SILVERBEES', displayName: 'Nippon India ETF Silver BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 91.20, isin: 'INF204KB18I7', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 520 },
  { instrumentId: 'NSE:ITBEES', symbol: 'ITBEES', displayName: 'Nippon India ETF Nifty IT', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 42.15, isin: 'INF204KB19I5', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 500 },
  { instrumentId: 'NSE:JUNIORBEES', symbol: 'JUNIORBEES', displayName: 'Nippon India ETF Nifty Next 50', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 725.00, isin: 'INF204KB15I9', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 480 },
  { instrumentId: 'NSE:MON100', symbol: 'MON100', displayName: 'Motilal Oswal Nasdaq 100 ETF', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 178.60, isin: 'INF247L01AU4', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 450 },
  { instrumentId: 'NSE:CPSEETF', symbol: 'CPSEETF', displayName: 'CPSE Central Public Sector ETF', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 94.30, isin: 'INF582M01011', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 420 },

  // --- Top Dual-Listed Indian Equities (NSE + BSE) ---
  // RELIANCE
  { instrumentId: 'NSE:RELIANCE', symbol: 'RELIANCE', displayName: 'Reliance Industries Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2945.50, isin: 'INE002A01018', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 990, aliases: ['ril', 'reliance'] },
  { instrumentId: 'BSE:RELIANCE', symbol: 'RELIANCE', displayName: 'Reliance Industries Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2945.00, isin: 'INE002A01018', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 920, aliases: ['ril', 'reliance'] },

  // TCS
  { instrumentId: 'NSE:TCS', symbol: 'TCS', displayName: 'Tata Consultancy Services Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4120.00, isin: 'INE467B01029', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 980, aliases: ['tcs'] },
  { instrumentId: 'BSE:TCS', symbol: 'TCS', displayName: 'Tata Consultancy Services Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4118.50, isin: 'INE467B01029', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 910, aliases: ['tcs'] },

  // HDFCBANK
  { instrumentId: 'NSE:HDFCBANK', symbol: 'HDFCBANK', displayName: 'HDFC Bank Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1720.80, isin: 'INE040A01034', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 970, aliases: ['hdfc', 'hdfc bank'] },
  { instrumentId: 'BSE:HDFCBANK', symbol: 'HDFCBANK', displayName: 'HDFC Bank Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1720.00, isin: 'INE040A01034', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 900, aliases: ['hdfc', 'hdfc bank'] },

  // INFY
  { instrumentId: 'NSE:INFY', symbol: 'INFY', displayName: 'Infosys Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1885.20, isin: 'INE009A01021', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 960, aliases: ['infy', 'infosys'] },
  { instrumentId: 'BSE:INFY', symbol: 'INFY', displayName: 'Infosys Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1884.50, isin: 'INE009A01021', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 890, aliases: ['infy', 'infosys'] },

  // ICICIBANK
  { instrumentId: 'NSE:ICICIBANK', symbol: 'ICICIBANK', displayName: 'ICICI Bank Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1260.40, isin: 'INE090A01021', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 950, aliases: ['icici', 'icici bank'] },
  { instrumentId: 'BSE:ICICIBANK', symbol: 'ICICIBANK', displayName: 'ICICI Bank Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1260.00, isin: 'INE090A01021', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 880, aliases: ['icici', 'icici bank'] },

  // SBIN
  { instrumentId: 'NSE:SBIN', symbol: 'SBIN', displayName: 'State Bank of India', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 815.75, isin: 'INE062A01020', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 940, aliases: ['sbi', 'state bank'] },
  { instrumentId: 'BSE:SBIN', symbol: 'SBIN', displayName: 'State Bank of India', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 815.20, isin: 'INE062A01020', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 870, aliases: ['sbi', 'state bank'] },

  // TATAMOTORS
  { instrumentId: 'NSE:TATAMOTORS', symbol: 'TATAMOTORS', displayName: 'Tata Motors Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 960.50, isin: 'INE155A01022', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 930, aliases: ['tata motors', 'tatamotors'] },
  { instrumentId: 'BSE:TATAMOTORS', symbol: 'TATAMOTORS', displayName: 'Tata Motors Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 960.00, isin: 'INE155A01022', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 860, aliases: ['tata motors', 'tatamotors'] },

  // JIOFIN (Jio Financial Services) - NSE & BSE
  { instrumentId: 'NSE:JIOFIN', symbol: 'JIOFIN', displayName: 'Jio Financial Services Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 320.00, isin: 'INE758E01017', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 920, aliases: ['jio', 'jio financial', 'jio financial services', 'jiofin'] },
  { instrumentId: 'BSE:JIOFIN', symbol: 'JIOFIN', displayName: 'Jio Financial Services Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 319.80, isin: 'INE758E01017', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 850, aliases: ['jio', 'jio financial', 'jio financial services', 'jiofin'] },

  // YESBANK (Yes Bank Limited) - NSE & BSE
  { instrumentId: 'NSE:YESBANK', symbol: 'YESBANK', displayName: 'Yes Bank Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 20.45, isin: 'INE528G01035', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 910, aliases: ['yes', 'yes bank', 'yesbank'] },
  { instrumentId: 'BSE:YESBANK', symbol: 'YESBANK', displayName: 'Yes Bank Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 20.42, isin: 'INE528G01035', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 840, aliases: ['yes', 'yes bank', 'yesbank'] },

  // IDEA (Vodafone Idea Limited / Vi) - NSE & BSE
  { instrumentId: 'NSE:IDEA', symbol: 'IDEA', displayName: 'Vodafone Idea Limited (Vi)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 8.45, isin: 'INE669E01016', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 900, aliases: ['vi', 'vodafone', 'idea', 'vodafone idea'] },
  { instrumentId: 'BSE:IDEA', symbol: 'IDEA', displayName: 'Vodafone Idea Limited (Vi)', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 8.44, isin: 'INE669E01016', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 830, aliases: ['vi', 'vodafone', 'idea', 'vodafone idea'] },

  // KNRCON (KNR Constructions Limited) - NSE & BSE
  { instrumentId: 'NSE:KNRCON', symbol: 'KNRCON', displayName: 'KNR Constructions Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 335.20, isin: 'INE634I01029', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 880, aliases: ['knr', 'knr constructions', 'knrcon'] },
  { instrumentId: 'BSE:KNRCON', symbol: 'KNRCON', displayName: 'KNR Constructions Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 334.80, isin: 'INE634I01029', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 810, aliases: ['knr', 'knr constructions', 'knrcon'] },

  // Other Top Indian Equities
  { instrumentId: 'NSE:BAJFINANCE', symbol: 'BAJFINANCE', displayName: 'Bajaj Finance Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6850.00, isin: 'INE296A01024', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 850 },
  { instrumentId: 'NSE:BHARTIARTL', symbol: 'BHARTIARTL', displayName: 'Bharti Airtel Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1680.00, isin: 'INE397D01024', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 840, aliases: ['airtel', 'bharti'] },
  { instrumentId: 'NSE:ITC', symbol: 'ITC', displayName: 'ITC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 485.50, isin: 'INE154A01025', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 830 },
  { instrumentId: 'NSE:LT', symbol: 'LT', displayName: 'Larsen & Toubro Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 3560.00, isin: 'INE018A01030', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 820, aliases: ['lt', 'l&t', 'larsen'] },
  { instrumentId: 'NSE:HINDUNILVR', symbol: 'HINDUNILVR', displayName: 'Hindustan Unilever Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2420.00, isin: 'INE030A01027', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 810 },
  { instrumentId: 'NSE:KOTAKBANK', symbol: 'KOTAKBANK', displayName: 'Kotak Mahindra Bank Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1780.00, isin: 'INE237A01028', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 800 },
  { instrumentId: 'NSE:MARUTI', symbol: 'MARUTI', displayName: 'Maruti Suzuki India Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 11450.00, isin: 'INE585B01010', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 790 },
  { instrumentId: 'NSE:SUNPHARMA', symbol: 'SUNPHARMA', displayName: 'Sun Pharmaceutical Industries', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1820.00, isin: 'INE044A01036', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 780 },
  { instrumentId: 'NSE:WIPRO', symbol: 'WIPRO', displayName: 'Wipro Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 540.00, isin: 'INE075A01022', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 770 },
  { instrumentId: 'NSE:TITAN', symbol: 'TITAN', displayName: 'Titan Company Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 3320.00, isin: 'INE280A01028', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 760 },
  { instrumentId: 'NSE:TATASTEEL', symbol: 'TATASTEEL', displayName: 'Tata Steel Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 152.00, isin: 'INE081A01020', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 750 },
  { instrumentId: 'NSE:AXISBANK', symbol: 'AXISBANK', displayName: 'Axis Bank Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1180.00, isin: 'INE238A01034', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 740 },
  { instrumentId: 'NSE:ZOMATO', symbol: 'ZOMATO', displayName: 'Zomato Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 265.00, isin: 'INE758T01015', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 730 },

  // Adani Group
  { instrumentId: 'NSE:ADANIENT', symbol: 'ADANIENT', displayName: 'Adani Enterprises Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2840.00, isin: 'INE423A01024', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 750 },
  { instrumentId: 'NSE:ADANIPORTS', symbol: 'ADANIPORTS', displayName: 'Adani Ports and SEZ Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1360.50, isin: 'INE742F01042', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 740 },
  { instrumentId: 'NSE:ADANIGREEN', symbol: 'ADANIGREEN', displayName: 'Adani Green Energy Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1580.00, isin: 'INE364U01010', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 720 },
  { instrumentId: 'NSE:ATGL', symbol: 'ATGL', displayName: 'Adani Total Gas Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 720.00, isin: 'INE399L01023', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 700 },
  { instrumentId: 'NSE:ADANIPOWER', symbol: 'ADANIPOWER', displayName: 'Adani Power Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 590.00, isin: 'INE814H01011', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 710 },
  { instrumentId: 'NSE:AMBUJACEM', symbol: 'AMBUJACEM', displayName: 'Ambuja Cements Ltd. (Adani)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 560.00, isin: 'INE079A01024', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 690 },

  // Additional PSU / Growth
  { instrumentId: 'NSE:BEL', symbol: 'BEL', displayName: 'Bharat Electronics Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 295.40, isin: 'INE263A01024', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 680 },
  { instrumentId: 'NSE:HAL', symbol: 'HAL', displayName: 'Hindustan Aeronautics Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4420.00, isin: 'INE066F01012', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 670 },
  { instrumentId: 'NSE:BHEL', symbol: 'BHEL', displayName: 'Bharat Heavy Electricals Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 238.10, isin: 'INE257A01026', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 650 },
  { instrumentId: 'NSE:COALINDIA', symbol: 'COALINDIA', displayName: 'Coal India Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 445.00, isin: 'INE522F01014', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 640 },
  { instrumentId: 'NSE:NTPC', symbol: 'NTPC', displayName: 'NTPC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 410.50, isin: 'INE733E01010', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 630 },
  { instrumentId: 'NSE:ONGC', symbol: 'ONGC', displayName: 'Oil & Natural Gas Corp Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 275.00, isin: 'INE213A01029', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 620 },
  { instrumentId: 'NSE:POWERGRID', symbol: 'POWERGRID', displayName: 'Power Grid Corporation of India', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 325.00, isin: 'INE752E01010', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 610 },
  { instrumentId: 'NSE:RECLTD', symbol: 'RECLTD', displayName: 'REC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 520.00, isin: 'INE020B01018', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 600 },
  { instrumentId: 'NSE:PFC', symbol: 'PFC', displayName: 'Power Finance Corporation', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 478.00, isin: 'INE134E01011', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 590 },
  { instrumentId: 'NSE:TRENT', symbol: 'TRENT', displayName: 'Trent Limited (Tata Group)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6950.00, isin: 'INE849A01020', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 720 },

  // BSE Exclusives
  { instrumentId: 'BSE:BSE', symbol: 'BSE', displayName: 'BSE Limited (Exchange)', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4720.00, isin: 'INE118H01025', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 750 },
  { instrumentId: 'BSE:CDSL', symbol: 'CDSL', displayName: 'Central Depository Services Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1480.00, isin: 'INE736A01011', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 740 },
  { instrumentId: 'BSE:POLYCAB', symbol: 'POLYCAB', displayName: 'Polycab India Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6850.00, isin: 'INE455K01017', segment: 'EQ', tradingStatus: 'ACTIVE', popularity: 710 },

  // MCX Commodities & Current-Month Futures Contracts
  { instrumentId: 'MCX:GOLD', symbol: 'GOLD', displayName: 'MCX Gold Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 1, basePrice: 78450.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 820, aliases: ['gold', 'gold 1kg'] },
  { instrumentId: 'MCX:GOLD 1KG', symbol: 'GOLD 1KG', displayName: 'MCX Gold Futures 1KG', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 1, basePrice: 78450.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 800, aliases: ['gold', 'gold 1kg'] },
  { instrumentId: 'MCX:GOLDFUT', symbol: 'GOLDFUT', displayName: 'MCX Gold Current-Month Futures (Nov 2024)', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 1, basePrice: 78520.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 790, aliases: ['gold fut', 'goldfut'] },
  { instrumentId: 'MCX:SILVER', symbol: 'SILVER', displayName: 'MCX Silver Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 30, basePrice: 94200.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 790, aliases: ['silver', 'silver 30kg'] },
  { instrumentId: 'MCX:SILVER 30KG', symbol: 'SILVER 30KG', displayName: 'MCX Silver Futures 30KG', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 30, basePrice: 94200.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 780, aliases: ['silver', 'silver 30kg'] },
  { instrumentId: 'MCX:SILVERFUT', symbol: 'SILVERFUT', displayName: 'MCX Silver Current-Month Futures (Dec 2024)', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 30, basePrice: 94350.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 770, aliases: ['silver fut', 'silverfut'] },
  { instrumentId: 'MCX:CRUDEOIL', symbol: 'CRUDEOIL', displayName: 'MCX Crude Oil 100 BBL', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 100, basePrice: 6120.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 810, aliases: ['crude', 'crudeoil', 'crude oil'] },
  { instrumentId: 'MCX:CRUDEOILFUT', symbol: 'CRUDEOILFUT', displayName: 'MCX Crude Oil Current-Month Futures (Nov 2024)', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 100, basePrice: 6135.00, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 800, aliases: ['crude fut', 'crudeoil fut'] },
  { instrumentId: 'MCX:NATURALGAS', symbol: 'NATURALGAS', displayName: 'MCX Natural Gas Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 0.1, lotSize: 1250, basePrice: 245.80, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 750, aliases: ['naturalgas', 'natgas'] },
  { instrumentId: 'MCX:NATGASFUT', symbol: 'NATGASFUT', displayName: 'MCX Natural Gas Current-Month Futures (Nov 2024)', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 0.1, lotSize: 1250, basePrice: 246.50, segment: 'COM', tradingStatus: 'ACTIVE', popularity: 740, aliases: ['natural gas fut', 'natgasfut'] },

  // Indian IPOs (Current & Upcoming Listings)
  { instrumentId: 'NSE:SWIGGY', symbol: 'SWIGGY', displayName: 'Swiggy Limited IPO', assetClass: 'IPO', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 38, basePrice: 390.00, segment: 'IPO', tradingStatus: 'ACTIVE', popularity: 890, aliases: ['swiggy', 'swiggy ipo'] },
  { instrumentId: 'NSE:HYUNDAI', symbol: 'HYUNDAI', displayName: 'Hyundai Motor India Ltd IPO', assetClass: 'IPO', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 7, basePrice: 1960.00, segment: 'IPO', tradingStatus: 'ACTIVE', popularity: 870, aliases: ['hyundai', 'hyundai ipo'] },
  { instrumentId: 'NSE:NTPCGREEN', symbol: 'NTPCGREEN', displayName: 'NTPC Green Energy Ltd IPO', assetClass: 'IPO', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 138, basePrice: 108.00, segment: 'IPO', tradingStatus: 'ACTIVE', popularity: 850, aliases: ['ntpc green', 'ntpcgreen', 'ntpc ipo'] },

  // Crypto 24/7 Spot Pairs
  { instrumentId: 'CRYPTO:BTC/USDT', symbol: 'BTC/USDT', displayName: 'Bitcoin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 77568.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 999, aliases: ['btc', 'bitcoin'] },
  { instrumentId: 'CRYPTO:ETH/USDT', symbol: 'ETH/USDT', displayName: 'Ethereum 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 2540.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 950, aliases: ['eth', 'ethereum'] },
  { instrumentId: 'CRYPTO:SOL/USDT', symbol: 'SOL/USDT', displayName: 'Solana 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 178.50, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 900, aliases: ['sol', 'solana'] },
  { instrumentId: 'CRYPTO:DOGE/USDT', symbol: 'DOGE/USDT', displayName: 'Dogecoin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.0001, lotSize: 1, basePrice: 0.165, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 850, aliases: ['doge', 'dogecoin'] },
  { instrumentId: 'CRYPTO:BNB/USDT', symbol: 'BNB/USDT', displayName: 'Binance Coin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 595.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 820 },
  { instrumentId: 'CRYPTO:XRP/USDT', symbol: 'XRP/USDT', displayName: 'Ripple 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.001, lotSize: 1, basePrice: 0.54, segment: 'CRYPTO', tradingStatus: 'ACTIVE', popularity: 800 },

  // US Equities & ETFs
  { instrumentId: 'US:AAPL', symbol: 'AAPL', displayName: 'Apple Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 231.41, isin: 'US0378331005', segment: 'US', tradingStatus: 'ACTIVE', popularity: 980, aliases: ['apple', 'aapl'] },
  { instrumentId: 'US:NVDA', symbol: 'NVDA', displayName: 'NVIDIA Corporation', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 141.54, isin: 'US67066G1040', segment: 'US', tradingStatus: 'ACTIVE', popularity: 975, aliases: ['nvidia', 'nvda'] },
  { instrumentId: 'US:MSFT', symbol: 'MSFT', displayName: 'Microsoft Corporation', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 428.15, isin: 'US5949181045', segment: 'US', tradingStatus: 'ACTIVE', popularity: 960, aliases: ['microsoft', 'msft'] },
  { instrumentId: 'US:TSLA', symbol: 'TSLA', displayName: 'Tesla Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 258.40, isin: 'US88160R1014', segment: 'US', tradingStatus: 'ACTIVE', popularity: 955, aliases: ['tesla', 'tsla'] },
  { instrumentId: 'US:GOOGL', symbol: 'GOOGL', displayName: 'Alphabet Inc. Class A', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 172.50, isin: 'US02079K3059', segment: 'US', tradingStatus: 'ACTIVE', popularity: 940, aliases: ['google'] },
  { instrumentId: 'US:AMZN', symbol: 'AMZN', displayName: 'Amazon.com Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 188.20, isin: 'US0231351067', segment: 'US', tradingStatus: 'ACTIVE', popularity: 930, aliases: ['amazon'] },
  { instrumentId: 'US:META', symbol: 'META', displayName: 'Meta Platforms Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 582.00, isin: 'US30303M1027', segment: 'US', tradingStatus: 'ACTIVE', popularity: 920, aliases: ['meta', 'facebook'] },
  { instrumentId: 'US:NFLX', symbol: 'NFLX', displayName: 'Netflix Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 760.00, isin: 'US64110L1061', segment: 'US', tradingStatus: 'ACTIVE', popularity: 900, aliases: ['netflix'] },
  { instrumentId: 'US:AMD', symbol: 'AMD', displayName: 'Advanced Micro Devices', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 155.00, isin: 'US0079031078', segment: 'US', tradingStatus: 'ACTIVE', popularity: 880, aliases: ['amd'] },
  { instrumentId: 'US:COIN', symbol: 'COIN', displayName: 'Coinbase Global Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 215.00, isin: 'US19260Q1076', segment: 'US', tradingStatus: 'ACTIVE', popularity: 850 },
  { instrumentId: 'US:SPY', symbol: 'SPY', displayName: 'SPDR S&P 500 ETF Trust', assetClass: 'ETF', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 586.46, isin: 'US78462F1030', segment: 'US', tradingStatus: 'ACTIVE', popularity: 910 },
  { instrumentId: 'US:QQQ', symbol: 'QQQ', displayName: 'Invesco QQQ Trust (Nasdaq 100)', assetClass: 'ETF', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 492.30, isin: 'US46090E1038', segment: 'US', tradingStatus: 'ACTIVE', popularity: 890 },

  // AMFI Mutual Funds
  { instrumentId: 'AMFI:120465', symbol: 'AXIS_BLUECHIP', displayName: 'Axis Bluechip Fund - Direct Plan - Growth', assetClass: 'MUTUAL_FUND', exchange: 'AMFI', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 62.45, isin: 'INF846K01DP8', segment: 'MF', tradingStatus: 'ACTIVE', popularity: 820, nav: 62.45, fundHouse: 'Axis Mutual Fund', schemeCode: '120465' },
  { instrumentId: 'AMFI:101206', symbol: 'HDFC_TOP100', displayName: 'HDFC Top 100 Fund - Growth Option', assetClass: 'MUTUAL_FUND', exchange: 'AMFI', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 1045.30, isin: 'INF179K01BE2', segment: 'MF', tradingStatus: 'ACTIVE', popularity: 810, nav: 1045.30, fundHouse: 'HDFC Mutual Fund', schemeCode: '101206' },
  { instrumentId: 'AMFI:118989', symbol: 'NIPPON_SMALLCAP', displayName: 'Nippon India Small Cap Fund - Growth Plan', assetClass: 'MUTUAL_FUND', exchange: 'AMFI', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 165.20, isin: 'INF204K01T23', segment: 'MF', tradingStatus: 'ACTIVE', popularity: 800, nav: 165.20, fundHouse: 'Nippon India Mutual Fund', schemeCode: '118989' },
  { instrumentId: 'AMFI:100377', symbol: 'SBI_CONTRA', displayName: 'SBI Contra Fund - Regular Plan - Growth', assetClass: 'MUTUAL_FUND', exchange: 'AMFI', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 382.15, isin: 'INF200K01460', segment: 'MF', tradingStatus: 'ACTIVE', popularity: 790, nav: 382.15, fundHouse: 'SBI Mutual Fund', schemeCode: '100377' },
];

export class InstrumentMasterService {
  private static isInitialized = false;
  private static lastSyncTimestamp: Date | null = null;
  private static syncIntervalTimer: NodeJS.Timeout | null = null;
  private static isSyncing = false;

  // In-memory lookup map for instant exact resolution (pre-seeded with curated baseline)
  private static memoryCatalog = new Map<string, NormalizedInstrument>(
    CURATED_INSTRUMENTS.flatMap((item) => [
      [item.symbol.toUpperCase(), item] as [string, NormalizedInstrument],
      [`${item.exchange}:${item.symbol}`.toUpperCase(), item] as [string, NormalizedInstrument],
      [item.instrumentId.toUpperCase(), item] as [string, NormalizedInstrument],
    ])
  );

  /**
   * Initializes the service, populates in-memory catalog, and triggers sync if collection has < 1000 items.
   */
  public static async init(): Promise<void> {
    if (this.isInitialized) return;

    // Load curated baseline into memory immediately
    this.populateMemoryCatalog(CURATED_INSTRUMENTS);

    // Check database state and trigger initial sync if needed
    await this.ensureSeededOrSync();

    // Schedule daily sync
    this.scheduleDailySync();

    this.isInitialized = true;
  }

  private static populateMemoryCatalog(instruments: NormalizedInstrument[]): void {
    for (const item of instruments) {
      this.memoryCatalog.set(item.symbol.toUpperCase(), item);
      this.memoryCatalog.set(`${item.exchange}:${item.symbol}`.toUpperCase(), item);
      this.memoryCatalog.set(item.instrumentId.toUpperCase(), item);
      if (item.schemeCode) {
        this.memoryCatalog.set(item.schemeCode.toUpperCase(), item);
        this.memoryCatalog.set(`AMFI:${item.schemeCode}`.toUpperCase(), item);
      }
    }
  }

  /**
   * Seed curated master into MongoDB if collection is empty,
   * or trigger background ingestion if count is below 1,000 documents.
   */
  public static async ensureSeededOrSync(): Promise<number> {
    if (mongoose.connection.readyState !== 1) {
      return this.memoryCatalog.size;
    }

    try {
      const count = await Instrument.countDocuments();

      // Always persist curated baseline so newly added target instruments are present in DB
      await this.persistBatch(CURATED_INSTRUMENTS);

      if (count < 1000) {
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[InstrumentMaster] Master collection count (${count}) < 1000. Initiating background official feed ingestion...`);
          // Trigger background sync without blocking server initialization
          this.syncFromUpstream().catch((err) => {
            console.warn('[InstrumentMaster] Background initial sync encountered non-fatal error:', err.message);
          });
        }
      } else {
        console.log(`[InstrumentMaster] Master catalog already loaded with ${count} instruments. Keeping active data.`);
        // Free-tier wake-up check: verify if last sync was > 24 hours ago
        if (process.env.NODE_ENV !== 'test') {
          try {
            const newestDoc = (await Instrument.findOne().sort({ updatedAt: -1 }).select('updatedAt').lean()) as Record<string, any> | null;
            const lastUpdated = newestDoc?.updatedAt ? new Date(newestDoc.updatedAt).getTime() : 0;
            const oneDayAgo = Date.now() - (24 * 60 * 60 * 1000);
            if (lastUpdated > 0 && lastUpdated < oneDayAgo) {
              console.log('[InstrumentMaster] Last master catalog sync was > 24 hours ago. Triggering daily background refresh on wake-up...');
              this.syncFromUpstream().catch((err) => {
                console.warn('[InstrumentMaster] Wake-up daily sync notice:', err.message);
              });
            }
          } catch {
            // Ignore check error
          }
        }
      }

      // Preload active & popular instruments from MongoDB into memory catalog for O(1) lookups
      try {
        const topInstruments = await Instrument.find().sort({ popularity: -1 }).limit(2500).lean();
        for (const doc of topInstruments) {
          const item: NormalizedInstrument = {
            instrumentId: doc.instrumentId,
            symbol: doc.symbol,
            displayName: doc.displayName,
            assetClass: doc.assetClass as AssetClass,
            exchange: doc.exchange as Exchange,
            quoteCurrency: doc.quoteCurrency,
            tickSize: doc.tickSize,
            lotSize: doc.lotSize,
            basePrice: doc.basePrice,
            isin: doc.isin,
            segment: doc.segment,
            tradingStatus: (doc.tradingStatus as any) || 'ACTIVE',
            aliases: doc.aliases,
            popularity: doc.popularity,
            nav: (doc as any).nav,
            fundHouse: (doc as any).fundHouse,
            schemeCode: (doc as any).schemeCode,
          };
          this.memoryCatalog.set(item.symbol.toUpperCase(), item);
          this.memoryCatalog.set(`${item.exchange}:${item.symbol}`.toUpperCase(), item);
          this.memoryCatalog.set(item.instrumentId.toUpperCase(), item);
        }
        console.log(`[InstrumentMaster] Preloaded ${topInstruments.length} active instruments into memory catalog.`);
      } catch (e) {
        console.warn('[InstrumentMaster] Failed to preload popular instruments:', (e as Error).message);
      }

      this.lastSyncTimestamp = new Date();
      return await Instrument.countDocuments();
    } catch (err) {
      console.warn('[InstrumentMaster] Database init warning:', (err as Error).message);
      return this.memoryCatalog.size;
    }
  }

  /**
   * Persists a batch of normalized instruments to MongoDB using bulkWrite upserts.
   */
  private static async persistBatch(batch: NormalizedInstrument[]): Promise<void> {
    if (batch.length === 0 || mongoose.connection.readyState !== 1) return;

    const bulkOps = batch.map((inst) => ({
      updateOne: {
        filter: { instrumentId: inst.instrumentId },
        update: { $set: inst },
        upsert: true,
      },
    }));

    const BATCH_SIZE = 500;
    for (let i = 0; i < bulkOps.length; i += BATCH_SIZE) {
      const chunk = bulkOps.slice(i, i + BATCH_SIZE);
      await Instrument.bulkWrite(chunk, { ordered: false });
    }
  }

  /**
   * Multi-source ingestion: NSE equities + dual-listed BSE, US Nasdaq directory, Binance Spot crypto, AMFI MFs.
   * If a source fails, logs the error and keeps previous data without dropping records.
   */
  public static async syncFromUpstream(options?: {
    url?: string;
    rawData?: any[];
  }): Promise<{ count: number; source: string; details: Record<string, number> }> {
    if (this.isSyncing) {
      return { count: this.memoryCatalog.size, source: 'sync-in-progress', details: {} };
    }

    this.isSyncing = true;
    const details: Record<string, number> = { nse: 0, bse: 0, us: 0, crypto: 0, amfi: 0, custom: 0 };
    let totalIngested = 0;

    try {
      // 1. If explicit rawData is supplied (e.g. in tests)
      if (options?.rawData && Array.isArray(options.rawData)) {
        const normalized = options.rawData.map(this.normalizeRawRecord).filter((r): r is NormalizedInstrument => r !== null);
        this.populateMemoryCatalog(normalized);
        await this.persistBatch(normalized);
        details.custom = normalized.length;
        totalIngested += normalized.length;
        this.lastSyncTimestamp = new Date();
        return { count: totalIngested, source: 'provided-data', details };
      }

      // Fast-path for unit tests to prevent remote network timeouts
      if (process.env.NODE_ENV === 'test' && !options?.url) {
        this.populateMemoryCatalog(CURATED_INSTRUMENTS);
        await this.persistBatch(CURATED_INSTRUMENTS);
        this.lastSyncTimestamp = new Date();
        return {
          count: this.memoryCatalog.size,
          source: 'curated-baseline',
          details: { nse: CURATED_INSTRUMENTS.length, bse: 0, us: 0, crypto: 0, amfi: 0, custom: 0 },
        };
      }

      // 2. Fetch and ingest official public sources
      // A. NSE Equities & Dual-listed BSE
      try {
        const nseCount = await this.syncNseEquities();
        details.nse = nseCount.nse;
        details.bse = nseCount.bse;
        totalIngested += nseCount.nse + nseCount.bse;
      } catch (err: any) {
        console.warn(`[InstrumentMaster] NSE ingestion skipped/failed: ${err.message}. Retaining existing records.`);
      }

      // B. Binance Spot Crypto
      try {
        const cryptoCount = await this.syncBinanceSpot();
        details.crypto = cryptoCount;
        totalIngested += cryptoCount;
      } catch (err: any) {
        console.warn(`[InstrumentMaster] Binance Crypto ingestion skipped/failed: ${err.message}. Retaining existing records.`);
      }

      // C. US Nasdaq Trader Directory
      try {
        const usCount = await this.syncNasdaqTrader();
        details.us = usCount;
        totalIngested += usCount;
      } catch (err: any) {
        console.warn(`[InstrumentMaster] Nasdaq US ingestion skipped/failed: ${err.message}. Retaining existing records.`);
      }

      // D. AMFI Mutual Funds
      try {
        const amfiCount = await this.syncAmfiMutualFunds();
        details.amfi = amfiCount;
        totalIngested += amfiCount;
      } catch (err: any) {
        console.warn(`[InstrumentMaster] AMFI Mutual Funds ingestion skipped/failed: ${err.message}. Retaining existing records.`);
      }

      // Ensure curated baseline is always firmly seeded
      this.populateMemoryCatalog(CURATED_INSTRUMENTS);
      await this.persistBatch(CURATED_INSTRUMENTS);

      this.lastSyncTimestamp = new Date();
      return {
        count: totalIngested || this.memoryCatalog.size,
        source: 'official-public-sources',
        details,
      };
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Syncs NSE Equities CSV from official NSE archives and generates dual-listed BSE scrips.
   */
  private static async syncNseEquities(): Promise<{ nse: number; bse: number }> {
    const url = DEFAULT_DATA_SOURCES.NSE_EQUITY_URL;
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status} from ${url}`);
    }

    const text = await response.text();
    const lines = text.split('\n');
    const nseBatch: NormalizedInstrument[] = [];
    const bseBatch: NormalizedInstrument[] = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;

      const cols = line.split(',');
      if (cols.length < 7) continue;

      const symbol = cols[0].trim().toUpperCase();
      const displayName = cols[1].trim();
      const series = cols[2].trim().toUpperCase();
      const isin = cols[6].trim().toUpperCase();

      if (!symbol || !displayName) continue;
      const isEtf = symbol.includes('BEES') || symbol.includes('ETF') || displayName.toUpperCase().includes('ETF');
      const assetClass: AssetClass = isEtf ? 'ETF' : 'EQUITY';

      const nseItem: NormalizedInstrument = {
        instrumentId: `NSE:${symbol}`,
        symbol,
        displayName,
        assetClass,
        exchange: 'NSE',
        quoteCurrency: 'INR',
        tickSize: 0.05,
        lotSize: 1,
        basePrice: 100.0,
        isin: isin || undefined,
        segment: series || 'EQ',
        tradingStatus: 'ACTIVE',
      };

      const bseItem: NormalizedInstrument = {
        instrumentId: `BSE:${symbol}`,
        symbol,
        displayName,
        assetClass,
        exchange: 'BSE',
        quoteCurrency: 'INR',
        tickSize: 0.05,
        lotSize: 1,
        basePrice: 100.0,
        isin: isin || undefined,
        segment: series || 'EQ',
        tradingStatus: 'ACTIVE',
      };

      nseBatch.push(nseItem);
      bseBatch.push(bseItem);
    }

    this.populateMemoryCatalog(nseBatch);
    this.populateMemoryCatalog(bseBatch);

    await this.persistBatch(nseBatch);
    await this.persistBatch(bseBatch);

    return { nse: nseBatch.length, bse: bseBatch.length };
  }

  /**
   * Syncs spot crypto pairs from Binance exchangeInfo.
   */
  private static async syncBinanceSpot(): Promise<number> {
    const url = DEFAULT_DATA_SOURCES.BINANCE_INFO_URL;
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);

    const json = (await response.json()) as any;
    if (!json.symbols || !Array.isArray(json.symbols)) return 0;

    const cryptoBatch: NormalizedInstrument[] = [];
    for (const s of json.symbols) {
      if (s.status !== 'TRADING' || s.quoteAsset !== 'USDT') continue;

      const base = s.baseAsset.toUpperCase();
      const symbol = `${base}/USDT`;

      const item: NormalizedInstrument = {
        instrumentId: `CRYPTO:${symbol}`,
        symbol,
        displayName: `${base} 24/7 Spot Stream`,
        assetClass: 'CRYPTO',
        exchange: 'CRYPTO',
        quoteCurrency: 'USD',
        tickSize: 0.01,
        lotSize: 1,
        basePrice: 100.0,
        segment: 'CRYPTO',
        tradingStatus: 'ACTIVE',
      };
      cryptoBatch.push(item);
    }

    this.populateMemoryCatalog(cryptoBatch);
    await this.persistBatch(cryptoBatch);
    return cryptoBatch.length;
  }

  /**
   * Syncs US equities and ETFs from Nasdaq Trader Directory.
   */
  private static async syncNasdaqTrader(): Promise<number> {
    const url = DEFAULT_DATA_SOURCES.NASDAQ_TRADER_URL;
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);

    const text = await response.text();
    const lines = text.split('\n');
    const usBatch: NormalizedInstrument[] = [];

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line || line.startsWith('File Creation Time')) continue;

      const parts = line.split('|');
      if (parts.length < 6) continue;

      const symbol = parts[1].trim().toUpperCase();
      const securityName = parts[2].trim();
      const isEtf = parts[5].trim().toUpperCase() === 'Y';
      const isTest = parts[7]?.trim().toUpperCase() === 'Y';

      if (isTest || !symbol || symbol.includes('$') || symbol.includes('.')) continue;

      const item: NormalizedInstrument = {
        instrumentId: `US:${symbol}`,
        symbol,
        displayName: securityName,
        assetClass: isEtf ? 'ETF' : 'EQUITY',
        exchange: 'US',
        quoteCurrency: 'USD',
        tickSize: 0.01,
        lotSize: 1,
        basePrice: 100.0,
        segment: 'US',
        tradingStatus: 'ACTIVE',
      };
      usBatch.push(item);
    }

    this.populateMemoryCatalog(usBatch);
    await this.persistBatch(usBatch);
    return usBatch.length;
  }

  /**
   * Syncs Indian Mutual Funds from AMFI NAVAll.txt.
   */
  private static async syncAmfiMutualFunds(): Promise<number> {
    const url = DEFAULT_DATA_SOURCES.AMFI_NAV_URL;
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);

    const text = await response.text();
    const lines = text.split('\n');
    const mfBatch: NormalizedInstrument[] = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      const parts = trimmed.split(';');
      if (parts.length < 6) continue;

      const schemeCode = parts[0].trim();
      if (!/^\d+$/.test(schemeCode)) continue;

      const isin = parts[1].trim();
      const schemeName = parts[3].trim();
      const nav = parseFloat(parts[4].trim()) || 10.0;

      const item: NormalizedInstrument = {
        instrumentId: `AMFI:${schemeCode}`,
        symbol: `MF_${schemeCode}`,
        displayName: schemeName,
        assetClass: 'MUTUAL_FUND',
        exchange: 'AMFI',
        quoteCurrency: 'INR',
        tickSize: 0.01,
        lotSize: 1,
        basePrice: nav,
        nav,
        schemeCode,
        isin: isin && isin !== '-' ? isin : undefined,
        segment: 'MF',
        tradingStatus: 'ACTIVE',
      };
      mfBatch.push(item);
    }

    this.populateMemoryCatalog(mfBatch);
    await this.persistBatch(mfBatch);
    return mfBatch.length;
  }

  /**
   * Normalizes incoming raw record from external feeds (Angel One / Upstox / NSE).
   */
  public static normalizeRawRecord(raw: any): NormalizedInstrument | null {
    if (!raw || (!raw.symbol && !raw.tradingsymbol && !raw.name)) return null;

    let symbol = (raw.symbol || raw.tradingsymbol || raw.name || '').trim().toUpperCase();
    symbol = symbol.replace(/-EQ$/, '').replace(/-BE$/, '').trim();

    const displayName = (raw.displayName || raw.name || raw.formatted_name || symbol).trim();
    const rawExchange = (raw.exchange || raw.exch_seg || 'NSE').toUpperCase().trim();

    let exchange: Exchange = 'NSE';
    if (rawExchange.includes('BSE')) exchange = 'BSE';
    else if (rawExchange.includes('MCX')) exchange = 'MCX';
    else if (rawExchange.includes('CRYPTO') || rawExchange.includes('BINANCE')) exchange = 'CRYPTO';
    else if (rawExchange.includes('US') || rawExchange.includes('NASDAQ') || rawExchange.includes('NYSE')) exchange = 'US';
    else if (rawExchange.includes('AMFI') || rawExchange.includes('MF')) exchange = 'AMFI';

    let assetClass: AssetClass = 'EQUITY';
    if (raw.assetClass) {
      assetClass = raw.assetClass;
    } else if (symbol.includes('BEES') || symbol.includes('ETF') || displayName.toUpperCase().includes('ETF')) {
      assetClass = 'ETF';
    } else if (symbol.includes('NIFTY') || symbol.includes('SENSEX') || displayName.toUpperCase().includes('INDEX')) {
      assetClass = 'INDEX';
    } else if (exchange === 'MCX') {
      assetClass = 'COMMODITY';
    } else if (exchange === 'CRYPTO') {
      assetClass = 'CRYPTO';
    } else if (exchange === 'AMFI' || raw.schemeCode || displayName.toUpperCase().includes('MUTUAL FUND')) {
      assetClass = 'MUTUAL_FUND';
    }

    const lotSize = Number(raw.lotsize || raw.lot_size || raw.lotSize || 1) || 1;
    const tickSize = Number(raw.tick_size || raw.tickSize || 0.05) || 0.05;
    const basePrice = Number(raw.basePrice || raw.price || raw.close || raw.nav || 100.0) || 100.0;
    const quoteCurrency = exchange === 'US' || exchange === 'CRYPTO' ? 'USD' : 'INR';
    const isin = raw.isin || raw.isin_code || undefined;
    const segment = raw.segment || raw.instrumenttype || (exchange === 'AMFI' ? 'MF' : 'EQ');

    return {
      instrumentId: `${exchange}:${symbol}`,
      symbol,
      displayName,
      assetClass,
      exchange,
      quoteCurrency,
      tickSize,
      lotSize,
      basePrice,
      isin,
      segment,
      tradingStatus: 'ACTIVE',
      aliases: raw.aliases,
      popularity: raw.popularity,
      nav: raw.nav,
      fundHouse: raw.fundHouse,
      schemeCode: raw.schemeCode,
    };
  }

  /**
   * Fast server-side prefix and fuzzy text search across all instruments with pagination and precision ranking.
   */
  public static async searchInstruments(options: SearchOptions = {}): Promise<SearchResult> {
    const rawQ = (options.query || '').trim();
    const page = Math.max(1, Number(options.page || options.cursor) || 1);
    const limit = Math.min(2000, Math.max(1, Number(options.limit) || 100));
    const exchangeFilter = (options.exchange || 'ALL').toUpperCase();
    const categoryFilter = (options.category || options.type || 'ALL').toUpperCase();

    // Typo and colloquialisms normalization
    const normalizedQuery = rawQ
      .replace(/adhani/gi, 'adani')
      .replace(/bicoin/gi, 'btc');

    // Cleaned query and target aliases
    const cleanQ = normalizedQuery.trim().toLowerCase();
    const targetSymbols = (cleanQ ? ALIAS_MAP[cleanQ] || [] : []).map((s) => s.toUpperCase());

    // Normalize category / type filter
    const normalizedCategory = this.normalizeCategoryFilter(categoryFilter);

    // Try MongoDB query if connected
    if (mongoose.connection.readyState === 1) {
      try {
        const matchCriteria: any = {};

        if (exchangeFilter !== 'ALL') {
          matchCriteria.exchange = exchangeFilter;
        }

        if (normalizedCategory !== 'ALL') {
          matchCriteria.assetClass = normalizedCategory;
        }

        if (rawQ) {
          const escaped = this.escapeRegex(rawQ);
          const normEscaped = this.escapeRegex(normalizedQuery);

          // For short queries (<= 3 chars), do NOT match arbitrary substrings in middle of words
          // to avoid false positives (e.g. 'vi' matching 'Services')
          if (rawQ.length <= 3) {
            const orConditions: any[] = [
              { symbol: { $in: targetSymbols } },
              { symbol: rawQ.toUpperCase() },
              { symbol: { $regex: `^${escaped}`, $options: 'i' } },
              { symbol: { $regex: `^${normEscaped}`, $options: 'i' } },
              { displayName: { $regex: `^${escaped}`, $options: 'i' } },
              { displayName: { $regex: `\\b${escaped}\\b`, $options: 'i' } },
              { displayName: { $regex: `\\b${escaped}`, $options: 'i' } },
            ];
            matchCriteria.$or = orConditions;
          } else {
            // For longer queries (> 3 chars), allow word-boundary and substring matching
            matchCriteria.$or = [
              { symbol: { $in: targetSymbols } },
              { symbol: { $regex: `^${escaped}`, $options: 'i' } },
              { symbol: { $regex: `^${normEscaped}`, $options: 'i' } },
              { symbol: { $regex: escaped, $options: 'i' } },
              { displayName: { $regex: `\\b${escaped}`, $options: 'i' } },
              { displayName: { $regex: `\\b${normEscaped}`, $options: 'i' } },
              { displayName: { $regex: escaped, $options: 'i' } },
              { displayName: { $regex: normEscaped, $options: 'i' } },
            ];
          }
        }

        const fetchLimit = Math.min(5000, Math.max(1000, limit * page * 2));
        const findQuery = Instrument.find(matchCriteria);
        if (!rawQ) {
          findQuery.sort({ popularity: -1, symbol: 1 });
        }
        const rawDocs = await findQuery.limit(fetchLimit).lean();

        if (rawDocs.length > 0) {
          // Score and rank candidates
          const scored = rawDocs
            .map((doc: any) => ({
              doc,
              score: this.calculateRelevanceScore(doc, rawQ, normalizedQuery, targetSymbols),
            }))
            .filter((item) => item.score > 0)
            .sort((a, b) => b.score - a.score);

          let total = scored.length;
          if (!rawQ) {
            try {
              total = await Instrument.countDocuments(matchCriteria);
            } catch {
              total = scored.length;
            }
          }
          const startIndex = (page - 1) * limit;
          const paged = scored.slice(startIndex, startIndex + limit).map((s) => this.formatResultItem(s.doc));

          return {
            success: true,
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit) || 1,
            instruments: paged,
          };
        }
      } catch {
        // Fallback to memoryCatalog
      }
    }

    // In-memory fallback search
    const all = Array.from(this.memoryCatalog.values());
    const seen = new Set<string>();
    const unique = all.filter((item) => {
      if (seen.has(item.instrumentId)) return false;
      seen.add(item.instrumentId);
      return true;
    });

    const filtered = unique
      .map((item) => {
        if (exchangeFilter !== 'ALL' && item.exchange !== exchangeFilter) return null;
        if (normalizedCategory !== 'ALL' && item.assetClass !== normalizedCategory) return null;
        if (!rawQ) {
          return { item, score: 100 + (item.popularity || 0) };
        }
        const score = this.calculateRelevanceScore(item, rawQ, normalizedQuery, targetSymbols);
        if (score <= 0) return null;
        return { item, score };
      })
      .filter((entry): entry is { item: NormalizedInstrument; score: number } => entry !== null);

    filtered.sort((a, b) => b.score - a.score);

    const total = filtered.length;
    const startIndex = (page - 1) * limit;
    const paged = filtered.slice(startIndex, startIndex + limit).map((entry) => this.formatResultItem(entry.item));

    return {
      success: true,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit) || 1,
      instruments: paged,
    };
  }

  /**
   * Precision relevance scoring:
   * 1. Exact symbol or exact target alias (e.g. 'vi' -> 'IDEA', 'knr' -> 'KNRCON')
   * 2. Symbol prefix
   * 3. Name prefix
   * 4. Word boundary match in name
   * 5. Word start in name
   * 6. Substring match ONLY if query length > 3
   */
  public static calculateRelevanceScore(
    item: { symbol: string; displayName: string; popularity?: number; exchange?: string },
    rawQ: string,
    normQ: string,
    targetSymbols: string[]
  ): number {
    const qUpper = rawQ.toUpperCase().trim();
    const nUpper = normQ.toUpperCase().trim();
    const sym = item.symbol.toUpperCase().trim();
    const name = item.displayName.toUpperCase().trim();
    const pop = item.popularity || 0;

    if (!qUpper) return 100 + pop;

    // 1. Exact target alias or exact symbol
    if (targetSymbols.includes(sym) || sym === qUpper || sym === nUpper) {
      return 10000 + pop + (item.exchange === 'NSE' ? 5 : 0);
    }

    // 2. Symbol starts with query
    if (sym.startsWith(qUpper) || sym.startsWith(nUpper)) {
      return 6000 + (100 - sym.length) + pop;
    }

    // 3. Name starts with query
    if (name.startsWith(qUpper) || name.startsWith(nUpper)) {
      return 4000 + pop;
    }

    // 4. Word boundary match in name (e.g. "KNR CONSTRUCTIONS" for "knr")
    const escaped = this.escapeRegex(rawQ);
    const normEscaped = this.escapeRegex(normQ);
    const wordBoundaryRegex = new RegExp(`\\b${escaped}\\b`, 'i');
    const normWordBoundaryRegex = new RegExp(`\\b${normEscaped}\\b`, 'i');
    if (wordBoundaryRegex.test(name) || normWordBoundaryRegex.test(name)) {
      return 3000 + pop;
    }

    // 5. Word start in name
    const wordStartRegex = new RegExp(`\\b${escaped}`, 'i');
    const normWordStartRegex = new RegExp(`\\b${normEscaped}`, 'i');
    if (wordStartRegex.test(name) || normWordStartRegex.test(name)) {
      return 2000 + pop;
    }

    // 6. Substring match ONLY if query length > 3
    if (rawQ.length > 3) {
      if (sym.includes(qUpper) || sym.includes(nUpper)) {
        return 1000 + pop;
      }
      if (name.includes(qUpper) || name.includes(nUpper)) {
        return 500 + pop;
      }
    }

    return 0; // Excluded
  }

  private static normalizeCategoryFilter(cat: string): string {
    const upper = cat.toUpperCase();
    if (upper === 'INDICES' || upper === 'INDEX') return 'INDEX';
    if (upper === 'ETFS' || upper === 'ETF') return 'ETF';
    if (upper === 'MUTUAL FUND' || upper === 'MUTUAL_FUND' || upper === 'MF') return 'MUTUAL_FUND';
    if (upper === 'EQUITY' || upper === 'COMMODITY' || upper === 'CRYPTO' || upper === 'IPO' || upper === 'US') {
      return upper;
    }
    return 'ALL';
  }

  private static escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * Format item with live quote / pricing
   */
  private static formatResultItem(item: any) {
    const live = MarketDataService.getQuote(item.symbol);
    const price = live?.price ?? item.basePrice ?? item.nav ?? 100.0;
    const change = live?.change ?? 0.0;
    const changePercent = live?.changePercent ?? 0.0;

    return {
      symbol: item.symbol,
      name: item.displayName || item.name || item.symbol,
      exchange: item.exchange,
      category: item.assetClass || item.category || 'EQUITY',
      segment: item.segment || (item.exchange === 'AMFI' ? 'MF' : 'EQ'),
      isin: item.isin,
      lotSize: item.lotSize || 1,
      tickSize: item.tickSize || 0.05,
      price,
      basePrice: item.basePrice || item.nav || price,
      change,
      changePercent,
      isPositive: change >= 0,
      currency: item.quoteCurrency || (item.exchange === 'US' || item.exchange === 'CRYPTO' ? 'USD' : 'INR'),
      isSimulated: live?.status === 'SIMULATED' || true,
      nav: item.nav,
      fundHouse: item.fundHouse,
      schemeCode: item.schemeCode,
    };
  }

  /**
   * Find an instrument by symbol or canonical name
   */
  public static getInstrument(symbol: string): NormalizedInstrument | undefined {
    const clean = symbol.trim().toUpperCase();
    const bare = clean.replace(/^(NSE|BSE|MCX|US|CRYPTO|AMFI):/, '');
    return (
      this.memoryCatalog.get(clean) ||
      this.memoryCatalog.get(bare) ||
      this.memoryCatalog.get(`NSE:${bare}`) ||
      this.memoryCatalog.get(`BSE:${bare}`) ||
      this.memoryCatalog.get(`MCX:${bare}`) ||
      this.memoryCatalog.get(`US:${bare}`) ||
      this.memoryCatalog.get(`CRYPTO:${bare}`) ||
      this.memoryCatalog.get(`AMFI:${bare}`)
    );
  }

  /**
   * Find an instrument by symbol or canonical name with MongoDB fallback
   */
  public static async getInstrumentAsync(symbol: string): Promise<NormalizedInstrument | undefined> {
    const clean = symbol.trim().toUpperCase();
    const bare = clean.replace(/^(NSE|BSE|MCX|US|CRYPTO|AMFI):/, '');
    const existing = this.getInstrument(clean);
    if (existing) return existing;

    if (mongoose.connection.readyState === 1) {
      try {
        const doc = (await Instrument.findOne({
          $or: [
            { symbol: clean },
            { symbol: bare },
            { instrumentId: clean },
            { instrumentId: bare },
            { instrumentId: `NSE:${bare}` },
            { instrumentId: `BSE:${bare}` },
            { instrumentId: `MCX:${bare}` },
            { instrumentId: `US:${bare}` },
            { instrumentId: `CRYPTO:${bare}` },
            { instrumentId: `AMFI:${bare}` },
            { schemeCode: bare },
          ],
        }).lean()) as any;

        if (doc) {
          const item: NormalizedInstrument = {
            instrumentId: doc.instrumentId,
            symbol: doc.symbol,
            displayName: doc.displayName,
            assetClass: doc.assetClass as AssetClass,
            exchange: doc.exchange as Exchange,
            quoteCurrency: doc.quoteCurrency,
            tickSize: doc.tickSize,
            lotSize: doc.lotSize,
            basePrice: doc.basePrice,
            isin: doc.isin,
            segment: doc.segment,
            tradingStatus: (doc.tradingStatus as any) || 'ACTIVE',
            aliases: doc.aliases,
            popularity: doc.popularity,
            nav: (doc as any).nav,
            fundHouse: (doc as any).fundHouse,
            schemeCode: (doc as any).schemeCode,
          };
          this.memoryCatalog.set(item.symbol.toUpperCase(), item);
          this.memoryCatalog.set(`${item.exchange}:${item.symbol}`.toUpperCase(), item);
          this.memoryCatalog.set(item.instrumentId.toUpperCase(), item);
          return item;
        }
      } catch {
        // Non-fatal
      }
    }
    return undefined;
  }

  /**
   * Schedule 24h periodic sync job
   */
  private static scheduleDailySync(): void {
    if (this.syncIntervalTimer) return;
    const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
    this.syncIntervalTimer = setInterval(() => {
      this.syncFromUpstream().catch((err) => {
        console.warn('[InstrumentMaster] Scheduled daily sync error:', err.message);
      });
    }, TWENTY_FOUR_HOURS_MS);

    if (this.syncIntervalTimer.unref) {
      this.syncIntervalTimer.unref();
    }
  }

  public static getLastSyncTime(): Date | null {
    return this.lastSyncTimestamp;
  }
}
