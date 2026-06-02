import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';

class LiabilityPage extends ConsumerStatefulWidget {
  const LiabilityPage({super.key});

  @override
  ConsumerState<LiabilityPage> createState() => _LiabilityPageState();
}

class _LiabilityPageState extends ConsumerState<LiabilityPage> {
  List<dynamic> _liabilities = [];
  double _totalBalance = 0;
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
      final response = await client.get('/api/families/current/finance/liabilities');
      final data = response.data['data'];
      setState(() {
        _liabilities = data['liabilities'] ?? [];
        _totalBalance = toDouble(data['total_balance']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLiability(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确认删除该负债？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/families/current/finance/liabilities/$id');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('负债管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('总负债', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(
                            formatCurrency(_totalBalance),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_liabilities.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('暂无负债')),
                      ),
                    )
                  else
                    ..._liabilities.map((liability) => _buildLiabilityCard(liability)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('添加负债'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLiabilityCard(Map<String, dynamic> liability) {
    final typeLabels = {
      'mortgage': '房贷', 'auto_loan': '车贷', 'credit_card': '信用卡',
      'consumer_loan': '消费贷', 'personal_loan': '个人借款',
    };
    final typeIcons = {
      'mortgage': Icons.home, 'auto_loan': Icons.directions_car, 'credit_card': Icons.credit_card,
      'consumer_loan': Icons.shopping_cart, 'personal_loan': Icons.person,
    };
    final typeColors = {
      'mortgage': const Color(0xFF1677FF), 'auto_loan': const Color(0xFF722ED1),
      'credit_card': const Color(0xFFFA8C16), 'consumer_loan': const Color(0xFF13C2C2),
      'personal_loan': const Color(0xFF52C41A),
    };
    final type = liability['type'] as String? ?? '';
    final icon = typeIcons[type] ?? Icons.account_balance;
    final color = typeColors[type] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(128),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liability['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabels[type] ?? type,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(toDouble(liability['current_balance'])),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (liability['monthly_payment'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  '月供 ${formatCurrency(toDouble(liability['monthly_payment']))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteLiability(liability['id']);
              if (value == 'edit') _showEditDialog(liability);
            },
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    final rateController = TextEditingController();
    final paymentController = TextEditingController();
    String type = 'mortgage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加负债'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'mortgage', child: Text('房贷')),
                    DropdownMenuItem(value: 'auto_loan', child: Text('车贷')),
                    DropdownMenuItem(value: 'credit_card', child: Text('信用卡')),
                    DropdownMenuItem(value: 'consumer_loan', child: Text('消费贷')),
                    DropdownMenuItem(value: 'personal_loan', child: Text('个人借款')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(controller: balanceController, decoration: const InputDecoration(labelText: '当前余额', prefixText: '¥'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: rateController, decoration: const InputDecoration(labelText: '年利率(%)', suffixText: '%'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: paymentController, decoration: const InputDecoration(labelText: '月供', prefixText: '¥'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final client = ref.read(apiClientProvider);
                  await client.post('/api/families/current/finance/liabilities', data: {
                    'name': nameController.text.trim(),
                    'type': type,
                    'original_amount': double.tryParse(balanceController.text) ?? 0,
                    'current_balance': double.tryParse(balanceController.text) ?? 0,
                    'interest_rate': double.tryParse(rateController.text),
                    'monthly_payment': double.tryParse(paymentController.text),
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加失败')));
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

  void _showEditDialog(Map<String, dynamic> liability) {
    final balanceController = TextEditingController(text: toDouble(liability['current_balance']).toString());
    final rateController = TextEditingController(text: (liability['interest_rate'] ?? '').toString());
    final paymentController = TextEditingController(text: (liability['monthly_payment'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑负债'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: balanceController, decoration: const InputDecoration(labelText: '当前余额', prefixText: '¥'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: rateController, decoration: const InputDecoration(labelText: '年利率(%)', suffixText: '%'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: paymentController, decoration: const InputDecoration(labelText: '月供', prefixText: '¥'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                final client = ref.read(apiClientProvider);
                await client.put('/api/families/current/finance/liabilities/${liability['id']}', data: {
                  'current_balance': double.tryParse(balanceController.text),
                  'interest_rate': double.tryParse(rateController.text),
                  'monthly_payment': double.tryParse(paymentController.text),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
