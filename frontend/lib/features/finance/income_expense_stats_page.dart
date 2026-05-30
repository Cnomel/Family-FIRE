import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../shared/theme/colors.dart';
import '../../shared/formatters/currency.dart';

class IncomeExpenseStatsPage extends ConsumerStatefulWidget {
  const IncomeExpenseStatsPage({super.key});

  @override
  ConsumerState<IncomeExpenseStatsPage> createState() => _IncomeExpenseStatsPageState();
}

class _IncomeExpenseStatsPageState extends ConsumerState<IncomeExpenseStatsPage> {
  Map<String, dynamic>? _summary;
  List<dynamic> _byCategory = [];
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
      final response = await client.get('/api/families/current/finance/income-expense/summary');
      final data = response.data['data'];
      setState(() {
        _summary = data;
        _byCategory = data['by_category'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalIncome = toDouble(_summary?['total_income']);
    final totalExpense = toDouble(_summary?['total_expense']);

    return Scaffold(
      appBar: AppBar(title: const Text('收支统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 收支柱状图
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('收支对比', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [
                            BarChartRodData(
                              toY: totalIncome / 10000,
                              color: AppColors.profit,
                              width: 40,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ]),
                          BarChartGroupData(x: 1, barRods: [
                            BarChartRodData(
                              toY: totalExpense / 10000,
                              color: AppColors.loss,
                              width: 40,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ]),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return const Text('收入', style: TextStyle(fontSize: 12));
                                  case 1:
                                    return const Text('支出', style: TextStyle(fontSize: 12));
                                  default:
                                    return const SizedBox.shrink();
                                }
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toStringAsFixed(0)}万', style: const TextStyle(fontSize: 11));
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.2),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 分类统计
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('分类统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_byCategory.isEmpty)
                    const Center(child: Text('暂无数据'))
                  else
                    ..._byCategory.map((cat) {
                      final amount = toDouble(cat['amount']);
                      final total = cat['type'] == 'income' ? totalIncome : totalExpense;
                      final percent = total > 0 ? amount / total * 100 : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat['name'] ?? ''),
                                Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (percent / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              color: cat['type'] == 'income' ? AppColors.profit : AppColors.loss,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
