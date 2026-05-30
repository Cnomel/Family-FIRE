import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AssetFilterPage extends StatefulWidget {
  const AssetFilterPage({super.key});

  @override
  State<AssetFilterPage> createState() => _AssetFilterPageState();
}

class _AssetFilterPageState extends State<AssetFilterPage> {
  String? _nature;
  String? _utility;
  String? _ownership;
  String? _liquidity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, String?>?;
    if (extra != null) {
      _nature = extra['nature'];
      _utility = extra['utility'];
      _ownership = extra['ownership'];
      _liquidity = extra['liquidity'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('筛选'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _nature = null;
                _utility = null;
                _ownership = null;
                _liquidity = null;
              });
            },
            child: const Text('重置'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('性质', [
            ('all', '全部'), ('tangible', '有形资产'), ('digital', '数字资产'),
            ('financial', '金融资产'), ('intangible', '无形资产'), ('service', '服务'),
          ], _nature, (v) => setState(() => _nature = v == 'all' ? null : v)),
          const SizedBox(height: 24),
          _buildSection('用途', [
            ('all', '全部'), ('productive', '生产性'), ('consumable', '消耗品'),
            ('protective', '防护性'), ('speculative', '投机性'), ('lifestyle', '生活方式'),
            ('essential', '必需品'),
          ], _utility, (v) => setState(() => _utility = v == 'all' ? null : v)),
          const SizedBox(height: 24),
          _buildSection('持有方式', [
            ('all', '全部'), ('owned', '自有'), ('mortgaged', '抵押'), ('leased', '租赁'),
            ('subscribed', '订阅'), ('licensed', '授权'), ('custodied', '托管'),
          ], _ownership, (v) => setState(() => _ownership = v == 'all' ? null : v)),
          const SizedBox(height: 24),
          _buildSection('流动性', [
            ('all', '全部'), ('instant', '即时'), ('high', '高'), ('medium', '中'),
            ('low', '低'), ('fixed', '固定'),
          ], _liquidity, (v) => setState(() => _liquidity = v == 'all' ? null : v)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              context.pop({
                'nature': _nature,
                'utility': _utility,
                'ownership': _ownership,
                'liquidity': _liquidity,
              });
            },
            child: const Text('应用筛选'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<(String, String)> options, String? selected, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = (opt.$1 == 'all' && selected == null) || opt.$1 == selected;
            return ChoiceChip(
              label: Text(opt.$2),
              selected: isSelected,
              onSelected: (_) => onChanged(opt.$1),
            );
          }).toList(),
        ),
      ],
    );
  }
}
