import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../services/api.dart';
import '../../models/models.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  List<Asset> _assets = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await Api.instance.get('/families/current/assets');
      setState(() {
        _assets = (resp['data']?['assets'] as List? ?? []).map((e) => Asset.fromJson(e)).toList();
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
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addAsset),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _buildFilters(),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip('全部', 'all'),
          _chip('📦 实物', 'tangible'),
          _chip('📈 金融', 'financial'),
          _chip('💻 数字', 'digital'),
          _chip('🎬 服务', 'service'),
          _chip('🛡️ 保险', 'intangible'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 13, color: sel ? Colors.white : kTextPrimary)),
        selected: sel,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: kPrimaryColor,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? kPrimaryColor : kBorderColor),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildList() {
    final filtered = _filter == 'all' ? _assets : _assets.where((a) => a.nature == _filter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: kTextTertiary),
            const SizedBox(height: 16),
            const Text('暂无资产', style: TextStyle(fontSize: 16, color: kTextSecondary)),
            const SizedBox(height: 8),
            const Text('点击右上角 + 添加', style: TextStyle(color: kTextTertiary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _assetCard(filtered[i]),
    );
  }

  Widget _assetCard(Asset asset) {
    final value = asset.financial?.currentValue ?? 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(asset),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(natureEmoji(asset.nature), style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              // 名称+分类
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(natureLabel(asset.nature), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // 价值
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatAmount(value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (asset.tags.isNotEmpty)
                    Text(asset.tags.take(2).join(' '), style: const TextStyle(color: kTextTertiary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addAsset() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String nature = 'tangible';
    String utility = 'essential';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '资产名称', prefixIcon: Icon(Icons.label_outline))),
              const SizedBox(height: 16),
              const Text('性质', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _radioChip('实物', 'tangible', nature, (v) => setSheet(() => nature = v)),
                  _radioChip('金融', 'financial', nature, (v) => setSheet(() => nature = v)),
                  _radioChip('数字', 'digital', nature, (v) => setSheet(() => nature = v)),
                  _radioChip('服务', 'service', nature, (v) => setSheet(() => nature = v)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('用途', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _radioChip('必需', 'essential', utility, (v) => setSheet(() => utility = v)),
                  _radioChip('生活', 'lifestyle', utility, (v) => setSheet(() => utility = v)),
                  _radioChip('投资', 'productive', utility, (v) => setSheet(() => utility = v)),
                  _radioChip('消耗', 'consumable', utility, (v) => setSheet(() => utility = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '购买价格', prefixIcon: Icon(Icons.attach_money), hintText: '0.00'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await Api.instance.post('/families/current/assets', body: {
                      'name': nameCtrl.text,
                      'nature': nature,
                      'utility': utility,
                      'ownership': 'owned',
                      'liquidity': 'medium',
                      'purchase_price': double.tryParse(priceCtrl.text) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('资产添加成功'), backgroundColor: kLossColor),
                      );
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: kErrorColor),
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

  Widget _radioChip(String label, String value, String selected, ValueChanged<String> onChanged) {
    final sel = selected == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: sel ? Colors.white : kTextPrimary)),
      selected: sel,
      onSelected: (_) => onChanged(value),
      selectedColor: kPrimaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(color: sel ? kPrimaryColor : kBorderColor),
      showCheckmark: false,
    );
  }

  void _showDetail(Asset asset) {
    final fin = asset.financial;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(natureEmoji(asset.nature), style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(asset.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('分类', natureLabel(asset.nature)),
            _detailRow('用途', asset.utility),
            _detailRow('持有', asset.ownership),
            _detailRow('流动性', asset.liquidity),
            if (fin != null) ...[
              const Divider(height: 24),
              _detailRow('当前价值', formatAmount(fin.currentValue)),
              _detailRow('购买价格', formatAmount(fin.purchasePrice)),
            ],
            if (asset.tags.isNotEmpty) _detailRow('标签', asset.tags.join('、')),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑'),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    await Api.instance.delete('/families/current/assets/${asset.id}');
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  icon: const Icon(Icons.archive_outlined, color: kWarningColor),
                  label: const Text('归档', style: TextStyle(color: kWarningColor)),
                )),
              ],
            ),
            const SizedBox(height: 8),
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
          Text(label, style: const TextStyle(color: kTextSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
