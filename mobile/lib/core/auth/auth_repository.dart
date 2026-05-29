import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({this.isAuthenticated = false, this.isLoading = false, this.error});

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkAuth();
    return const AuthState();
  }

  Future<void> _checkAuth() async {
    final repo = ref.read(authRepositoryProvider);
    final hasToken = await repo.hasToken();
    state = state.copyWith(isAuthenticated: hasToken);
  }

  Future<bool> login(String identifier, String password) async {
    final repo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      await repo.login(identifier, password);
      state = state.copyWith(isAuthenticated: true, isLoading: false, error: null);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '登录失败: ${e.toString()}');
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, String fullName) async {
    final repo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true, error: null);
    try {
      await repo.register(username, email, password, fullName);
      state = state.copyWith(isLoading: false, error: null);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '注册失败: ${e.toString()}');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<bool> hasToken() => _api.hasToken();

  Future<void> login(String identifier, String password) async {
    try {
      final response = await _api.dio.post('/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await _api.saveTokens(data['access_token'], data['refresh_token']);
      } else {
        throw ApiException(
          message: response.data['error']?['message'] ?? '登录失败',
          code: 'LOGIN_FAILED',
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> register(String username, String email, String password, String fullName) async {
    try {
      final response = await _api.dio.post('/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
      });

      if (response.statusCode != 201 || response.data['success'] != true) {
        throw ApiException(
          message: response.data['error']?['message'] ?? '注册失败',
          code: 'REGISTER_FAILED',
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {}
    await _api.clearTokens();
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _api.dio.get('/auth/me');
    return response.data['data'];
  }
}
