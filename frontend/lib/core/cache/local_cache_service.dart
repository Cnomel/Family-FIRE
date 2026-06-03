import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存项
class CacheItem {
  final dynamic data;
  final DateTime cachedAt;
  final Duration? ttl;

  CacheItem({
    required this.data,
    required this.cachedAt,
    this.ttl,
  });

  /// 是否已过期
  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(cachedAt) > ttl!;
  }

  Map<String, dynamic> toJson() => {
        'data': data,
        'cachedAt': cachedAt.toIso8601String(),
        'ttl': ttl?.inSeconds,
      };

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      data: json['data'],
      cachedAt: DateTime.parse(json['cachedAt']),
      ttl: json['ttl'] != null ? Duration(seconds: json['ttl']) : null,
    );
  }
}

/// 本地缓存服务 - 用于断网时提供数据
class LocalCacheService {
  SharedPreferences? _prefs;
  final Map<String, CacheItem> _memoryCache = {};

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
  }

  /// 从磁盘加载缓存
  void _loadFromDisk() {
    try {
      final cacheJson = _prefs?.getString('local_cache');
      if (cacheJson != null) {
        final Map<String, dynamic> cacheMap = json.decode(cacheJson);
        cacheMap.forEach((key, value) {
          _memoryCache[key] = CacheItem.fromJson(value);
        });
      }
    } catch (e) {
      debugPrint('加载本地缓存失败: $e');
    }
  }

  /// 保存到磁盘
  Future<void> _saveToDisk() async {
    try {
      final cacheMap = <String, dynamic>{};
      _memoryCache.forEach((key, value) {
        cacheMap[key] = value.toJson();
      });
      await _prefs?.setString('local_cache', json.encode(cacheMap));
    } catch (e) {
      debugPrint('保存本地缓存失败: $e');
    }
  }

  /// 获取缓存数据
  dynamic get(String key) {
    final item = _memoryCache[key];
    if (item == null || item.isExpired) {
      _memoryCache.remove(key);
      return null;
    }
    return item.data;
  }

  /// 设置缓存数据
  Future<void> set(
    String key,
    dynamic data, {
    Duration? ttl,
  }) async {
    _memoryCache[key] = CacheItem(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl,
    );
    await _saveToDisk();
  }

  /// 删除缓存
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _saveToDisk();
  }

  /// 清空缓存
  Future<void> clear() async {
    _memoryCache.clear();
    await _prefs?.remove('local_cache');
  }

  /// 获取API响应缓存
  dynamic getApiResponse(String path, {Map<String, dynamic>? queryParams}) {
    final key = _buildCacheKey(path, queryParams);
    return get(key);
  }

  /// 设置API响应缓存
  Future<void> setApiResponse(
    String path,
    dynamic data, {
    Map<String, dynamic>? queryParams,
    Duration ttl = const Duration(hours: 1),
  }) async {
    final key = _buildCacheKey(path, queryParams);
    await set(key, data, ttl: ttl);
  }

  /// 构建缓存key
  String _buildCacheKey(String path, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return 'api:$path';
    }
    final sortedParams = Map.fromEntries(
      queryParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return 'api:$path:${sortedParams.toString()}';
  }
}

/// 本地缓存服务提供者
final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});
