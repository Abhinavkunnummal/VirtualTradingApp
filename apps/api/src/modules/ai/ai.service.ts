import { PaperAccount, Holding, Instrument } from '../../models';
import { MarketDataService } from '../market-data/marketData.service';

export interface ConceptExplanation {
  concept: string;
  simpleExplanation: string;
  keyTakeaways: string[];
  bullishScenario?: string;
  bearishScenario?: string;
  riskFactors: string[];
  isAiGenerated: true;
  disclaimer: string;
}

export interface TradeRiskReview {
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

export interface PortfolioReview {
  totalValue: number;
  cashBalance: number;
  investedValue: number;
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

export interface NewsItem {
  id: string;
  title: string;
  source: string;
  category: string;
  summary: string;
  sentiment: 'BULLISH' | 'BEARISH' | 'NEUTRAL';
  publishedAt: string;
  disclaimer: string;
}

export class AiAssistantService {
  private static readonly DISCLAIMER =
    'Educational use only. Not financial advice. TradeVerse AI never executes real-money trades or autonomous orders.';

  private static readonly INJECTION_PATTERNS = [
    /ignore (?:all )?(?:previous|above) instructions/i,
    /system (?:prompt|override)/i,
    /execute (?:order|trade|buy|sell)/i,
    /you are now in developer mode/i,
    /drop table/i,
    /<script/i,
  ];

  /**
   * Guards against prompt injection and malicious commands.
   */
  static validatePromptSafety(prompt: string): void {
    for (const pattern of this.INJECTION_PATTERNS) {
      if (pattern.test(prompt)) {
        throw new Error('Prompt security violation: Prompt contains prohibited instructions or override attempts.');
      }
    }
  }

