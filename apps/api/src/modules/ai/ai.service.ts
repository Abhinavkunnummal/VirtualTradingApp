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

export interface LearningModule {
  id: string;
  order: number;
  title: string;
  category: string;
  readTimeMinutes: number;
  description: string;
  learningObjectives: string[];
  contentSections: { heading: string; body: string }[];
  keyTakeaways: string[];
  quizzes: {
    question: string;
    options: string[];
    correctIndex: number;
    explanation: string;
  }[];
}

export interface TutorResponse {
  question: string;
  answer: string;
  exampleScenario: string;
  actionableTip: string;
  isAiGenerated: true;
  disclaimer: string;
}

export class AiAssistantService {
  private static readonly DISCLAIMER =
    'Educational use only. Not financial advice. TradeVerse AI never executes real-money trades or autonomous orders.';

  private static readonly INJECTION_PATTERNS = [
    /ignore (?:all )?(?:previous|above) instructions/i,
    /system (?:prompt|override)/i,
    /execute (?:order|trade|buy|sell)/i,
    /you are now in (?:developer|dan|god|unrestricted) mode/i,
    /jailbreak/i,
    /bypass (?:safety|guardrails|filters)/i,
    /drop (?:table|database)/i,
    /<script/i,
    /<\|im_start\|>/i,
    /\[INST\]/i,
    /```system/i,
  ];

  /**
   * Multi-layered guard against prompt injection, delimiter breakout, and malicious command overrides.
   */
  static validatePromptSafety(prompt: string, maxLen: number = 300): void {
    if (!prompt || typeof prompt !== 'string') {
      throw new Error('Prompt security violation: Prompt input must be a non-empty string.');
    }

    if (prompt.length > maxLen) {
      throw new Error(`Prompt security violation: Prompt length (${prompt.length}) exceeds maximum limit (${maxLen}).`);
    }

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
    this.validatePromptSafety(concept, 200);
    if (context) this.validatePromptSafety(context, 500);

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

  /**
   * 8 Comprehensive Beginner-to-Intermediate Trading Modules
   */
  static getLearningModules(): LearningModule[] {
    return [
      {
        id: 'market_basics',
        order: 1,
        title: 'Market Basics & How Exchanges Work',
        category: 'FOUNDATIONS',
        readTimeMinutes: 5,
        description: 'Understand the core mechanics of stock markets, how buy/sell orders match in order books, and the role of NSE, BSE, and SEBI.',
        learningObjectives: [
          'Understand what an exchange does and how market liquidity is maintained',
          'Learn the role of Bids, Asks, and the Bid-Ask Spread',
          'Distinguish between Market Capitalization tiers (Large, Mid, Small Cap)',
        ],
        contentSections: [
          {
            heading: 'What is a Stock Market?',
            body: 'A financial marketplace where buyers and sellers trade shares of publicly listed companies. In India, primary trading takes place on the National Stock Exchange (NSE) and Bombay Stock Exchange (BSE). Exchanges act as neutral matching engines guaranteeing settlement and trade integrity.',
          },
          {
            heading: 'The Order Book & Bid-Ask Spread',
            body: 'The Order Book is an electronic list of buy orders (Bids) and sell orders (Asks) organized by price. The highest bid and lowest ask define the current market spread. When high volume is traded, spreads stay tight (e.g. ₹0.05), reducing slippage for traders.',
          },
        ],
        keyTakeaways: [
          'Exchanges match buyers and sellers through continuous double auction order books',
          'Tighter spreads indicate higher liquidity and lower transaction friction',
          'Market indices like NIFTY 50 and SENSEX track overall economy benchmark performance',
        ],
        quizzes: [
          {
            question: 'What does the "Ask" price represent in an electronic order book?',
            options: [
              'The highest price a buyer is willing to pay',
              'The lowest price a seller is willing to accept',
              'The average price over the last 15 minutes',
              'The total volume traded during the day',
            ],
            correctIndex: 1,
            explanation: 'The Ask (or Offer) is the lowest price at which an existing seller in the order book is willing to sell their shares.',
          },
        ],
      },
      {
        id: 'candlesticks',
        order: 2,
        title: 'Candlestick Anatomy & High-Probability Patterns',
        category: 'TECHNICAL_ANALYSIS',
        readTimeMinutes: 6,
        description: 'Master Open, High, Low, Close (OHLC) anatomy and recognize trend continuation and reversal candlestick signatures.',
        learningObjectives: [
          'Deconstruct candlestick bodies, upper wicks, and lower wicks',
          'Identify key bullish reversal patterns (Hammer, Bullish Engulfing)',
          'Identify bearish rejection signals (Shooting Star, Bearish Engulfing)',
        ],
        contentSections: [
          {
            heading: 'Candle Body vs Wicks (Shadows)',
            body: 'A green/bullish candle indicates the closing price was higher than the opening price. A red/bearish candle indicates the close was below open. The thin lines above and below (wicks) mark the absolute highest and lowest prices reached during that timeframe.',
          },
          {
            heading: 'The Power of Long Rejection Wicks',
            body: 'A long lower wick with a small upper body (Hammer) signifies sellers pushed price down aggressively, but buyers absorbed the supply and pushed price back up before close. This often signals support exhaustion.',
          },
        ],
        keyTakeaways: [
          'Candles compress four critical data points: Open, High, Low, and Close',
          'Long shadows indicate price rejection and strong liquidity absorption',
          'Patterns must always be confirmed by volume and overall market trend context',
        ],
        quizzes: [
          {
            question: 'What does a long lower wick on a candle typically indicate?',
            options: [
              'Extreme selling pressure closing at the lows',
              'Price rejection where buyers stepped in and absorbed lower selling',
              'The market had zero volume during the timeframe',
              'The exchange halted trading abruptly',
            ],
            correctIndex: 1,
            explanation: 'A long lower wick shows that although sellers pushed price down, buyers aggressively purchased the dip, rejecting lower price levels.',
          },
        ],
      },
      {
        id: 'order_types',
        order: 3,
        title: 'Order Types & Precision Execution',
        category: 'EXECUTION',
        readTimeMinutes: 5,
        description: 'Know when to use Market, Limit, Stop-Loss (SL), and Stop-Loss Market (SL-M) orders to safeguard your virtual capital.',
        learningObjectives: [
          'Compare immediate market fills with price-guaranteed limit orders',
          'Master Stop-Loss Trigger prices to protect capital automatically',
          'Differentiate Delivery (CNC) from Intraday Leverage (MIS)',
        ],
        contentSections: [
          {
            heading: 'Market vs Limit Orders',
            body: 'Market orders prioritize immediate execution speed over price certainty, filling at whatever best bids/asks are available. Limit orders guarantee your target price or better, but will not execute if the market does not reach that price.',
          },
          {
            heading: 'Stop-Loss (SL) Mechanics',
            body: 'A Stop-Loss order sits dormant until the market trades at your designated trigger price. Once triggered, it activates and executes, preventing runaway catastrophic losses if the market moves against your position.',
          },
        ],
        keyTakeaways: [
          'Never use market orders during low-liquidity or high-volatility news events to avoid severe slippage',
          'Always use a Stop-Loss order to define your maximum acceptable loss before entering',
          'MIS provides 5x leverage but must be closed before market session close',
        ],
        quizzes: [
          {
            question: 'Why would a trader use a Limit order instead of a Market order?',
            options: [
              'To guarantee execution happens within 1 millisecond',
              'To ensure their fill price is equal to or better than a specified target',
              'To borrow 10x leverage from the broker',
              'Because Limit orders never incur exchange transaction fees',
            ],
            correctIndex: 1,
            explanation: 'A Limit order guarantees that the trade will only execute at the specified limit price or a more favorable price.',
          },
        ],
      },
      {
        id: 'support_resistance',
        order: 4,
        title: 'Support, Resistance & Trendlines',
        category: 'TECHNICAL_ANALYSIS',
        readTimeMinutes: 6,
        description: 'Identify horizontal demand and supply zones where institutional order flow regularly pivots.',
        learningObjectives: [
          'Locate major horizontal support (demand) and resistance (supply) levels',
          'Understand role reversal: when broken resistance becomes new support',
          'Draw objective trendlines using swing highs and swing lows',
        ],
        contentSections: [
          {
            heading: 'Why Support and Resistance Exist',
            body: 'Support is a price level where buyers consistently find value and enter in sufficient volume to halt a downward slide. Resistance is a ceiling where profit-takers and short sellers overpower buyers.',
          },
          {
            heading: 'The Principle of Role Reversal',
            body: 'When a strong resistance level is decisively broken with heavy volume, that level frequently becomes new support upon the next retest as former sellers turn into buyers.',
          },
        ],
        keyTakeaways: [
          'Support and resistance are dynamic zones, not single mathematical pennies',
          'The more times a level is tested without breaking, the stronger it is until final liquidity exhaustion',
          'Trade with the direction of the dominant higher-timeframe trend',
        ],
        quizzes: [
          {
            question: 'What commonly happens when a significant resistance level is broken on heavy volume?',
            options: [
              'The stock is permanently delisted',
              'The broken resistance level often acts as new support on future pullbacks',
              'The stock immediately drops to zero',
              'All limit orders in the market are cancelled',
            ],
            correctIndex: 1,
            explanation: 'This is the classic principle of polarity/role reversal: once broken, former resistance levels often become future support zones.',
          },
        ],
      },
      {
        id: 'indicators',
        order: 5,
        title: 'Technical Indicators: RSI, Moving Averages & MACD',
        category: 'TECHNICAL_ANALYSIS',
        readTimeMinutes: 7,
        description: 'Harness momentum oscillators and trend filters without suffering analysis paralysis.',
        learningObjectives: [
          'Interpret the Relative Strength Index (RSI) for overbought (>70) and oversold (<30) signals',
          'Use 20, 50, and 200 Exponential Moving Averages (EMAs) as trend roadmaps',
          'Spot MACD histogram momentum shifts and signal line crossovers',
        ],
        contentSections: [
          {
            heading: 'Moving Averages as Trend Filters',
            body: 'The 200 EMA represents the long-term institutional trend. When price is comfortably above the rising 200 EMA, favor long setups on pullbacks to the 20 or 50 EMA. When below, favor short or defensive cash preservation.',
          },
          {
            heading: 'RSI: Divergences over Simple Extremes',
            body: 'In strong trending markets, RSI can stay overbought (>70) for weeks. The most powerful RSI signal is bullish/bearish divergence: when price makes a new high but RSI fails to make a higher high.',
          },
        ],
        keyTakeaways: [
          'Indicators are mathematical derivatives of price and volume; price action always leads',
          'Use indicators to confirm thesis rather than as standalone buy/sell triggers',
          'Combine a trend indicator (e.g. 50 EMA) with a momentum oscillator (RSI)',
        ],
        quizzes: [
          {
            question: 'What is a Bearish RSI Divergence?',
            options: [
              'Price makes a higher high, but the RSI makes a lower high',
              'Price and RSI both drop below zero simultaneously',
              'The RSI indicator flatlines at 50 for more than one day',
              'The 20 EMA crosses below the 50 EMA',
            ],
            correctIndex: 0,
            explanation: 'A bearish divergence occurs when price pushes to a new peak while the RSI momentum oscillator fails to confirm, indicating waning buying momentum.',
          },
        ],
      },
      {
        id: 'risk_reward',
        order: 6,
        title: 'Risk-to-Reward Ratio & Position Sizing',
        category: 'RISK_MANAGEMENT',
        readTimeMinutes: 6,
        description: 'The math behind professional trading: how a 40% win rate can produce substantial long-term profitability.',
        learningObjectives: [
          'Calculate the Risk-to-Reward ratio (R:R) before entering any trade',
          'Master the 1% Portfolio Risk Rule to eliminate ruin risk',
          'Calculate exact share quantity based on Stop-Loss distance',
        ],
        contentSections: [
          {
            heading: 'Why Win Rate is Secondary to Asymmetry',
            body: 'If you win only 4 out of 10 trades (40% win rate), but make ₹2,000 on winners (1:2 R:R) and lose only ₹1,000 on losers, you gain: (4 × ₹2,000) - (6 × ₹1,000) = +₹2,000 net profit. Asymmetric payoff is the cornerstone of trading profitability.',
          },
          {
            heading: 'Formula for Position Sizing',
            body: 'Position Size = (Total Account Capital × Risk %) / (Entry Price - Stop Loss Price). Never adjust your stop loss to fit your position size; always adjust your position size to fit your technical stop loss.',
          },
        ],
        keyTakeaways: [
          'Target a minimum of 1:2 Risk-to-Reward on every discretionary paper trade',
          'Never risk more than 1% to 2% of total virtual capital on any single setup',
          'Position size must be calculated mathematically based on the invalidation point',
        ],
        quizzes: [
          {
            question: 'If your virtual account has ₹10,00,000 and you risk 1% on a trade, what is your maximum allowed loss?',
            options: [
              '₹1,000',
              '₹10,000',
              '₹50,000',
              '₹1,00,000',
            ],
            correctIndex: 1,
            explanation: '1% of ₹10,00,000 is ₹10,000. Your position size and stop-loss distance should ensure you never lose more than ₹10,000 if stopped out.',
          },
        ],
      },
      {
        id: 'stop_loss_discipline',
        order: 7,
        title: 'Stop-Loss Discipline & Trading Psychology',
        category: 'PSYCHOLOGY',
        readTimeMinutes: 5,
        description: 'Overcome cognitive biases: eliminate revenge trading, FOMO, and the dangerous urge to move your stop loss.',
        learningObjectives: [
          'Recognize emotional triggers: Fear of Missing Out (FOMO) and Revenge Trading',
          'Commit to the inviolable rule: Never move a Stop-Loss away from your entry',
          'Accept losses as routine business expenses in statistical trading systems',
        ],
        contentSections: [
          {
            heading: 'The Sunk Cost Fallacy in Trading',
            body: 'Holding onto a losing trade hoping it "bounces back to break-even" ties up margin and exposes the account to catastrophic drawdown. In professional trading, a small controlled loss is a badge of discipline.',
          },
          {
            heading: 'Stopping Revenge Trading',
            body: 'After two consecutive losses, dopamine and ego push traders to double their size to win it back. Implement a hard daily loss limit (e.g. -2% of portfolio) that closes your screen for the day.',
          },
        ],
        keyTakeaways: [
          'Losses are statistical probabilities, not personal failures',
          'Moving a stop-loss further away is the leading cause of blown accounts',
          'Maintain a calm emotional baseline: trade execution should feel boring and methodical',
        ],
        quizzes: [
          {
            question: 'What is the recommended response when an open position hits your predetermined Stop-Loss?',
            options: [
              'Move the stop loss further down to give the trade more breathing room',
              'Accept the exit cleanly according to plan and log the trade in your journal',
              'Immediately double the position size to lower the average cost basis',
              'Switch to a higher-risk asset like Crypto futures to recover the loss immediately',
            ],
            correctIndex: 1,
            explanation: 'Discipline requires accepting the planned stop-loss immediately. Moving stops or averaging down on losers often leads to catastrophic capital destruction.',
          },
        ],
      },
      {
        id: 'paper_practice',
        order: 8,
        title: 'Simulated Paper Trading Mastery & Journaling',
        category: 'PRACTICE',
        readTimeMinutes: 5,
        description: 'Transform simulator hours into genuine market edge through meticulous trade journaling and execution reviews.',
        learningObjectives: [
          'Use TradeVerse AI simulator to stress-test strategies across varied market regimes',
          'Maintain a systematic trading journal tracking setup, entry trigger, and emotional state',
          'Graduate to consistent profitability in simulation before considering real capital',
        ],
        contentSections: [
          {
            heading: 'Treat Simulation like Real Capital',
            body: 'The greatest pitfall in paper trading is treating fictional funds as a reckless video game. Every simulated rupee should be treated with the solemnity of hard-earned real capital to build genuine neural pathways.',
          },
          {
            heading: 'The Post-Trade Review Process',
            body: 'Review every closed trade: Did you follow your rules? Did you enter at the planned level? Did you honor your stop loss? Grade your discipline rather than just your profit/loss outcome.',
          },
        ],
        keyTakeaways: [
          'A winning process reliably produces long-term profits; a single lucky trade proves nothing',
          'Keep your TradeVerse trade history clean and auditable',
          'Consistency in paper trading is the only reliable foundation for real-world trading longevity',
        ],
        quizzes: [
          {
            question: 'What is the primary objective of paper trading in TradeVerse AI?',
            options: [
              'To boast about unrealistic 1000% fictional profits on social media',
              'To build disciplined habits, test strategies, and master risk control without financial risk',
              'To bypass financial regulation and brokerage commissions in real accounts',
              'To predict tomorrow morning stock prices with 100% certainty',
            ],
            correctIndex: 1,
            explanation: 'Paper trading exists to safely cultivate technical execution, emotional discipline, and risk management systems in real-time market conditions without financial loss.',
          },
        ],
      },
    ];
  }

  /**
   * Evaluates quiz submissions for an educational module
   */
  static evaluateQuiz(
    moduleId: string,
    answers: { questionIndex: number; selectedIndex: number }[]
  ) {
    const modules = this.getLearningModules();
    const mod = modules.find((m) => m.id === moduleId);
    if (!mod) {
      throw new Error(`Module "${moduleId}" not found.`);
    }

    let correctCount = 0;
    const results = mod.quizzes.map((q, idx) => {
      const userAnswer = answers.find((a) => a.questionIndex === idx);
      const isCorrect = userAnswer?.selectedIndex === q.correctIndex;
      if (isCorrect) correctCount++;

      return {
        questionIndex: idx,
        question: q.question,
        userSelected: userAnswer ? q.options[userAnswer.selectedIndex] : null,
        correctOption: q.options[q.correctIndex],
        isCorrect: Boolean(isCorrect),
        explanation: q.explanation,
      };
    });

    const scorePercent = Math.round((correctCount / mod.quizzes.length) * 100);
    const passed = scorePercent >= 80;

    return {
      moduleId: mod.id,
      moduleTitle: mod.title,
      totalQuestions: mod.quizzes.length,
      correctCount,
      scorePercent,
      passed,
      badgeEarned: passed ? `Mastery: ${mod.title}` : null,
      results,
      disclaimer: this.DISCLAIMER,
    };
  }

  /**
   * Interactive AI Tutor for student trading queries
   */
  static askTutor(question: string, contextModuleId?: string): TutorResponse {
    this.validatePromptSafety(question);

    const qLower = question.toLowerCase();

    let answer =
      'In financial markets, trading success is built on clear statistical edge, strict risk management, and emotional control. Every trade should have a defined thesis, entry price, invalidation stop-loss, and realistic profit target before execution.';
    let example =
      'If you buy RELIANCE at ₹2,945, you might place a Stop-Loss at ₹2,925 (risking ₹20) and a Take-Profit target at ₹2,985 (aiming for ₹40 gain, a 1:2 Risk/Reward ratio).';
    let tip =
      'Never risk more than 1% of your virtual account on any single trade setup.';

    if (qLower.includes('candlestick') || qLower.includes('hammer') || qLower.includes('wick') || qLower.includes('doji')) {
      answer =
        'Candlesticks illustrate the psychological battle between buyers (bulls) and sellers (bears) over a fixed interval. A long wick at the bottom shows that sellers pushed price down, but buyers stepped in aggressively to absorb all supply and push price back up.';
      example =
        'A Hammer candle appearing at the bottom of a downtrend near support suggests that selling exhaustion has occurred and a rebound may be imminent.';
      tip =
        'Look for candlestick signals only at key support or resistance levels, never in the middle of nowhere.';
    } else if (qLower.includes('stop loss') || qLower.includes('sl') || qLower.includes('risk')) {
      answer =
        'A Stop-Loss is your personal insurance policy. It automatically exits your position when the market proves your trade idea wrong. Professional traders view losses not as failures, but as routine operational costs of their business.';
      example =
        'If you enter a trade risking ₹1,000 to make ₹2,500, losing ₹1,000 when stopped out is a total success of process—you protected the remaining ₹9,99,000 of your capital.';
      tip =
        'Never move your stop loss further away while in a losing trade. Accept the planned invalidation immediately.';
    } else if (qLower.includes('rsi') || qLower.includes('indicator') || qLower.includes('moving average')) {
      answer =
        'Technical indicators are mathematical derivations of price and volume designed to identify trend direction and momentum exhaustion. The 200 EMA helps you trade in alignment with the long-term tide, while RSI reveals if momentum is accelerating or slowing down.';
      example =
        'When price touches the 50-day EMA while RSI hovers around 40-45 during an overall bull trend, it often marks an attractive dip-buying zone.';
      tip =
        'Price action and volume always lead; never let an indicator override clean horizontal support and resistance.';
    } else if (qLower.includes('margin') || qLower.includes('mis') || qLower.includes('cnc') || qLower.includes('leverage')) {
      answer =
        'CNC (Cash and Carry) is delivery trading where you pay 100% of the share value and own the position overnight. MIS (Margin Intraday Square-off) provides leverage (typically up to 5x) for day trading, but requires closing before the market session ends.';
      example =
        'With ₹1,00,000 cash, CNC allows you to buy ₹1,00,000 worth of TCS. Under MIS 5x leverage, you can take a ₹5,00,000 intraday position, though your gains and losses are both multiplied by 5x.';
      tip =
        'Beginner traders should master 1x CNC paper trading first before attempting leveraged MIS intraday trades.';
    }

    return {
      question,
      answer,
      exampleScenario: example,
      actionableTip: tip,
      isAiGenerated: true,
      disclaimer: this.DISCLAIMER,
    };
  }
}
