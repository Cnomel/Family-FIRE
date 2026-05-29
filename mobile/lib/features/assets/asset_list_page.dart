import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../shared/formatters/currency.dart';

class AssetListPage extends StatefulWidget {
  const AssetListPage({super.key});

  @override
  State<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends State<AssetListPage> {
  String _filterNature = 'all';
  bool _privacyMode = false;
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _assets = [
    {'name': '贵州茅台', 'nature': 'financial', 'value': 188800, 'change': 0.0126, 'icon': Icons.trending_up, 'color': AppColors.profit},
    {'name': '2024 Toyota Camry', 'nature': 'tangible', 'value': 180000, 'change': -0.10, 'icon': Icons.directions_car, 'color': AppColors.transport},
    {'name': '招商银行储蓄卡', 'nature': 'financial', 'value': 125000, 'change': 0, 'icon': Icons.account_balance, 'color': AppColors.primary},
    {'name': 'Netflix Premium', 'nature': 'service', 'value': 0, 'change': 0, 'icon': Icons.movie, 'color': AppColors.entertainment},
    {'name': '维达抽纸', 'nature': 'tangible', 'value': 29.9, 'change': 0, 'icon': Icons.inventory_2, 'color': AppColors.food},
    {'name': 'BTC', 'nature': 'financial', 'value': 50000, 'change': 0.035, 'icon': Icons.currency_bitcoin, 'color': AppColors.warning},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          IconButton(
            icon: Icon(_privacyMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _privacyMode = !_privacyMode),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddAsset),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索资产...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('全部', 'all'),
                _buildFilterChip('金融', 'financial'),
                _buildFilterChip('实物', 'tangible'),
                _buildFilterChip('服务', 'service'),
                _buildFilterChip('数字', 'digital'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Asset List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredAssets.length,
              itemBuilder: (context, index) => _buildAssetCard(_filteredAssets[index]),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredAssets {
    if (_filterNature == 'all') return _assets;
    return _assets.where((a) => a['nature'] == _filterNature).toList();
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

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final change = asset['change'] as double;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (asset['color'] as Color).withValues(alpha: 0.1),
          child: Icon(asset['icon'] as IconData, color: asset['color'] as Color, size: 20),
        ),
        title: Text(asset['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_natureLabel(asset['nature'] as String), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _privacyMode ? '****' : CurrencyFormatter.format(asset['value'] as double),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (change != 0)
              Text(
                CurrencyFormatter.formatPercent(change),
                style: TextStyle(color: change > 0 ? AppColors.profit : AppColors.loss, fontSize: 12),
              ),
          ],
        ),
        onTap: () => _showAssetDetail(asset),
      ),
    );
  }

  String _natureLabel(String nature) {
    switch (nature) {
      case 'financial': return '金融资产';
      case 'tangible': return '实物资产';
      case 'service': return '服务订阅';
      case 'digital': return '数字资产';
      default: return nature;
    }
  }

  void _showAddAsset() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _buildAddAssetSheet(scrollController),
      ),
    );
  }

  Widget _buildAddAssetSheet(ScrollController scrollController) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          const Text('添加资产', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          const TextField(decoration: InputDecoration(labelText: '资产名称', prefixIcon: Icon(Icons.label))),
          const SizedBox(height: 16),
          const Text('选择分类', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildCategoryChip('实物', Icons.inventory_2),
              _buildCategoryChip('金融', Icons.account_balance),
              _buildCategoryChip('数字', Icons.devices),
              _buildCategoryChip('服务', Icons.movie),
              _buildCategoryChip('保险', Icons.shield),
            ],
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: '购买价格', prefixIcon: Icon(Icons.attach_money)),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('添加')),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {},
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
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (asset['color'] as Color).withValues(alpha: 0.1),
                    child: Icon(asset['icon'] as IconData, color: asset['color'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(asset['name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('当前价值', CurrencyFormatter.format(asset['value'] as double)),
              _buildDetailRow('分类', _natureLabel(asset['nature'] as String)),
              _buildDetailRow('购买日期', '2024-01-15'),
              _buildDetailRow('购买价格', '¥200,000.00'),
              const SizedBox(height: 16),
              const Text('价值变化', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('价值走势图表')),
              ),
              const SizedBox(height: 16),
              const Text('关联资产', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildRelationItem('车险', '保护'),
              _buildRelationItem('车贷', '担保'),
            ],
          ),
        ),
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

  Widget _buildRelationItem(String name, String type) {
    return ListTile(
      leading: const Icon(Icons.link, color: AppColors.primary),
      title: Text(name),
      subtitle: Text(type, style: const TextStyle(color: AppColors.textSecondary)),
      dense: true,
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
