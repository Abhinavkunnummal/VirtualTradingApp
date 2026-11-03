import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'api_exceptions.dart';
import 'token_storage.dart';

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;
  void Function()? onSessionExpired;

  ApiClient({
    required this.tokenStorage,
    this.onSessionExpired,
    String? baseUrl,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach authorization token if present and not explicitly omitted
          if (!options.headers.containsKey('Authorization')) {
            final token = await tokenStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If 401 Unauthorized, attempt refresh session once
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/')) {
            // Guard: Do not trigger session-expired logout if the request was never authenticated!
            final authHeader = error.requestOptions.headers['Authorization'] as String?;
            if (authHeader == null || !authHeader.startsWith('Bearer ')) {
              return handler.next(error);
            }

            final refreshToken = await tokenStorage.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final refreshResponse = await dio.post<Map<String, dynamic>>(
                  ApiConstants.refresh,
                  data: {'refreshToken': refreshToken},
                  options: Options(headers: {'Authorization': null}),
                );

                if (refreshResponse.statusCode == 200 &&
                    refreshResponse.data?['success'] == true) {
                  final newAccess = refreshResponse.data!['accessToken'] as String;
                  final newRefresh = refreshResponse.data!['refreshToken'] as String;
                  await tokenStorage.saveTokens(
                    accessToken: newAccess,
                    refreshToken: newRefresh,
                  );
                  setAuthToken(newAccess);

                  // Retry the original request
                  final clonedRequest = error.requestOptions;
                  clonedRequest.headers['Authorization'] = 'Bearer $newAccess';
                  final retryResponse = await dio.fetch<dynamic>(clonedRequest);
                  return handler.resolve(retryResponse);
                }
              } catch (_) {
                // Refresh failed; clear session and notify
                await tokenStorage.clearTokens();
                clearAuthToken();
                onSessionExpired?.call();
              }
            } else {
              await tokenStorage.clearTokens();
              clearAuthToken();
              onSessionExpired?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.post<T>(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.delete<T>(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
