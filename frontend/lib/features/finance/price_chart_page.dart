import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/number.dart';

class PriceChartPage extends ConsumerStatefulWidget {
  final String assetId;
  const PriceChartPage({super.key, required this.assetId});

  @override
  ConsumerState<PriceChartPage> createState() => _PriceChartPageState();
}

class _PriceChartPageState extends ConsumerState<PriceChartPage> {
  List<dynamic> _prices = [];
  bool _isLoading = true;
  int _days = 30;

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
        '/api/families/current/finance/price-history/${widget.assetId}',
        queryParams: {'days': _days},
      );
      setState(() {
        _prices = response.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('价格走势')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [7, 30, 90, 365].map((d) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('${d}天'),
                        selected: _days == d,
                        onSelected: (_) {
                          setState(() => _days = d);
                          _loadData();
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                if (_prices.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            formatCurrency(toDouble(_prices.last['price'])),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          Text('暂无图表数据', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('暂无价格数据')),
                    ),
                  ),
              ],
            ),
    );
  }
}
