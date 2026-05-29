import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API异常
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});
  @override
  String toString() => message;
}

/// API服务 - 单例模式
class Api {
  static final Api instance = Api._();
  Api._();

  String? _token;
  String? _refreshToken;

  String get _base => kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  bool get isLoggedIn => _token != null;

  void setTokens(String access, String refresh) {
    _token = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _token = null;
    _refreshToken = null;
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) => _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) => _request('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_base$path');
    final jsonBody = body != null ? jsonEncode(body) : null;

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await http.post(url, headers: _headers, body: jsonBody).timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          response = await http.put(url, headers: _headers, body: jsonBody).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ApiException(statusCode: 0, message: '不支持的HTTP方法');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: '网络连接失败，请检查网络');
    }

    final bodyMap = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return bodyMap;
    }

    // 提取错误信息
    String message = '请求失败';
    if (bodyMap is Map<String, dynamic>) {
      final error = bodyMap['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] ?? message;
      }
    }

    // 自动刷新token
    if (response.statusCode == 401 && _refreshToken != null && !path.contains('/auth/')) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body);
      }
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }

  Future<bool> _tryRefresh() async {
    try {
      final url = Uri.parse('$_base/auth/refresh');
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        _token = data['access_token'];
        _refreshToken = data['refresh_token'];
        return true;
      }
      clearTokens();
      return false;
    } catch (e) {
      clearTokens();
      return false;
    }
  }
}
