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
          // 说明卡片
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('什么是蒙特卡洛模拟？', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '蒙特卡洛模拟是一种通过随机抽样来预测未来可能性的方法。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '在 FIRE 规划中，它会模拟 1000 种可能的市场情况，考虑收益率的波动，计算你达到 FIRE 目标的概率和时间。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('参数说明：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('• 预期收益率：长期股票市场平均约 7%', style: TextStyle(fontSize: 12)),
                        Text('• 波动率：市场波动程度，美股历史约 15%', style: TextStyle(fontSize: 12)),
                        Text('• 模拟次数：越多越准确，默认 1000 次', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

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
                    decoration: const InputDecoration(
                      labelText: 'FIRE数字 (可选)',
                      prefixText: '¥',
                      helperText: '留空则自动从系统获取',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expectedReturnController,
                    decoration: const InputDecoration(
                      labelText: '预期年化收益率',
                      suffixText: '%',
                      helperText: '长期股票市场平均约 7%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _volatilityController,
                    decoration: const InputDecoration(
                      labelText: '波动率',
                      suffixText: '%',
                      helperText: '市场波动程度，美股历史约 15%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _simulationsController,
                    decoration: const InputDecoration(
                      labelText: '模拟次数',
                      helperText: '推荐 1000 次，越多越准确',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _runSimulation,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('运行模拟'),
                    ),
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
    final simulations = _result!['simulations'] ?? 1000;

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
            const SizedBox(height: 8),
            Text(
              '在 $simulations 次模拟中，${(successRate * simulations).toInt()} 次在 50 年内达成目标',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('P10', p10Years != null ? '${(p10Years as num).toStringAsFixed(1)}年' : '-', '乐观情况\n(10%概率)'),
                _buildMetric('中位数', medianYears != null ? '${(medianYears as num).toStringAsFixed(1)}年' : '-', '最可能\n(50%概率)'),
                _buildMetric('P90', p90Years != null ? '${(p90Years as num).toStringAsFixed(1)}年' : '-', '悲观情况\n(90%概率)'),
              ],
            ),
            const SizedBox(height: 16),
            // 指标说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(64),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      const Text('指标解读', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• P10（乐观）：10%的情况下，你在这么短时间内达成\n'
                    '• 中位数：最可能的达成时间\n'
                    '• P90（悲观）：90%的情况下，你在这么短时间内达成\n'
                    '• 成功率越高、时间越短，说明你的 FIRE 计划越稳健',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, String description) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(description, style: TextStyle(fontSize: 10, color: Colors.grey[400]), textAlign: TextAlign.center),
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
