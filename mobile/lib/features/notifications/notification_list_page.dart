import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_repository.dart';

final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/notifications');
  return response.data['data']['notifications'] ?? [];
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/notifications/unread-count');
  return response.data['data'] ?? 0;
});

class NotificationListPage extends ConsumerWidget {
  const NotificationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);
    final unreadAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () async {
              final api = ref.read(apiClientProvider);
              await api.dio.put('/notifications/read-all');
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('全部已读'),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text('暂无通知', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('新消息将在这里显示', style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          // Group by date
          final grouped = _groupByDate(notifs);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped.entries.elementAt(index);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                  ...entry.value.map((n) => _buildNotificationCard(context, ref, n)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<dynamic>> _groupByDate(List<dynamic> notifs) {
    final now = DateTime.now();
    final Map<String, List<dynamic>> grouped = {};

    for (final n in notifs) {
      final createdAt = DateTime.tryParse(n['created_at'] ?? '') ?? now;
      final diff = now.difference(createdAt);

      String key;
      if (diff.inDays == 0) {
        key = '今天';
      } else if (diff.inDays == 1) {
        key = '昨天';
      } else if (diff.inDays < 7) {
        key = '本周';
      } else {
        key = '更早';
      }

      grouped.putIfAbsent(key, () => []).add(n);
    }

    return grouped;
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref, Map<String, dynamic> notif) {
    final isRead = notif['is_read'] == true;
    final type = notif['type'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? null : AppColors.primaryLight,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _typeColor(type).withValues(alpha: 0.1),
          child: Icon(_typeIcon(type), color: _typeColor(type), size: 20),
        ),
        title: Text(
          notif['title'] ?? '',
          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              _formatTime(notif['created_at']),
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
        onTap: () async {
          if (!isRead) {
            final api = ref.read(apiClientProvider);
            await api.dio.put('/notifications/${notif['id']}/read');
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          }
        },
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'asset_added': return Icons.add_circle;
      case 'asset_expiring': return Icons.timer;
      case 'consumable_low': return Icons.warning;
      case 'family_invite': return Icons.group_add;
      case 'price_alert': return Icons.trending_up;
      default: return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'asset_added': return AppColors.profit;
      case 'asset_expiring': return AppColors.warning;
      case 'consumable_low': return AppColors.loss;
      case 'family_invite': return AppColors.primary;
      case 'price_alert': return AppColors.profit;
      default: return AppColors.neutral;
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}月${date.day}日';
  }
}
