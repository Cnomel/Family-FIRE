import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/formatters.dart';
import '../../core/api_service.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final _api = ApiService();
  Map<String, dynamic> _fireSnapshot = {};
  Map<String, dynamic> _allocation = {};
  Map<String, dynamic> _summary = {};
  List<dynamic> _records = [];
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
        _api.get('/families/current/finance/fire/snapshot').catchError((_) => {'data': {}}),
        _api.get('/families/current/finance/fire/allocation').catchError((_) => {'data': {}}),
        _api.get('/families/current/finance/income-expense/summary').catchError((_) => {'data': {}}),
        _api.get('/families/current/finance/income-expense').catchError((_) => {'data': {'records': []}}),
      ]);

      setState(() {
        _fireSnapshot = results[0]['data'] ?? {};
        _allocation = results[1]['data'] ?? {};
        _summary = results[2]['data'] ?? {};
        _records = results[3]['data']?['records'] ?? [];
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
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddRecord),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFireCard(),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    const Text('资产配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildAllocationChart(),
                    const SizedBox(height: 24),
                    const Text('收支记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _buildRecordsList(),
                  ],
                ),
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
          colors: [AppColors.primary, AppColors.primaryDark],
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
              Expanded(child: _fireStat('净资产', formatAmount(netWorth))),
              Expanded(child: _fireStat('FIRE数字', formatAmount(fireNumber))),
              Expanded(child: _fireStat('完成度', '${(fiRatio * 100).toStringAsFixed(1)}%')),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: fiRatio.clamp(0, 1),
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            color: Colors.white,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _fireStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
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
          _summaryItem('收入', income, AppColors.profit),
          Container(width: 1, height: 40, color: AppColors.border),
          _summaryItem('支出', expense, AppColors.loss),
          Container(width: 1, height: 40, color: AppColors.border),
          _summaryItem('结余', net, AppColors.primary),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(formatAmount(amount), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAllocationChart() {
    final entries = _allocation.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('暂无资产数据', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final colors = [AppColors.primary, AppColors.loss, AppColors.warning, Colors.purple, Colors.teal];

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: PieChart(
        PieChartData(
          sections: entries.asMap().entries.map((e) {
            final percent = (e.value.value * 100).toDouble();
            return PieChartSectionData(
              value: percent,
              title: '${percent.toStringAsFixed(0)}%',
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

  Widget _buildRecordsList() {
    if (_records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('暂无收支记录', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: _records.map((record) {
          final isIncome = record['type'] == 'income';
          final amount = (record['amount'] ?? 0).toDouble();
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (isIncome ? AppColors.profit : AppColors.loss).withValues(alpha: 0.1),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppColors.profit : AppColors.loss,
                size: 20,
              ),
            ),
            title: Text(record['description'] ?? ''),
            subtitle: Text(formatDate(record['date'] ?? ''), style: const TextStyle(fontSize: 12)),
            trailing: Text(
              '${isIncome ? '+' : '-'}${formatAmount(amount)}',
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

  void _showAddRecord() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('记录收支', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheetState(() => selectedType = 'income'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'income' ? AppColors.profit.withValues(alpha: 0.1) : null,
                      ),
                      child: Text('收入', style: TextStyle(color: selectedType == 'income' ? AppColors.profit : AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheetState(() => selectedType = 'expense'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedType == 'expense' ? AppColors.loss.withValues(alpha: 0.1) : null,
                      ),
                      child: Text('支出', style: TextStyle(color: selectedType == 'expense' ? AppColors.loss : AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: '金额', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述', prefixIcon: Icon(Icons.note)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (amountController.text.isEmpty || descController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写金额和描述'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  try {
                    await _api.post('/families/current/finance/income-expense', body: {
                      'type': selectedType,
                      'amount': double.tryParse(amountController.text) ?? 0,
                      'description': descController.text,
                      'date': DateTime.now().toIso8601String(),
                    });
                    Navigator.pop(context);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('记录成功'), backgroundColor: AppColors.loss),
                      );
                    }
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
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
