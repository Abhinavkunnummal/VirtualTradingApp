import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/learn/domain/learn_models.dart';

final learningModulesProvider = FutureProvider<List<LearningModuleModel>>((ref) async {
  final authState = ref.watch(authProvider);

  if (authState.isDemoMode) {
    return _getDemoLearningModules();
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>('/ai/lessons');
    if (response.statusCode == 200 && response.data?['success'] == true) {
      final list = response.data!['modules'] as List<dynamic>? ?? [];
      return list.map((m) => LearningModuleModel.fromJson(m as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return _getDemoLearningModules();
});

final completedModulesProvider = StateProvider<Set<String>>((ref) => <String>{});

final aiTutorServiceProvider = Provider<AiTutorService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final isDemo = ref.watch(authProvider).isDemoMode;
  return AiTutorService(apiClient: apiClient, isDemo: isDemo);
});

class AiTutorService {
  final ApiClient apiClient;
  final bool isDemo;

  AiTutorService({required this.apiClient, required this.isDemo});

  Future<TutorResponseModel> askTutor(String question, {String? contextModuleId}) async {
    if (isDemo) {
      return TutorResponseModel(
        question: question,
        answer: 'In paper trading, discipline and risk control are paramount. Focus on technical setups where you can define a tight invalidation stop-loss, giving you at least a 1:2 risk-to-reward ratio.',
        exampleScenario: 'For example, if you buy RELIANCE at ₹2,945 with a stop-loss at ₹2,925 (risking ₹20), aim for ₹2,985 target (+₹40 gain).',
        actionableTip: 'Never risk more than 1% to 2% of total capital on any single trade.',
        disclaimer: 'Educational simulated tutor response. Not financial advice.',
      );
    }

    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/ai/tutor',
        data: {'question': question, if (contextModuleId != null) 'contextModuleId': contextModuleId},
      );

      if (response.statusCode == 200 && response.data?['success'] == true) {
        return TutorResponseModel.fromJson(response.data!['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return TutorResponseModel(
      question: question,
      answer: 'Always adhere to predefined stop-loss orders and verify that market volatility does not exceed your risk capacity.',
      exampleScenario: 'Paper practice helps you test execution without financial pressure.',
      actionableTip: 'Review every trade in your paper-trading history.',
      disclaimer: 'Simulated educational response.',
    );
  }
}

List<LearningModuleModel> _getDemoLearningModules() {
  return const [
    LearningModuleModel(
      id: 'market_basics',
      order: 1,
      title: 'Market Basics & How Exchanges Work',
      category: 'FOUNDATIONS',
      readTimeMinutes: 5,
      description: 'Understand the core mechanics of stock markets, how buy/sell orders match in order books, and the role of NSE, BSE, and SEBI.',
      learningObjectives: [
        'Understand what an exchange does and how market liquidity is maintained',
        'Learn the role of Bids, Asks, and the Bid-Ask Spread',
        'Distinguish between Market Capitalization tiers',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'What is a Stock Market?',
          body: 'A financial marketplace where buyers and sellers trade shares of publicly listed companies. Exchanges act as neutral matching engines guaranteeing settlement and trade integrity.',
        ),
      ],
      keyTakeaways: [
        'Exchanges match buyers and sellers through continuous double auction order books',
        'Tighter spreads indicate higher liquidity and lower transaction friction',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What does the "Ask" price represent in an electronic order book?',
          options: [
            'The highest price a buyer is willing to pay',
            'The lowest price a seller is willing to accept',
            'The average price over the last 15 minutes',
            'The total volume traded today',
          ],
          correctIndex: 1,
          explanation: 'The Ask is the lowest price at which an existing seller in the order book is willing to sell.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'candlesticks',
      order: 2,
      title: 'Candlestick Anatomy & Patterns',
      category: 'TECHNICAL_ANALYSIS',
      readTimeMinutes: 6,
      description: 'Master Open, High, Low, Close (OHLC) anatomy and recognize trend continuation and reversal candlestick signatures.',
      learningObjectives: [
        'Deconstruct candlestick bodies, upper wicks, and lower wicks',
        'Identify key bullish reversal patterns (Hammer, Bullish Engulfing)',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Candle Body vs Wicks',
          body: 'Green candle: Close > Open. Red candle: Close < Open. The wicks mark the absolute extremes reached during the timeframe.',
        ),
      ],
      keyTakeaways: [
        'Candles compress four critical data points: Open, High, Low, and Close',
        'Long lower wicks indicate buyer absorption of selling pressure',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What does a long lower wick on a candle typically indicate?',
          options: [
            'Extreme selling pressure closing at the lows',
            'Price rejection where buyers stepped in and absorbed lower selling',
            'The market had zero volume during the timeframe',
            'The exchange halted trading abruptly',
          ],
          correctIndex: 1,
          explanation: 'A long lower wick shows buyers rejected lower prices and absorbed seller supply.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'order_types',
      order: 3,
      title: 'Order Types & Precision Execution',
      category: 'EXECUTION',
      readTimeMinutes: 5,
      description: 'Know when to use Market, Limit, Stop-Loss (SL), and Stop-Loss Market (SL-M) orders.',
      learningObjectives: [
        'Compare immediate market fills with price-guaranteed limit orders',
        'Master Stop-Loss trigger prices',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Market vs Limit Orders',
          body: 'Market orders fill immediately at prevailing market prices. Limit orders execute only at specified price or better.',
        ),
      ],
      keyTakeaways: [
        'Always protect positions with Stop-Loss orders',
        'Limit orders prevent slippage during volatile periods',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'Why would a trader use a Limit order instead of a Market order?',
          options: [
            'To guarantee execution happens in 1 millisecond',
            'To ensure their fill price is equal to or better than a specified target',
            'To borrow 10x leverage from the broker',
            'Because Limit orders never incur fees',
          ],
          correctIndex: 1,
          explanation: 'Limit orders ensure price certainty.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'support_resistance',
      order: 4,
      title: 'Support, Resistance & Trendlines',
      category: 'TECHNICAL_ANALYSIS',
      readTimeMinutes: 6,
      description: 'Identify horizontal demand and supply zones where institutional order flow regularly pivots.',
      learningObjectives: [
        'Locate major horizontal support and resistance levels',
        'Understand role reversal',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Role Reversal Principle',
          body: 'When broken decisively, former resistance frequently turns into support on pullbacks.',
        ),
      ],
      keyTakeaways: [
        'Support and resistance are zones, not single pennies',
        'Trade with the trend of the higher timeframe',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What commonly happens when a significant resistance level is broken on heavy volume?',
          options: [
            'The stock is delisted',
            'The broken resistance often acts as new support on future pullbacks',
            'The stock immediately drops to zero',
            'All limit orders are cancelled',
          ],
          correctIndex: 1,
          explanation: 'Former resistance turns into new support.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'indicators',
      order: 5,
      title: 'Technical Indicators (RSI, EMAs, MACD)',
      category: 'TECHNICAL_ANALYSIS',
      readTimeMinutes: 7,
      description: 'Harness momentum oscillators and trend filters without suffering analysis paralysis.',
      learningObjectives: [
        'Use RSI for momentum divergences',
        'Follow 50 and 200 EMAs for trend direction',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'EMAs as Trend Guides',
          body: 'Above 200 EMA favors bullish setups; below favors defensive capital preservation.',
        ),
      ],
      keyTakeaways: [
        'Price action always leads mathematical indicators',
        'Look for momentum divergences near key structural levels',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What is a Bearish RSI Divergence?',
          options: [
            'Price makes a higher high, but RSI makes a lower high',
            'Price and RSI both drop below zero',
            'RSI flatlines at 50',
            'The 20 EMA crosses below 50 EMA',
          ],
          correctIndex: 0,
          explanation: 'A bearish divergence signals waning upward momentum.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'risk_reward',
      order: 6,
      title: 'Risk-to-Reward Ratio & Position Sizing',
      category: 'RISK_MANAGEMENT',
      readTimeMinutes: 6,
      description: 'The math behind professional trading: how a 40% win rate produces solid long-term profitability.',
      learningObjectives: [
        'Calculate Risk-to-Reward before order entry',
        'Enforce 1% maximum portfolio risk rule',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Asymmetric Payoff',
          body: 'Aiming for 1:2 R:R means 4 wins out of 10 trades yields net positive profit.',
        ),
      ],
      keyTakeaways: [
        'Target minimum 1:2 Risk-to-Reward ratio',
        'Size positions according to stop loss distance, not account balance',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'If your virtual account has ₹10,00,000 and you risk 1% on a trade, what is your maximum allowed loss?',
          options: ['₹1,000', '₹10,000', '₹50,000', '₹1,00,000'],
          correctIndex: 1,
          explanation: '1% of ₹10,00,000 is ₹10,000.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'stop_loss_discipline',
      order: 7,
      title: 'Stop-Loss Discipline & Psychology',
      category: 'PSYCHOLOGY',
      readTimeMinutes: 5,
      description: 'Overcome cognitive biases: eliminate revenge trading, FOMO, and the urge to move stop losses.',
      learningObjectives: [
        'Eliminate emotional revenge trading',
        'Never move a stop-loss further away',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Respecting Invalidation',
          body: 'Taking a small planned stop is a hallmark of professional discipline.',
        ),
      ],
      keyTakeaways: [
        'Losses are regular costs of statistical trading systems',
        'Maintain an emotionally neutral execution baseline',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What is the recommended response when an open position hits your predetermined Stop-Loss?',
          options: [
            'Move the stop loss further down to give it room',
            'Accept the exit cleanly according to plan and log the trade',
            'Double the position size immediately',
            'Switch to 20x leverage crypto to recover',
          ],
          correctIndex: 1,
          explanation: 'Accept the exit cleanly to preserve capital.',
        ),
      ],
    ),
    LearningModuleModel(
      id: 'paper_practice',
      order: 8,
      title: 'Simulated Paper Trading Mastery',
      category: 'PRACTICE',
      readTimeMinutes: 5,
      description: 'Transform simulator hours into genuine market edge through disciplined trade journaling.',
      learningObjectives: [
        'Stress-test strategies without real capital loss',
        'Maintain a systematic trading journal',
      ],
      contentSections: [
        ContentSectionModel(
          heading: 'Treat Simulation with Real Solemnity',
          body: 'Treat each simulated rupee with genuine respect to build disciplined behavioral patterns.',
        ),
      ],
      keyTakeaways: [
        'Consistency in paper trading is the only reliable foundation for future success',
        'Track process execution rather than just P&L',
      ],
      quizzes: [
        QuizQuestionModel(
          question: 'What is the primary objective of paper trading in TradeVerse AI?',
          options: [
            'To boast about unrealistic fictional profits',
            'To build disciplined habits, test strategies, and master risk control without financial risk',
            'To bypass financial regulation',
            'To predict tomorrow morning stock prices with 100% certainty',
          ],
          correctIndex: 1,
          explanation: 'Paper trading safely cultivates technical skill and psychological discipline.',
        ),
      ],
    ),
  ];
}
