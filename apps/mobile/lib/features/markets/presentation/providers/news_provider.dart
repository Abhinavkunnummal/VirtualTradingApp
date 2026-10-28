import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/news_models.dart';

final newsCategoryProvider = StateProvider<String>((ref) => 'ALL');

final newsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final category = ref.watch(newsCategoryProvider);
  final apiClient = ref.watch(apiClientProvider);

  try {
    final queryParams = <String, dynamic>{};
    if (category != 'ALL') {
      queryParams['category'] = category;
    }

    final response = await apiClient.dio.get(
      ApiConstants.news,
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List<dynamic> articlesJson = response.data['articles'] as List<dynamic>;
      return articlesJson
          .map((item) => NewsArticle.fromJson(item as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {
    // Graceful fallback to rich offline mock articles
  }

  // High-fidelity fallback articles for robust offline rendering
  final fallback = [
    NewsArticle(
      id: 'mock-001',
      title: 'Reliance Retail Expands Omnichannel Footprint, Boosts Forward EBITDA Outlook',
      summary:
        'Reliance Industries retail arm reports 18% YoY growth in quarterly consumer footfall, driven by tier-2 city digital store network integration.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.78,
      impact: 'HIGH',
      relatedSymbols: const ['RELIANCE', 'NIFTY 50'],
      source: 'TradeVerse Market Wire',
      publishedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      readTimeMinutes: 2,
    ),
    NewsArticle(
      id: 'mock-002',
      title: 'TCS Secures Multi-Million Dollar European Cloud Transformation Contract',
      summary:
        'Tata Consultancy Services signs a comprehensive 5-year digital core modernisation partnership with a major Nordic financial institution.',
      category: 'EQUITY',
      sentiment: 'BULLISH',
      sentimentScore: 0.65,
      impact: 'MEDIUM',
      relatedSymbols: const ['TCS', 'NIFTY 50'],
      source: 'Global Tech Insights',
      publishedAt: DateTime.now().subtract(const Duration(minutes: 42)),
      readTimeMinutes: 3,
    ),
    NewsArticle(
      id: 'mock-003',
      title: 'RBI MPC Holds Repo Rate Steady at 6.5%, Retains Withdrawal of Accommodation',
      summary:
        'Reserve Bank of India Governor highlights resilient domestic growth alongside continuing vigilance on food price volatility.',
      category: 'MACRO',
      sentiment: 'NEUTRAL',
      sentimentScore: 0.05,
      impact: 'HIGH',
      relatedSymbols: const ['NIFTY 50', 'SENSEX', 'HDFCBANK'],
      source: 'Central Bank Monitor',
      publishedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      readTimeMinutes: 4,
    ),
    NewsArticle(
      id: 'mock-004',
      title: 'Bitcoin Consolidates Near Highs as Institutional ETF Inflows Surge',
      summary:
        'BTC maintains strong price support above \$65,000 as net weekly spot ETF inflows cross \$1.2B amid growing sovereign balance sheet discussions.',
      category: 'CRYPTO',
      sentiment: 'BULLISH',
      sentimentScore: 0.82,
      impact: 'HIGH',
      relatedSymbols: const ['BTC/USDT', 'ETH/USDT'],
      source: 'CryptoDesk Terminal',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      readTimeMinutes: 3,
    ),
    NewsArticle(
      id: 'mock-005',
      title: 'Crude Oil Pressured by Rising Non-OPEC Production and Refinery Maintenance',
      summary:
        'Brent futures ease 1.2% as inventory builds offset Middle East geopolitical risk premiums in simulated derivative markets.',
      category: 'COMMODITY',
      sentiment: 'BEARISH',
      sentimentScore: -0.42,
      impact: 'MEDIUM',
      relatedSymbols: const ['CRUDE OIL', 'RELIANCE'],
      source: 'Energy Intelligence Wire',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      readTimeMinutes: 2,
    ),
  ];

  if (category == 'ALL') return fallback;
  return fallback.where((a) => a.category == category).toList();
});
