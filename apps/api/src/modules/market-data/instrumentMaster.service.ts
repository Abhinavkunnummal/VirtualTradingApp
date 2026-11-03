import mongoose from 'mongoose';
import { z } from 'zod';
import { Instrument, IInstrument, AssetClass, Exchange } from '../../models/Instrument';
import { MarketQuote, CandleInterval, Candle, MarketDataService } from './marketData.service';
import { RealtimeMarketService } from './realtimeMarket.service';

export const InstrumentSearchQuerySchema = z.object({
  q: z.string().optional().default(''),
  exchange: z.enum(['ALL', 'NSE', 'BSE', 'MCX', 'US', 'CRYPTO']).optional().default('ALL'),
  category: z.enum(['ALL', 'EQUITY', 'INDEX', 'ETF', 'COMMODITY', 'CRYPTO', 'US']).optional().default('ALL'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

export type InstrumentSearchQuery = z.infer<typeof InstrumentSearchQuerySchema>;

export interface SearchOptions {
  query?: string;
  exchange?: string;
  category?: string;
  page?: number;
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
}

/**
 * Curated master baseline of Indian Equities, Indices, ETFs, MCX, Crypto, and US Stocks.
 * Automatically seeded if database is empty or offline.
 */
export const CURATED_INSTRUMENTS: NormalizedInstrument[] = [
  // --- Indian Indices ---
  { instrumentId: 'NSE:NIFTY 50', symbol: 'NIFTY 50', displayName: 'Nifty 50 Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 50, basePrice: 24852.15, segment: 'INDICES', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BANKNIFTY', symbol: 'BANKNIFTY', displayName: 'Nifty Bank Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 15, basePrice: 51820.00, segment: 'INDICES', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:FINNIFTY', symbol: 'FINNIFTY', displayName: 'Nifty Financial Services Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 40, basePrice: 23450.00, segment: 'INDICES', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:MIDCPNIFTY', symbol: 'MIDCPNIFTY', displayName: 'Nifty Midcap Select Index', assetClass: 'INDEX', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 75, basePrice: 12840.00, segment: 'INDICES', tradingStatus: 'ACTIVE' },
  { instrumentId: 'BSE:SENSEX', symbol: 'SENSEX', displayName: 'BSE Sensex Index', assetClass: 'INDEX', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 10, basePrice: 81420.30, segment: 'INDICES', tradingStatus: 'ACTIVE' },
  { instrumentId: 'BSE:BANKEX', symbol: 'BANKEX', displayName: 'BSE Bankex Index', assetClass: 'INDEX', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 15, basePrice: 58920.00, segment: 'INDICES', tradingStatus: 'ACTIVE' },

  // --- Indian ETFs ---
  { instrumentId: 'NSE:NIFTYBEES', symbol: 'NIFTYBEES', displayName: 'Nippon India ETF Nifty 50 BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 272.50, isin: 'INF204KB14I2', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BANKBEES', symbol: 'BANKBEES', displayName: 'Nippon India ETF Nifty Bank BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 535.10, isin: 'INF204KB1476', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:GOLDBEES', symbol: 'GOLDBEES', displayName: 'Nippon India ETF Gold BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 65.40, isin: 'INF204KB17I9', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:SILVERBEES', symbol: 'SILVERBEES', displayName: 'Nippon India ETF Silver BeES', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 91.20, isin: 'INF204KB18I7', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ITBEES', symbol: 'ITBEES', displayName: 'Nippon India ETF Nifty IT', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 42.15, isin: 'INF204KB19I5', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:JUNIORBEES', symbol: 'JUNIORBEES', displayName: 'Nippon India ETF Nifty Next 50', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 725.00, isin: 'INF204KB15I9', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:MON100', symbol: 'MON100', displayName: 'Motilal Oswal Nasdaq 100 ETF', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 178.60, isin: 'INF247L01AU4', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:CPSEETF', symbol: 'CPSEETF', displayName: 'CPSE Central Public Sector ETF', assetClass: 'ETF', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.01, lotSize: 1, basePrice: 94.30, isin: 'INF582M01011', segment: 'EQ', tradingStatus: 'ACTIVE' },

  // --- Top NSE Bluechip Equities ---
  { instrumentId: 'NSE:RELIANCE', symbol: 'RELIANCE', displayName: 'Reliance Industries Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2945.50, isin: 'INE002A01018', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TCS', symbol: 'TCS', displayName: 'Tata Consultancy Services Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4120.00, isin: 'INE467B01029', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:HDFCBANK', symbol: 'HDFCBANK', displayName: 'HDFC Bank Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1720.80, isin: 'INE040A01034', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:INFY', symbol: 'INFY', displayName: 'Infosys Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1885.20, isin: 'INE009A01021', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ICICIBANK', symbol: 'ICICIBANK', displayName: 'ICICI Bank Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1260.40, isin: 'INE090A01021', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:SBIN', symbol: 'SBIN', displayName: 'State Bank of India', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 815.75, isin: 'INE062A01020', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TATAMOTORS', symbol: 'TATAMOTORS', displayName: 'Tata Motors Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 960.50, isin: 'INE155A01022', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BAJFINANCE', symbol: 'BAJFINANCE', displayName: 'Bajaj Finance Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6850.00, isin: 'INE296A01024', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BHARTIARTL', symbol: 'BHARTIARTL', displayName: 'Bharti Airtel Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1680.00, isin: 'INE397D01024', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ITC', symbol: 'ITC', displayName: 'ITC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 485.50, isin: 'INE154A01025', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:LT', symbol: 'LT', displayName: 'Larsen & Toubro Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 3560.00, isin: 'INE018A01030', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:HINDUNILVR', symbol: 'HINDUNILVR', displayName: 'Hindustan Unilever Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2420.00, isin: 'INE030A01027', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:KOTAKBANK', symbol: 'KOTAKBANK', displayName: 'Kotak Mahindra Bank Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1780.00, isin: 'INE237A01028', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:MARUTI', symbol: 'MARUTI', displayName: 'Maruti Suzuki India Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 11450.00, isin: 'INE585B01010', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:SUNPHARMA', symbol: 'SUNPHARMA', displayName: 'Sun Pharmaceutical Industries', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1820.00, isin: 'INE044A01036', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:WIPRO', symbol: 'WIPRO', displayName: 'Wipro Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 540.00, isin: 'INE075A01022', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TITAN', symbol: 'TITAN', displayName: 'Titan Company Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 3320.00, isin: 'INE280A01028', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TATASTEEL', symbol: 'TATASTEEL', displayName: 'Tata Steel Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 152.00, isin: 'INE081A01020', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:AXISBANK', symbol: 'AXISBANK', displayName: 'Axis Bank Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1180.00, isin: 'INE238A01034', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ZOMATO', symbol: 'ZOMATO', displayName: 'Zomato Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 265.00, isin: 'INE758T01015', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:JIOFIN', symbol: 'JIOFIN', displayName: 'Jio Financial Services Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 320.00, isin: 'INE758E01017', segment: 'EQ', tradingStatus: 'ACTIVE' },

  // --- Adani Group ---
  { instrumentId: 'NSE:ADANIENT', symbol: 'ADANIENT', displayName: 'Adani Enterprises Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2840.00, isin: 'INE423A01024', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ADANIPORTS', symbol: 'ADANIPORTS', displayName: 'Adani Ports and SEZ Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1360.50, isin: 'INE742F01042', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ADANIGREEN', symbol: 'ADANIGREEN', displayName: 'Adani Green Energy Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1580.00, isin: 'INE364U01010', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ATGL', symbol: 'ATGL', displayName: 'Adani Total Gas Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 720.00, isin: 'INE399L01023', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ADANIPOWER', symbol: 'ADANIPOWER', displayName: 'Adani Power Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 590.00, isin: 'INE814H01011', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:AMBUJACEM', symbol: 'AMBUJACEM', displayName: 'Ambuja Cements Ltd. (Adani)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 560.00, isin: 'INE079A01024', segment: 'EQ', tradingStatus: 'ACTIVE' },

  // --- Additional Top Indian Growth & PSU Stocks ---
  { instrumentId: 'NSE:BEL', symbol: 'BEL', displayName: 'Bharat Electronics Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 295.40, isin: 'INE263A01024', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:HAL', symbol: 'HAL', displayName: 'Hindustan Aeronautics Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4420.00, isin: 'INE066F01012', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BHEL', symbol: 'BHEL', displayName: 'Bharat Heavy Electricals Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 238.10, isin: 'INE257A01026', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:COALINDIA', symbol: 'COALINDIA', displayName: 'Coal India Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 445.00, isin: 'INE522F01014', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:NTPC', symbol: 'NTPC', displayName: 'NTPC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 410.50, isin: 'INE733E01010', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ONGC', symbol: 'ONGC', displayName: 'Oil & Natural Gas Corp Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 275.00, isin: 'INE213A01029', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:POWERGRID', symbol: 'POWERGRID', displayName: 'Power Grid Corporation of India', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 325.00, isin: 'INE752E01010', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:RECLTD', symbol: 'RECLTD', displayName: 'REC Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 520.00, isin: 'INE020B01018', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:PFC', symbol: 'PFC', displayName: 'Power Finance Corporation', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 478.00, isin: 'INE134E01011', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TRENT', symbol: 'TRENT', displayName: 'Trent Limited (Tata Group)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6950.00, isin: 'INE849A01020', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:TATACONSUM', symbol: 'TATACONSUM', displayName: 'Tata Consumer Products Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1045.00, isin: 'INE192A01025', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:PIDILITIND', symbol: 'PIDILITIND', displayName: 'Pidilite Industries Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 3120.00, isin: 'INE318A01026', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:ASIANPAINT', symbol: 'ASIANPAINT', displayName: 'Asian Paints Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2980.00, isin: 'INE021A01026', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:DMART', symbol: 'DMART', displayName: 'Avenue Supermarts Ltd. (DMart)', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4150.00, isin: 'INE192R01011', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:M&M', symbol: 'M&M', displayName: 'Mahindra & Mahindra Ltd.', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 2850.00, isin: 'INE101A01026', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:HEROMOTOCO', symbol: 'HEROMOTOCO', displayName: 'Hero MotoCorp Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4920.00, isin: 'INE158A01026', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'NSE:BAJAJ-AUTO', symbol: 'BAJAJ-AUTO', displayName: 'Bajaj Auto Limited', assetClass: 'EQUITY', exchange: 'NSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 9750.00, isin: 'INE917I01010', segment: 'EQ', tradingStatus: 'ACTIVE' },

  // --- BSE Exclusives ---
  { instrumentId: 'BSE:BSE', symbol: 'BSE', displayName: 'BSE Limited (Exchange)', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 4720.00, isin: 'INE118H01025', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'BSE:CDSL', symbol: 'CDSL', displayName: 'Central Depository Services Ltd.', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 1480.00, isin: 'INE736A01011', segment: 'EQ', tradingStatus: 'ACTIVE' },
  { instrumentId: 'BSE:POLYCAB', symbol: 'POLYCAB', displayName: 'Polycab India Limited', assetClass: 'EQUITY', exchange: 'BSE', quoteCurrency: 'INR', tickSize: 0.05, lotSize: 1, basePrice: 6850.00, isin: 'INE455K01017', segment: 'EQ', tradingStatus: 'ACTIVE' },

  // --- MCX Commodities ---
  { instrumentId: 'MCX:GOLD 1KG', symbol: 'GOLD 1KG', displayName: 'MCX Gold Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 1, basePrice: 78450.00, segment: 'COM', tradingStatus: 'ACTIVE' },
  { instrumentId: 'MCX:SILVER 30KG', symbol: 'SILVER 30KG', displayName: 'MCX Silver Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 30, basePrice: 94200.00, segment: 'COM', tradingStatus: 'ACTIVE' },
  { instrumentId: 'MCX:CRUDEOIL', symbol: 'CRUDEOIL', displayName: 'MCX Crude Oil 100 BBL', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 1.0, lotSize: 100, basePrice: 6120.00, segment: 'COM', tradingStatus: 'ACTIVE' },
  { instrumentId: 'MCX:NATURALGAS', symbol: 'NATURALGAS', displayName: 'MCX Natural Gas Futures', assetClass: 'COMMODITY', exchange: 'MCX', quoteCurrency: 'INR', tickSize: 0.1, lotSize: 1250, basePrice: 245.80, segment: 'COM', tradingStatus: 'ACTIVE' },

  // --- Crypto 24/7 ---
  { instrumentId: 'CRYPTO:BTC/USDT', symbol: 'BTC/USDT', displayName: 'Bitcoin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 77568.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },
  { instrumentId: 'CRYPTO:ETH/USDT', symbol: 'ETH/USDT', displayName: 'Ethereum 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 2540.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },
  { instrumentId: 'CRYPTO:SOL/USDT', symbol: 'SOL/USDT', displayName: 'Solana 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 178.50, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },
  { instrumentId: 'CRYPTO:DOGE/USDT', symbol: 'DOGE/USDT', displayName: 'Dogecoin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.0001, lotSize: 1, basePrice: 0.165, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },
  { instrumentId: 'CRYPTO:BNB/USDT', symbol: 'BNB/USDT', displayName: 'Binance Coin 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 595.00, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },
  { instrumentId: 'CRYPTO:XRP/USDT', symbol: 'XRP/USDT', displayName: 'Ripple 24/7 Live Stream', assetClass: 'CRYPTO', exchange: 'CRYPTO', quoteCurrency: 'USD', tickSize: 0.001, lotSize: 1, basePrice: 0.54, segment: 'CRYPTO', tradingStatus: 'ACTIVE' },

  // --- US Equities & ETFs ---
  { instrumentId: 'US:AAPL', symbol: 'AAPL', displayName: 'Apple Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 231.41, isin: 'US0378331005', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:NVDA', symbol: 'NVDA', displayName: 'NVIDIA Corporation', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 141.54, isin: 'US67066G1040', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:MSFT', symbol: 'MSFT', displayName: 'Microsoft Corporation', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 428.15, isin: 'US5949181045', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:TSLA', symbol: 'TSLA', displayName: 'Tesla Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 258.40, isin: 'US88160R1014', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:GOOGL', symbol: 'GOOGL', displayName: 'Alphabet Inc. Class A', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 172.50, isin: 'US02079K3059', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:AMZN', symbol: 'AMZN', displayName: 'Amazon.com Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 188.20, isin: 'US0231351067', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:META', symbol: 'META', displayName: 'Meta Platforms Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 582.00, isin: 'US30303M1027', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:NFLX', symbol: 'NFLX', displayName: 'Netflix Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 760.00, isin: 'US64110L1061', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:AMD', symbol: 'AMD', displayName: 'Advanced Micro Devices', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 155.00, isin: 'US0079031078', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:COIN', symbol: 'COIN', displayName: 'Coinbase Global Inc.', assetClass: 'EQUITY', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 215.00, isin: 'US19260Q1076', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:SPY', symbol: 'SPY', displayName: 'SPDR S&P 500 ETF Trust', assetClass: 'ETF', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 586.46, isin: 'US78462F1030', segment: 'US', tradingStatus: 'ACTIVE' },
  { instrumentId: 'US:QQQ', symbol: 'QQQ', displayName: 'Invesco QQQ Trust (Nasdaq 100)', assetClass: 'ETF', exchange: 'US', quoteCurrency: 'USD', tickSize: 0.01, lotSize: 1, basePrice: 492.30, isin: 'US46090E1038', segment: 'US', tradingStatus: 'ACTIVE' },
];

export class InstrumentMasterService {
  private static isInitialized = false;
  private static lastSyncTimestamp: Date | null = null;
  private static syncIntervalTimer: NodeJS.Timeout | null = null;

  // In-memory lookup map for rapid exact resolution
  private static memoryCatalog = new Map<string, NormalizedInstrument>();

  /**
   * Initializes the service, populates in-memory catalog and ensures MongoDB contains master instruments.
   */
  public static async init(): Promise<void> {
    if (this.isInitialized) return;

    // Load curated baseline into memory
    for (const item of CURATED_INSTRUMENTS) {
      this.memoryCatalog.set(item.symbol.toUpperCase(), item);
      this.memoryCatalog.set(`${item.exchange}:${item.symbol}`.toUpperCase(), item);
    }

    // Ensure database contains instruments
    await this.ensureSeeded();

    // Schedule daily sync
    this.scheduleDailySync();

    this.isInitialized = true;
  }

  /**
   * Seed curated master into MongoDB if collection is empty
   */
  public static async ensureSeeded(): Promise<number> {
    if (mongoose.connection.readyState !== 1) {
      return this.memoryCatalog.size;
    }
    try {
      const count = await Instrument.countDocuments();
      if (count >= CURATED_INSTRUMENTS.length) {
        return count;
      }

      // Upsert curated instruments
      const bulkOps = CURATED_INSTRUMENTS.map((inst) => ({
        updateOne: {
          filter: { instrumentId: inst.instrumentId },
          update: { $set: inst },
          upsert: true,
        },
      }));

      await Instrument.bulkWrite(bulkOps, { ordered: false });
      this.lastSyncTimestamp = new Date();
      return await Instrument.countDocuments();
    } catch (err) {
      // In unit test environments without full MongoDB connection, memoryCatalog serves as fallback
      return this.memoryCatalog.size;
    }
  }

  /**
   * Sync instruments from remote file or external source (Angel One / Upstox / NSE)
   */
  public static async syncFromUpstream(options?: { url?: string; rawData?: any[] }): Promise<{ count: number; source: string }> {
    const upstreamUrl = options?.url || process.env.INSTRUMENT_MASTER_URL;
    let recordsToIngest: NormalizedInstrument[] = [];
    let sourceName = 'curated-baseline';

    if (options?.rawData && Array.isArray(options.rawData)) {
      recordsToIngest = options.rawData.map(this.normalizeRawRecord).filter((r): r is NormalizedInstrument => r !== null);
      sourceName = 'provided-data';
    } else if (upstreamUrl) {
      try {
        const response = await fetch(upstreamUrl, { signal: AbortSignal.timeout(10000) });
        if (response.ok) {
          const json = await response.json();
          if (Array.isArray(json)) {
            recordsToIngest = json.map(this.normalizeRawRecord).filter((r): r is NormalizedInstrument => r !== null);
            sourceName = upstreamUrl;
          }
        }
      } catch (e) {
        // Fallback to curated
        recordsToIngest = CURATED_INSTRUMENTS;
        sourceName = 'curated-fallback-after-error';
      }
    } else {
      recordsToIngest = CURATED_INSTRUMENTS;
    }

    if (recordsToIngest.length === 0) {
      recordsToIngest = CURATED_INSTRUMENTS;
    }

    // Update in-memory map
    for (const item of recordsToIngest) {
      this.memoryCatalog.set(item.symbol.toUpperCase(), item);
      this.memoryCatalog.set(`${item.exchange}:${item.symbol}`.toUpperCase(), item);
    }

    // Persist to MongoDB if connected
    if (mongoose.connection.readyState === 1) {
      try {
        const bulkOps = recordsToIngest.map((inst) => ({
          updateOne: {
            filter: { instrumentId: inst.instrumentId },
            update: { $set: inst },
            upsert: true,
          },
        }));

        // Ingest in chunks of 500
        const chunkSize = 500;
        for (let i = 0; i < bulkOps.length; i += chunkSize) {
          const chunk = bulkOps.slice(i, i + chunkSize);
          await Instrument.bulkWrite(chunk, { ordered: false });
        }

        this.lastSyncTimestamp = new Date();
      } catch {
        // Database bulk write failure non-fatal if offline
      }
    }

    return {
      count: recordsToIngest.length,
      source: sourceName,
    };
  }

  /**
   * Normalizes incoming raw record from external feeds (Angel One / Upstox / NSE)
   */
  public static normalizeRawRecord(raw: any): NormalizedInstrument | null {
    if (!raw || (!raw.symbol && !raw.tradingsymbol && !raw.name)) return null;

    let symbol = (raw.symbol || raw.tradingsymbol || raw.name || '').trim().toUpperCase();
    // Strip suffixes like -EQ, -BE
    symbol = symbol.replace(/-EQ$/, '').replace(/-BE$/, '').trim();

    const displayName = (raw.displayName || raw.name || raw.formatted_name || symbol).trim();
    const rawExchange = (raw.exchange || raw.exch_seg || 'NSE').toUpperCase().trim();

    let exchange: Exchange = 'NSE';
    if (rawExchange.includes('BSE')) exchange = 'BSE';
    else if (rawExchange.includes('MCX')) exchange = 'MCX';
    else if (rawExchange.includes('CRYPTO') || rawExchange.includes('BINANCE')) exchange = 'CRYPTO';
    else if (rawExchange.includes('US') || rawExchange.includes('NASDAQ') || rawExchange.includes('NYSE')) exchange = 'US';

    let assetClass: AssetClass = 'EQUITY';
    if (symbol.includes('BEES') || symbol.includes('ETF') || displayName.toUpperCase().includes('ETF')) {
      assetClass = 'ETF';
    } else if (symbol.includes('NIFTY') || symbol.includes('SENSEX') || displayName.toUpperCase().includes('INDEX')) {
      assetClass = 'INDEX';
    } else if (exchange === 'MCX') {
      assetClass = 'COMMODITY';
    } else if (exchange === 'CRYPTO') {
      assetClass = 'CRYPTO';
    }

    const lotSize = Number(raw.lotsize || raw.lot_size || raw.lotSize || 1) || 1;
    const tickSize = Number(raw.tick_size || raw.tickSize || 0.05) || 0.05;
    const basePrice = Number(raw.basePrice || raw.price || raw.close || 100.0) || 100.0;
    const quoteCurrency = exchange === 'US' || exchange === 'CRYPTO' ? 'USD' : 'INR';
    const isin = raw.isin || raw.isin_code || undefined;
    const segment = raw.segment || raw.instrumenttype || 'EQ';

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
    };
  }

  /**
   * Fast server-side prefix and fuzzy text search across all instruments with pagination
   */
  public static async searchInstruments(options: SearchOptions = {}): Promise<SearchResult> {
    const rawQ = (options.query || '').trim();
    const page = Math.max(1, Number(options.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(options.limit) || 30));
    const exchangeFilter = (options.exchange || 'ALL').toUpperCase();
    const categoryFilter = (options.category || 'ALL').toUpperCase();

    // Normalizations for typos / colloquialisms
    const normalizedQuery = rawQ
      .replace(/adhani/gi, 'adani')
      .replace(/bicoin/gi, 'btc')
      .replace(/rel/gi, 'reliance');

    // Try MongoDB query first if connected
    if (mongoose.connection.readyState === 1) {
      try {
        const matchCriteria: any = {};

      if (exchangeFilter !== 'ALL') {
        matchCriteria.exchange = exchangeFilter;
      }

      if (categoryFilter !== 'ALL') {
        if (categoryFilter === 'INDICES' || categoryFilter === 'INDEX') {
          matchCriteria.assetClass = 'INDEX';
        } else if (categoryFilter === 'ETFS' || categoryFilter === 'ETF') {
          matchCriteria.assetClass = 'ETF';
        } else {
          matchCriteria.assetClass = categoryFilter;
        }
      }

      if (rawQ) {
        const escaped = rawQ.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const normEscaped = normalizedQuery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        matchCriteria.$or = [
          { symbol: { $regex: `^${escaped}`, $options: 'i' } },
          { symbol: { $regex: `^${normEscaped}`, $options: 'i' } },
          { symbol: { $regex: escaped, $options: 'i' } },
          { displayName: { $regex: escaped, $options: 'i' } },
          { displayName: { $regex: normEscaped, $options: 'i' } },
        ];
      }

      const total = await Instrument.countDocuments(matchCriteria);
      if (total > 0) {
        const rawDocs = await Instrument.find(matchCriteria)
          .sort({ symbol: 1 })
          .skip((page - 1) * limit)
          .limit(limit)
          .lean();

        const enriched = rawDocs.map((doc: any) => this.formatResultItem(doc));
        return {
          success: true,
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit) || 1,
          instruments: enriched,
        };
      }
    } catch {
      // In-memory fallback if database query unavailable
    }
  }

    // In-memory fallback search
    const all = Array.from(this.memoryCatalog.values());
    // Filter duplicates
    const seen = new Set<string>();
    const unique = all.filter((item) => {
      if (seen.has(item.instrumentId)) return false;
      seen.add(item.instrumentId);
      return true;
    });

    const filtered = unique.filter((item) => {
      if (exchangeFilter !== 'ALL' && item.exchange !== exchangeFilter) return false;
      if (categoryFilter !== 'ALL') {
        const cat = categoryFilter === 'INDICES' ? 'INDEX' : categoryFilter === 'ETFS' ? 'ETF' : categoryFilter;
        if (item.assetClass !== cat) return false;
      }
      if (!rawQ) return true;

      const sym = item.symbol.toLowerCase();
      const name = item.displayName.toLowerCase();
      const q = rawQ.toLowerCase();
      const nq = normalizedQuery.toLowerCase();

      return sym.startsWith(q) || sym.startsWith(nq) || sym.includes(q) || name.includes(q) || name.includes(nq);
    });

    // Custom sorting: exact matches first, then prefix, then rest
    filtered.sort((a, b) => {
      const q = rawQ.toUpperCase();
      if (a.symbol === q) return -1;
      if (b.symbol === q) return 1;
      const aStarts = a.symbol.startsWith(q);
      const bStarts = b.symbol.startsWith(q);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.symbol.localeCompare(b.symbol);
    });

    const total = filtered.length;
    const startIndex = (page - 1) * limit;
    const paged = filtered.slice(startIndex, startIndex + limit);

    return {
      success: true,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit) || 1,
      instruments: paged.map((i) => this.formatResultItem(i)),
    };
  }

  /**
   * Format item with live quote / pricing
   */
  private static formatResultItem(item: any) {
    const live = MarketDataService.getQuote(item.symbol);
    const price = live?.price ?? item.basePrice ?? 100.0;
    const change = live?.change ?? 0.0;
    const changePercent = live?.changePercent ?? 0.0;

    return {
      symbol: item.symbol,
      name: item.displayName || item.name || item.symbol,
      exchange: item.exchange,
      category: item.assetClass || item.category || 'EQUITY',
      segment: item.segment || 'EQ',
      isin: item.isin,
      lotSize: item.lotSize || 1,
      tickSize: item.tickSize || 0.05,
      price,
      basePrice: item.basePrice || price,
      change,
      changePercent,
      isPositive: change >= 0,
      currency: item.quoteCurrency || (item.exchange === 'US' || item.exchange === 'CRYPTO' ? 'USD' : 'INR'),
      isSimulated: live?.status === 'SIMULATED' || true,
    };
  }

  /**
   * Find an instrument by symbol or canonical name
   */
  public static getInstrument(symbol: string): NormalizedInstrument | undefined {
    const clean = symbol.trim().toUpperCase();
    return this.memoryCatalog.get(clean) || this.memoryCatalog.get(`NSE:${clean}`) || this.memoryCatalog.get(`BSE:${clean}`);
  }

  /**
   * Schedule 24h periodic sync job
   */
  private static scheduleDailySync(): void {
    if (this.syncIntervalTimer) return;
    const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
    this.syncIntervalTimer = setInterval(() => {
      this.syncFromUpstream().catch(() => {});
    }, TWENTY_FOUR_HOURS_MS);

    // Unref so process doesn't hang in tests
    if (this.syncIntervalTimer.unref) {
      this.syncIntervalTimer.unref();
    }
  }

  public static getLastSyncTime(): Date | null {
    return this.lastSyncTimestamp;
  }
}
