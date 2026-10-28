class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String sentiment;
  final double sentimentScore;
  final String impact;
  final List<String> relatedSymbols;
  final String source;
  final DateTime publishedAt;
  final int readTimeMinutes;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.sentiment,
    required this.sentimentScore,
    required this.impact,
    required this.relatedSymbols,
    required this.source,
    required this.publishedAt,
    required this.readTimeMinutes,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      category: json['category'] as String? ?? 'ALL',
      sentiment: json['sentiment'] as String? ?? 'NEUTRAL',
      sentimentScore: (json['sentimentScore'] as num?)?.toDouble() ?? 0.0,
      impact: json['impact'] as String? ?? 'MEDIUM',
      relatedSymbols: (json['relatedSymbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      source: json['source'] as String? ?? 'TradeVerse Wire',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      readTimeMinutes: (json['readTimeMinutes'] as num?)?.toInt() ?? 2,
    );
  }
}
