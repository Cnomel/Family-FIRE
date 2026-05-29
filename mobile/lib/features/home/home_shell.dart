import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/auth/auth_repository.dart';
import '../assets/asset_list_page.dart';
import '../finance/fire_dashboard_page.dart';
import '../notifications/notification_list_page.dart';
import '../settings/settings_page.dart';

// Providers for dashboard data
final dashboardNetWorthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/current/finance/fire/net-worth');
    return response.data['data'] ?? {};
  } catch (e) {
    return {'total_assets': 0, 'net_worth': 0, 'liquid_net_worth': 0};
  }
});

final dashboardFireProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/current/finance/fire/snapshot');
    return response.data['data'] ?? {};
  } catch (e) {
    return {'savings_rate': 0, 'fi_ratio': 0, 'years_to_fire': 999};
  }
});

final dashboardTransactionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/current/finance/income-expense?page_size=5');
    return response.data['data']['records'] ?? [];
  } catch (e) {
    return [];
  }
});

final dashboardAllocationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.dio.get('/families/current/finance/fire/allocation');
    return response.data['data'] ?? {};
  } catch (e) {
    return {};
  }
});

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _privacyMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Fire'),
        actions: [
          IconButton(
            icon: Icon(_privacyMode ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _privacyMode = !_privacyMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          const AssetListPage(),
          const FireDashboardPage(),
          const NotificationListPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '资产'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '财务'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '通知'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final nwAsync = ref.watch(dashboardNetWorthProvider);
    final fireAsync = ref.watch(dashboardFireProvider);
    final txAsync = ref.watch(dashboardTransactionsProvider);
    final allocAsync = ref.watch(dashboardAllocationProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardNetWorthProvider);
        ref.invalidate(dashboardFireProvider);
        ref.invalidate(dashboardTransactionsProvider);
        ref.invalidate(dashboardAllocationProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net Worth Hero Card
            nwAsync.when(
              loading: () => _buildLoadingCard(height: 140),
              error: (e, _) => _buildErrorCard(e),
              data: (nw) => _buildNetWorthCard(nw),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            fireAsync.when(
              loading: () => _buildLoadingCard(height: 80),
              error: (e, _) => _buildErrorCard(e),
              data: (fire) => _buildQuickStats(fire),
            ),
            const SizedBox(height: 24),

            // Asset Allocation
            const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            allocAsync.when(
              loading: () => _buildLoadingCard(height: 60),
              error: (e, _) => _buildErrorCard(e),
              data: (alloc) => _buildAllocationSection(alloc),
            ),
            const SizedBox(height: 24),

            // Recent Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            txAsync.when(
              loading: () => _buildLoadingCard(height: 200),
              error: (e, _) => _buildErrorCard(e),
              data: (txs) => _buildTransactionList(txs),
            ),
          ],
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
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
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

  Widget _buildQuickStats(Map<String, dynamic> fire) {
    final savingsRate = (fire['savings_rate'] ?? 0).toDouble();
    final fiRatio = (fire['fi_ratio'] ?? 0).toDouble();
    final yearsToFire = fire['years_to_fire'] ?? 999;

    return Row(
      children: [
        _buildStatCard('储蓄率', _privacyMode ? '**%' : '${(savingsRate * 100).toStringAsFixed(1)}%', AppColors.profit),
        const SizedBox(width: 12),
        _buildStatCard('FIRE进度', _privacyMode ? '**%' : '${(fiRatio * 100).toStringAsFixed(1)}%', AppColors.primary),
        const SizedBox(width: 12),
        _buildStatCard('距FIRE', _privacyMode ? '**' : (yearsToFire >= 999 ? '—' : '$yearsToFire年'), AppColors.warning),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationSection(Map<String, dynamic> alloc) {
    if (alloc.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('暂无资产数据', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final entries = alloc.entries.where((e) => e.value > 0).toList();
    final colors = [AppColors.primary, AppColors.housing, AppColors.profit, AppColors.warning, AppColors.shopping];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final color = colors[entry.key % colors.length];
          final percent = (entry.value.value * 100).toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(_natureLabel(entry.value.key), style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text('${percent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionList(List<dynamic> txs) {
    if (txs.isEmpty) {
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
              Text('暂无交易记录', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text('去财务页面记录收支', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
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
        children: txs.map((tx) => _buildTransactionItem(tx)).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final amount = (tx['amount'] ?? 0).toDouble();
    final description = tx['description'] ?? '';
    final date = tx['date'] ?? '';

    return ListTile(
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
        _privacyMode ? '****' : '${isIncome ? '+' : '-'}¥${_formatAmount(amount)}',
        style: TextStyle(
          color: isIncome ? AppColors.profit : AppColors.loss,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

  String _natureLabel(String nature) {
    switch (nature) {
      case 'tangible': return '实物资产';
      case 'financial': return '金融资产';
      case 'digital': return '数字资产';
      case 'service': return '服务订阅';
      case 'intangible': return '保险';
      default: return nature;
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
