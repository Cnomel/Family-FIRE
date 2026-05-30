import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/theme/colors.dart';
import '../../shared/formatters/currency.dart';

class FireDashboardPage extends ConsumerStatefulWidget {
  const FireDashboardPage({super.key});

  @override
  ConsumerState<FireDashboardPage> createState() => _FireDashboardPageState();
}

class _FireDashboardPageState extends ConsumerState<FireDashboardPage> {
  Map<String, dynamic>? _snapshot;
  Map<String, dynamic>? _netWorth;
  Map<String, dynamic>? _allocation;
  Map<String, dynamic>? _expenses;
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
      final results = await Future.wait([
        client.get('/api/families/current/finance/fire/snapshot'),
        client.get('/api/families/current/finance/fire/net-worth'),
        client.get('/api/families/current/finance/fire/allocation'),
        client.get('/api/families/current/finance/fire/expenses'),
      ]);

      setState(() {
        _snapshot = results[0].data['data'];
        _netWorth = results[1].data['data'];
        _allocation = results[2].data['data'];
        _expenses = results[3].data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Skeleton(height: 200),
          SizedBox(height: 16),
          Skeleton(height: 100),
          SizedBox(height: 16),
          Skeleton(height: 200),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // FIRE Hero卡片
          _buildFireHeroCard(),
          const SizedBox(height: 16),

          // FIRE指标行
          _buildFireMetrics(),
          const SizedBox(height: 16),

          // 净资产趋势图
          _buildNetWorthChart(),
          const SizedBox(height: 16),

          // 资产配置饼图
          _buildAllocationChart(),
          const SizedBox(height: 16),

          // 支出分析
          _buildExpenseSection(),
          const SizedBox(height: 16),

          // 快捷入口
          _buildQuickLinks(),
        ],
      ),
    );
  }

  Widget _buildFireHeroCard() {
    final netWorthData = _snapshot?['net_worth'];
    final netWorth = (netWorthData is Map ? netWorthData['net_worth'] : netWorthData) ?? 0;
    final fireNumber = _snapshot?['fire_number'] ?? 0;
    final fiRatio = _snapshot?['fi_ratio'] ?? 0;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('净资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    AmountText(amount: netWorth, showColor: false, fontSize: 28, fontWeight: FontWeight.bold),
                  ],
                ),
                ProgressRing(
                  progress: fiRatio,
                  size: 80,
                  strokeWidth: 8,
                  color: fiRatio >= 1.0 ? AppColors.profit : Colors.white,
                  backgroundColor: Colors.white24,
                  child: Text(
                    '${(fiRatio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FIRE数字: ${formatCurrency(fireNumber)}', style: const TextStyle(color: Colors.white70)),
                Text(
                  fiRatio >= 1.0 ? '已实现财务独立!' : '距目标: ${formatCurrency(fireNumber - netWorth)}',
                  style: TextStyle(color: fiRatio >= 1.0 ? AppColors.profit : Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFireMetrics() {
    final savingsRate = toDouble(_snapshot?['savings_rate']);
    final yearsToFire = _snapshot?['years_to_fire'];
    final safeWithdrawal = toDouble(_snapshot?['safe_withdrawal_monthly']);

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.savings,
            label: '储蓄率',
            value: formatPercent(savingsRate),
            color: AppColors.profit,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            icon: Icons.timer,
            label: '距FIRE',
            value: yearsToFire != null ? '${(yearsToFire as num).toStringAsFixed(1)}年' : '-',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            icon: Icons.account_balance_wallet,
            label: '月安全提取',
            value: formatCurrency(safeWithdrawal),
            color: const Color(0xFF13C2C2),
          ),
        ),
      ],
    );
  }

  Widget _buildNetWorthChart() {
    final data = _netWorth?['history'] as List<dynamic>? ?? [];
    if (data.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('净资产趋势', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          toDouble(entry.value['value']) / 10000,
                        );
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('单位: 万元', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationChart() {
    final allocation = _allocation as Map<String, dynamic>? ?? {};
    if (allocation.isEmpty) return const SizedBox.shrink();

    final colors = {
      'stocks': const Color(0xFF1677FF),
      'bonds': const Color(0xFF13C2C2),
      'real_estate': const Color(0xFFFA8C16),
      'crypto': const Color(0xFF722ED1),
      'cash': const Color(0xFF52C41A),
      'other': const Color(0xFF999999),
    };
    final labels = {
      'stocks': '股票',
      'bonds': '债券',
      'real_estate': '房产',
      'crypto': '加密货币',
      'cash': '现金',
      'other': '其他',
    };

    final totalAllocation = allocation.values.fold<double>(0, (a, b) => a + toDouble(b));
    final sections = allocation.entries.where((e) => toDouble(e.value) > 0).map((entry) {
      final pct = totalAllocation > 0 ? toDouble(entry.value) / totalAllocation * 100 : 0.0;
      return PieChartSectionData(
        value: toDouble(entry.value),
        title: '${pct.toStringAsFixed(0)}%',
        color: colors[entry.key] ?? Colors.grey,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('资产配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: allocation.entries.where((e) => (e.value as num) > 0).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[entry.key] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(labels[entry.key] ?? entry.key, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection() {
    final monthlyExpense = toDouble(_expenses?['monthly_expense'] ?? _expenses?['monthly_total']);
    final categories = (_expenses?['by_category'] as List<dynamic>?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('支出分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () async {
                    await context.push('/finance/income-expense/stats');
                    if (mounted) _loadData();
                  },
                  child: const Text('查看详情'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '月支出: ${formatCurrency(monthlyExpense)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...categories.take(5).map((cat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(cat['name'] ?? '', style: const TextStyle(fontSize: 13))),
                        Text(formatCurrency(toDouble(cat['amount'])),
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildLinkTile(Icons.account_balance, '负债管理', '/finance/liabilities'),
            _buildLinkTile(Icons.receipt_long, '收支管理', '/finance/income-expense'),
            _buildLinkTile(Icons.pie_chart, '投资组合', '/finance/portfolio'),
            _buildLinkTile(Icons.trending_up, '被动收入', '/finance/passive-income'),
            _buildLinkTile(Icons.show_chart, '蒙特卡洛模拟', '/finance/monte-carlo'),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String title, String path) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        await context.push(path);
        if (mounted) _loadData();
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
