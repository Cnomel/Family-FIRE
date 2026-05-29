import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../shared/formatters/currency.dart';

class IncomeExpensePage extends StatefulWidget {
  const IncomeExpensePage({super.key});

  @override
  State<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends State<IncomeExpensePage> {
  String _selectedPeriod = 'month';

  final List<Map<String, dynamic>> _transactions = [
    {'type': 'income', 'category': '工资薪金', 'amount': 15000, 'date': '05-01', 'icon': Icons.work},
    {'type': 'income', 'category': '奖金', 'amount': 5000, 'date': '05-01', 'icon': Icons.card_giftcard},
    {'type': 'income', 'category': '投资收益', 'amount': 2345, 'date': '05-15', 'icon': Icons.trending_up},
    {'type': 'expense', 'category': '餐饮美食', 'amount': 3500, 'date': '05-15', 'icon': Icons.restaurant},
    {'type': 'expense', 'category': '交通出行', 'amount': 800, 'date': '05-10', 'icon': Icons.directions_car},
    {'type': 'expense', 'category': '购物消费', 'amount': 2200, 'date': '05-08', 'icon': Icons.shopping_bag},
    {'type': 'expense', 'category': '居住生活', 'amount': 3500, 'date': '05-01', 'icon': Icons.home},
    {'type': 'expense', 'category': '休闲娱乐', 'amount': 1000, 'date': '05-12', 'icon': Icons.movie},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收支管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddRecord),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildCategoryChart(),
            const SizedBox(height: 24),
            _buildTransactionList(),
          ],
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
        onTap: () => setState(() => _selectedPeriod = value),
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildSummaryItem('收入', 22345, AppColors.profit),
          Container(width: 1, height: 50, color: AppColors.border),
          _buildSummaryItem('支出', 11000, AppColors.loss),
          Container(width: 1, height: 50, color: AppColors.border),
          _buildSummaryItem('结余', 11345, AppColors.primary),
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
          Text(CurrencyFormatter.format(amount), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('支出分类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const labels = ['餐饮', '居住', '购物', '交通', '娱乐'];
                      return Text(labels[value.toInt()], style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 3500, color: AppColors.food, width: 24, borderRadius: BorderRadius.circular(4))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 3500, color: AppColors.housing, width: 24, borderRadius: BorderRadius.circular(4))]),
                BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 2200, color: AppColors.shopping, width: 24, borderRadius: BorderRadius.circular(4))]),
                BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 800, color: AppColors.transport, width: 24, borderRadius: BorderRadius.circular(4))]),
                BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 1000, color: AppColors.entertainment, width: 24, borderRadius: BorderRadius.circular(4))]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('交易记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._transactions.map((t) => _buildTransactionItem(t)),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isIncome = transaction['type'] == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isIncome ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
            child: Icon(transaction['icon'] as IconData, color: isIncome ? AppColors.profit : AppColors.loss, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction['category'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(transaction['date'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction['amount'] as double)}',
            style: TextStyle(
              color: isIncome ? AppColors.profit : AppColors.loss,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRecord() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_downward, color: AppColors.profit),
                    label: const Text('收入', style: TextStyle(color: AppColors.profit)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_upward, color: AppColors.loss),
                    label: const Text('支出', style: TextStyle(color: AppColors.loss)),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: '金额', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('选择分类', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryTag('餐饮', Icons.restaurant),
                  _buildCategoryTag('交通', Icons.directions_car),
                  _buildCategoryTag('购物', Icons.shopping_bag),
                  _buildCategoryTag('居住', Icons.home),
                  _buildCategoryTag('娱乐', Icons.movie),
                  _buildCategoryTag('医疗', Icons.local_hospital),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: '备注', prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTag(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {},
    );
  }
}
