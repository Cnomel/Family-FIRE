import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../shared/formatters/currency.dart';

class FireDashboardPage extends StatefulWidget {
  const FireDashboardPage({super.key});

  @override
  State<FireDashboardPage> createState() => _FireDashboardPageState();
}

class _FireDashboardPageState extends State<FireDashboardPage> {
  bool _privacyMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIRE 仪表盘'),
        actions: [
          IconButton(
            icon: Icon(_privacyMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _privacyMode = !_privacyMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNetWorthCard(),
            const SizedBox(height: 16),
            _buildFireMetrics(),
            const SizedBox(height: 24),
            _buildAssetAllocation(),
            const SizedBox(height: 24),
            _buildIncomeExpenseSummary(),
            const SizedBox(height: 24),
            _buildMonteCarloChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('净资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            _privacyMode ? '****' : '¥1,234,567.89',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('+¥12,345.67 本月', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('+1.01%', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFireMetrics() {
    return Row(
      children: [
        _buildMetricCard('储蓄率', '63.3%', AppColors.profit, Icons.savings),
        const SizedBox(width: 12),
        _buildMetricCard('FIRE进度', '24.7%', AppColors.primary, Icons.local_fire_department),
        const SizedBox(width: 12),
        _buildMetricCard('距FIRE', '12年', AppColors.warning, Icons.timer),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetAllocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(value: 45, title: '45%', color: AppColors.primary, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                PieChartSectionData(value: 35, title: '35%', color: AppColors.housing, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                PieChartSectionData(value: 20, title: '20%', color: AppColors.profit, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAllocationLegend('金融资产', 45, AppColors.primary),
        _buildAllocationLegend('固定资产', 35, AppColors.housing),
        _buildAllocationLegend('流动资金', 20, AppColors.profit),
      ],
    );
  }

  Widget _buildAllocationLegend(String label, int percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('本月收支', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildIncomeExpenseItem('收入', 30000, AppColors.profit)),
                  Container(width: 1, height: 40, color: AppColors.border),
                  Expanded(child: _buildIncomeExpenseItem('支出', 11000, AppColors.loss)),
                  Container(width: 1, height: 40, color: AppColors.border),
                  Expanded(child: _buildIncomeExpenseItem('结余', 19000, AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeExpenseItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          _privacyMode ? '****' : CurrencyFormatter.format(amount),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMonteCarloChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FIRE 蒙特卡洛模拟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 100), FlSpot(1, 120), FlSpot(2, 150), FlSpot(3, 180),
                    FlSpot(4, 220), FlSpot(5, 280), FlSpot(6, 350), FlSpot(7, 420),
                  ],
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 100), FlSpot(1, 110), FlSpot(2, 130), FlSpot(3, 140),
                    FlSpot(4, 160), FlSpot(5, 190), FlSpot(6, 230), FlSpot(7, 280),
                  ],
                  isCurved: true,
                  color: AppColors.loss,
                  barWidth: 1,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 100), FlSpot(1, 140), FlSpot(2, 200), FlSpot(3, 260),
                    FlSpot(4, 340), FlSpot(5, 450), FlSpot(6, 580), FlSpot(7, 700),
                  ],
                  isCurved: true,
                  color: AppColors.profit,
                  barWidth: 1,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('中位数', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            Text('悲观', style: TextStyle(color: AppColors.loss, fontSize: 12)),
            Text('乐观', style: TextStyle(color: AppColors.profit, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
