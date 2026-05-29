import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../services/api.dart';
import '../../models/models.dart';
import '../assets/assets_page.dart';
import '../finance/finance_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
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
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardPage(privacy: _privacy),
          const AssetsPage(),
          const FinancePage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
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

/// 首页仪表盘
class DashboardPage extends StatefulWidget {
  final bool privacy;
  const DashboardPage({super.key, required this.privacy});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  FireSnapshot? _fire;
  List<Transaction> _transactions = [];
  Map<String, dynamic> _allocation = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Api.instance.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense?page_size=5').catchError((_) => {'data': {'records': []}}),
        Api.instance.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
      ]);
      setState(() {
        _fire = FireSnapshot.fromJson(results[0]['data'] ?? {});
        _transactions = (results[1]['data']?['records'] as List? ?? []).map((e) => Transaction.fromJson(e)).toList();
        _allocation = results[2]['data'] ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 净资产卡片
          _buildNetWorthCard(),
          const SizedBox(height: 12),
          // FIRE指标
          _buildFireMetrics(),
          const SizedBox(height: 24),
          // 资产配置
          _sectionTitle('资产配置'),
          const SizedBox(height: 8),
          _buildAllocation(),
          const SizedBox(height: 24),
          // 最近交易
          _sectionTitle('最近交易'),
          const SizedBox(height: 8),
          _buildTransactions(),
        ],
      ),
    );
  }

  Widget _buildNetWorthCard() {
    final nw = _fire?.netWorth ?? 0;
    final liquid = _fire?.liquidNetWorth ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kPrimaryColor, kPrimaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('净资产', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            widget.privacy ? '****' : formatAmount(nw),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
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
    final sr = _fire?.savingsRate ?? 0;
    final fi = _fire?.fiRatio ?? 0;
    final yrs = _fire?.yearsToFire ?? 999;

    return Row(
      children: [
        _metricCard('储蓄率', widget.privacy ? '**%' : formatPercent(sr), kProfitColor, Icons.savings_outlined),
        const SizedBox(width: 8),
        _metricCard('FIRE进度', widget.privacy ? '**%' : formatPercent(fi), kPrimaryColor, Icons.local_fire_department),
        const SizedBox(width: 8),
        _metricCard('距FIRE', widget.privacy ? '**' : (yrs >= 999 ? '—' : '$yrs年'), kWarningColor, Icons.timer_outlined),
      ],
    );
  }

  Widget _metricCard(String label, String value, Color color, IconData icon) {
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
            Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocation() {
    if (_allocation.isEmpty) {
      return _emptyCard('暂无资产数据');
    }

    final entries = _allocation.entries.where((e) => (e.value as num) > 0).toList();
    final colors = [kPrimaryColor, kLossColor, kWarningColor, Colors.purple, Colors.teal];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
                Text(natureLabel(e.value.key), style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: kBorderColor,
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
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return _emptyCard('暂无交易记录\n点击下方"财务"添加收支');
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: _transactions.map((tx) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (tx.isIncome ? kProfitColor : kLossColor).withValues(alpha: 0.1),
              child: Icon(
                tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: tx.isIncome ? kProfitColor : kLossColor,
                size: 20,
              ),
            ),
            title: Text(tx.description ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(formatShortDate(tx.date), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
            trailing: Text(
              widget.privacy ? '****' : '${tx.isIncome ? '+' : '-'}${formatAmount(tx.amount)}',
              style: TextStyle(color: tx.isIncome ? kProfitColor : kLossColor, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary)),
    );
  }
}
