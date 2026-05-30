import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/privacy_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 主题
          _buildSectionHeader(context, '外观'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ],
              selected: {themeMode},
              onSelectionChanged: (v) {
                ref.read(themeModeProvider.notifier).setThemeMode(v.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const Divider(),

          // 语言
          _buildSectionHeader(context, '语言'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle: Text(_localeName(locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref, locale),
          ),
          const Divider(),

          // 隐私
          _buildSectionHeader(context, '隐私'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('隐私模式'),
            subtitle: const Text('隐藏金额显示'),
            value: isPrivacy,
            onChanged: (v) {
              ref.read(privacyModeProvider.notifier).toggle();
            },
          ),
          const Divider(),

          // 生物识别
          _buildSectionHeader(context, '安全'),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('生物识别'),
            subtitle: const Text('Face ID / 指纹'),
            trailing: Switch(
              value: false, // TODO: Read from biometric service
              onChanged: (v) {
                // TODO: Enable/disable biometric
              },
            ),
          ),
          const Divider(),

          // 通知
          _buildSectionHeader(context, '通知'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/notifications/settings'),
          ),
          const Divider(),

          // 管理员 (仅 admin 可见)
          if (ref.watch(authStateProvider).user?.role == 'admin') ...[
            _buildSectionHeader(context, '管理'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
              title: const Text('用户管理'),
              subtitle: const Text('管理员功能'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/users'),
            ),
            const Divider(),
          ],

          // 关于
          _buildSectionHeader(context, '关于'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('版本'),
            subtitle: const Text('v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(),

          // 退出登录
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('确认退出登录？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('退出', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _localeName(Locale? locale) {
    if (locale == null) return '跟随系统';
    if (locale.languageCode == 'zh') return '中文';
    return 'English';
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, Locale? current) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择语言'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setSystem();
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Text('跟随系统'),
                if (current == null) const Spacer(),
                if (current == null) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setChinese();
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Text('中文'),
                if (current?.languageCode == 'zh') const Spacer(),
                if (current?.languageCode == 'zh') const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setEnglish();
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Text('English'),
                if (current?.languageCode == 'en') const Spacer(),
                if (current?.languageCode == 'en') const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