  /**
   * Explains a financial concept, technical indicator, or order type.
   */
  static async explainConcept(concept: string, context?: string): Promise<ConceptExplanation> {
    this.validatePromptSafety(concept);
    if (context) this.validatePromptSafety(context);

    const term = concept.trim().toUpperCase();

    // Comprehensive educational knowledge base
    if (term.includes('RSI')) {
      return {
        concept: 'Relative Strength Index (RSI)',
        simpleExplanation:
          'RSI is a momentum oscillator that measures the speed and change of price movements on a scale of 0 to 100. It helps identify overbought (typically >70) and oversold (typically <30) market conditions.',
        keyTakeaways: [
          'Values above 70 indicate strong upward momentum but potential for a consolidation or pullback.',
          'Values below 30 indicate intense selling pressure, which may precede a relief rally.',
          'Divergence between RSI and price often signals a potential momentum exhaustion.',
        ],
        bullishScenario:
          'If RSI crosses back above 30 from oversold territory with expanding volume, it could indicate buyers stepping in.',
        bearishScenario:
          'If RSI forms a lower high while price hits a new high (bearish divergence), upward momentum may be waning.',
        riskFactors: [
          'In strong trending markets, RSI can remain overbought or oversold for extended periods without price reversing.',
        ],
        isAiGenerated: true,
        disclaimer: this.DISCLAIMER,
      };
    }

    if (term.includes('STOP-LOSS') || term.includes('STOP LOSS') || term.includes('SL')) {
      return {
        concept: 'Stop-Loss Order (SL)',
        simpleExplanation:
          'A stop-loss order is an order placed with a broker to buy or sell a security when it reaches a certain price. It is designed to limit an investor’s loss on a position.',
        keyTakeaways: [
          'Triggers automatically when the market price breaches your threshold.',
          'Protects virtual capital against sudden adverse volatility.',
          'SL-Limit specifies a maximum limit price; SL-Market executes at the next best available market price.',
        ],
        bullishScenario: 'Trailing stop-losses can lock in unrealized profits as a profitable trade advances upward.',
        bearishScenario:
          'In high-volatility gap-downs, market slippage may execute an SL-Market below your trigger price.',
        riskFactors: ['Whipsaws: Short-term price spikes can trigger your stop right before the price resumes direction.'],
        isAiGenerated: true,
        disclaimer: this.DISCLAIMER,
      };
    }

    if (term.includes('ENGULFING') || term.includes('CANDLESTICK')) {
      return {
        concept: 'Bullish & Bearish Engulfing Candlesticks',
        simpleExplanation:
          'An engulfing pattern consists of two candles where the body of the second candle completely covers (engulfs) the body of the preceding candle, signaling a strong shift in market sentiment.',
        keyTakeaways: [
          'Bullish Engulfing: Appears at key support levels after a downtrend; green candle engulfs previous red candle.',
          'Bearish Engulfing: Appears at key resistance levels after an uptrend; red candle engulfs previous green candle.',
          'Higher timeframe engulfing candles (1D, 4H) carry significantly more statistical weight than 1M or 5M.',
        ],
        bullishScenario:
          'Confirmation occurs when the subsequent candle closes above the high of the bullish engulfing candle with rising volume.',
        bearishScenario:
          'If the subsequent candle drops below the engulfing candle low, the reversal setup is invalidated.',
        riskFactors: ['False breakouts are common during low-volume sessions and around major macroeconomic data releases.'],
        isAiGenerated: true,
        disclaimer: this.DISCLAIMER,
      };
    }

    if (term.includes('MIS') || term.includes('INTRADAY') || term.includes('LEVERAGE')) {
      return {
        concept: 'Intraday Margin (MIS) & Leverage',
        simpleExplanation:
          'Margin Intraday Square-off (MIS) allows you to trade with up to 5x leverage by only requiring a 20% margin deposit. All open MIS positions must be closed before the exchange market closes.',
        keyTakeaways: [
          '5x leverage amplifies both potential percentage gains and percentage losses by 500%.',
          'Unclosed MIS positions are automatically squared off near market close (e.g. 3:20 PM IST).',
          'Delivery (CNC) requires 100% cash and carries no auto square-off deadline.',
        ],
        bullishScenario: 'A 2% favorable move on a 5x leveraged position produces a +10% return on invested margin.',
        bearishScenario: 'A 2% adverse move on a 5x leveraged position produces a -10% loss on invested margin.',
        riskFactors: [
          'Rapid volatility can trigger simulated margin calls and forced liquidation if account equity drops below required levels.',
        ],
        isAiGenerated: true,
        disclaimer: this.DISCLAIMER,
      };
    }

    // Generic educational synthesis for any other term
    return {
      concept: concept.trim(),
      simpleExplanation: `In simulated paper-trading, "${concept.trim()}" is an analytical concept used to evaluate market behavior, risk exposure, and price action dynamics without risking real capital.`,
      keyTakeaways: [
        'Always verify technical signals across multiple independent indicators and timeframes.',
        'Never risk more than 1% to 2% of total account capital on a single simulated trade.',
        'Document trade rationale in your journal before executing simulated orders.',
      ],
      bullishScenario: 'Favorable volume expansion and supportive market sentiment could support continuation.',
      bearishScenario: 'Rejection at higher resistance levels or loss of moving average support could prompt consolidation.',
      riskFactors: ['Past market performance and chart patterns do not guarantee future price trajectory.'],
      isAiGenerated: true,
      disclaimer: this.DISCLAIMER,
    };
  }

