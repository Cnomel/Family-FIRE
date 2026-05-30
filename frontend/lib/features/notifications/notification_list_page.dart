import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/date.dart';

class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        client.get('/api/notifications', queryParams: {'page': 1, 'page_size': 50}),
        client.get('/api/notifications/unread-count'),
      ]);
      setState(() {
        _notifications = results[0].data['data']?['notifications'] ?? [];
        _unreadCount = results[1].data['data'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/notifications/$id/read');
      _loadData();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/notifications/read-all');
      _loadData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('全部已读'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/notifications/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text('暂无通知'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return _buildNotificationTile(notif);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final isRead = notif['is_read'] ?? false;
    final type = notif['type'] ?? '';
    final icon = _getIconForType(type);
    final color = _getColorForType(type);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        notif['title'] ?? '',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notif['message'] != null)
            Text(
              notif['message'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(
            notif['created_at'] != null ? formatRelativeTime(DateTime.parse(notif['created_at'])) : '',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      trailing: isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        if (!isRead) _markRead(notif['id']);
        // TODO: Navigate based on notification type
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'asset_added': return Icons.add_circle;
      case 'asset_consumed': return Icons.remove_circle;
      case 'asset_expiring': return Icons.warning;
      case 'consumable_low': return Icons.inventory;
      case 'family_invite': return Icons.group_add;
      case 'family_joined': return Icons.group;
      case 'price_alert': return Icons.trending_up;
      case 'system': return Icons.info;
      default: return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'asset_added': return const Color(0xFF52C41A);
      case 'asset_consumed': return const Color(0xFFFA8C16);
      case 'asset_expiring': return const Color(0xFFFF4D4F);
      case 'consumable_low': return const Color(0xFFFA8C16);
      case 'family_invite': return const Color(0xFF1677FF);
      case 'price_alert': return const Color(0xFF722ED1);
      default: return const Color(0xFF999999);
    }
  }
}
