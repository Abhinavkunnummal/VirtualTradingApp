import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:tradeverse_mobile/features/ai/domain/ai_models.dart';

final selectedAiPromptProvider = StateProvider<String>((ref) => 'RSI Momentum');

final aiExplanationProvider = FutureProvider.family<ConceptExplanationModel, String>((ref, concept) async {
  final authState = ref.watch(authProvider);

  if (authState.isDemoMode) {
    return ConceptExplanationModel.demo(concept);
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/ai/explain',
      data: {'concept': concept},
    );

    if (response.statusCode == 200 && response.data?['success'] == true) {
      return ConceptExplanationModel.fromJson(response.data!['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  return ConceptExplanationModel.demo(concept);
});

final aiNewsProvider = FutureProvider<List<NewsArticleModel>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isDemoMode) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.get<Map<String, dynamic>>('/ai/news-summary');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final list = response.data!['articles'] as List<dynamic>? ?? [];
        return list.map((a) => NewsArticleModel.fromJson(a as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  // Fallback curated news feed for demo mode
  return [
    const NewsArticleModel(
      id: 'news_1',
      title: 'RBI Monetary Policy Committee Keeps Repo Rate Steady at 6.5%',
      source: 'RBI Policy Bulletin',
      category: 'MONETARY_POLICY',
      summary: 'Central bank maintains pause to balance 4% inflation alignment with robust manufacturing growth.',
      sentiment: 'NEUTRAL',
      publishedAt: '45m ago',
      disclaimer: 'Curated financial news summary for educational simulation.',
    ),
    const NewsArticleModel(
      id: 'news_2',
      title: 'NIFTY IT Index Extends Gains as Cloud Modernization Orders Surge',
      source: 'NSE Sector Pulse',
      category: 'EQUITIES',
      summary: 'TCS and Infosys lead gains following multi-year enterprise transformation contract renewals.',
      sentiment: 'BULLISH',
      publishedAt: '1h ago',
      disclaimer: 'Curated financial news summary for educational simulation.',
    ),
    const NewsArticleModel(
      id: 'news_3',
      title: 'MCX Gold Tests ₹78,500 Resistance as Central Bank Allocations Persist',
      source: 'MCX Wire',
      category: 'COMMODITIES',
      summary: 'Safe-haven accumulation keeps physical bullion demand elevated despite high interest rates.',
      sentiment: 'BULLISH',
      publishedAt: '2h ago',
      disclaimer: 'Curated financial news summary for educational simulation.',
    ),
  ];
});

final aiPortfolioReviewProvider = FutureProvider<PortfolioReviewModel>((ref) async {
  final authState = ref.watch(authProvider);

  if (authState.isDemoMode) {
    return PortfolioReviewModel.demo();
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>('/ai/portfolio-review');
    if (response.statusCode == 200 && response.data?['success'] == true) {
      return PortfolioReviewModel.fromJson(response.data!['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  return PortfolioReviewModel.demo();
});
