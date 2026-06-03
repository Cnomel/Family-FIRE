import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/theme/colors.dart';

class MonthlyBudgetPage extends ConsumerStatefulWidget {
  const MonthlyBudgetPage({super.key});

  @override
  ConsumerState<MonthlyBudgetPage> createState() => _MonthlyBudgetPageState();
}

class _MonthlyBudgetPageState extends ConsumerState<MonthlyBudgetPage> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadData();
  }

  String get _yearMonth => '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/finance/monthly/$_yearMonth');
      setState(() {
        _summary = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _saveRecords() async {
    try {
      final client = ref.read(apiClientProvider);
      final records = <Map<String, dynamic>>[];

      // Collect expense records
      for (final record in (_summary?['expense_records'] ?? [])) {
        if (record['actual_amount'] > 0) {
          records.add({
            'template_id': record['template_id'],
            'template_type': 'expense',
            'actual_amount': record['actual_amount'],
            'notes': record['notes'],
          });
        }
      }

      // Collect income records
      for (final record in (_summary?['income_records'] ?? [])) {
        if (record['actual_amount'] > 0) {
          records.add({
            'template_id': record['template_id'],
            'template_type': 'income',
            'actual_amount': record['actual_amount'],
            'notes': record['notes'],
          });
        }
      }

      await client.post(
        '/api/families/current/finance/monthly/$_yearMonth',
        data: {'records': records},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收支管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/finance/yearly-stats'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/finance/budget-templates'),
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
                  // Month selector
                  _buildMonthSelector(),
                  const SizedBox(height: 16),

                  // Summary card
                  _buildSummaryCard(),
                  const SizedBox(height: 24),

                  // Income section
                  _buildSectionTitle('收入', Icons.arrow_downward, AppColors.profit),
                  const SizedBox(height: 8),
                  _buildIncomeList(),
                  const SizedBox(height: 24),

                  // Expense section
                  _buildSectionTitle('支出', Icons.arrow_upward, AppColors.loss),
                  const SizedBox(height: 8),
                  _buildExpenseList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveRecords,
        icon: const Icon(Icons.save),
        label: const Text('保存'),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              '$_selectedYear年$_selectedMonth月',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalIncome = (_summary?['total_income'] ?? 0).toDouble();
    final totalExpense = (_summary?['total_expense'] ?? 0).toDouble();
    final net = (_summary?['net'] ?? 0).toDouble();
    final savingsRate = (_summary?['savings_rate'] ?? 0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('收入', totalIncome, AppColors.profit),
                _buildSummaryItem('支出', totalExpense, AppColors.loss),
                _buildSummaryItem('结余', net, AppColors.forChange(net)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('储蓄率: ', style: TextStyle(color: Colors.grey)),
                Text(
                  '${savingsRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: savingsRate >= 0 ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          formatCurrency(value),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildIncomeList() {
    final records = (_summary?['income_records'] ?? []) as List;
    
    return Card(
      child: Column(
        children: [
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('暂无收入项')),
            )
          else
            ...records.map((record) => _buildRecordItem(record, AppColors.profit)),
          // 添加临时项按钮
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.grey),
            title: const Text('添加收入项', style: TextStyle(color: Colors.grey)),
            onTap: () => _showAddTempItemDialog('income'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    final records = (_summary?['expense_records'] ?? []) as List;
    
    return Card(
      child: Column(
        children: [
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('暂无支出项')),
            )
          else
            ...records.map((record) => _buildRecordItem(record, AppColors.loss)),
          // 添加临时项按钮
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.grey),
            title: const Text('添加支出项', style: TextStyle(color: Colors.grey)),
            onTap: () => _showAddTempItemDialog('expense'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTempItemDialog(String type) async {
    // 获取所有可用的模板（包括临时项）
    try {
      final client = ref.read(apiClientProvider);
      final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
      final response = await client.get('/api/families/current/finance/$endpoint');
      final allTemplates = response.data['data'] ?? [];
      
      // 获取当前已显示的模板ID
      final currentRecords = type == 'expense' 
          ? (_summary?['expense_records'] ?? []) 
          : (_summary?['income_records'] ?? []);
      final currentIds = currentRecords.map((r) => r['template_id']).toSet();
      
      // 过滤出未显示的模板
      final availableTemplates = allTemplates.where((t) => 
        !currentIds.contains(t['id']) && t['is_active'] == true
      ).toList();

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('添加${type == 'expense' ? '支出' : '收入'}项'),
          content: SizedBox(
            width: double.maxFinite,
            child: availableTemplates.isEmpty
                ? const Center(child: Text('没有可用的项目'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableTemplates.length,
                    itemBuilder: (context, index) {
                      final template = availableTemplates[index];
                      return ListTile(
                        leading: Icon(
                          _getIconData(template['icon']),
                          color: type == 'expense' ? Colors.red : Colors.green,
                        ),
                        title: Text(template['name'] ?? ''),
                        subtitle: template['is_fixed'] == true
                            ? const Text('固定项', style: TextStyle(fontSize: 12))
                            : const Text('临时项', style: TextStyle(fontSize: 12)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addTempItem(template, type);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  void _addTempItem(Map<String, dynamic> template, String type) {
    setState(() {
      final records = type == 'expense'
          ? (_summary?['expense_records'] ?? [])
          : (_summary?['income_records'] ?? []);
      
      records.add({
        'id': '',
        'template_id': template['id'],
        'template_type': type,
        'template_name': template['name'],
        'template_icon': template['icon'],
        'expected_min': template['expected_min'] ?? 0,
        'expected_max': template['expected_max'] ?? 0,
        'actual_amount': 0,
        'notes': null,
        'created_at': null,
      });
      
      if (type == 'expense') {
        _summary?['expense_records'] = records;
      } else {
        _summary?['income_records'] = records;
      }
    });
  }

  Widget _buildRecordItem(Map<String, dynamic> record, Color color) {
    final name = record['template_name'] ?? '';
    final icon = record['template_icon'];
    final actualAmount = (record['actual_amount'] ?? 0).toDouble();
    final expectedMin = (record['expected_min'] ?? 0).toDouble();
    final expectedMax = (record['expected_max'] ?? 0).toDouble();

    return ListTile(
      leading: Icon(_getIconData(icon), color: color),
      title: Text(name),
      subtitle: expectedMin > 0 || expectedMax > 0
          ? Text(
              '预期: ${formatCurrency(expectedMin)} - ${formatCurrency(expectedMax)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      trailing: SizedBox(
        width: 120,
        child: TextField(
          controller: TextEditingController(text: actualAmount > 0 ? actualAmount.toString() : ''),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            prefixText: '¥',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            hintText: '0',
          ),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            setState(() {
              record['actual_amount'] = amount;
            });
          },
        ),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'bolt':
        return Icons.bolt;
      case 'phone':
        return Icons.phone;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'security':
        return Icons.security;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'movie':
        return Icons.movie;
      case 'work':
        return Icons.work;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'trending_up':
        return Icons.trending_up;
      case 'business_center':
        return Icons.business_center;
      default:
        return Icons.category;
    }
  }
}
