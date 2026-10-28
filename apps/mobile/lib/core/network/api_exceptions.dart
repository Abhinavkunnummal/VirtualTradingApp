import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final bool isNetworkError;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.isNetworkError = false,
  });

  factory ApiException.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Connection timed out or network offline. Please check your connection and retry.',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final status = dioError.response?.statusCode;
        final data = dioError.response?.data;
        String msg = 'An unexpected server error occurred.';
        String? errCode;

        if (data is Map<String, dynamic>) {
          msg = data['message'] as String? ?? msg;
          errCode = data['code'] as String?;
        }

        if (status == 401) {
          return ApiException(
            message: msg.isNotEmpty ? msg : 'Session expired or unauthenticated.',
            statusCode: status,
            code: errCode ?? 'UNAUTHENTICATED',
          );
        } else if (status == 404) {
          return ApiException(
            message: msg.isNotEmpty ? msg : 'Requested resource was not found.',
            statusCode: status,
            code: 'NOT_FOUND',
          );
        } else if (status == 409) {
          return ApiException(
            message: msg,
            statusCode: status,
            code: 'CONFLICT',
          );
        }
        return ApiException(
          message: msg,
          statusCode: status,
          code: errCode,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');
      default:
        return ApiException(
          message: 'Network communication failed. Please check server status.',
          isNetworkError: true,
        );
    }
  }

  @override
  String toString() => message;
}
