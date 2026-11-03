import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'tradeverse_access_token';
  static const String _refreshTokenKey = 'tradeverse_refresh_token';
  static const String _demoModeKey = 'tradeverse_demo_mode';

  final FlutterSecureStorage _storage;

  // In-memory cache to eliminate async KeyStore/MethodChannel race conditions
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  bool? _cachedDemoMode;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    // 1. Synchronous in-memory update for zero-latency consecutive reads
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;

    // 2. Asynchronous disk persistence
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    final diskToken = await _storage.read(key: _accessTokenKey);
    _cachedAccessToken = diskToken;
    return diskToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    final diskToken = await _storage.read(key: _refreshTokenKey);
    _cachedRefreshToken = diskToken;
    return diskToken;
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> setDemoMode(bool isDemo) async {
    _cachedDemoMode = isDemo;
    await _storage.write(key: _demoModeKey, value: isDemo ? 'true' : 'false');
  }

  Future<bool> isDemoMode() async {
    if (_cachedDemoMode != null) {
      return _cachedDemoMode!;
    }
    final val = await _storage.read(key: _demoModeKey);
    final isDemo = val == 'true';
    _cachedDemoMode = isDemo;
    return isDemo;
  }
}
