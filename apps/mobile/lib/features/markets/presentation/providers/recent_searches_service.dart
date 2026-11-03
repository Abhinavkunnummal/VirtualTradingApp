import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'tradeverse_recent_searches';
  static const int _maxRecent = 10;

  RecentSearchesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      if (list != null && list.isNotEmpty) {
        state = list;
      }
    } catch (_) {
      // In tests or if storage unavailable
    }
  }

  Future<void> addSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final updated = [
      clean,
      ...state.where((item) => item.toLowerCase() != clean.toLowerCase()),
    ];

    if (updated.length > _maxRecent) {
      updated.removeRange(_maxRecent, updated.length);
    }

    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, updated);
    } catch (_) {}
  }

  Future<void> removeSearch(String query) async {
    final updated = state.where((item) => item != query).toList();
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, updated);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}

final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});
