import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';
import '../../shared/theme/colors.dart';

class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key});

  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  Map<String, dynamic>? _portfolio;
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
      final response = await client.get('/api/families/current/finance/portfolio');
      if (mounted) {
        setState(() {
          _portfolio = response.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _portfolio = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投资组合')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _portfolio == null || (_portfolio!['holdings'] as List).isEmpty
              ? _buildEmptyState()
              : _buildPortfolio(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('暂无投资记录', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Text('添加金融资产后记录交易', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddTransactionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('记录第一笔交易'),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolio() {
    final totalValue = toDouble(_portfolio!['total_value']);
    final totalCost = toDouble(_portfolio!['total_cost']);
    final totalGain = toDouble(_portfolio!['total_gain']);
    final totalGainPercent = toDouble(_portfolio!['total_gain_percent']);
    final holdings = _portfolio!['holdings'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览卡片
          _buildSummaryCard(totalValue, totalCost, totalGain, totalGainPercent),
          const SizedBox(height: 16),

          // 持仓列表
          const Text('持仓明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...holdings.map((h) => _buildHoldingCard(h)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalValue, double totalCost, double totalGain, double totalGainPercent) {
    final isProfit = totalGain >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('总资产', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              formatCurrency(totalValue),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('总成本', formatCurrency(totalCost)),
                _buildSummaryItem('总收益', formatCurrency(totalGain), color: isProfit ? AppColors.profit : AppColors.loss),
                _buildSummaryItem('收益率', '${totalGainPercent.toStringAsFixed(2)}%', color: isProfit ? AppColors.profit : AppColors.loss),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingCard(Map<String, dynamic> holding) {
    final name = holding['name'] ?? '';
    final ticker = holding['ticker'] as String?;
    final instrumentType = holding['instrument_type'] as String?;
    final shares = toDouble(holding['shares']);
    final currentValue = toDouble(holding['current_value']);
    final cost = toDouble(holding['cost']);
    final gain = toDouble(holding['gain']);
    final gainPercent = toDouble(holding['gain_percent']);
    final recentTxs = holding['recent_transactions'] as List? ?? [];
    final assetId = holding['asset_id'] ?? '';

    final isProfit = gain >= 0;
    final typeLabel = _getInstrumentTypeLabel(instrumentType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [if (ticker != null) ticker, typeLabel].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(currentValue),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${isProfit ? '+' : ''}${formatCurrency(gain)} (${gainPercent.toStringAsFixed(2)}%)',
                style: TextStyle(fontSize: 12, color: isProfit ? AppColors.profit : AppColors.loss),
              ),
            ],
          ),
          children: [
            // 持仓详情
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Divider(),
                  _buildDetailRow('持有份额', shares.toStringAsFixed(2)),
                  _buildDetailRow('总成本', formatCurrency(cost)),
                  _buildDetailRow('当前市值', formatCurrency(currentValue)),
                  if (recentTxs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('最近交易', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    ...recentTxs.map((tx) => _buildTransactionTile(tx)),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await context.push('/finance/price/$assetId');
                      if (mounted) _loadData();
                    },
                    child: const Text('查看价格走势'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final type = tx['type'] ?? '';
    final total = toDouble(tx['total']);
    final dateStr = tx['date'] as String?;

    final typeInfo = _getTypeInfo(type);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final dateLabel = date != null ? '${date.month}/${date.day}' : '';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(typeInfo.$2, size: 20, color: typeInfo.$3),
      title: Text('${typeInfo.$1}  $dateLabel', style: const TextStyle(fontSize: 13)),
      trailing: Text(
        '${type == 'buy' ? '-' : '+'}${formatCurrency(total.abs())}',
        style: TextStyle(fontSize: 13, color: typeInfo.$3),
      ),
    );
  }

  String _getInstrumentTypeLabel(String? type) {
    switch (type) {
      case 'stock': return '股票';
      case 'etf': return 'ETF';
      case 'mutual_fund': return '基金';
      case 'bond': return '债券';
      case 'crypto': return '加密货币';
      case 'reit': return 'REIT';
      case 'option': return '期权';
      case 'cd': return '定期';
      case 'money_market': return '货币基金';
      default: return '';
    }
  }

  (String, IconData, Color) _getTypeInfo(String type) {
    switch (type) {
      case 'buy': return ('买入', Icons.add_circle, AppColors.loss);
      case 'sell': return ('卖出', Icons.remove_circle, AppColors.profit);
      case 'dividend': return ('分红', Icons.attach_money, AppColors.profit);
      case 'split': return ('拆股', Icons.call_split, Colors.blue);
      case 'transfer': return ('转账', Icons.swap_horiz, Colors.orange);
      case 'fee': return ('手续费', Icons.money_off, Colors.grey);
      default: return (type, Icons.help_outline, Colors.grey);
    }
  }

  void _showAddTransactionDialog() {
    final totalController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    String txType = 'buy';
    String? selectedAssetId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('记录交易'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 交易类型
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'buy', label: Text('买入'), icon: Icon(Icons.add)),
                    ButtonSegment(value: 'sell', label: Text('卖出'), icon: Icon(Icons.remove)),
                    ButtonSegment(value: 'dividend', label: Text('分红'), icon: Icon(Icons.attach_money)),
                  ],
                  selected: {txType},
                  onSelectionChanged: (v) => setDialogState(() => txType = v.first),
                ),
                const SizedBox(height: 16),

                // 资产ID
                TextField(
                  decoration: const InputDecoration(
                    labelText: '资产ID',
                    hintText: '输入金融资产的ID',
                  ),
                  onChanged: (v) => selectedAssetId = v.trim(),
                ),
                const SizedBox(height: 12),

                // 总金额
                TextField(
                  controller: totalController,
                  decoration: const InputDecoration(labelText: '总金额', prefixText: '¥'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // 数量
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: '数量（可选）'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // 单价
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: '单价（可选）', prefixText: '¥'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                if (selectedAssetId == null || selectedAssetId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入资产ID')));
                  return;
                }
                final total = double.tryParse(totalController.text);
                if (total == null || total <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
                  return;
                }

                try {
                  final client = ref.read(apiClientProvider);
                  await client.post('/api/families/current/finance/transactions', data: {
                    'asset_id': selectedAssetId,
                    'type': txType,
                    'total': total,
                    if (quantityController.text.isNotEmpty) 'quantity': double.parse(quantityController.text),
                    if (priceController.text.isNotEmpty) 'price': double.parse(priceController.text),
                    'date': DateTime.now().toIso8601String(),
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录失败')));
                  }
                }
              },
              child: const Text('记录'),
            ),
          ],
        ),
      ),
    );
  }
}
