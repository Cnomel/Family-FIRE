import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/formatters.dart';
import '../../core/api_service.dart';
import '../../main.dart';
import '../assets/assets_page.dart';
import '../finance/finance_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _privacyMode = false;
  final _api = ApiService();

  // Dashboard data
  Map<String, dynamic> _netWorth = {};
  Map<String, dynamic> _fireMetrics = {};
  List<dynamic> _recentTransactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('/families/current/finance/fire/net-worth').catchError((_) => {'data': {}}),
        _api.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        _api.get('/families/current/finance/income-expense?page_size=5').catchError((_) => {'data': {'records': []}}),
      ]);

      setState(() {
        _netWorth = results[0]['data'] ?? {};
        _fireMetrics = results[1]['data'] ?? {};
        _recentTransactions = results[2]['data']?['records'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

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
          const AssetsPage(),
          const FinancePage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNetWorthCard(),
            const SizedBox(height: 16),
            _buildFireMetrics(),
            const SizedBox(height: 24),
            const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard() {
    final netWorth = (_netWorth['net_worth'] ?? 0).toDouble();
    final liquid = (_netWorth['liquid_net_worth'] ?? 0).toDouble();

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
            _privacyMode ? '****' : formatAmount(netWorth),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _privacyMode ? '****' : '流动: ${formatAmount(liquid)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFireMetrics() {
    final savingsRate = (_fireMetrics['savings_rate'] ?? 0).toDouble();
    final fiRatio = (_fireMetrics['fi_ratio'] ?? 0).toDouble();
    final yearsToFire = _fireMetrics['years_to_fire'] ?? 999;

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
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_recentTransactions.isEmpty) {
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
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _recentTransactions.map((tx) {
          final isIncome = tx['type'] == 'income';
          final amount = (tx['amount'] ?? 0).toDouble();
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (isIncome ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppColors.profit : AppColors.loss,
                size: 20,
              ),
            ),
            title: Text(tx['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(formatDate(tx['date'] ?? ''), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: Text(
              _privacyMode ? '****' : '${isIncome ? '+' : '-'}${formatAmount(amount)}',
              style: TextStyle(
                color: isIncome ? AppColors.profit : AppColors.loss,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
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
              authState.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
