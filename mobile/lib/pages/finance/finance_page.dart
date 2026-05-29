import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/theme.dart';
import '../../utils/formatters.dart';
import '../../services/api.dart';
import '../../models/models.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  FireSnapshot? _fire;
  Map<String, dynamic> _allocation = {};
  Map<String, dynamic> _summary = {};
  List<Transaction> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        Api.instance.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense/summary').catchError((_) => {'data': {}}),
        Api.instance.get('/families/current/finance/income-expense').catchError((_) => {'data': {'records': []}}),
      ]);
      setState(() {
        _fire = FireSnapshot.fromJson(r[0]['data'] ?? {});
        _allocation = r[1]['data'] ?? {};
        _summary = r[2]['data'] ?? {};
        _records = (r[3]['data']?['records'] as List? ?? []).map((e) => Transaction.fromJson(e)).toList();
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
        title: const Text('财务'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addRecord),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _fireCard(),
                  const SizedBox(height: 12),
                  _summaryCard(),
                  const SizedBox(height: 24),
                  _sectionTitle('资产配置'),
                  const SizedBox(height: 8),
                  _allocationChart(),
                  const SizedBox(height: 24),
                  _sectionTitle('收支记录'),
                  const SizedBox(height: 8),
                  _recordsList(),
                ],
              ),
            ),
    );
  }

  Widget _fireCard() {
    final nw = _fire?.netWorth ?? 0;
    final fn = _fire?.fireNumber ?? 0;
    final fi = _fire?.fiRatio ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kPrimaryColor, kPrimaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FIRE 仪表盘', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _fireStat('净资产', formatAmount(nw)),
              _fireStat('FIRE数字', formatAmount(fn)),
              _fireStat('完成度', '${(fi * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fi.clamp(0, 1).toDouble(),
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fireStat(String label, String value) {
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

  Widget _summaryCard() {
    final income = (_summary['total_income'] ?? 0).toDouble();
    final expense = (_summary['total_expense'] ?? 0).toDouble();
    final net = (_summary['net'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _summaryItem('收入', income, kProfitColor),
          Container(width: 1, height: 40, color: kBorderColor),
          _summaryItem('支出', expense, kLossColor),
          Container(width: 1, height: 40, color: kBorderColor),
          _summaryItem('结余', net, kPrimaryColor),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(formatAmount(amount), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _allocationChart() {
    final entries = _allocation.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) return _emptyCard('暂无资产数据');

    final colors = [kPrimaryColor, kLossColor, kWarningColor, Colors.purple, Colors.teal];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _recordsList() {
    if (_records.isEmpty) return _emptyCard('暂无收支记录');

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: _records.map((tx) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (tx.isIncome ? kProfitColor : kLossColor).withValues(alpha: 0.1),
              child: Icon(
                tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: tx.isIncome ? kProfitColor : kLossColor,
                size: 20,
              ),
            ),
            title: Text(tx.description ?? ''),
            subtitle: Text(formatShortDate(tx.date), style: const TextStyle(fontSize: 12)),
            trailing: Text(
              '${tx.isIncome ? '+' : '-'}${formatAmount(tx.amount)}',
              style: TextStyle(color: tx.isIncome ? kProfitColor : kLossColor, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _addRecord() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _typeButton('收入', 'income', type, (v) => setSheet(() => type = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _typeButton('支出', 'expense', type, (v) => setSheet(() => type = v))),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '金额', prefixIcon: Icon(Icons.attach_money), hintText: '0.00')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl,
                decoration: const InputDecoration(labelText: '描述', prefixIcon: Icon(Icons.note_outlined), hintText: '例如：超市购物')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (amountCtrl.text.isEmpty || descCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写金额和描述'), backgroundColor: kErrorColor));
                    return;
                  }
                  try {
                    await Api.instance.post('/families/current/finance/income-expense', body: {
                      'type': type,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'description': descCtrl.text,
                      'date': DateTime.now().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录成功'), backgroundColor: kLossColor));
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: kErrorColor));
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

  Widget _typeButton(String label, String value, String selected, ValueChanged<String> onChanged) {
    final sel = selected == value;
    final color = value == 'income' ? kProfitColor : kLossColor;
    return OutlinedButton(
      onPressed: () => onChanged(value),
      style: OutlinedButton.styleFrom(
        backgroundColor: sel ? color.withValues(alpha: 0.1) : null,
        side: BorderSide(color: sel ? color : kBorderColor),
      ),
      child: Text(label, style: TextStyle(color: sel ? color : kTextSecondary)),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
  Widget _emptyCard(String t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary)),
  );
}
