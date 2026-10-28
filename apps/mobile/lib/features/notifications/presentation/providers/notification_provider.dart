import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/notification_models.dart';

class NotificationNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;

  NotificationNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.dio.get(ApiConstants.notifications);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> notifsJson = response.data['notifications'] as List<dynamic>;
        final list = notifsJson
            .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(list);
        return;
      }
    } catch (_) {
      // Offline fallback
    }

    state = AsyncValue.data([
      AppNotification(
        id: 'mock-notif-1',
        title: 'Order Filled: BUY 10 RELIANCE',
        message: 'Executed @ ₹2,580.45. Paper order filled successfully.',
        type: 'ORDER_FILL',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      AppNotification(
        id: 'mock-notif-2',
        title: 'Virtual Funds Added',
        message: '₹1,00,000 credited to your paper sandbox account.',
        type: 'TOPUP',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: 'mock-notif-3',
        title: 'Bracket Target Profit Placed',
        message: 'Target limit order active @ ₹2,650.00 for RELIANCE.',
        type: 'BRACKET_OCO',
        read: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  Future<void> markAsRead(String id) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => n.id == id ? n.copyWith(read: true) : n).toList(),
    );

    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.dio.patch('${ApiConstants.notifications}/$id/read');
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => n.copyWith(read: true)).toList(),
    );

    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.dio.post(ApiConstants.notificationsReadAll);
    } catch (_) {}
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationNotifier, AsyncValue<List<AppNotification>>>(
  (ref) => NotificationNotifier(ref),
);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  return notifsAsync.maybeWhen(
    data: (items) => items.where((n) => !n.read).length,
    orElse: () => 0,
  );
});
