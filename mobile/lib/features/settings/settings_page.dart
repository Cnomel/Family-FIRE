import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_repository.dart';

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/auth/me');
    return response.data['data'] ?? {};
  } catch (e) {
    return {};
  }
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // Profile Section
          profileAsync.when(
            loading: () => _buildProfileLoading(),
            error: (e, _) => _buildProfileError(e),
            data: (profile) => _buildProfileSection(context, ref, profile),
          ),

          const SizedBox(height: 8),

          // Appearance
          _buildSection('外观', [
            ListTile(
              leading: const Icon(Icons.palette, color: AppColors.primary),
              title: const Text('主题'),
              subtitle: const Text('跟随系统'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.primary),
              title: const Text('语言'),
              subtitle: const Text('中文'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(context),
            ),
          ]),

          const SizedBox(height: 8),

          // Notifications
          _buildSection('通知', [
            ListTile(
              leading: const Icon(Icons.notifications, color: AppColors.primary),
              title: const Text('通知设置'),
              subtitle: const Text('管理通知偏好'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to notification settings
              },
            ),
          ]),

          const SizedBox(height: 8),

          // Family
          _buildSection('家庭', [
            ListTile(
              leading: const Icon(Icons.family_restroom, color: AppColors.primary),
              title: const Text('家庭管理'),
              subtitle: const Text('管理家庭和成员'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to family management
              },
            ),
          ]),

          const SizedBox(height: 8),

          // About
          _buildSection('关于', [
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.primary),
              title: const Text('关于 Family Fire'),
              subtitle: const Text('版本 0.1.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.description, color: AppColors.primary),
              title: const Text('开源协议'),
              subtitle: const Text('MIT License'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.loss,
                side: const BorderSide(color: AppColors.loss),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('退出登录'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    final username = profile['username'] ?? '';
    final fullName = profile['full_name'] ?? '';
    final email = profile['email'] ?? '';
    final role = profile['role'] ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName.isNotEmpty ? fullName : username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_getRoleLabel(role), style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textSecondary),
            onPressed: () {
              // TODO: Navigate to edit profile
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileLoading() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 30, child: CircularProgressIndicator()),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('加载中...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileError(Object error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, child: Icon(Icons.error, color: AppColors.loss)),
          const SizedBox(width: 16),
          Text('加载失败: $error', style: const TextStyle(color: AppColors.loss)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return '系统管理员';
      case 'family_admin': return '家庭管理员';
      case 'member': return '成员';
      default: return role;
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('跟随系统'), trailing: const Icon(Icons.check, color: AppColors.primary), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text('浅色'), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text('深色'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('中文'), trailing: const Icon(Icons.check, color: AppColors.primary), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text('English'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 Family Fire'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 0.1.0'),
            SizedBox(height: 8),
            Text('家庭资产管理系统'),
            SizedBox(height: 8),
            Text('通过资产关系管理、日常支出追踪、投资分析，帮助家庭实现FIRE财务独立。'),
            SizedBox(height: 16),
            Text('开源协议: MIT', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
