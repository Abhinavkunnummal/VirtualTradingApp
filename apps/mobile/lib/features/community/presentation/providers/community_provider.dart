import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/community_models.dart';

final selectedRoomIdProvider = StateProvider<String>((ref) => 'room:general');

final communityRoomsProvider = FutureProvider<List<CommunityRoomModel>>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isDemoMode) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.get('/community/rooms');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['rooms'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          return list.map((r) => CommunityRoomModel.fromJson(r as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
  }

  // Baseline rooms
  return const [
    CommunityRoomModel(
      roomId: 'room:general',
      name: 'Live Trading Floor',
      description: 'General discussion & market sentiment.',
      category: 'GENERAL',
      memberCount: 1420,
    ),
    CommunityRoomModel(
      roomId: 'room:nifty',
      name: 'NIFTY & Equities Desk',
      description: 'NSE / BSE index futures & breakouts.',
      category: 'EQUITIES',
      memberCount: 890,
    ),
    CommunityRoomModel(
      roomId: 'room:crypto',
      name: 'Crypto 24/7 Floor',
      description: 'Continuous Bitcoin & Ethereum setups.',
      category: 'CRYPTO',
      memberCount: 650,
    ),
    CommunityRoomModel(
      roomId: 'room:commodities',
      name: 'MCX Gold & Crude Hub',
      description: 'Commodity futures & crude oil simulations.',
      category: 'COMMODITIES',
      memberCount: 410,
    ),
  ];
});

final roomMessagesProvider = FutureProvider.family<List<CommunityMessageModel>, String>((ref, roomId) async {
  final authState = ref.watch(authProvider);

  if (!authState.isDemoMode) {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.get('/community/rooms/$roomId/messages');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['messages'] as List<dynamic>? ?? [];
        return list.map((m) => CommunityMessageModel.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  // Baseline demo messages
  return [
    CommunityMessageModel(
      id: 'demo_msg_1',
      roomId: roomId,
      authorName: 'Vikram Mehra',
      content: 'RELIANCE closed above 20 EMA on 1H chart with expanding volume. Paper long initiated with target ₹3,020 and invalidation at ₹2,925.',
      type: 'EDUCATIONAL',
      tradeTag: 'PAPER BUY • RELIANCE',
      sentiment: 'BULLISH',
      likesCount: 42,
      createdAt: '12m ago',
    ),
    CommunityMessageModel(
      id: 'demo_msg_2',
      roomId: roomId,
      authorName: 'Priya Sen',
      content: 'Testing short volatility regime for tomorrow. Delta neutral setup yielding 1:1.8 risk reward with 74% win probability in backtest.',
      type: 'CHAT',
      tradeTag: 'PAPER SPREAD • NIFTY',
      sentiment: 'NEUTRAL',
      likesCount: 88,
      createdAt: '45m ago',
    ),
    CommunityMessageModel(
      id: 'demo_msg_3',
      roomId: roomId,
      authorName: 'Siddharth Rao',
      content: 'BTC/USDT 15m Momentum Bot 7-Day Performance: virtual account achieved +14.2% return over 120 simulated fills with max drawdown limited to 2.8%.',
      type: 'EDUCATIONAL',
      tradeTag: 'ALGO BOT • BTC/USDT',
      sentiment: 'BULLISH',
      likesCount: 134,
      createdAt: '2h ago',
    ),
  ];
});

final postMessageProvider = Provider<PostMessageService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final isDemo = ref.watch(authProvider).isDemoMode;
  return PostMessageService(apiClient: apiClient, isDemo: isDemo, ref: ref);
});

class PostMessageService {
  final dynamic apiClient;
  final bool isDemo;
  final Ref ref;

  PostMessageService({required this.apiClient, required this.isDemo, required this.ref});

  Future<bool> postMessage({
    required String roomId,
    required String content,
    String? tradeTag,
    String? sentiment,
  }) async {
    if (isDemo) {
      ref.invalidate(roomMessagesProvider(roomId));
      return true;
    }

    try {
      final response = await apiClient.post(
        '/community/rooms/$roomId/messages',
        data: {
          'content': content,
          'type': 'CHAT',
          if (tradeTag != null) 'tradeTag': tradeTag,
          if (sentiment != null) 'sentiment': sentiment,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        ref.invalidate(roomMessagesProvider(roomId));
        return true;
      }
    } catch (_) {}

    return false;
  }
}
