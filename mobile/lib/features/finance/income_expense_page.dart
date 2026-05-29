import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';

const String _defaultFamilyId = 'current';

// Providers
final incomeExpenseProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/$_defaultFamilyId/finance/income-expense');
    return response.data['data']['records'] ?? [];
  } catch (e) {
    return [];
  }
});

final incomeExpenseSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/$_defaultFamilyId/finance/income-expense/summary');
    return response.data['data'] ?? {};
  } catch (e) {
    return {'total_income': 0, 'total_expense': 0, 'net': 0, 'savings_rate': 0};
  }
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/$_defaultFamilyId/finance/categories/expense');
    return response.data['data'] ?? [];
  } catch (e) {
    return [];
  }
});

class IncomeExpensePage extends ConsumerStatefulWidget {
  const IncomeExpensePage({super.key});

  @override
  ConsumerState<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends ConsumerState<IncomeExpensePage> {
  String _selectedPeriod = 'month';

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(incomeExpenseProvider);
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收支管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddRecord(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(incomeExpenseProvider);
          ref.invalidate(incomeExpenseSummaryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              summaryAsync.when(
                loading: () => _buildLoadingCard(),
                error: (e, _) => _buildErrorCard(e),
                data: (summary) => _buildSummaryCard(summary),
              ),
              const SizedBox(height: 24),
              const Text('支出分类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildCategoryChart(),
              const SizedBox(height: 24),
              const Text('交易记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              recordsAsync.when(
                loading: () => _buildLoadingCard(height: 200),
                error: (e, _) => _buildErrorCard(e),
                data: (records) => _buildRecordsList(records),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          _buildPeriodButton('周', 'week'),
          _buildPeriodButton('月', 'month'),
          _buildPeriodButton('年', 'year'),
          _buildPeriodButton('全部', 'all'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          // TODO: Filter by period when API supports it
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          )),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final income = (summary['total_income'] ?? 0).toDouble();
    final expense = (summary['total_expense'] ?? 0).toDouble();
    final net = (summary['net'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildSummaryItem('收入', income, AppColors.profit),
          Container(width: 1, height: 50, color: AppColors.border),
          _buildSummaryItem('支出', expense, AppColors.loss),
          Container(width: 1, height: 50, color: AppColors.border),
          _buildSummaryItem('结余', net, AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '¥${_formatAmount(amount)}',
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: const Center(
        child: Text('选择时间范围后显示分类统计', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildRecordsList(List<dynamic> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 48, color: AppColors.textTertiary),
              SizedBox(height: 8),
              Text('暂无收支记录', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text('点击右上角 + 添加记录', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: records.map((record) => _buildRecordItem(record)).toList(),
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    final isIncome = record['type'] == 'income';
    final amount = (record['amount'] ?? 0).toDouble();
    final description = record['description'] ?? '';
    final date = record['date'] ?? '';

    return Dismissible(
      key: Key(record['id'] ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.loss,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条记录吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteRecord(record['id']),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isIncome ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? AppColors.profit : AppColors.loss,
            size: 20,
          ),
        ),
        title: Text(description, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_formatDate(date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Text(
          '${isIncome ? '+' : '-'}¥${_formatAmount(amount)}',
          style: TextStyle(
            color: isIncome ? AppColors.profit : AppColors.loss,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _showAddRecord(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'expense';
    String? selectedCategoryId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                // Type selector
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => setSheetState(() => selectedType = 'income'),
                      icon: Icon(Icons.arrow_downward, color: selectedType == 'income' ? AppColors.profit : AppColors.textSecondary),
                      label: Text('收入', style: TextStyle(color: selectedType == 'income' ? AppColors.profit : AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'income' ? AppColors.profit.withValues(alpha: 0.1) : null,
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => setSheetState(() => selectedType = 'expense'),
                      icon: Icon(Icons.arrow_upward, color: selectedType == 'expense' ? AppColors.loss : AppColors.textSecondary),
                      label: Text('支出', style: TextStyle(color: selectedType == 'expense' ? AppColors.loss : AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'expense' ? AppColors.loss.withValues(alpha: 0.1) : null,
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: '金额', prefixIcon: Icon(Icons.attach_money)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '描述', prefixIcon: Icon(Icons.note)),
                ),
                const SizedBox(height: 16),
                const Text('选择分类', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryTag('餐饮', Icons.restaurant, selectedCategoryId == 'food', () => setSheetState(() => selectedCategoryId = 'food')),
                    _buildCategoryTag('交通', Icons.directions_car, selectedCategoryId == 'transport', () => setSheetState(() => selectedCategoryId = 'transport')),
                    _buildCategoryTag('购物', Icons.shopping_bag, selectedCategoryId == 'shopping', () => setSheetState(() => selectedCategoryId = 'shopping')),
                    _buildCategoryTag('居住', Icons.home, selectedCategoryId == 'housing', () => setSheetState(() => selectedCategoryId = 'housing')),
                    _buildCategoryTag('娱乐', Icons.movie, selectedCategoryId == 'entertainment', () => setSheetState(() => selectedCategoryId = 'entertainment')),
                    _buildCategoryTag('医疗', Icons.local_hospital, selectedCategoryId == 'healthcare', () => setSheetState(() => selectedCategoryId = 'healthcare')),
                    _buildCategoryTag('教育', Icons.school, selectedCategoryId == 'education', () => setSheetState(() => selectedCategoryId = 'education')),
                    _buildCategoryTag('其他', Icons.more_horiz, selectedCategoryId == 'other', () => setSheetState(() => selectedCategoryId = 'other')),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isEmpty || descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写金额和描述'), backgroundColor: AppColors.loss),
                      );
                      return;
                    }
                    await _addRecord(
                      type: selectedType,
                      amount: double.tryParse(amountController.text) ?? 0,
                      description: descController.text,
                      categoryId: selectedCategoryId,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTag(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
      label: Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary)),
      backgroundColor: isSelected ? AppColors.primaryLight : null,
      onPressed: onTap,
    );
  }

  Future<void> _addRecord({
    required String type,
    required double amount,
    required String description,
    String? categoryId,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post('/families/$_defaultFamilyId/finance/income-expense', data: {
        'type': type,
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'category_id': categoryId,
      });
      ref.invalidate(incomeExpenseProvider);
      ref.invalidate(incomeExpenseSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录成功'), backgroundColor: AppColors.profit),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  Future<void> _deleteRecord(String? recordId) async {
    if (recordId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.delete('/families/$_defaultFamilyId/finance/income-expense/$recordId');
      ref.invalidate(incomeExpenseProvider);
      ref.invalidate(incomeExpenseSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.loss),
        );
      }
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) return '${(amount / 100000000).toStringAsFixed(2)}亿';
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(2)}万';
    return amount.toStringAsFixed(2);
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return '今天';
      if (diff.inDays == 1) return '昨天';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${date.month}月${date.day}日';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildLoadingCard({double height = 100}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text('加载失败: $error', style: const TextStyle(color: AppColors.loss))),
    );
  }
}
