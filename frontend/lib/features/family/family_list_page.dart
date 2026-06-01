import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';

class FamilyListPage extends ConsumerStatefulWidget {
  const FamilyListPage({super.key});

  @override
  ConsumerState<FamilyListPage> createState() => _FamilyListPageState();
}

class _FamilyListPageState extends ConsumerState<FamilyListPage> {
  List<dynamic> _families = [];
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
      final response = await client.get('/api/families');
      setState(() {
        _families = response.data['data']?['families'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家庭管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_families.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.family_restroom, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            const Text('暂无家庭'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('创建家庭'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._families.map((family) => _buildFamilyCard(family)),
                  const SizedBox(height: 16),
                  // 加入家庭
                  OutlinedButton.icon(
                    onPressed: () => _showJoinDialog(),
                    icon: const Icon(Icons.group_add),
                    label: const Text('加入家庭'),
                  ),
                ],
              ),
            ),
      floatingActionButton: _families.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildFamilyCard(Map<String, dynamic> family) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text((family['name'] ?? '?')[0]),
        ),
        title: Text(family['name'] ?? ''),
        subtitle: Text('${family['member_count'] ?? 0} 人 · ${family['asset_count'] ?? 0} 个资产'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await context.push('/family/${family['id']}');
          if (mounted) _loadData();
        },
      ),
    );
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建家庭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '家庭名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '描述 (可选)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                final client = ref.read(apiClientProvider);
                await client.post('/api/families', data: {
                  'name': nameController.text.trim(),
                  if (descController.text.isNotEmpty) 'description': descController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建失败')));
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入家庭'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: '邀请码'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                final client = ref.read(apiClientProvider);
                await client.post('/api/families/join', data: {
                  'invite_code': codeController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加入失败')));
                }
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}
