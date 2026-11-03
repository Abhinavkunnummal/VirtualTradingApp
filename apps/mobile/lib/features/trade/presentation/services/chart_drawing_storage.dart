import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChartDrawingStorage {
  static const String _keyPrefix = 'chart_drawings_';

  final FlutterSecureStorage _storage;

  ChartDrawingStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static String _canonicalSymbol(String symbol) {
    return symbol.toUpperCase().replaceAll(RegExp(r'[\/\-_]'), '').replaceFirst(RegExp(r'USDT$|USD$'), '');
  }

  Future<void> saveDrawings(String symbol, List<Map<String, dynamic>> drawings) async {
    final key = '$_keyPrefix${_canonicalSymbol(symbol)}';
    if (drawings.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: jsonEncode(drawings));
    }
  }

  Future<List<Map<String, dynamic>>> loadDrawings(String symbol) async {
    try {
      final key = '$_keyPrefix${_canonicalSymbol(symbol)}';
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearDrawings(String symbol) async {
    final key = '$_keyPrefix${_canonicalSymbol(symbol)}';
    await _storage.delete(key: key);
  }
}
