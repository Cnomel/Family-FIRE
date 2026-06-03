import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/theme/colors.dart';

class YearlyStatsPage extends ConsumerStatefulWidget {
  const YearlyStatsPage({super.key});

  @override
  ConsumerState<YearlyStatsPage> createState() => _YearlyStatsPageState();
}

class _YearlyStatsPageState extends ConsumerState<YearlyStatsPage> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get(
        '/api/families/current/finance/yearly/$_selectedYear/summary',
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('年度统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _selectedYear--);
              _loadData();
            },
          ),
          Center(
            child: Text(
              '$_selectedYear',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _selectedYear++);
              _loadData();
            },
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
                  // Yearly summary
                  _buildYearlySummary(),
                  const SizedBox(height: 24),

                  // Monthly trend chart
                  _buildSectionTitle('月度趋势'),
                  const SizedBox(height: 8),
                  _buildMonthlyTrendChart(),
                  const SizedBox(height: 24),

                  // Monthly detail table
                  _buildSectionTitle('月度明细'),
                  const SizedBox(height: 8),
                  _buildMonthlyDetailTable(),
                  const SizedBox(height: 24),

                  // Category breakdown
                  _buildSectionTitle('分类统计'),
                  const SizedBox(height: 8),
                  _buildCategoryBreakdown(),
                ],
              ),
            ),
    );
  }

  Widget _buildYearlySummary() {
    final totalIncome = (_summary?['total_income'] ?? 0).toDouble();
    final totalExpense = (_summary?['total_expense'] ?? 0).toDouble();
    final totalNet = (_summary?['total_net'] ?? 0).toDouble();
    final avgSavingsRate = (_summary?['average_savings_rate'] ?? 0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '年度汇总',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('总收入', totalIncome, AppColors.profit),
                _buildSummaryItem('总支出', totalExpense, AppColors.loss),
                _buildSummaryItem('总结余', totalNet, AppColors.forChange(totalNet)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('平均储蓄率: ', style: TextStyle(color: Colors.grey)),
                Text(
                  '${avgSavingsRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: avgSavingsRate >= 0 ? AppColors.profit : AppColors.loss,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildMonthlyTrendChart() {
    final monthlyData = (_summary?['monthly_data'] ?? []) as List;
    if (monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('暂无数据')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final month = value.toInt() + 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$month月',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Income line
                LineChartBarData(
                  spots: monthlyData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (entry.value['income'] ?? 0).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: AppColors.profit,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                // Expense line
                LineChartBarData(
                  spots: monthlyData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (entry.value['expense'] ?? 0).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: AppColors.loss,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                // Net line
                LineChartBarData(
                  spots: monthlyData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (entry.value['net'] ?? 0).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyDetailTable() {
    final monthlyData = (_summary?['monthly_data'] ?? []) as List;
    if (monthlyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('暂无数据')),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('月份')),
            DataColumn(label: Text('收入'), numeric: true),
            DataColumn(label: Text('支出'), numeric: true),
            DataColumn(label: Text('结余'), numeric: true),
          ],
          rows: monthlyData.map((data) {
            final month = data['month'] ?? 0;
            final income = (data['income'] ?? 0).toDouble();
            final expense = (data['expense'] ?? 0).toDouble();
            final net = (data['net'] ?? 0).toDouble();

            return DataRow(cells: [
              DataCell(Text('$month月')),
              DataCell(Text(
                formatCurrency(income),
                style: TextStyle(color: AppColors.profit),
              )),
              DataCell(Text(
                formatCurrency(expense),
                style: TextStyle(color: AppColors.loss),
              )),
              DataCell(Text(
                formatCurrency(net),
                style: TextStyle(color: AppColors.forChange(net)),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = (_summary?['by_category'] ?? []) as List;
    if (categories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('暂无数据')),
        ),
      );
    }

    // Separate income and expense categories
    final incomeCategories = categories.where((c) => c['type'] == 'income').toList();
    final expenseCategories = categories.where((c) => c['type'] == 'expense').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expenseCategories.isNotEmpty) ...[
              const Text(
                '支出分类',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ...expenseCategories.map((cat) => _buildCategoryItem(cat, Colors.red)),
              const SizedBox(height: 16),
            ],
            if (incomeCategories.isNotEmpty) ...[
              const Text(
                '收入分类',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
              ),
              const SizedBox(height: 8),
              ...incomeCategories.map((cat) => _buildCategoryItem(cat, Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category, Color color) {
    final name = category['name'] ?? '';
    final total = (category['total'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(
            formatCurrency(total),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
