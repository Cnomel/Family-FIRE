import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// 简化的离线数据库（内存缓存）
/// 后续可通过 drift 代码生成升级为 SQLite
class AppDatabase {
  final List<Map<String, dynamic>> _cachedAssets = [];
  final List<Map<String, dynamic>> _cachedNotifications = [];
  final List<Map<String, dynamic>> _offlineQueue = [];

  // === Asset Cache ===
  List<Map<String, dynamic>> getAllCachedAssets() => List.unmodifiable(_cachedAssets);

  void insertCachedAsset(Map<String, dynamic> asset) {
    final idx = _cachedAssets.indexWhere((a) => a['id'] == asset['id']);
    if (idx >= 0) {
      _cachedAssets[idx] = asset;
    } else {
      _cachedAssets.add(asset);
    }
  }

  void insertCachedAssets(List<Map<String, dynamic>> assets) {
    for (final asset in assets) {
      insertCachedAsset(asset);
    }
  }

  void clearCachedAssets() => _cachedAssets.clear();

  // === Notification Cache ===
  List<Map<String, dynamic>> getCachedNotifications() {
    final sorted = List<Map<String, dynamic>>.from(_cachedNotifications);
    sorted.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return sorted;
  }

  void insertCachedNotification(Map<String, dynamic> notif) {
    final idx = _cachedNotifications.indexWhere((n) => n['id'] == notif['id']);
    if (idx >= 0) {
      _cachedNotifications[idx] = notif;
    } else {
      _cachedNotifications.add(notif);
    }
  }

  int getUnreadCount() => _cachedNotifications.where((n) => n['is_read'] == false).length;

  void markNotificationRead(String id) {
    final idx = _cachedNotifications.indexWhere((n) => n['id'] == id);
    if (idx >= 0) {
      _cachedNotifications[idx]['is_read'] = true;
    }
  }

  void clearCachedNotifications() => _cachedNotifications.clear();

  // === Offline Queue ===
  int enqueue(String method, String path, String? body) {
    _offlineQueue.add({
      'id': _offlineQueue.length + 1,
      'method': method,
      'path': path,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
      'synced': false,
    });
    return _offlineQueue.length;
  }

  List<Map<String, dynamic>> getPendingQueue() =>
      _offlineQueue.where((q) => q['synced'] == false).toList();

  void markSynced(int id) {
    final idx = _offlineQueue.indexWhere((q) => q['id'] == id);
    if (idx >= 0) {
      _offlineQueue[idx]['synced'] = true;
    }
  }
}
