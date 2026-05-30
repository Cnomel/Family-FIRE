import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';

class CostBasisPage extends ConsumerStatefulWidget {
  final String assetId;
  const CostBasisPage({super.key, required this.assetId});

  @override
  ConsumerState<CostBasisPage> createState() => _CostBasisPageState();
}

class _CostBasisPageState extends ConsumerState<CostBasisPage> {
  Map<String, dynamic>? _costBasis;
  bool _isLoading = true;
  String _method = 'average_cost';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get(
        '/api/families/current/finance/cost-basis/${widget.assetId}',
        queryParams: {'method': _method},
      );
      setState(() {
        _costBasis = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成本基础'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _method,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'average_cost', child: Text('平均成本')),
              const PopupMenuItem(value: 'fifo', child: Text('FIFO')),
              const PopupMenuItem(value: 'lifo', child: Text('LIFO')),
            ],
            onSelected: (v) {
              setState(() => _method = v);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _costBasis == null
              ? const Center(child: Text('暂无数据'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              _methodLabel(_method),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetric('总份额', toDouble(_costBasis!['total_shares']).toString()),
                                _buildMetric('平均成本', formatCurrency(toDouble(_costBasis!['average_cost']))),
                                _buildMetric('总成本', formatCurrency(toDouble(_costBasis!['total_cost']))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if ((_costBasis!['lots'] as List?)?.isNotEmpty == true) ...[
                      const Text('持仓批次', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...(_costBasis!['lots'] as List).map((lot) => Card(
                            child: ListTile(
                              title: Text('${toDouble(lot['quantity'])} 份 @ ${formatCurrency(toDouble(lot['cost_per_unit']))}'),
                              subtitle: Text(lot['purchase_date'] ?? ''),
                              trailing: Text(formatCurrency(toDouble(lot['total_cost']))),
                            ),
                          )),
                    ],
                  ],
                ),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'fifo': return '先进先出 (FIFO)';
      case 'lifo': return '后进先出 (LIFO)';
      case 'average_cost': return '平均成本法';
      default: return method;
    }
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
