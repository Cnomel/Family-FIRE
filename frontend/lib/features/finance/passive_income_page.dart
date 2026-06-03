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
    final annual = toDouble(_data?['total_annual']);
    final monthly = toDouble(_data?['total_monthly']);
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
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E3A8A),  // 深蓝
                                Color(0xFF7C3AED),  // 紫色
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
                                '月均: ${formatCurrency(monthly)}',
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
                        ...sources.map((source) {
                          final incomeSource = source['income_source'] ?? '';
                          final instrumentType = source['instrument_type'] ?? '';
                          final totalGain = source['total_gain'];
                          final holdingDays = source['holding_days'];
                          final cost = toDouble(source['cost']);
                          
                          String sourceLabel;
                          String? detailText;
                          
                          switch (incomeSource) {
                            case 'stable_yield':
                              sourceLabel = '稳定收益 ${source['yield_rate']}%';
                              break;
                            case 'manual':
                              sourceLabel = '手动输入收益';
                              break;
                            case 'calculated':
                              sourceLabel = '年化收益率 ${source['yield_rate']}%';
                              if (totalGain != null && holdingDays != null) {
                                detailText = '总收益 ¥${toDouble(totalGain).toStringAsFixed(2)} · 持仓 $holdingDays天';
                              }
                              break;
                            case 'insufficient':
                              sourceLabel = '持仓不足或亏损';
                              if (totalGain != null) {
                                detailText = '总收益 ¥${toDouble(totalGain).toStringAsFixed(2)}';
                              }
                              break;
                            default:
                              sourceLabel = '暂无数据';
                          }
                          
                          // 获取资产类型图标
                          IconData typeIcon;
                          switch (instrumentType) {
                            case 'stock':
                              typeIcon = Icons.show_chart;
                              break;
                            case 'etf':
                              typeIcon = Icons.pie_chart;
                              break;
                            case 'fund':
                              typeIcon = Icons.account_balance_wallet;
                              break;
                            case 'cd':
                              typeIcon = Icons.savings;
                              break;
                            case 'bond':
                              typeIcon = Icons.account_balance;
                              break;
                            default:
                              typeIcon = Icons.trending_up;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: (incomeSource == 'stable_yield' ? Colors.green : Colors.blue).withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(typeIcon, color: incomeSource == 'stable_yield' ? Colors.green : Colors.blue, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          source['asset_name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          sourceLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (detailText != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            detailText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatCurrency(toDouble(source['estimated_annual_income'])),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      Text(
                                        '本金 ${formatCurrency(cost)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
