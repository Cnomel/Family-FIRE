import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../shared/formatters/date.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像 + 基本信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.fullName ?? user?.username ?? '?')[0],
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? user?.username ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (user?.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '注册于 ${formatDateShort(user!.createdAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 功能列表
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑资料'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditProfileDialog(context, ref, user),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('修改密码'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('家庭管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/family'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 退出登录
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () async {
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
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, AppUser? user) {
    final nameController = TextEditingController(text: user?.fullName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '姓名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(authStateProvider.notifier).updateProfile(
                      fullName: nameController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('更新失败')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final oldPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPwdController,
              decoration: const InputDecoration(labelText: '当前密码'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwdController,
              decoration: const InputDecoration(labelText: '新密码'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPwdController,
              decoration: const InputDecoration(labelText: '确认新密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newPwdController.text != confirmPwdController.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              try {
                await ref.read(authStateProvider.notifier).changePassword(
                      oldPassword: oldPwdController.text,
                      newPassword: newPwdController.text,
                    );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('密码修改成功')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('修改失败')));
                }
              }
            },
            child: const Text('修改'),
          ),
        ],
      ),
    );
  }
}
