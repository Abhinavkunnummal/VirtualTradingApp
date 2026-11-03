import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'tradeverse_recent_searches';
  static const int _maxRecent = 10;
  final FlutterSecureStorage _storage;

  RecentSearchesNotifier([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          state = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      // In tests or if storage is uninitialized
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
      await _storage.write(key: _storageKey, value: jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> removeSearch(String query) async {
    final updated = state.where((item) => item != query).toList();
    state = updated;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = const [];
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});
