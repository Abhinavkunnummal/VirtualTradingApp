import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tradeverse_mobile/core/network/api_client.dart';
import 'package:tradeverse_mobile/core/network/token_storage.dart';
import 'package:tradeverse_mobile/core/constants/api_constants.dart';
import 'package:tradeverse_mobile/features/auth/domain/auth_models.dart';
import 'package:tradeverse_mobile/features/auth/presentation/providers/auth_provider.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth First Session & Token Sync Tests', () {
    late _FakeSecureStorage fakeStorage;
    late TokenStorage tokenStorage;
    late ApiClient apiClient;
    bool sessionExpiredTriggered = false;
    String? socketAuthToken;

    setUp(() {
      fakeStorage = _FakeSecureStorage();
      tokenStorage = TokenStorage(storage: fakeStorage);
      sessionExpiredTriggered = false;
      socketAuthToken = null;

      apiClient = ApiClient(
        tokenStorage: tokenStorage,
        onSessionExpired: () {
          sessionExpiredTriggered = true;
        },
      );
    });

    test('Login-then-first-request succeeds without session expiration or restarts', () async {
      // Mock Dio adapter to intercept login and subsequent portfolio call
      apiClient.dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.path.contains(ApiConstants.login)) {
          return ResponseBody.fromString(
            '{"success": true, "accessToken": "access_jwt_valid_123", "refreshToken": "refresh_jwt_valid_456", "user": {"id": "usr_01", "email": "pro@tradeverse.ai", "displayName": "Alpha Pro"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path.contains(ApiConstants.portfolio)) {
          // Verify that Authorization header is attached
          final authHeader = options.headers['Authorization'] as String?;
          if (authHeader == 'Bearer access_jwt_valid_123') {
            return ResponseBody.fromString(
              '{"success": true, "portfolio": {"totalPortfolioValue": 1000000.0, "availableCash": 1000000.0, "investedValue": 0.0, "startingCapital": 1000000.0, "totalPnl": 0.0, "totalPnlPercent": 0.0, "isSimulated": true, "holdings": []}}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          } else {
            return ResponseBody.fromString(
              '{"success": false, "message": "Unauthorized"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
        }

        return ResponseBody.fromString('{"success": true}', 200);
      });

      final authNotifier = AuthNotifier(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        onAuthSuccess: (token) {
          socketAuthToken = token;
        },
      );

      // 1. Initial State: Unauthenticated
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(socketAuthToken, isNull);

      // 2. Perform Login (First Session)
      final success = await authNotifier.login(
        email: 'pro@tradeverse.ai',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(authNotifier.state.status, AuthStatus.authenticated);
      expect(authNotifier.state.user?.displayName, 'Alpha Pro');

      // 3. Verify in-memory synchronous token cache and socket auth token
      expect(await tokenStorage.getAccessToken(), 'access_jwt_valid_123');
      expect(socketAuthToken, 'access_jwt_valid_123');

      // 4. Immediately dispatch the first authenticated request (e.g. portfolio on dashboard mount)
      final portfolioResponse = await apiClient.get<Map<String, dynamic>>(ApiConstants.portfolio);

      expect(portfolioResponse.statusCode, 200);
      expect(portfolioResponse.data?['success'], isTrue);
      expect(sessionExpiredTriggered, isFalse);

      // 5. Ensure tokens were not wiped and session is healthy
      expect(await tokenStorage.getAccessToken(), 'access_jwt_valid_123');
      expect(authNotifier.state.isAuthenticated, isTrue);
    });

    test('401 from unauthenticated request does not wipe valid cached tokens', () async {
      await tokenStorage.saveTokens(
        accessToken: 'valid_access_token',
        refreshToken: 'valid_refresh_token',
      );

      apiClient.dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        // Return 401 for an unauthenticated request without Bearer token
        return ResponseBody.fromString(
          '{"success": false, "message": "Unauthorized"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      // Clear the request header to simulate an unauthenticated call
      try {
        await apiClient.dio.get<dynamic>(
          '/public-endpoint',
          options: Options(headers: {'Authorization': null}),
        );
      } catch (_) {}

      // Verified guard: tokens should NOT be wiped
      expect(sessionExpiredTriggered, isFalse);
      expect(await tokenStorage.getAccessToken(), 'valid_access_token');
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
