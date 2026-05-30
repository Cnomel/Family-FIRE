import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/date.dart';
import '../../shared/theme/colors.dart';

class IncomeExpensePage extends ConsumerStatefulWidget {
  const IncomeExpensePage({super.key});

  @override
  ConsumerState<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends ConsumerState<IncomeExpensePage> {
  List<dynamic> _records = [];
  Map<String, dynamic>? _summary;
  List<dynamic> _expenseCategories = [];
  List<dynamic> _incomeCategories = [];
  bool _isLoading = true;
  String _typeFilter = 'all'; // all, income, expense

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{'page': 1, 'page_size': 50};
      if (_typeFilter != 'all') params['type'] = _typeFilter;

      final results = await Future.wait([
        client.get('/api/families/current/finance/income-expense', queryParams: params),
        client.get('/api/families/current/finance/income-expense/summary'),
        client.get('/api/families/current/finance/categories/expense'),
        client.get('/api/families/current/finance/categories/income'),
      ]);

      setState(() {
        _records = results[0].data['data']?['records'] ?? [];
        _summary = results[1].data['data'];
        _expenseCategories = results[2].data['data'] ?? [];
        _incomeCategories = results[3].data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收支管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/finance/income-expense/stats'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 汇总卡片
                  _buildSummaryCard(),
                  const SizedBox(height: 16),

                  // 筛选
                  _buildFilterChips(),
                  const SizedBox(height: 16),

                  // 记录列表
                  if (_records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('暂无收支记录')),
                      ),
                    )
                  else
                    ..._records.map((record) => _buildRecordCard(record)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalIncome = toDouble(_summary?['total_income']);
    final totalExpense = toDouble(_summary?['total_expense']);
    final net = toDouble(_summary?['net']);
    final savingsRate = toDouble(_summary?['savings_rate']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('收入', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(totalIncome), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.profit)),
                  ],
                ),
                Column(
                  children: [
                    const Text('支出', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(totalExpense), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.loss)),
                  ],
                ),
                Column(
                  children: [
                    const Text('结余', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(net), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.forChange(net))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('储蓄率: ', style: TextStyle(color: Colors.grey)),
                Text(formatPercent(savingsRate), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.profit)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildFilterChip('全部', 'all'),
        const SizedBox(width: 8),
        _buildFilterChip('收入', 'income'),
        const SizedBox(width: 8),
        _buildFilterChip('支出', 'expense'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _typeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _typeFilter = value);
        _loadData();
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final isIncome = record['type'] == 'income';
    final amount = toDouble(record['amount']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isIncome ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? AppColors.profit : AppColors.loss,
          ),
        ),
        title: Text(record['description'] ?? record['category_id'] ?? ''),
        subtitle: Text(record['date'] != null ? formatDateShort(DateTime.parse(record['date'])) : ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? "+" : "-"}${formatCurrency(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isIncome ? AppColors.profit : AppColors.loss,
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (value) {
                if (value == 'edit') _editRecord(record);
                if (value == 'delete') _deleteRecord(record['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord(String id) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/families/current/finance/income-expense/$id');
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }

  void _editRecord(Map<String, dynamic> record) {
    final amountController = TextEditingController(text: (record['amount'] ?? 0).toString());
    final descController = TextEditingController(text: record['description'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑记录'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                final client = ref.read(apiClientProvider);
                await client.put('/api/families/current/finance/income-expense/${record['id']}', data: {
                  'amount': double.tryParse(amountController.text),
                  'description': descController.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('更新失败')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'expense';
    String? categoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final categories = type == 'expense' ? _expenseCategories : _incomeCategories;
          return AlertDialog(
            title: const Text('添加记录'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('支出')),
                      ButtonSegment(value: 'income', label: Text('收入')),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) => setDialogState(() {
                      type = v.first;
                      categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: categoryId,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: categories.map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem(
                          value: cat['id']?.toString(),
                          child: Text(cat['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => categoryId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: '金额', prefixText: '¥'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: '描述'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(apiClientProvider);
                    await client.post('/api/families/current/finance/income-expense', data: {
                      'type': type,
                      'amount': double.tryParse(amountController.text) ?? 0,
                      'description': descController.text.trim(),
                      'date': DateTime.now().toIso8601String(),
                      'category_id': categoryId,
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
          );
        },
      ),
    );
  }
}
