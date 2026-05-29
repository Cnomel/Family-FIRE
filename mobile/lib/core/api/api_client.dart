import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String code;

  ApiException({this.statusCode, required this.message, this.code = 'UNKNOWN'});

  factory ApiException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: '连接超时，请检查网络', code: 'TIMEOUT');
      case DioExceptionType.connectionError:
        return ApiException(message: '网络连接失败，请检查网络', code: 'NETWORK_ERROR');
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.cancel:
        return ApiException(message: '请求已取消', code: 'CANCELLED');
      default:
        return ApiException(message: '请求失败: ${e.message}', code: 'UNKNOWN');
    }
  }

  factory ApiException.fromResponse(Response? response) {
    return _fromResponse(response);
  }

  static ApiException _fromResponse(Response? response) {
    if (response == null) {
      return ApiException(message: '服务器无响应', code: 'NO_RESPONSE');
    }

    final data = response.data;
    String message = '请求失败';
    String code = 'ERROR';

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] ?? '请求失败';
        code = error['code'] ?? 'ERROR';
      }
    }

    switch (response.statusCode) {
      case 400:
        if (message == '请求失败') message = '请求参数错误';
        break;
      case 401:
        if (message == '请求失败') message = '用户名/邮箱或密码错误';
        code = 'UNAUTHORIZED';
        break;
      case 403:
        if (message == '请求失败') message = '权限不足';
        break;
      case 404:
        if (message == '请求失败') message = '资源不存在';
        break;
      case 409:
        break;
      case 422:
        break;
      case 423:
        break;
      case 429:
        message = '请求过于频繁，请稍后重试';
        break;
      case 500:
        message = '服务器内部错误';
        break;
    }

    return ApiException(statusCode: response.statusCode, message: message, code: code);
  }

  @override
  String toString() => message;
}

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  final String baseUrl;

  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? _getDefaultBaseUrl() {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio),
      if (kDebugMode) _LogInterceptor(),
    ]);
  }

  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    // Android emulator uses 10.0.2.2 to reach host
    return 'http://10.0.2.2:8000/api';
  }

  Dio get dio => _dio;

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> hasToken() async {
    try {
      final token = await _storage.read(key: 'access_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  // Paths that should not trigger token refresh
  static const _publicPaths = ['/auth/login', '/auth/register', '/auth/refresh', '/auth/password/forgot', '/auth/password/reset'];

  _AuthInterceptor(this._storage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Don't add token for public endpoints
    if (!_publicPaths.any((p) => options.path.contains(p))) {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't try to refresh for public endpoints or if already refreshing
    final isPublicPath = _publicPaths.any((p) => err.requestOptions.path.contains(p));
    if (err.response?.statusCode == 401 && !_isRefreshing && !isPublicPath) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          await _storage.deleteAll();
          handler.next(err);
          return;
        }

        final response = await Dio().post(
          '${_dio.options.baseUrl}/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200) {
          final data = response.data['data'];
          await _storage.write(key: 'access_token', value: data['access_token']);
          await _storage.write(key: 'refresh_token', value: data['refresh_token']);

          // Retry original request
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer ${data['access_token']}';
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        }
      } catch (e) {
        await _storage.deleteAll();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('[API] ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('[API] ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('[API ERROR] ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}
