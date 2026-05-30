import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';

class InsuranceGapsPage extends ConsumerStatefulWidget {
  const InsuranceGapsPage({super.key});

  @override
  ConsumerState<InsuranceGapsPage> createState() => _InsuranceGapsPageState();
}

class _InsuranceGapsPageState extends ConsumerState<InsuranceGapsPage> {
  List<dynamic> _gaps = [];
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
      final response = await client.get('/api/families/current/assets/insurance-gaps');
      setState(() {
        _gaps = response.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('保险缺口分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _gaps.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('所有高价值资产已投保', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _gaps.length,
                    itemBuilder: (context, index) {
                      final gap = _gaps[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            child: const Icon(Icons.warning, color: Colors.red),
                          ),
                          title: Text(gap['name'] ?? gap['asset_name'] ?? ''),
                          subtitle: Text('价值: ${formatCurrency(toDouble(gap['current_value']))}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final assetId = gap['asset_id'] ?? gap['id'];
                            if (assetId != null) {
                              await context.push('/assets/$assetId');
                              if (mounted) _loadData();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
