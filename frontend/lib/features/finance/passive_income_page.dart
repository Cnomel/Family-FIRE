import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';

class PassiveIncomePage extends ConsumerStatefulWidget {
  const PassiveIncomePage({super.key});

  @override
  ConsumerState<PassiveIncomePage> createState() => _PassiveIncomePageState();
}

class _PassiveIncomePageState extends ConsumerState<PassiveIncomePage> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/finance/fire/passive-income');
      setState(() {
        _data = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final annual = toDouble(_data?['annual']);
    final sources = (_data?['sources'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('被动收入')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('暂无数据'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('年被动收入', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(
                                formatCurrency(annual),
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '月均: ${formatCurrency(annual / 12)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('收入来源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (sources.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('暂无被动收入来源')),
                          ),
                        )
                      else
                        ...sources.map((source) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                                  child: const Icon(Icons.trending_up, color: Colors.green),
                                ),
                                title: Text(source['asset_name'] ?? source['type'] ?? ''),
                                subtitle: Text(source['type'] ?? ''),
                                trailing: Text(
                                  formatCurrency(toDouble(source['annual_income'])),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
