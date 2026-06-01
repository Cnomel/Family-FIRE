import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/formatters/date.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  List<dynamic> _users = [];
  int _total = 0;
  bool _isLoading = true;
  final int _page = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/users', queryParams: {
        'page': _page,
        'page_size': _pageSize,
      });
      final data = response.data['data'];
      setState(() {
        _users = data['users'] ?? [];
        _total = data['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载失败，可能需要管理员权限')),
        );
      }
    }
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/users/$userId/role', data: {'role': newRole});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('角色已更新为 $newRole')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败')),
        );
      }
    }
  }

  Future<void> _updateStatus(String userId, bool isActive) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/api/users/$userId/status', data: {'is_active': isActive});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? '用户已启用' : '用户已禁用')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('用户管理 ($_total)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isCurrentUser = user['id'] == currentUser?.id;
                  return _buildUserTile(user, isCurrentUser);
                },
              ),
            ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isCurrentUser) {
    final role = user['role'] ?? 'member';
    final isActive = user['is_active'] ?? true;
    final isVerified = user['is_verified'] ?? false;
    final lastLogin = user['last_login_at'];

    final roleLabels = {
      'admin': '管理员',
      'family_admin': '家庭管理员',
      'member': '成员',
    };

    final roleColors = {
      'admin': Colors.red,
      'family_admin': Colors.orange,
      'member': Colors.blue,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? null : Colors.grey,
          backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
          child: user['avatar_url'] == null
              ? Text((user['full_name'] ?? user['username'] ?? '?')[0])
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['full_name'] ?? user['username'] ?? '',
                style: TextStyle(
                  color: isActive ? null : Colors.grey,
                  decoration: isActive ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (roleColors[role] ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabels[role] ?? role,
                style: TextStyle(
                  fontSize: 11,
                  color: roleColors[role] ?? Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已禁用', style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? '', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Row(
              children: [
                if (isVerified)
                  const Icon(Icons.verified, size: 14, color: Colors.green)
                else
                  const Icon(Icons.circle_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  isVerified ? '已验证' : '未验证',
                  style: TextStyle(fontSize: 11, color: isVerified ? Colors.green : Colors.grey),
                ),
                const SizedBox(width: 12),
                if (lastLogin != null)
                  Text(
                    '登录: ${formatRelativeTime(DateTime.parse(lastLogin))}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
        trailing: isCurrentUser
            ? const Chip(label: Text('当前', style: TextStyle(fontSize: 11)))
            : PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'detail', child: Text('查看详情')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'role_admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('设为管理员'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'role_family_admin',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('设为家庭管理员'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'role_member',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('设为成员'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: isActive ? 'disable' : 'enable',
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.block : Icons.check_circle,
                          size: 18,
                          color: isActive ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? '禁用用户' : '启用用户'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'detail':
                      _showUserDetail(user['id']);
                      break;
                    case 'role_admin':
                      _updateRole(user['id'], 'admin');
                      break;
                    case 'role_family_admin':
                      _updateRole(user['id'], 'family_admin');
                      break;
                    case 'role_member':
                      _updateRole(user['id'], 'member');
                      break;
                    case 'disable':
                      _showStatusConfirm(user['id'], false);
                      break;
                    case 'enable':
                      _updateStatus(user['id'], true);
                      break;
                  }
                },
              ),
      ),
    );
  }

  void _showStatusConfirm(String userId, bool isActive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认禁用'),
        content: const Text('禁用后该用户将无法登录。确认禁用？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(userId, isActive);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('禁用'),
          ),
        ],
      ),
    );
  }

  void _showUserDetail(String userId) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/users/$userId');
      final user = response.data['data'];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(user['username'] ?? '用户详情'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('ID', user['id'] ?? ''),
                _detailRow('用户名', user['username'] ?? ''),
                _detailRow('邮箱', user['email'] ?? ''),
                _detailRow('姓名', user['full_name'] ?? ''),
                _detailRow('角色', user['role'] ?? ''),
                _detailRow('状态', user['is_active'] == true ? '正常' : '已禁用'),
                _detailRow('验证', user['is_verified'] == true ? '已验证' : '未验证'),
                _detailRow('登录失败', '${user['login_attempts'] ?? 0} 次'),
                if (user['locked_until'] != null)
                  _detailRow('锁定至', user['locked_until']),
                _detailRow('注册时间', user['created_at'] ?? ''),
                if (user['last_login_at'] != null)
                  _detailRow('最后登录', user['last_login_at']),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取详情失败')),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
