import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_repository.dart';

const String _defaultFamilyId = 'current';

final fireSnapshotProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families/$_defaultFamilyId/finance/fire/snapshot');
  return response.data['data'] ?? {};
});

final netWorthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families/$_defaultFamilyId/finance/fire/net-worth');
  return response.data['data'] ?? {};
});

final allocationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.dio.get('/families/$_defaultFamilyId/finance/fire/allocation');
  return response.data['data'] ?? {};
});

class FireDashboardPage extends ConsumerStatefulWidget {
  const FireDashboardPage({super.key});

  @override
  ConsumerState<FireDashboardPage> createState() => _FireDashboardPageState();
}

class _FireDashboardPageState extends ConsumerState<FireDashboardPage> {
  bool _privacyMode = false;

  @override
  Widget build(BuildContext context) {
    final fireAsync = ref.watch(fireSnapshotProvider);
    final nwAsync = ref.watch(netWorthProvider);
    final allocAsync = ref.watch(allocationProvider);

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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fireSnapshotProvider);
          ref.invalidate(netWorthProvider);
          ref.invalidate(allocationProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Net Worth Card
              nwAsync.when(
                loading: () => _buildLoadingCard(),
                error: (e, _) => _buildErrorCard(e),
                data: (nw) => _buildNetWorthCard(nw),
              ),
              const SizedBox(height: 16),

              // FIRE Metrics
              fireAsync.when(
                loading: () => _buildLoadingCard(),
                error: (e, _) => _buildErrorCard(e),
                data: (fire) => _buildFireMetrics(fire),
              ),
              const SizedBox(height: 24),

              // Asset Allocation
              const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              allocAsync.when(
                loading: () => _buildLoadingCard(),
                error: (e, _) => _buildErrorCard(e),
                data: (alloc) => _buildAllocationChart(alloc),
              ),
              const SizedBox(height: 24),

              // Income/Expense Summary
              _buildIncomeExpenseSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(Map<String, dynamic> nw) {
    final netWorth = (nw['net_worth'] ?? 0).toDouble();
    final liquid = (nw['liquid_net_worth'] ?? 0).toDouble();

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
            _privacyMode ? '****' : '¥${_formatAmount(netWorth)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _privacyMode ? '****' : '流动: ¥${_formatAmount(liquid)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFireMetrics(Map<String, dynamic> fire) {
    final savingsRate = (fire['savings_rate'] ?? 0).toDouble();
    final fiRatio = (fire['fi_ratio'] ?? 0).toDouble();
    final yearsToFire = fire['years_to_fire'] ?? 999;

    return Row(
      children: [
        _buildMetricCard('储蓄率', '${(savingsRate * 100).toStringAsFixed(1)}%', AppColors.profit, Icons.savings),
        const SizedBox(width: 12),
        _buildMetricCard('FIRE进度', '${(fiRatio * 100).toStringAsFixed(1)}%', AppColors.primary, Icons.local_fire_department),
        const SizedBox(width: 12),
        _buildMetricCard('距FIRE', yearsToFire >= 999 ? '—' : '$yearsToFire年', AppColors.warning, Icons.timer),
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

  Widget _buildAllocationChart(Map<String, dynamic> alloc) {
    final entries = alloc.entries.where((e) => e.value > 0).toList();
    final colors = [AppColors.primary, AppColors.housing, AppColors.profit, AppColors.warning, AppColors.shopping, AppColors.entertainment];

    if (entries.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: PieChart(
        PieChartData(
          sections: entries.asMap().entries.map((entry) {
            final percent = (entry.value.value * 100).toDouble();
            return PieChartSectionData(
              value: percent,
              title: '$percent%',
              color: colors[entry.key % colors.length],
              radius: 60,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月收支', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildIEItem('收入', 0, AppColors.profit),
              Container(width: 1, height: 40, color: AppColors.border),
              _buildIEItem('支出', 0, AppColors.loss),
              Container(width: 1, height: 40, color: AppColors.border),
              _buildIEItem('结余', 0, AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          const Text('连接API后显示实际数据', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildIEItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            _privacyMode ? '****' : '¥${_formatAmount(amount)}',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(Object error) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text('加载失败: $error', style: const TextStyle(color: AppColors.loss))),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000000) return '${(amount / 100000000).toStringAsFixed(2)}亿';
    if (amount >= 10000) return '${(amount / 10000).toStringAsFixed(2)}万';
    return amount.toStringAsFixed(2);
  }
}
