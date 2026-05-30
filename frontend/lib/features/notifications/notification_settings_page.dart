import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  List<dynamic> _preferences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/notifications/settings');
      setState(() {
        _preferences = response.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePreference(String type, bool enabled) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/notifications/settings', data: {
        'type': type,
        'enabled': enabled,
      });
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabels = {
      'asset_added': '资产添加',
      'asset_consumed': '消耗品消耗',
      'asset_duplicate': '重复资产',
      'asset_expiring': '资产到期',
      'consumable_low': '库存不足',
      'family_invite': '家庭邀请',
      'family_joined': '成员加入',
      'price_alert': '价格提醒',
      'system': '系统通知',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('通知设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _preferences.map((pref) {
                final type = pref['notification_type'] ?? pref['type'] ?? '';
                final enabled = pref['enabled'] ?? true;
                return SwitchListTile(
                  title: Text(typeLabels[type] ?? type),
                  value: enabled,
                  onChanged: (v) => _togglePreference(type, v),
                );
              }).toList(),
            ),
    );
  }
}
