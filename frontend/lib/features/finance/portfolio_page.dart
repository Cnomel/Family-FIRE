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
  List<dynamic> _transactions = [];
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
      final response = await client.get('/api/families/current/finance/transactions', queryParams: {'page': 1, 'page_size': 50});
      setState(() {
        _transactions = response.data['data']?['transactions'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投资组合')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_transactions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('暂无交易记录')),
                      ),
                    )
                  else
                    ..._transactions.map((tx) => _buildTransactionCard(tx)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final typeLabels = {'buy': '买入', 'sell': '卖出', 'dividend': '分红', 'split': '拆股', 'transfer': '转账', 'fee': '手续费'};
    final typeColors = {'buy': AppColors.loss, 'sell': AppColors.profit, 'dividend': AppColors.profit};

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (typeColors[tx['type']] ?? Colors.grey).withValues(alpha: 0.1),
          child: Icon(
            tx['type'] == 'buy' ? Icons.arrow_downward : Icons.arrow_upward,
            color: typeColors[tx['type']] ?? Colors.grey,
          ),
        ),
        title: Text(typeLabels[tx['type']] ?? tx['type'] ?? ''),
        subtitle: Text(tx['date'] != null ? tx['date'].toString().substring(0, 10) : ''),
        trailing: Text(
          formatCurrency(toDouble(tx['total'])),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showAddTransactionDialog() {
    final totalController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final assetIdController = TextEditingController();
    String type = 'buy';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('记录交易'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'buy', label: Text('买入')),
                    ButtonSegment(value: 'sell', label: Text('卖出')),
                    ButtonSegment(value: 'dividend', label: Text('分红')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setDialogState(() => type = v.first),
                ),
                const SizedBox(height: 16),
                TextField(controller: assetIdController, decoration: const InputDecoration(labelText: '资产ID')),
                const SizedBox(height: 12),
                TextField(controller: totalController, decoration: const InputDecoration(labelText: '总金额', prefixText: '¥'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: quantityController, decoration: const InputDecoration(labelText: '数量'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: '单价', prefixText: '¥'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final client = ref.read(apiClientProvider);
                  await client.post('/api/families/current/finance/transactions', data: {
                    'asset_id': assetIdController.text.trim(),
                    'type': type,
                    'total': double.tryParse(totalController.text) ?? 0,
                    'quantity': double.tryParse(quantityController.text),
                    'price': double.tryParse(priceController.text),
                    'date': DateTime.now().toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('添加失败')));
                  }
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
