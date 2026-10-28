import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeverse_mobile/core/network/api_exceptions.dart';

void main() {
  group('ApiException Tests', () {
    test('converts connection timeout to network error', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final apiException = ApiException.fromDioError(dioError);
      expect(apiException.isNetworkError, true);
      expect(apiException.message, contains('Connection timed out'));
    });

    test('parses 401 unauthenticated response with custom message', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
          data: {'success': false, 'message': 'Access token expired.', 'code': 'TOKEN_EXPIRED'},
        ),
      );

      final apiException = ApiException.fromDioError(dioError);
      expect(apiException.statusCode, 401);
      expect(apiException.code, 'TOKEN_EXPIRED');
      expect(apiException.message, 'Access token expired.');
    });

    test('parses 409 conflict response', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 409,
          data: {'success': false, 'message': 'An account with this email address already exists.'},
        ),
      );

      final apiException = ApiException.fromDioError(dioError);
      expect(apiException.statusCode, 409);
      expect(apiException.code, 'CONFLICT');
      expect(apiException.message, contains('already exists'));
    });
  });
}
