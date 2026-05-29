import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';

// Default family ID - would come from family selection in real app
const String _defaultFamilyId = 'current';

final assetsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families/$_defaultFamilyId/assets');
  return response.data['data']['assets'] ?? [];
});

final assetStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families/$_defaultFamilyId/assets/stats');
  return response.data['data'] ?? {};
});

class AssetListPage extends ConsumerStatefulWidget {
  const AssetListPage({super.key});

  @override
  ConsumerState<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends ConsumerState<AssetListPage> {
  String _filterNature = 'all';
  bool _privacyMode = false;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetsProvider);
    final statsAsync = ref.watch(assetStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          IconButton(
            icon: Icon(_privacyMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _privacyMode = !_privacyMode),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAsset(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Summary
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _buildStatsBar(stats),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索资产...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('全部', 'all'),
                _buildFilterChip('实物', 'tangible'),
                _buildFilterChip('金融', 'financial'),
                _buildFilterChip('数字', 'digital'),
                _buildFilterChip('服务', 'service'),
                _buildFilterChip('保险', 'intangible'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Asset List
          Expanded(
            child: assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (assets) {
                final filtered = _filterAssets(assets);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 80, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        const Text('暂无资产', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        const Text('点击右上角 + 添加资产', style: TextStyle(color: AppColors.textTertiary)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(assetsProvider);
                    ref.invalidate(assetStatsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildAssetCard(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildStatItem('总资产', '${stats['total_count'] ?? 0}'),
          Container(width: 1, height: 24, color: AppColors.border),
          _buildStatItem('总价值', _privacyMode ? '****' : '¥${_formatAmount((stats['total_value'] ?? 0).toDouble())}'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterNature == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterNature = value),
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
      ),
    );
  }

  List<dynamic> _filterAssets(List<dynamic> assets) {
    var filtered = assets;
    if (_filterNature != 'all') {
      filtered = filtered.where((a) => a['nature'] == _filterNature).toList();
    }
    if (_searchController.text.isNotEmpty) {
      final search = _searchController.text.toLowerCase();
      filtered = filtered.where((a) => (a['name'] as String).toLowerCase().contains(search)).toList();
    }
    return filtered;
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final nature = asset['nature'] as String? ?? '';
    final financial = asset['financial'] as Map<String, dynamic>?;
    final value = (financial?['current_value'] ?? 0).toDouble();
    final icon = _natureIcon(nature);
    final color = _natureColor(nature);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(asset['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_natureLabel(nature), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _privacyMode ? '****' : '¥${_formatAmount(value)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
              Text(
                (asset['tags'] as List).take(2).join(', '),
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
          ],
        ),
        onTap: () => _showAssetDetail(asset),
      ),
    );
  }

  String _natureLabel(String nature) {
    switch (nature) {
      case 'tangible': return '实物资产';
      case 'financial': return '金融资产';
      case 'digital': return '数字资产';
      case 'service': return '服务订阅';
      case 'intangible': return '保险';
      default: return nature;
    }
  }

  IconData _natureIcon(String nature) {
    switch (nature) {
      case 'tangible': return Icons.inventory_2;
      case 'financial': return Icons.trending_up;
      case 'digital': return Icons.devices;
      case 'service': return Icons.movie;
      case 'intangible': return Icons.shield;
      default: return Icons.category;
    }
  }

  Color _natureColor(String nature) {
    switch (nature) {
      case 'tangible': return AppColors.transport;
      case 'financial': return AppColors.profit;
      case 'digital': return AppColors.shopping;
      case 'service': return AppColors.entertainment;
      case 'intangible': return AppColors.healthcare;
      default: return AppColors.primary;
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) return '${(amount / 100000000).toStringAsFixed(2)}亿';
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(2)}万';
    return amount.toStringAsFixed(2);
  }

  void _showAddAsset(BuildContext context) {
    final nameController = TextEditingController();
    String selectedNature = 'tangible';
    String selectedUtility = 'essential';
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                const Text('添加资产', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '资产名称', prefixIcon: Icon(Icons.label)),
                ),
                const SizedBox(height: 16),
                const Text('性质', style: TextStyle(fontWeight: FontWeight.w500)),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildChoiceChip('实物', 'tangible', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                    _buildChoiceChip('金融', 'financial', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                    _buildChoiceChip('数字', 'digital', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                    _buildChoiceChip('服务', 'service', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                    _buildChoiceChip('保险', 'intangible', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('用途', style: TextStyle(fontWeight: FontWeight.w500)),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildChoiceChip('必需', 'essential', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                    _buildChoiceChip('生活', 'lifestyle', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                    _buildChoiceChip('投资', 'productive', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                    _buildChoiceChip('消耗', 'consumable', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                    _buildChoiceChip('保护', 'protective', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: '购买价格', prefixIcon: Icon(Icons.attach_money)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    try {
                      final api = ref.read(apiClientProvider);
                      await api.dio.post('/families/$_defaultFamilyId/assets', data: {
                        'name': nameController.text,
                        'nature': selectedNature,
                        'utility': selectedUtility,
                        'ownership': 'owned',
                        'liquidity': 'medium',
                        'purchase_price': double.tryParse(priceController.text) ?? 0,
                      });
                      Navigator.pop(context);
                      ref.invalidate(assetsProvider);
                      ref.invalidate(assetStatsProvider);
                    } on ApiException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
                      );
                    }
                  },
                  child: const Text('添加资产'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String selected, ValueChanged<String> onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }

  void _showAssetDetail(Map<String, dynamic> asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final financial = asset['financial'] as Map<String, dynamic>?;
          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _natureColor(asset['nature']).withValues(alpha: 0.1),
                      child: Icon(_natureIcon(asset['nature']), color: _natureColor(asset['nature']), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          Text(_natureLabel(asset['nature']), style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('当前价值', '¥${_formatAmount((financial?['current_value'] ?? 0).toDouble())}'),
                _buildDetailRow('购买价格', '¥${_formatAmount((financial?['purchase_price'] ?? 0).toDouble())}'),
                _buildDetailRow('分类', _natureLabel(asset['nature'])),
                if (asset['tags'] != null)
                  _buildDetailRow('标签', (asset['tags'] as List).join(', ')),
                const SizedBox(height: 24),
                const Text('操作', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('编辑'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _archiveAsset(asset['id']);
                      },
                      icon: const Icon(Icons.archive, color: AppColors.warning),
                      label: const Text('归档', style: TextStyle(color: AppColors.warning)),
                    )),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _archiveAsset(String? assetId) async {
    if (assetId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/families/$_defaultFamilyId/assets/$assetId');
      ref.invalidate(assetsProvider);
      ref.invalidate(assetStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('资产已归档')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
