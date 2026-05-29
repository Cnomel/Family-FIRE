import 'package:flutter/material.dart';
import 'api_service.dart';

class AuthState extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _api.isLoggedIn;
  Map<String, dynamic>? get user => _user;

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/login', body: {
        'identifier': identifier,
        'password': password,
      });

      if (response['success'] == true) {
        final data = response['data'];
        _api.setTokens(data['access_token'], data['refresh_token']);
        await fetchUser();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response['error']?['message'] ?? '登录失败';
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = '网络错误: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/register', body: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
      });

      if (response['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = response['error']?['message'] ?? '注册失败';
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = '网络错误: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchUser() async {
    try {
      final response = await _api.get('/auth/me');
      _user = response['data'];
      notifyListeners();
    } catch (e) {
      // Ignore
    }
  }

  void logout() {
    _api.clearTokens();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
