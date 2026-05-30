import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/date.dart';

class FamilyDetailPage extends ConsumerStatefulWidget {
  final String familyId;
  const FamilyDetailPage({super.key, required this.familyId});

  @override
  ConsumerState<FamilyDetailPage> createState() => _FamilyDetailPageState();
}

class _FamilyDetailPageState extends ConsumerState<FamilyDetailPage> {
  Map<String, dynamic>? _family;
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
      final response = await client.get('/api/families/${widget.familyId}');
      setState(() {
        _family = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteCode() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/api/families/${widget.familyId}/invite');
      final code = response.data['data']?['invite_code'];
      if (mounted && code != null) {
        context.push('/family/${widget.familyId}/invite', extra: code);
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('生成邀请码失败')));
      }
    }
  }

  Future<void> _updateFamily() async {
    final nameController = TextEditingController(text: _family?['name'] ?? '');
    final descController = TextEditingController(text: _family?['description'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑家庭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '家庭名称')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: '描述')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put('/api/families/${widget.familyId}', data: {
          'name': nameController.text.trim(),
          'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
        }
      }
    }
  }

  Future<void> _deleteFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除家庭'),
        content: const Text('此操作不可撤销，将删除家庭及所有关联数据。确认删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/families/${widget.familyId}');
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
        }
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: const Text('确认移除该成员？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('移除')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/families/${widget.familyId}/members/$userId');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('移除失败')));
        }
      }
    }
  }

  Future<void> _updateMemberRole(String userId, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改角色'),
        content: Text('确认将该成员角色修改为${newRole == 'admin' ? '管理员' : '成员'}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put('/api/families/${widget.familyId}/members/$userId/role', data: {
          'role': newRole,
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改失败')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('家庭详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final family = _family ?? {};
    final members = family['members'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(family['name'] ?? '家庭详情'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'invite', child: Text('邀请成员')),
              const PopupMenuItem(value: 'edit', child: Text('编辑家庭')),
              const PopupMenuItem(value: 'delete', child: Text('删除家庭', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (value) {
              switch (value) {
                case 'invite':
                  _generateInviteCode();
                  break;
                case 'edit':
                  _updateFamily();
                  break;
                case 'delete':
                  _deleteFamily();
                  break;
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 家庭信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      (family['name'] ?? '?')[0],
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    family['name'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (family['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      family['description'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(label: Text('${members.length} 成员')),
                      const SizedBox(width: 8),
                      Chip(label: Text('${family['asset_count'] ?? 0} 资产')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 邀请码
          if (family['invite_code'] != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('邀请码'),
                subtitle: Text(family['invite_code']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/family/${widget.familyId}/invite', extra: family['invite_code']),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 成员列表
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('成员', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _generateInviteCode,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('邀请'),
                      ),
                    ],
                  ),
                  ...members.map((member) => _buildMemberTile(member)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 操作
          OutlinedButton.icon(
            onPressed: _generateInviteCode,
            icon: const Icon(Icons.share),
            label: const Text('分享邀请码'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final isAdmin = member['role'] == 'admin';
    return ListTile(
      leading: CircleAvatar(
        child: Text((member['full_name'] ?? member['username'] ?? '?')[0]),
      ),
      title: Text(member['full_name'] ?? member['username'] ?? ''),
      subtitle: Text(isAdmin ? '管理员' : '成员'),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'role',
            child: Text(isAdmin ? '降为成员' : '升为管理员'),
          ),
          if (!isAdmin)
            const PopupMenuItem(value: 'remove', child: Text('移除', style: TextStyle(color: Colors.red))),
        ],
        onSelected: (value) {
          if (value == 'role') _updateMemberRole(member['user_id'], member['role']);
          if (value == 'remove') _removeMember(member['user_id']);
        },
      ),
    );
  }
}
