import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../shared/theme/colors.dart';

class MonteCarloPage extends ConsumerStatefulWidget {
  const MonteCarloPage({super.key});

  @override
  ConsumerState<MonteCarloPage> createState() => _MonteCarloPageState();
}

class _MonteCarloPageState extends ConsumerState<MonteCarloPage> {
  Map<String, dynamic>? _result;
  bool _isLoading = false;

  final _fireNumberController = TextEditingController();
  final _expectedReturnController = TextEditingController(text: '7');
  final _volatilityController = TextEditingController(text: '15');
  final _simulationsController = TextEditingController(text: '1000');

  @override
  void dispose() {
    _fireNumberController.dispose();
    _expectedReturnController.dispose();
    _volatilityController.dispose();
    _simulationsController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/api/families/current/finance/fire/monte-carlo', data: {
        'fire_number': double.tryParse(_fireNumberController.text),
        'expected_return': double.tryParse(_expectedReturnController.text),
        'volatility': double.tryParse(_volatilityController.text),
        'simulations': int.tryParse(_simulationsController.text),
      });
      setState(() {
        _result = response.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('蒙特卡洛模拟')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 参数输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('模拟参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fireNumberController,
                    decoration: const InputDecoration(labelText: 'FIRE数字 (可选)', prefixText: '¥'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expectedReturnController,
                    decoration: const InputDecoration(labelText: '预期年化收益率', suffixText: '%'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _volatilityController,
                    decoration: const InputDecoration(labelText: '波动率', suffixText: '%'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _simulationsController,
                    decoration: const InputDecoration(labelText: '模拟次数'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _runSimulation,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('运行模拟'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 结果
          if (_result != null) ...[
            _buildResultCard(),
            const SizedBox(height: 16),
            _buildChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final successRate = toDouble(_result!['success_rate']);
    final medianYears = _result!['median_years'];
    final p10Years = _result!['p10_years'];
    final p90Years = _result!['p90_years'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 成功率
            Text(
              '${(successRate * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: successRate >= 0.8 ? AppColors.profit : successRate >= 0.5 ? Colors.orange : AppColors.loss,
              ),
            ),
            const Text('成功率', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('P10', p10Years != null ? '${(p10Years as num).toStringAsFixed(1)}年' : '-'),
                _buildMetric('中位数', medianYears != null ? '${(medianYears as num).toStringAsFixed(1)}年' : '-'),
                _buildMetric('P90', p90Years != null ? '${(p90Years as num).toStringAsFixed(1)}年' : '-'),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildChart() {
    final samplePaths = _result!['sample_paths'] as List<dynamic>? ?? [];
    if (samplePaths.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('模拟路径', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: samplePaths.take(20).map((path) {
                    final points = (path as List<dynamic>).cast<num>();
                    return LineChartBarData(
                      spots: points.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.toDouble() / 10000);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary.withValues(alpha: 0.2),
                      barWidth: 1,
                      dotData: const FlDotData(show: false),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('单位: 万元 (仅显示前20条路径)', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
