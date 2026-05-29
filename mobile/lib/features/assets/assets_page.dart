import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/formatters.dart';
import '../../core/api_service.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final _api = ApiService();
  List<dynamic> _assets = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/families/current/assets');
      setState(() {
        _assets = response['data']?['assets'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddAsset),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAssets,
              child: Column(
                children: [
                  _buildFilterChips(),
                  Expanded(child: _buildAssetList()),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip('全部', 'all'),
          _chip('实物', 'tangible'),
          _chip('金融', 'financial'),
          _chip('服务', 'service'),
          _chip('数字', 'digital'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primaryLight,
      ),
    );
  }

  Widget _buildAssetList() {
    final filtered = _filter == 'all'
        ? _assets
        : _assets.where((a) => a['nature'] == _filter).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 80, color: AppColors.textTertiary),
            SizedBox(height: 16),
            Text('暂无资产', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
            SizedBox(height: 8),
            Text('点击右上角 + 添加资产', style: TextStyle(color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildAssetCard(filtered[index]),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final nature = asset['nature'] ?? '';
    final financial = asset['financial'] as Map<String, dynamic>?;
    final value = (financial?['current_value'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(_natureIcon(nature), color: AppColors.primary, size: 20),
        ),
        title: Text(asset['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_natureLabel(nature), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Text(
          formatAmount(value),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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

  void _showAddAsset() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String selectedNature = 'tangible';
    String selectedUtility = 'essential';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('添加资产', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '资产名称', prefixIcon: Icon(Icons.label)),
              ),
              const SizedBox(height: 12),
              const Text('性质', style: TextStyle(fontWeight: FontWeight.w500)),
              Wrap(
                spacing: 8,
                children: [
                  _choiceChip('实物', 'tangible', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _choiceChip('金融', 'financial', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _choiceChip('数字', 'digital', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _choiceChip('服务', 'service', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('用途', style: TextStyle(fontWeight: FontWeight.w500)),
              Wrap(
                spacing: 8,
                children: [
                  _choiceChip('必需', 'essential', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _choiceChip('生活', 'lifestyle', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _choiceChip('投资', 'productive', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _choiceChip('消耗', 'consumable', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: '购买价格', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  try {
                    await _api.post('/families/current/assets', body: {
                      'name': nameController.text,
                      'nature': selectedNature,
                      'utility': selectedUtility,
                      'ownership': 'owned',
                      'liquidity': 'medium',
                      'purchase_price': double.tryParse(priceController.text) ?? 0,
                    });
                    Navigator.pop(context);
                    _loadAssets();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('资产添加成功'), backgroundColor: AppColors.loss),
                      );
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                    );
                  }
                },
                child: const Text('添加资产'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String label, String value, String selected, ValueChanged<String> onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }

  void _showAssetDetail(Map<String, dynamic> asset) {
    final financial = asset['financial'] as Map<String, dynamic>?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(asset['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _detailRow('分类', _natureLabel(asset['nature'] ?? '')),
            _detailRow('当前价值', formatAmount((financial?['current_value'] ?? 0).toDouble())),
            _detailRow('购买价格', formatAmount((financial?['purchase_price'] ?? 0).toDouble())),
            if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
              _detailRow('标签', (asset['tags'] as List).join(', ')),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _api.delete('/families/current/assets/${asset['id']}');
                      Navigator.pop(context);
                      _loadAssets();
                    },
                    icon: const Icon(Icons.archive, color: AppColors.warning),
                    label: const Text('归档', style: TextStyle(color: AppColors.warning)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
