import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/formatters.dart';

class FinanceTab extends StatefulWidget {
  final bool privacy;
  const FinanceTab({super.key, required this.privacy});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  Map<String, dynamic> _fireSnapshot = {};
  Map<String, dynamic> _allocation = {};
  Map<String, dynamic> _summary = {};
  List<dynamic> _records = [];
  List<dynamic> _liabilities = [];
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
        Api.instance.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense/summary').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense').catchError((_) => {'data': {'records': []}}),
        Api.instance.get('/families/current/finance/liabilities').catchError((_) => {'data': {'liabilities': []}}),
      ]);

      setState(() {
        _fireSnapshot = results[0]['data'] ?? {};
        _allocation = results[1]['data'] ?? {};
        _summary = results[2]['data'] ?? {};
        _records = results[3]['data']?['records'] ?? [];
        _liabilities = results[4]['data']?['liabilities'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('财务'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddRecord,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFireCard(),
            const SizedBox(height: 12),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildLiabilitiesSection(),
            const SizedBox(height: 24),
            _buildAllocationSection(),
            const SizedBox(height: 24),
            _buildRecordsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFireCard() {
    final netWorth = (_fireSnapshot['net_worth']?['net_worth'] ?? 0).toDouble();
    final fireNumber = (_fireSnapshot['fire_number'] ?? 0).toDouble();
    final fiRatio = (_fireSnapshot['fi_ratio'] ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text('FIRE 仪表盘', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildFireStat('净资产', formatAmount(netWorth)),
              _buildFireStat('FIRE数字', formatAmount(fireNumber)),
              _buildFireStat('完成度', '${(fiRatio * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fiRatio.clamp(0, 1).toDouble(),
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFireStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final income = (_summary['total_income'] ?? 0).toDouble();
    final expense = (_summary['total_expense'] ?? 0).toDouble();
    final net = (_summary['net'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSummaryItem('收入', income, kProfit),
          Container(width: 1, height: 40, color: kBorder),
          _buildSummaryItem('支出', expense, kLoss),
          Container(width: 1, height: 40, color: kBorder),
          _buildSummaryItem('结余', net, kPrimary),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: kText2, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            widget.privacy ? '****' : formatAmount(amount),
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilitiesSection() {
    if (_liabilities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('负债', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _liabilities.map((liability) {
              final balance = (liability['current_balance'] ?? 0).toDouble();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: kWarn.withValues(alpha: 0.1),
                  child: const Icon(Icons.account_balance, color: kWarn, size: 20),
                ),
                title: Text(liability['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(liabilityTypeLabel(liability['type'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12)),
                trailing: Text(
                  widget.privacy ? '****' : formatAmount(balance),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kWarn),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationSection() {
    final entries = _allocation.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) return _buildEmptyCard('暂无资产数据');

    final colors = [kPrimary, kLoss, kWarn, Colors.purple, Colors.teal];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: PieChart(
            PieChartData(
              sections: entries.asMap().entries.map((e) {
                final pct = (e.value.value * 100).toDouble();
                return PieChartSectionData(
                  value: pct,
                  title: '${pct.toStringAsFixed(0)}%',
                  color: colors[e.key % colors.length],
                  radius: 60,
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('收支记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_records.isEmpty)
          _buildEmptyCard('暂无收支记录')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _records.map((record) {
                final isIncome = record['type'] == 'income';
                final amount = (record['amount'] ?? 0).toDouble();
                return Dismissible(
                  key: Key(record['id'] ?? ''),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: kError,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await Api.instance.delete('/families/current/finance/income-expense/${record['id']}');
                    _loadData();
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isIncome ? kProfit : kLoss).withValues(alpha: 0.1),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIncome ? kProfit : kLoss,
                        size: 20,
                      ),
                    ),
                    title: Text(record['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(formatDate(record['date'] ?? ''), style: const TextStyle(color: kText2, fontSize: 12)),
                    trailing: Text(
                      widget.privacy ? '****' : '${isIncome ? '+' : '-'}${formatAmount(amount)}',
                      style: TextStyle(
                        color: isIncome ? kProfit : kLoss,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _showAddRecord() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheetState(() => selectedType = 'income'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'income' ? kProfit.withValues(alpha: 0.1) : null,
                        side: BorderSide(color: selectedType == 'income' ? kProfit : kBorder),
                      ),
                      child: Text('收入', style: TextStyle(color: selectedType == 'income' ? kProfit : kText2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheetState(() => selectedType = 'expense'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'expense' ? kLoss.withValues(alpha: 0.1) : null,
                        side: BorderSide(color: selectedType == 'expense' ? kLoss : kBorder),
                      ),
                      child: Text('支出', style: TextStyle(color: selectedType == 'expense' ? kLoss : kText2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  prefixIcon: Icon(Icons.note_outlined),
                  hintText: '例如：超市购物',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (amountController.text.isEmpty || descController.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请填写金额和描述'), backgroundColor: kError),
                    );
                    return;
                  }
                  try {
                    await Api.instance.post('/families/current/finance/income-expense', body: {
                      'type': selectedType,
                      'amount': double.tryParse(amountController.text) ?? 0,
                      'description': descController.text,
                      'date': DateTime.now().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('记录成功'), backgroundColor: kLoss),
                      );
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: kError),
                    );
                  }
                },
                child: const Text('保存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