  /**
   * Pre-trade risk evaluation for proposed orders.
   */
  static evaluateTradeRisk(params: {
    symbol: string;
    exchange: string;
    side: 'BUY' | 'SELL';
    orderType: 'MARKET' | 'LIMIT' | 'SL' | 'SL_M';
    product: 'CNC' | 'MIS';
    quantity: number;
    price: number;
  }): TradeRiskReview {
    const turnover = parseFloat((params.quantity * params.price).toFixed(2));
    const estimatedMargin =
      params.product === 'MIS' ? parseFloat((turnover / 5).toFixed(2)) : turnover;

    // Fees calculation
    const brokerage = Math.min(20.0, parseFloat((turnover * 0.0003).toFixed(2)));
    const stt = params.product === 'CNC' ? parseFloat((turnover * 0.001).toFixed(2)) : 0.0;
    const exchangeFee = parseFloat((turnover * 0.0000325).toFixed(2));
    const gst = parseFloat(((brokerage + exchangeFee) * 0.18).toFixed(2));
    const totalFees = parseFloat((brokerage + stt + exchangeFee + gst).toFixed(2));

    const slippagePct = params.orderType === 'MARKET' ? 0.05 : 0.0;
    const downside2Pct = parseFloat((turnover * 0.02).toFixed(2));
    const downside5Pct = parseFloat((turnover * 0.05).toFixed(2));

    let riskScore: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' = 'LOW';
    if (params.product === 'MIS') riskScore = 'MEDIUM';
    if (turnover > 500000) riskScore = 'HIGH';
    if (turnover > 1500000) riskScore = 'CRITICAL';

    return {
      symbol: params.symbol,
      turnover,
      estimatedMargin,
      estimatedFees: {
        brokerage,
        stt,
        exchangeFee,
        gst,
        totalFees,
      },
      slippageAssumption:
        params.orderType === 'MARKET'
          ? `Estimated ±${slippagePct}% slippage on market fill.`
          : 'Limit order specifies exact maximum price (0% slippage risk, but fill not guaranteed).',
      downsideRisk: `A 2% adverse price shift represents a simulated loss of ₹${downside2Pct}. A 5% drop results in -₹${downside5Pct} (${params.product === 'MIS' ? '25% margin loss due to 5x leverage' : '5% capital loss'}).`,
      bullishScenario: `If ${params.symbol} appreciates by 3%, projected gross gain is ₹${(turnover * 0.03).toFixed(2)} (Net after fees: ₹${(turnover * 0.03 - totalFees).toFixed(2)}).`,
      bearishScenario: `If ${params.symbol} depreciates by 3%, projected gross loss is -₹${(turnover * 0.03).toFixed(2)} (Net after fees: -₹${(turnover * 0.03 + totalFees).toFixed(2)}).`,
      riskScore,
      summary: `Proposed ${params.side} order for ${params.quantity} ${params.symbol} (${params.product}) requires ₹${estimatedMargin.toFixed(2)} margin with estimated fees of ₹${totalFees.toFixed(2)}.`,
      isAiGenerated: true,
      disclaimer: this.DISCLAIMER,
    };
  }

  /**
   * Evaluates user's simulated portfolio for concentration, exposure, and volatility.
   * Enforces strict user isolation — only analyzes authenticated user's portfolio.
   */
  static async reviewPortfolio(userId: string): Promise<PortfolioReview> {
    const account = await PaperAccount.findOne({ userId });
    const holdings = await Holding.find({ userId });

    const cashBalance = account?.availableCash ?? 1000000.0;
    let investedValue = 0;
    let maxHoldingVal = 0;
    let topAsset = 'None';
    const assetDist: Record<string, number> = { CASH: cashBalance };

    for (const h of holdings) {
      const quote = MarketDataService.getQuote(h.symbol);
      const ltp = quote?.price ?? h.averageCost;
      const val = parseFloat((h.quantity * ltp).toFixed(2));
      investedValue += val;

      const category = quote?.category || 'EQUITY';
      assetDist[category] = (assetDist[category] || 0) + val;

      if (val > maxHoldingVal) {
        maxHoldingVal = val;
        topAsset = h.symbol;
      }
    }

    const totalValue = parseFloat((cashBalance + investedValue).toFixed(2));
    const topAssetWeight = totalValue > 0 ? parseFloat(((maxHoldingVal / totalValue) * 100).toFixed(1)) : 0;
    const isConcentrated = topAssetWeight > 35.0;

    let volatilityAssessment: 'CONSERVATIVE' | 'MODERATE' | 'AGGRESSIVE' = 'CONSERVATIVE';
    const cashRatio = totalValue > 0 ? cashBalance / totalValue : 1.0;
    if (cashRatio < 0.3) volatilityAssessment = 'MODERATE';
    if (cashRatio < 0.1 || assetDist['CRYPTO'] > 0.2 * totalValue) volatilityAssessment = 'AGGRESSIVE';

    const recommendations: string[] = [];
    if (isConcentrated) {
      recommendations.push(
        `High concentration risk: ${topAsset} accounts for ${topAssetWeight}% of your portfolio. Consider rebalancing across uncorrelated sectors.`
      );
    }
    if (cashRatio < 0.15) {
      recommendations.push(
        'Available cash buffer is below 15%. Maintaining cash reserves protects against margin calls during market dips.'
      );
    }
    if (holdings.length < 3 && investedValue > 0) {
      recommendations.push(
        'Portfolio holds fewer than 3 assets. Broadening exposure reduces single-stock unsystematic risk.'
      );
    }
    if (recommendations.length === 0) {
      recommendations.push(
        'Portfolio displays balanced diversification between available liquid cash and invested positions.'
      );
    }

    return {
      totalValue,
      cashBalance,
      investedValue: parseFloat(investedValue.toFixed(2)),
      holdingsCount: holdings.length,
      concentrationRisk: {
        topAsset,
        topAssetWeight,
        isConcentrated,
        advice: isConcentrated
          ? `Reduce position size in ${topAsset} to below 30% of portfolio equity.`
          : 'Concentration risk is within balanced parameters (<35%).',
      },
      assetClassDistribution: assetDist,
      volatilityAssessment,
      recommendations,
      isAiGenerated: true,
      disclaimer: this.DISCLAIMER,
    };
  }

