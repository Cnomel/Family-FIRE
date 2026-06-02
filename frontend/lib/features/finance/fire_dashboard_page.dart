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
    final client = ref.read(apiClientProvider);

    // 独立加载，单个失败不影响其他
    Map<String, dynamic>? snapshot;
    Map<String, dynamic>? netWorth;
    Map<String, dynamic>? allocation;
    Map<String, dynamic>? expenses;

    try { snapshot = (await client.get('/api/families/current/finance/fire/snapshot')).data['data']; } catch (_) {}
    try { netWorth = (await client.get('/api/families/current/finance/fire/net-worth')).data['data']; } catch (_) {}
    try { allocation = (await client.get('/api/families/current/finance/fire/allocation')).data['data']; } catch (_) {}
    try { expenses = (await client.get('/api/families/current/finance/fire/expenses')).data['data']; } catch (_) {}

    if (mounted) {
      setState(() {
        _snapshot = snapshot;
        _netWorth = netWorth;
        _allocation = allocation;
        _expenses = expenses;
        _isLoading = false;
      });
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
    final financialNwData = _snapshot?['financial_net_worth'];
    final netWorth = (financialNwData is Map ? financialNwData['net_worth'] : financialNwData) ?? 0;
    final fireNumber = _snapshot?['fire_number'] ?? 0;
    final fiRatio = _snapshot?['fi_ratio'] ?? 0;
    final annualExpense = _snapshot?['annual_expense'] ?? 0;
    final withdrawalRate = _snapshot?['withdrawal_rate'] ?? 0.04;

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
            const SizedBox(height: 16),
            // FIRE 数字说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      const Text(
                        '什么是 FIRE 数字？',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FIRE数字 = 年支出 ÷ 提取率\n'
                    '${formatCurrency(annualExpense)} ÷ ${(withdrawalRate * 100).toStringAsFixed(0)}% = ${formatCurrency(fireNumber)}\n\n'
                    '当你的资产达到这个数字时，每年提取 ${(withdrawalRate * 100).toStringAsFixed(0)}% 作为生活费，理论上本金可以永续使用（4%法则）。',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.savings,
                label: '储蓄率',
                value: formatPercent(savingsRate),
                color: AppColors.profit,
                tooltip: '储蓄率 = (收入 - 支出) / 收入\n越高说明攒钱越快',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                icon: Icons.timer,
                label: '距FIRE',
                value: yearsToFire != null ? '${(yearsToFire as num).toStringAsFixed(1)}年' : '-',
                color: AppColors.primary,
                tooltip: '按当前储蓄率和7%年化收益\n预估达到FIRE数字的年数',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                icon: Icons.account_balance_wallet,
                label: '月安全提取',
                value: formatCurrency(safeWithdrawal),
                color: const Color(0xFF13C2C2),
                tooltip: '净资产 × 4% ÷ 12\n这是你每月可安全提取的金额',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 指标说明
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(64),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FIRE = 财务独立，提前退休。核心是攒够年支出25倍的资产，然后每年提取4%生活。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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
    final allocation = _allocation ?? {};

    // 没有金融资产时显示引导
    if (allocation.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('资产配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('暂无金融资产', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('添加股票、基金等金融资产后显示配置', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final colors = {
      'stock': const Color(0xFF1677FF),
      'etf': const Color(0xFF13C2C2),
      'fund': const Color(0xFFFA8C16),
      'bond': const Color(0xFF722ED1),
      'money_market': const Color(0xFF52C41A),
      'cd': const Color(0xFFEB2F96),
      'crypto': const Color(0xFFFF4D4F),
      'other': const Color(0xFF999999),
    };
    final labels = {
      'stock': '股票',
      'etf': '场内基金',
      'fund': '场外基金',
      'bond': '国债',
      'money_market': '货币基金',
      'cd': '定期存款',
      'crypto': '加密货币',
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
  final String? tooltip;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (tooltip != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: tooltip!,
                    child: Icon(Icons.help_outline, size: 12, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
