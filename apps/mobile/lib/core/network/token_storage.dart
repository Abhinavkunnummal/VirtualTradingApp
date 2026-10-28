import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'tradeverse_access_token';
  static const String _refreshTokenKey = 'tradeverse_refresh_token';
  static const String _demoModeKey = 'tradeverse_demo_mode';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> setDemoMode(bool isDemo) async {
    await _storage.write(key: _demoModeKey, value: isDemo ? 'true' : 'false');
  }

  Future<bool> isDemoMode() async {
    final val = await _storage.read(key: _demoModeKey);
    return val == 'true';
  }
}
