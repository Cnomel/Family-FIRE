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
        return ApiException(
          code: 'CONNECTION_TIMEOUT',
          message: '连接超时，请检查网络是否正常或服务器是否可达',
          statusCode: 408,
        );
      case DioExceptionType.sendTimeout:
        return ApiException(
          code: 'SEND_TIMEOUT',
          message: '发送超时，网络可能不稳定，请稍后重试',
          statusCode: 408,
        );
      case DioExceptionType.receiveTimeout:
        return ApiException(
          code: 'RECEIVE_TIMEOUT',
          message: '接收超时，服务器响应过慢，请稍后重试',
          statusCode: 408,
        );
      case DioExceptionType.connectionError:
        return _handleConnectionError(e);
      case DioExceptionType.badResponse:
        return _fromResponse(e.response!);
      case DioExceptionType.cancel:
        return ApiException(
          code: 'REQUEST_CANCELLED',
          message: '请求已取消',
        );
      default:
        return ApiException(
          code: 'UNKNOWN',
          message: '未知错误: ${e.message}',
        );
    }
  }

  /// 处理连接错误，提供更详细的错误信息
  static ApiException _handleConnectionError(DioException e) {
    final message = e.message?.toLowerCase() ?? '';

    if (message.contains('network is unreachable') ||
        message.contains('no network') ||
        message.contains('network unreachable')) {
      return ApiException(
        code: 'NETWORK_UNREACHABLE',
        message: '当前无网络连接，请检查WiFi或移动数据是否开启',
      );
    }

    if (message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection aborted')) {
      return ApiException(
        code: 'CONNECTION_REFUSED',
        message: '服务器拒绝连接，可能正在维护中，请稍后重试',
      );
    }

    if (message.contains('host is unreachable') ||
        message.contains('no route to host')) {
      return ApiException(
        code: 'HOST_UNREACHABLE',
        message: '无法访问服务器，请检查网络设置或VPN连接',
      );
    }

    if (message.contains('ssl') || message.contains('certificate')) {
      return ApiException(
        code: 'SSL_ERROR',
        message: '安全连接失败，请检查系统时间或网络代理设置',
      );
    }

    if (message.contains('socket') || message.contains('broken pipe')) {
      return ApiException(
        code: 'SOCKET_ERROR',
        message: '网络连接中断，请检查网络稳定性',
      );
    }

    return ApiException(
      code: 'NETWORK_ERROR',
      message: '网络连接失败，请检查网络设置后重试',
    );
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
