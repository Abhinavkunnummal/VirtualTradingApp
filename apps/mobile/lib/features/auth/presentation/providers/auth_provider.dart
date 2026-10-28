import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/auth_models.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () {
      ref.read(authProvider.notifier).handleSessionExpired();
    },
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthNotifier(apiClient: apiClient, tokenStorage: tokenStorage);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  AuthNotifier({
    required this.apiClient,
    required this.tokenStorage,
  }) : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = AuthState.loading();
    try {
      final isDemo = await tokenStorage.isDemoMode();
      if (isDemo) {
        state = AuthState.demoMode();
        return;
      }

      final token = await tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }

      final response = await apiClient.get(ApiConstants.me);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
        state = AuthState.authenticated(user);
      } else {
        await tokenStorage.clearTokens();
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      // Offline fallback: check if demo mode enabled
      final isDemo = await tokenStorage.isDemoMode();
      if (isDemo) {
        state = AuthState.demoMode();
      } else {
        state = AuthState.unauthenticated();
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = AuthState.loading();
    try {
      final response = await apiClient.post(
        ApiConstants.login,
        data: {'email': email.trim(), 'password': password},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final accessToken = response.data['accessToken'] as String;
        final refreshToken = response.data['refreshToken'] as String;
        final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);

        await tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
        await tokenStorage.setDemoMode(false);
        state = AuthState.authenticated(user);
        return true;
      } else {
        state = AuthState.unauthenticated(response.data['message'] as String? ?? 'Login failed');
        return false;
      }
    } on ApiException catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated('Unable to connect to TradeVerse server. Check network connection.');
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    double? startingCapital,
  }) async {
    state = AuthState.loading();
    try {
      final response = await apiClient.post(
        ApiConstants.register,
        data: {
          'email': email.trim(),
          'password': password,
          'displayName': displayName.trim(),
          if (startingCapital != null) 'startingCapital': startingCapital,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final accessToken = response.data['accessToken'] as String;
        final refreshToken = response.data['refreshToken'] as String;
        final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);

        await tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
        await tokenStorage.setDemoMode(false);
        state = AuthState.authenticated(user);
        return true;
      } else {
        state = AuthState.unauthenticated(response.data['message'] as String? ?? 'Registration failed');
        return false;
      }
    } on ApiException catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated('Unable to connect to server. Check network connection.');
      return false;
    }
  }

  Future<void> enableDemoMode() async {
    await tokenStorage.setDemoMode(true);
    state = AuthState.demoMode();
  }

  Future<void> logout() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await apiClient.post(ApiConstants.logout, data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await tokenStorage.clearTokens();
    await tokenStorage.setDemoMode(false);
    state = AuthState.unauthenticated();
  }

  void handleSessionExpired() {
    state = AuthState.unauthenticated('Your session has expired. Please log in again.');
  }
}
