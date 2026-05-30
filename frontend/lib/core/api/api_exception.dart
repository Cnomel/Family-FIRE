import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final dynamic details;
  final int? statusCode;

  ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          code: 'TIMEOUT',
          message: '网络超时，请检查网络连接',
          statusCode: 408,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'NETWORK_ERROR',
          message: '网络连接失败，请检查网络设置',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response!);
      default:
        return ApiException(
          code: 'UNKNOWN',
          message: '未知错误: ${e.message}',
        );
    }
  }

  factory ApiException.fromResponse(Response response) {
    return _fromResponse(response);
  }

  static ApiException _fromResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] != null) {
      return ApiException(
        code: data['error']['code'] ?? 'UNKNOWN',
        message: data['error']['message'] ?? '服务器错误',
        details: data['error']['details'],
        statusCode: response.statusCode,
      );
    }

    switch (response.statusCode) {
      case 400:
        return ApiException(code: 'BAD_REQUEST', message: '请求参数错误', statusCode: 400);
      case 401:
        return ApiException(code: 'UNAUTHORIZED', message: '认证失败，请重新登录', statusCode: 401);
      case 403:
        return ApiException(code: 'FORBIDDEN', message: '权限不足', statusCode: 403);
      case 404:
        return ApiException(code: 'NOT_FOUND', message: '资源不存在', statusCode: 404);
      case 409:
        return ApiException(code: 'CONFLICT', message: '数据冲突', statusCode: 409);
      case 422:
        return ApiException(code: 'VALIDATION_ERROR', message: '数据验证失败', statusCode: 422);
      case 429:
        return ApiException(code: 'RATE_LIMIT', message: '请求过于频繁，请稍后重试', statusCode: 429);
      case 500:
        return ApiException(code: 'SERVER_ERROR', message: '服务器内部错误', statusCode: 500);
      default:
        return ApiException(
          code: 'HTTP_${response.statusCode}',
          message: '请求失败 (${response.statusCode})',
          statusCode: response.statusCode,
        );
    }
  }

  /// 从API响应数据中解析错误
  static String? parseErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['error'] is Map) {
        return data['error']['message']?.toString();
      }
      if (data['message'] is String) {
        return data['message'];
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($code): $message';
}
