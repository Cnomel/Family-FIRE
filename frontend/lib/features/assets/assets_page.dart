import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';

class AssetsTab extends StatefulWidget {
  final bool privacy;
  const AssetsTab({super.key, required this.privacy});

  @override
  State<AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<AssetsTab> {
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
      final response = await Api.instance.get('/families/current/assets');
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddAsset,
          ),
        ],
      ),
      body: RefreshIndicator(
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
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildChip('全部', 'all'),
          _buildChip('📦 实物', 'tangible'),
          _buildChip('📈 金融', 'financial'),
          _buildChip('💻 数字', 'digital'),
          _buildChip('🎬 服务', 'service'),
          _buildChip('🛡️ 保险', 'intangible'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : kText),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: kPrimary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? kPrimary : kBorder),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildAssetList() {
    final filtered = _filter == 'all'
        ? _assets
        : _assets.where((a) => a['nature'] == _filter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: kText3),
            const SizedBox(height: 16),
            const Text('暂无资产', style: TextStyle(fontSize: 16, color: kText2)),
            const SizedBox(height: 8),
            const Text('点击右上角 + 添加', style: TextStyle(color: kText3)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildAssetCard(filtered[index]),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final value = (asset['financial']?['current_value'] ?? 0).toDouble();
    final nature = asset['nature'] ?? '';
    final emoji = _natureEmoji(nature);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAssetDetail(asset),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(natureLabel(nature), style: const TextStyle(color: kText2, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.privacy ? '****' : formatAmount(value),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
                    Text(
                      (asset['tags'] as List).take(2).join(' '),
                      style: const TextStyle(color: kText3, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _natureEmoji(String nature) {
    switch (nature) {
      case 'tangible': return '📦';
      case 'financial': return '📈';
      case 'digital': return '💻';
      case 'service': return '🎬';
      case 'intangible': return '🛡️';
      default: return '📋';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('添加资产', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '资产名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              const Text('性质', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildChoiceChip('实物', 'tangible', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _buildChoiceChip('金融', 'financial', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _buildChoiceChip('数字', 'digital', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                  _buildChoiceChip('服务', 'service', selectedNature, (v) => setSheetState(() => selectedNature = v)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('用途', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildChoiceChip('必需', 'essential', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _buildChoiceChip('生活', 'lifestyle', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _buildChoiceChip('投资', 'productive', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                  _buildChoiceChip('消耗', 'consumable', selectedUtility, (v) => setSheetState(() => selectedUtility = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '购买价格',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  try {
                    await Api.instance.post('/families/current/assets', body: {
                      'name': nameController.text,
                      'nature': selectedNature,
                      'utility': selectedUtility,
                      'ownership': 'owned',
                      'liquidity': 'medium',
                      'purchase_price': double.tryParse(priceController.text) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadAssets();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('资产添加成功'), backgroundColor: kLoss),
                      );
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: kError),
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

  Widget _buildChoiceChip(String label, String value, String selected, ValueChanged<String> onChanged) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : kText)),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: kPrimary,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? kPrimary : kBorder),
      showCheckmark: false,
    );
  }

  void _showAssetDetail(Map<String, dynamic> asset) {
    final financial = asset['financial'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(_natureEmoji(asset['nature'] ?? ''), style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    asset['name'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('分类', natureLabel(asset['nature'] ?? '')),
            _buildDetailRow('用途', utilityLabel(asset['utility'] ?? '')),
            _buildDetailRow('持有', asset['ownership'] ?? ''),
            _buildDetailRow('流动性', asset['liquidity'] ?? ''),
            const Divider(height: 24),
            _buildDetailRow('当前价值', formatAmount((financial['current_value'] ?? 0).toDouble())),
            _buildDetailRow('购买价格', formatAmount((financial['purchase_price'] ?? 0).toDouble())),
            if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
              _buildDetailRow('标签', (asset['tags'] as List).join('、')),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Api.instance.delete('/families/current/assets/${asset['id']}');
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAssets();
                    },
                    icon: const Icon(Icons.archive_outlined, color: kWarn),
                    label: const Text('归档', style: TextStyle(color: kWarn)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kText2)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
