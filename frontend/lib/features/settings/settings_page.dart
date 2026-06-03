import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/privacy_provider.dart';
import '../../config/i18n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _appVersion = 'v0.1.0-beta.1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isPrivacy = ref.watch(privacyModeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // 主题
          _buildSectionHeader(context, l10n.appearance),
          _buildThemeModeTile(context, ref, themeMode, l10n),
          const Divider(),

          // 语言
          _buildSectionHeader(context, l10n.language),
          _buildListTile(
            context,
            icon: Icons.language,
            title: l10n.language,
            subtitle: _localeName(locale, l10n),
            onTap: () => _showLanguageDialog(context, ref, locale, l10n),
          ),
          const Divider(),

          // 隐私
          _buildSectionHeader(context, l10n.privacy),
          _buildSwitchTile(
            context,
            icon: Icons.visibility_off,
            title: l10n.privacyMode,
            subtitle: l10n.hideAmountDisplay,
            value: isPrivacy,
            onChanged: (v) {
              ref.read(privacyModeProvider.notifier).toggle();
            },
          ),
          const Divider(),

          // 生物识别
          _buildSectionHeader(context, l10n.security),
          _buildSwitchTile(
            context,
            icon: Icons.fingerprint,
            title: l10n.biometric,
            subtitle: l10n.biometricSubtitle,
            value: false,
            onChanged: (v) {
              // TODO: Enable/disable biometric
            },
          ),
          const Divider(),

          // 通知
          _buildSectionHeader(context, l10n.notifications),
          _buildListTile(
            context,
            icon: Icons.notifications,
            title: l10n.notificationSettings,
            onTap: () => context.push('/notifications/settings'),
          ),
          const Divider(),

          // 管理员 (仅 admin 可见)
          if (ref.watch(authStateProvider).user?.role == 'admin') ...[
            _buildSectionHeader(context, l10n.admin),
            _buildListTile(
              context,
              icon: Icons.admin_panel_settings,
              title: l10n.userManagement,
              subtitle: l10n.adminFunctions,
              iconColor: Colors.red,
              onTap: () => context.push('/admin/users'),
            ),
            const Divider(),
          ],

          // 关于
          _buildSectionHeader(context, l10n.about),
          _buildListTile(
            context,
            icon: Icons.menu_book,
            title: '使用手册',
            subtitle: 'FIRE 知识和使用指南',
            onTap: () => context.push('/settings/guide'),
          ),
          _buildListTile(
            context,
            icon: Icons.info,
            title: l10n.version,
            subtitle: _appVersion,
            onTap: () => _checkForUpdate(context, l10n),
          ),
          _buildListTile(
            context,
            icon: Icons.description,
            title: l10n.userAgreement,
            onTap: () => context.push('/settings/terms'),
          ),
          _buildListTile(
            context,
            icon: Icons.privacy_tip,
            title: l10n.privacyPolicy,
            onTap: () => context.push('/settings/privacy'),
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
                    title: Text(l10n.confirmLogout),
                    content: Text(l10n.confirmLogoutMessage),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
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
              child: Text(l10n.logout),
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

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildThemeModeTile(BuildContext context, WidgetRef ref, ThemeMode themeMode, AppLocalizations l10n) {
    return ListTile(
      leading: const Icon(Icons.dark_mode),
      title: Text(l10n.darkMode),
      subtitle: Text(_themeModeName(themeMode, l10n)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, ref, themeMode, l10n),
    );
  }

  String _themeModeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.systemDefault;
      case ThemeMode.light:
        return l10n.darkMode == '深色模式' ? '浅色' : 'Light';
      case ThemeMode.dark:
        return l10n.darkMode;
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.darkMode),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Text(l10n.systemDefault),
                if (current == ThemeMode.system) const Spacer(),
                if (current == ThemeMode.system) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Text(l10n.darkMode == '深色模式' ? '浅色' : 'Light'),
                if (current == ThemeMode.light) const Spacer(),
                if (current == ThemeMode.light) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Text(l10n.darkMode),
                if (current == ThemeMode.dark) const Spacer(),
                if (current == ThemeMode.dark) const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localeName(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.systemDefault;
    if (locale.languageCode == 'zh') return l10n.chinese;
    return l10n.english;
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, Locale? current, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.selectLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setSystem();
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Text(l10n.systemDefault),
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
                Text(l10n.chinese),
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
                Text(l10n.english),
                if (current?.languageCode == 'en') const Spacer(),
                if (current?.languageCode == 'en') const Icon(Icons.check, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context, AppLocalizations l10n) async {
    // 显示加载对话框
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('检查更新中...'),
          ],
        ),
      ),
    );

    try {
      final client = ProviderScope.containerOf(context).read(apiClientProvider);
      final response = await client.get(
        '/api/version/check',
        queryParams: {'current_version': _appVersion},
      );
      final data = response.data;

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      final latestVersion = data['latest_version'] ?? '';
      final needUpdate = data['need_update'] ?? false;
      final forceUpdate = data['force_update'] ?? false;
      final downloadUrl = data['download_url'];
      final releaseNotes = data['release_notes'] ?? '';
      final releaseDate = data['release_date'] ?? '';

      if (!needUpdate) {
        // 已是最新版本
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.checkUpdate),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text('${l10n.version}: $_appVersion'),
                const SizedBox(height: 8),
                Text(l10n.latestVersion),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
      } else {
        // 有新版本
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.blue),
                const SizedBox(width: 8),
                Text('发现新版本 $latestVersion'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.version}: $_appVersion → $latestVersion'),
                  if (releaseDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('发布日期: $releaseDate', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(releaseNotes),
                  if (forceUpdate) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '此为强制更新，必须更新后才能使用',
                              style: TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (downloadUrl != null) {
                    final uri = Uri.parse(downloadUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('无法打开下载链接')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('下载更新'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.checkUpdate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('检查更新失败: $e'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    }
  }
}
