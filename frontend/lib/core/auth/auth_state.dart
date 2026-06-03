import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../network/network_service.dart';
import '../storage/secure_storage.dart';

/// 用户信息模型
class AppUser {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'member',
      isActive: json['is_active'] ?? true,
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

/// 认证状态
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// 认证状态管理
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  /// 启动时检查认证状态
  Future<void> _checkAuth() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        await fetchCurrentUser();
      } catch (_) {
        // token 无效，静默处理
        await storage.clearTokens();
        state = const AuthState();
      }
    }
  }

  /// 获取当前用户信息
  Future<void> fetchCurrentUser() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/api/auth/me');
      final data = response.data['data'];
      final user = AppUser.fromJson(data);
      state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isAuthenticated: false, user: null, isLoading: false);
      rethrow;
    }
  }

  /// 登录
  Future<void> login({required String identifier, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    // 检查网络连接
    final networkService = _ref.read(networkServiceProvider);
    if (!networkService.isConnected) {
      state = state.copyWith(
        isLoading: false,
        error: '当前无网络连接，请检查网络设置',
      );
      throw ApiException(
        code: 'NETWORK_UNREACHABLE',
        message: '当前无网络连接，请检查网络设置',
      );
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.post('/api/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });
      final data = response.data['data'];
      final storage = _ref.read(secureStorageProvider);
      await storage.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );

      // 直接标记为已登录，不依赖 fetchCurrentUser
      state = state.copyWith(isAuthenticated: true, isLoading: false);

      // 后台获取用户信息
      fetchCurrentUser().catchError((_) {});
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '登录失败，请重试');
      rethrow;
    }
  }

  /// 注册
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = _ref.read(apiClientProvider);
      await client.post('/api/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      // 注册成功后自动登录
      await login(identifier: username, password: password);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      final client = _ref.read(apiClientProvider);
      await client.post('/api/auth/logout');
    } catch (_) {}
    final storage = _ref.read(secureStorageProvider);
    await storage.clearTokens();
    state = const AuthState();
  }

  /// 修改密码
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/auth/password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// 更新个人资料
  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.put('/api/auth/me', data: {
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
    final user = AppUser.fromJson(response.data['data']);
    state = state.copyWith(user: user);
  }

  /// 请求密码重置
  Future<void> forgotPassword(String email) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/auth/password/forgot', data: {'email': email});
  }

  /// 重置密码
  Future<void> resetPassword({required String token, required String newPassword}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/auth/password/reset', data: {
      'token': token,
      'new_password': newPassword,
    });
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
