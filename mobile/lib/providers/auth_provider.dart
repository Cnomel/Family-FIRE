import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/models.dart';

class AuthState extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => Api.instance.isLoggedIn && _user != null;

  Future<bool> login(String identifier, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await Api.instance.post('/auth/login', body: {
        'identifier': identifier,
        'password': password,
      });
      final data = resp['data'];
      Api.instance.setTokens(data['access_token'], data['refresh_token']);
      await _fetchUser();
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = '网络错误，请检查连接';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, String fullName) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Api.instance.post('/auth/register', body: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = '网络错误，请检查连接';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _fetchUser() async {
    try {
      final resp = await Api.instance.get('/auth/me');
      _user = User.fromJson(resp['data']);
    } catch (e) {
      // 忽略
    }
  }

  Future<void> tryAutoLogin() async {
    if (!Api.instance.isLoggedIn) return;
    await _fetchUser();
    notifyListeners();
  }

  void logout() {
    Api.instance.clearTokens();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// 全局AuthState实例
final authState = AuthState();
