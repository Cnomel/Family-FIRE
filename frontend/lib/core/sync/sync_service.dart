import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

class SyncService {
  /// 同步离线队列中的待处理请求
  Future<void> syncPendingRequests() async {
    // TODO: Implement with drift database when code generation is complete
  }

  /// 缓存资产列表到本地
  Future<void> cacheAssets(List<Map<String, dynamic>> assets, String familyId) async {
    // TODO: Implement with drift database when code generation is complete
  }
}