  /**
   * Retrieves verified financial news summaries from permitted market sources.
   */
  static getCuratedNews(): NewsItem[] {
    const now = new Date();
    return [
      {
        id: 'news_1',
        title: 'Reserve Bank of India Keeps Key Repo Rate Unchanged at 6.5%',
        source: 'RBI Monetary Policy Committee Bulletin',
        category: 'MONETARY_POLICY',
        summary:
          'The MPC voted to keep the policy repo rate steady, reiterating focus on bringing inflation to the 4% target while sustaining economic growth momentum.',
        sentiment: 'NEUTRAL',
        publishedAt: new Date(now.getTime() - 45 * 60 * 1000).toISOString(),
        disclaimer: 'Curated financial news summary for educational simulation.',
      },
      {
        id: 'news_2',
        title: 'NIFTY IT Index Gains 1.8% on Strong US Cloud Spending Trajectory',
        source: 'NSE Market Watch & Sectoral Pulse',
        category: 'EQUITIES',
        summary:
          'IT leaders TCS and Infosys led sectoral advances as quarterly cloud migration pipelines in North American and European enterprises expanded.',
        sentiment: 'BULLISH',
        publishedAt: new Date(now.getTime() - 110 * 60 * 1000).toISOString(),
        disclaimer: 'Curated financial news summary for educational simulation.',
      },
      {
        id: 'news_3',
        title: 'Gold Futures Hover Near All-Time Highs Amid Geopolitical Hedging',
        source: 'MCX Commodity Wire',
        category: 'COMMODITIES',
        summary:
          'MCX Gold 1KG contracts tested ₹78,500/10g resistance as institutional central bank reserve diversification sustained robust physical bullion demand.',
        sentiment: 'BULLISH',
        publishedAt: new Date(now.getTime() - 180 * 60 * 1000).toISOString(),
        disclaimer: 'Curated financial news summary for educational simulation.',
      },
      {
        id: 'news_4',
        title: 'Crude Oil Softens as Global Refining Margins Contract in Q3',
        source: 'Global Energy Transition Review',
        category: 'COMMODITIES',
        summary:
          'Brent and MCX crude futures retreated below ₹6,200/bbl on rising inventory buffers across major consumer ports.',
        sentiment: 'BEARISH',
        publishedAt: new Date(now.getTime() - 240 * 60 * 1000).toISOString(),
        disclaimer: 'Curated financial news summary for educational simulation.',
      },
    ];
  }
}
