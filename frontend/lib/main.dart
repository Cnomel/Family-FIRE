import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cache/local_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地缓存服务
  final cacheService = LocalCacheService();
  await cacheService.init();

  runApp(
    ProviderScope(
      overrides: [
        localCacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const FamilyFireApp(),
    ),
  );
}
