import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Fire'),
        actions: [
          IconButton(
            icon: Icon(_privacy ? Icons.visibility_off : Icons.visibility_outlined),
            onPressed: () => setState(() => _privacy = !_privacy),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Api.instance.clearTokens();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardTab(privacy: _privacy),
          const Center(child: Text('资产 - 开发中', style: TextStyle(fontSize: 18, color: kText2))),
          const Center(child: Text('财务 - 开发中', style: TextStyle(fontSize: 18, color: kText2))),
          const Center(child: Text('设置 - 开发中', style: TextStyle(fontSize: 18, color: kText2))),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: '资产'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), activeIcon: Icon(Icons.trending_up), label: '财务'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  final bool privacy;
  const DashboardTab({super.key, required this.privacy});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic> _netWorth = {};
  Map<String, dynamic> _fireMetrics = {};
  List<dynamic> _transactions = [];
  Map<String, dynamic> _allocation = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Api.instance.get('/families/current/finance/fire/net-worth').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense?page_size=5').catchError((_) => {'data': {'records': []}}),
        Api.instance.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
      ]);

      setState(() {
        _netWorth = results[0]['data'] ?? {};
        _fireMetrics = results[1]['data'] ?? {};
        _transactions = results[2]['data']?['records'] ?? [];
        _allocation = results[3]['data'] ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNetWorthCard(),
          const SizedBox(height: 12),
          _buildFireMetrics(),
          const SizedBox(height: 24),
          _buildAllocationSection(),
          const SizedBox(height: 24),
          _buildTransactionsSection(),
        ],
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
          colors: [kPrimary, kPrimaryDark],
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
            widget.privacy ? '****' : formatAmount(netWorth),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.privacy ? '****' : '流动资产 ${formatAmount(liquid)}',
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
        _buildMetricCard('储蓄率', widget.privacy ? '**%' : formatPercent(savingsRate), kProfit, Icons.savings_outlined),
        const SizedBox(width: 8),
        _buildMetricCard('FIRE进度', widget.privacy ? '**%' : formatPercent(fiRatio), kPrimary, Icons.local_fire_department),
        const SizedBox(width: 8),
        _buildMetricCard('距FIRE', widget.privacy ? '**' : (yearsToFire >= 999 ? '—' : '$yearsToFire年'), kWarn, Icons.timer_outlined),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: kText2, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationSection() {
    if (_allocation.isEmpty) {
      return _buildEmptyCard('暂无资产数据');
    }

    final entries = _allocation.entries.where((e) => (e.value as num) > 0).toList();
    final colors = [kPrimary, kLoss, kWarn, Colors.purple, Colors.teal];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: entries.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              final pct = (e.value.value * 100).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Text(natureLabel(e.value.key)),
                    const Spacer(),
                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: kBorder,
                        color: color,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          _buildEmptyCard('暂无交易记录')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _transactions.map((tx) {
                final isIncome = tx['type'] == 'income';
                final amount = (tx['amount'] ?? 0).toDouble();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isIncome ? kProfit : kLoss).withValues(alpha: 0.1),
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? kProfit : kLoss,
                      size: 20,
                    ),
                  ),
                  title: Text(tx['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(formatDate(tx['date'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12)),
                  trailing: Text(
                    widget.privacy ? '****' : '${isIncome ? '+' : '-'}${formatAmount(amount)}',
                    style: TextStyle(
                      color: isIncome ? kProfit : kLoss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kText2)),
    );
  }
}
