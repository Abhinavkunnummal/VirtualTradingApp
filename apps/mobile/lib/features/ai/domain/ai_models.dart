class ConceptExplanationModel {
  final String concept;
  final String simpleExplanation;
  final List<String> keyTakeaways;
  final String? bullishScenario;
  final String? bearishScenario;
  final List<String> riskFactors;
  final bool isAiGenerated;
  final String disclaimer;

  const ConceptExplanationModel({
    required this.concept,
    required this.simpleExplanation,
    required this.keyTakeaways,
    this.bullishScenario,
    this.bearishScenario,
    required this.riskFactors,
    this.isAiGenerated = true,
    required this.disclaimer,
  });

  factory ConceptExplanationModel.fromJson(Map<String, dynamic> json) {
    return ConceptExplanationModel(
      concept: json['concept'] as String? ?? '',
      simpleExplanation: json['simpleExplanation'] as String? ?? '',
      keyTakeaways: (json['keyTakeaways'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      bullishScenario: json['bullishScenario'] as String?,
      bearishScenario: json['bearishScenario'] as String?,
      riskFactors: (json['riskFactors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isAiGenerated: json['isAiGenerated'] as bool? ?? true,
      disclaimer: json['disclaimer'] as String? ??
          'Educational use only. Not financial advice. TradeVerse AI never executes real-money trades.',
    );
  }

  factory ConceptExplanationModel.demo(String concept) {
    return ConceptExplanationModel(
      concept: concept,
      simpleExplanation:
          'RSI is a momentum oscillator measuring price velocity from 0 to 100. Values above 70 indicate overbought conditions, while values below 30 indicate oversold conditions.',
      keyTakeaways: const [
        'Above 70 signals extended upward momentum and potential consolidation.',
        'Below 30 signals intense selling pressure and possible relief rally.',
        'Divergence between RSI and price often precedes trend exhaustion.',
      ],
      bullishScenario: 'Crossing back above 30 from oversold levels suggests buyers may be regaining control.',
      bearishScenario: 'Bearish divergence at key resistance points to momentum deceleration.',
      riskFactors: const ['In strong trends, RSI can remain overbought or oversold for extended periods.'],
      isAiGenerated: true,
      disclaimer: 'Educational use only. Not financial advice. Simulated data.',
    );
  }
}

class NewsArticleModel {
  final String id;
  final String title;
  final String source;
  final String category;
  final String summary;
  final String sentiment;
  final String publishedAt;
  final String disclaimer;

  const NewsArticleModel({
    required this.id,
    required this.title,
    required this.source,
    required this.category,
    required this.summary,
    required this.sentiment,
    required this.publishedAt,
    required this.disclaimer,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? '',
      category: json['category'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sentiment: json['sentiment'] as String? ?? 'NEUTRAL',
      publishedAt: json['publishedAt'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class PortfolioReviewModel {
  final double totalValue;
  final double cashBalance;
  final double investedValue;
  final int holdingsCount;
  final String topAsset;
  final double topAssetWeight;
  final bool isConcentrated;
  final String volatilityAssessment;
  final List<String> recommendations;
  final String disclaimer;

  const PortfolioReviewModel({
    required this.totalValue,
    required this.cashBalance,
    required this.investedValue,
    required this.holdingsCount,
    required this.topAsset,
    required this.topAssetWeight,
    required this.isConcentrated,
    required this.volatilityAssessment,
    required this.recommendations,
    required this.disclaimer,
  });

  factory PortfolioReviewModel.fromJson(Map<String, dynamic> json) {
    final conc = json['concentrationRisk'] as Map<String, dynamic>? ?? {};
    return PortfolioReviewModel(
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
      cashBalance: (json['cashBalance'] as num?)?.toDouble() ?? 0.0,
      investedValue: (json['investedValue'] as num?)?.toDouble() ?? 0.0,
      holdingsCount: json['holdingsCount'] as int? ?? 0,
      topAsset: conc['topAsset'] as String? ?? 'None',
      topAssetWeight: (conc['topAssetWeight'] as num?)?.toDouble() ?? 0.0,
      isConcentrated: conc['isConcentrated'] as bool? ?? false,
      volatilityAssessment: json['volatilityAssessment'] as String? ?? 'CONSERVATIVE',
      recommendations: (json['recommendations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }

  factory PortfolioReviewModel.demo() {
    return const PortfolioReviewModel(
      totalValue: 1248750.00,
      cashBalance: 425000.00,
      investedValue: 823750.00,
      holdingsCount: 3,
      topAsset: 'RELIANCE',
      topAssetWeight: 35.4,
      isConcentrated: true,
      volatilityAssessment: 'MODERATE',
      recommendations: [
        'RELIANCE represents 35.4% of portfolio capital. Consider rebalancing into uncorrelated assets.',
        'Cash buffer (34%) provides healthy liquidity against intraday margin calls.',
      ],
      disclaimer: 'Educational analysis based on simulated paper holdings. Not investment advice.',
    );
  }
}
