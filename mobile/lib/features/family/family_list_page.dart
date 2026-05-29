import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';

final familiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families');
  return response.data['data']['families'] ?? [];
});

class FamilyListPage extends ConsumerWidget {
  const FamilyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familiesAsync = ref.watch(familiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的家庭'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateFamily(context, ref),
          ),
        ],
      ),
      body: familiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (families) {
          if (families.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 80, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text('暂无家庭', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('创建家庭或通过邀请码加入', style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateFamily(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('创建家庭'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showJoinFamily(context, ref),
                    icon: const Icon(Icons.group_add),
                    label: const Text('加入家庭'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: families.length,
            itemBuilder: (context, index) {
              final family = families[index];
              return _buildFamilyCard(context, ref, family);
            },
          );
        },
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, WidgetRef ref, Map<String, dynamic> family) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.family_restroom, color: AppColors.primary),
        ),
        title: Text(family['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${family['member_count'] ?? 0} 位成员', style: const TextStyle(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showFamilyDetail(context, ref, family),
      ),
    );
  }

  void _showCreateFamily(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建家庭'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '家庭名称', hintText: '例如：我的家庭'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final api = ref.read(apiClientProvider);
              await api.dio.post('/families', data: {'name': nameController.text});
              Navigator.pop(context);
              ref.invalidate(familiesProvider);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinFamily(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入家庭'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: '邀请码', hintText: '输入6位邀请码'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty) return;
              try {
                final api = ref.read(apiClientProvider);
                await api.dio.post('/families/join', data: {'invite_code': codeController.text});
                Navigator.pop(context);
                ref.invalidate(familiesProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('成功加入家庭'), backgroundColor: AppColors.profit),
                );
              } on ApiException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
                );
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  void _showFamilyDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> family) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => FamilyDetailSheet(
          family: family,
          scrollController: scrollController,
          onRefresh: () => ref.invalidate(familiesProvider),
        ),
      ),
    );
  }
}

class FamilyDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> family;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  const FamilyDetailSheet({
    super.key,
    required this.family,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.family_restroom, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    Text('${family['member_count'] ?? 0} 位成员', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Invite Code Section
          _buildSection('邀请码', [
            ListTile(
              leading: const Icon(Icons.qr_code, color: AppColors.primary),
              title: Text(family['invite_code'] ?? '未生成'),
              subtitle: const Text('分享此邀请码邀请家人加入'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  // Copy to clipboard
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邀请码已复制')),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _generateInviteCode(context, ref),
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成邀请码'),
            ),
          ]),

          const SizedBox(height: 16),

          // Members Section
          _buildSection('家庭成员', [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('加载中...'),
            ),
          ]),

          const SizedBox(height: 24),

          // Actions
          OutlinedButton.icon(
            onPressed: () => _showJoinFamily(context, ref),
            icon: const Icon(Icons.group_add),
            label: const Text('邀请家人加入'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  void _generateInviteCode(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post('/families/${family['id']}/invite');
      final code = response.data['data']['invite_code'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新邀请码: $code')),
      );
      onRefresh();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
      );
    }
  }

  void _showJoinFamily(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入家庭'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: '邀请码'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty) return;
              try {
                final api = ref.read(apiClientProvider);
                await api.dio.post('/families/join', data: {'invite_code': codeController.text});
                Navigator.pop(context);
                onRefresh();
              } on ApiException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
                );
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  const AppCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: child,
    );
  }
}
