import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _accessToken;
  String? _refreshToken;

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    return 'http://10.0.2.2:8000/api';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  void setTokens(String access, String refresh) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  bool get isLoggedIn => _accessToken != null;

  Future<Map<String, dynamic>> get(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await http.get(url, headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await http.post(url, headers: _headers, body: jsonEncode(body ?? {}));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await http.put(url, headers: _headers, body: jsonEncode(body ?? {}));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    final response = await http.delete(url, headers: _headers);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Extract error message
    String message = '请求失败';
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] ?? message;
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
