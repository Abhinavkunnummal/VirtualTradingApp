export type NewsCategory = 'EQUITY' | 'CRYPTO' | 'COMMODITY' | 'MACRO' | 'FOREX';
export type NewsSentiment = 'BULLISH' | 'BEARISH' | 'NEUTRAL';
export type NewsImpact = 'HIGH' | 'MEDIUM' | 'LOW';

export interface NewsArticle {
  id: string;
  title: string;
  summary: string;
  category: NewsCategory;
  sentiment: NewsSentiment;
  sentimentScore: number; // -1.0 to 1.0
  impact: NewsImpact;
  relatedSymbols: string[];
  source: string;
  publishedAt: string;
  readTimeMinutes: number;
}

export class NewsService {
  private static readonly newsFeed: NewsArticle[] = [
    {
      id: 'news-001',
      title: 'Reliance Retail Expands Omnichannel Footprint, Boosts Forward EBITDA Outlook',
      summary:
        'Reliance Industries retail arm reports 18% YoY growth in quarterly consumer footfall, driven by tier-2 city digital store network integration.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.78,
      impact: 'HIGH',
      relatedSymbols: ['RELIANCE', 'NIFTY 50'],
      source: 'TradeVerse Market Wire',
      publishedAt: new Date(Date.now() - 12 * 60 * 1000).toISOString(),
      readTimeMinutes: 2,
    },
    {
      id: 'news-002',
      title: 'TCS Secures Multi-Million Dollar European Cloud Transformation Contract',
      summary:
        'Tata Consultancy Services signs a comprehensive 5-year digital core modernisation partnership with a major Nordic financial institution.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.65,
      impact: 'MEDIUM',
      relatedSymbols: ['TCS', 'NIFTY 50'],
      source: 'Global Tech Insights',
      publishedAt: new Date(Date.now() - 35 * 60 * 1000).toISOString(),
      readTimeMinutes: 3,
    },
    {
      id: 'news-003',
      title: 'RBI MPC Holds Repo Rate Steady at 6.5%, Retains Withdrawal of Accommodation',
      summary:
        'Reserve Bank of India Governor highlights resilient domestic growth alongside continuing vigilance on food price volatility and geopolitical shipping corridors.',
      category: 'MACRO',
      sentiment: 'NEUTRAL',
      sentimentScore: 0.05,
      impact: 'HIGH',
      relatedSymbols: ['NIFTY 50', 'SENSEX', 'HDFCBANK'],
      source: 'Central Bank Monitor',
      publishedAt: new Date(Date.now() - 75 * 60 * 1000).toISOString(),
      readTimeMinutes: 4,
    },
    {
      id: 'news-004',
      title: 'Bitcoin Consolidates Near Highs as Institutional ETF Inflows Surge',
      summary:
        'BTC maintains strong price support above $65,000 as net weekly spot ETF inflows cross $1.2B amid growing sovereign balance sheet discussions.',
      category: 'CRYPTO',
      sentiment: 'BULLISH',
      sentimentScore: 0.82,
      impact: 'HIGH',
      relatedSymbols: ['BTC/USDT', 'ETH/USDT'],
      source: 'CryptoDesk Terminal',
      publishedAt: new Date(Date.now() - 110 * 60 * 1000).toISOString(),
      readTimeMinutes: 3,
    },
    {
      id: 'news-005',
      title: 'Gold Tests Key Resistance Amid Global Safe-Haven Diversification',
      summary:
        'Physical bullion and sovereign central bank purchases maintain strong upward pressure on MCX gold futures as yields adjust.',
      category: 'COMMODITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.61,
      impact: 'MEDIUM',
      relatedSymbols: ['GOLD 1KG'],
      source: 'Precious Metals Bulletin',
      publishedAt: new Date(Date.now() - 180 * 60 * 1000).toISOString(),
      readTimeMinutes: 2,
    },
    {
      id: 'news-006',
      title: 'HDFC Bank Deposits Grow 15% YoY; Loan-to-Deposit Ratio Moderates Favorably',
      summary:
        'India’s largest private sector lender continues steady post-merger balance sheet integration with retail term deposit accretion outpacing advances.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.54,
      impact: 'MEDIUM',
      relatedSymbols: ['HDFCBANK', 'NIFTY 50'],
      source: 'Banking Sector Review',
      publishedAt: new Date(Date.now() - 240 * 60 * 1000).toISOString(),
      readTimeMinutes: 3,
    },
    {
      id: 'news-007',
      title: 'Nvidia Unveils Next-Gen AI Silicon Architecture, Forecasts Hyperscale Demand',
      summary:
        'Semiconductor giant details improved energy efficiency and accelerated LLM training benchmarks for enterprise cloud providers.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.88,
      impact: 'HIGH',
      relatedSymbols: ['NVDA', 'AAPL'],
      source: 'Silicon Intelligence Report',
      publishedAt: new Date(Date.now() - 320 * 60 * 1000).toISOString(),
      readTimeMinutes: 4,
    },
    {
      id: 'news-008',
      title: 'Crude Oil Pressured by Rising Non-OPEC Production and Refinery Maintenance',
      summary:
        'Brent futures ease 1.2% as inventory builds offset Middle East geopolitical risk premiums in simulated derivative markets.',
      category: 'COMMODITY',
      sentiment: 'BEARISH',
      sentimentScore: -0.42,
      impact: 'MEDIUM',
      relatedSymbols: ['CRUDE OIL', 'RELIANCE'],
      source: 'Energy Intelligence Wire',
      publishedAt: new Date(Date.now() - 400 * 60 * 1000).toISOString(),
      readTimeMinutes: 2,
    },
  ];

  static getNews(filters?: { category?: string; symbol?: string; limit?: number }): NewsArticle[] {
    let result = [...this.newsFeed];

    if (filters?.category && filters.category !== 'ALL') {
      const cat = filters.category.toUpperCase();
      result = result.filter((item) => item.category === cat);
    }

    if (filters?.symbol) {
      const sym = filters.symbol.toUpperCase();
      result = result.filter((item) => item.relatedSymbols.some((s) => s.toUpperCase() === sym));
    }

    const limit = filters?.limit ? Math.min(filters.limit, 50) : 20;
    return result.slice(0, limit);
  }

  static getArticleById(id: string): NewsArticle | null {
    return this.newsFeed.find((a) => a.id === id) || null;
  }
}
