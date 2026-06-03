import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// 网络连接状态
enum NetworkStatus {
  /// 已连接
  connected,

  /// 未连接
  disconnected,

  /// 正在检查
  checking,
}

/// 网络服务 - 检测网络连接状态
class NetworkService {
  final Ref _ref;
  NetworkStatus _status = NetworkStatus.connected;
  Timer? _checkTimer;
  final _statusController = StreamController<NetworkStatus>.broadcast();

  NetworkService(this._ref) {
    _startPeriodicCheck();
  }

  /// 网络状态流
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// 当前网络状态
  NetworkStatus get status => _status;

  /// 是否已连接
  bool get isConnected => _status == NetworkStatus.connected;

  /// 开始定期检查
  void _startPeriodicCheck() {
    // 每30秒检查一次
    _checkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnection(),
    );
  }

  /// 检查网络连接
  Future<bool> checkConnection() async {
    _status = NetworkStatus.checking;
    _statusController.add(_status);

    try {
      final client = _ref.read(apiClientProvider);
      // 使用一个轻量级的请求来检测连接
      final response = await client.dio.get(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      _status = NetworkStatus.connected;
      _statusController.add(_status);
      return true;
    } catch (e) {
      _status = NetworkStatus.disconnected;
      _statusController.add(_status);
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}

/// 网络服务提供者
final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// 网络状态提供者
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.statusStream;
});
