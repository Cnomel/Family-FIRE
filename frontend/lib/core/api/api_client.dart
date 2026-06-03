import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';
import '../../config/env.dart';
import '../storage/secure_storage.dart';
import '../network/network_service.dart';
import '../cache/local_cache_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

class ApiClient {
  final Ref _ref;
  late final Dio _dio;

  /// 根据平台返回合适的 base URL
  static String get defaultBaseUrl {
    // 优先使用环境变量配置
    if (EnvConfig.apiBaseUrl.isNotEmpty) {
      return EnvConfig.apiBaseUrl;
    }
    // 本地开发默认地址
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  ApiClient(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: defaultBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Web: 不发送 cookies，避免 CORS + credentials 冲突
      extra: {'withCredentials': false},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_ref),
      _RefreshInterceptor(_dio, _ref),
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
    ]);
  }

  Dio get dio => _dio;

  /// GET request (支持缓存)
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool useCache = false,
    Duration cacheTtl = const Duration(hours: 1),
  }) async {
    // 检查网络状态
    final networkService = _ref.read(networkServiceProvider);
    if (!networkService.isConnected && useCache) {
      // 断网时尝试从缓存获取
      final cacheService = _ref.read(localCacheServiceProvider);
      final cachedData = cacheService.getApiResponse(path, queryParams: queryParams);
      if (cachedData != null) {
        return Response(
          data: cachedData,
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
        );
      }
    }

    try {
      final response = await _dio.get(path, queryParameters: queryParams);

      // 成功时缓存响应
      if (useCache && response.statusCode == 200) {
        final cacheService = _ref.read(localCacheServiceProvider);
        await cacheService.setApiResponse(
          path,
          response.data,
          queryParams: queryParams,
          ttl: cacheTtl,
        );
      }

      return response;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST request
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT request
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE request
  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Multipart upload
  Future<Response> upload(String path, {required FormData data}) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// 认证拦截器 - 自动附加Token
class _AuthInterceptor extends Interceptor {
  final Ref _ref;

  _AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Token刷新拦截器 - 401时自动刷新（支持并发请求）
class _RefreshInterceptor extends Interceptor {
  final Dio _dio;
  final Ref _ref;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshCompleters = [];

  // 不需要刷新token的路径
  static const _excludedPaths = [
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/refresh',
    '/api/auth/password/forgot',
    '/api/auth/password/reset',
  ];

  _RefreshInterceptor(this._dio, this._ref);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 排除登录等不需要token的请求
    final path = err.requestOptions.path;
    if (_excludedPaths.any((p) => path.contains(p))) {
      handler.next(err);
      return;
    }

    if (err.response?.statusCode == 401) {
      if (_isRefreshing) {
        // 已经在刷新中，等待刷新完成
        final completer = Completer<void>();
        _refreshCompleters.add(completer);
        try {
          await completer.future;
          // 刷新完成后重试原请求
          final storage = _ref.read(secureStorageProvider);
          final newToken = await storage.getAccessToken();
          if (newToken != null) {
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newToken';
            final retryResponse = await _dio.fetch(opts);
            handler.resolve(retryResponse);
            return;
          }
        } catch (_) {
          // 刷新失败
        }
        handler.next(err);
        return;
      }

      _isRefreshing = true;
      try {
        final storage = _ref.read(secureStorageProvider);
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken != null) {
          final response = await _dio.post(
            '/api/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final data = response.data['data'];
          await storage.saveTokens(
            accessToken: data['access_token'],
            refreshToken: data['refresh_token'],
          );
          // 通知所有等待的请求
          for (final completer in _refreshCompleters) {
            completer.complete();
          }
          _refreshCompleters.clear();

          // 重试原请求
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer ${data['access_token']}';
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // 刷新失败，清除token，通知等待的请求
        for (final completer in _refreshCompleters) {
          completer.completeError(Exception('Token刷新失败'));
        }
        _refreshCompleters.clear();
        final storage = _ref.read(secureStorageProvider);
        await storage.clearTokens();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

/// 日志拦截器
class _LoggingInterceptor extends Interceptor {
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
      print('[API] Error: ${err.response?.statusCode} ${err.requestOptions.uri}');
    }
    handler.next(err);
  }
}

/// 重试拦截器
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const int maxRetries = 3;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && (err.requestOptions.extra['retryCount'] ?? 0) < maxRetries) {
      final retryCount = (err.requestOptions.extra['retryCount'] ?? 0) + 1;
      err.requestOptions.extra['retryCount'] = retryCount;

      await Future.delayed(Duration(seconds: retryCount));
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}
