import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class ConsumablePage extends ConsumerStatefulWidget {
  final String assetId;
  const ConsumablePage({super.key, required this.assetId});

  @override
  ConsumerState<ConsumablePage> createState() => _ConsumablePageState();
}

class _ConsumablePageState extends ConsumerState<ConsumablePage> {
  Map<String, dynamic>? _lifecycle;
  bool _isLoading = true;
  bool _isSaving = false;

  final _quantityController = TextEditingController();
  final _maxQuantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _reorderThresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _maxQuantityController.dispose();
    _unitController.dispose();
    _reorderThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/${widget.assetId}/lifecycle');
      final data = response.data['data'];

      // 后端返回 config 字段（包含 consumption_config 的内容）
      final consumption = data['config'] ?? {};
      _quantityController.text = (consumption['current_quantity'] ?? 0).toString();
      _maxQuantityController.text = (consumption['initial_quantity'] ?? 0).toString();
      _unitController.text = consumption['unit'] ?? '';
      _reorderThresholdController.text = (consumption['reorder_threshold'] ?? 0).toString();

      setState(() {
        _lifecycle = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateConsumption() async {
    setState(() => _isSaving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        '/api/families/current/assets/${widget.assetId}/lifecycle',
        data: {
          'trajectory': 'consumable',
          'consumption_config': {
            'current_quantity': double.tryParse(_quantityController.text) ?? 0,
            'initial_quantity': double.tryParse(_maxQuantityController.text) ?? 0,
            'unit': _unitController.text.trim(),
            'reorder_threshold': double.tryParse(_reorderThresholdController.text) ?? 0,
          },
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新成功')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('消耗品追踪')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final consumption = _lifecycle?['config'] ?? {};
    final maxQty = toDouble(consumption['initial_quantity']);
    final currentQty = toDouble(consumption['current_quantity']);
    final unit = consumption['unit'] ?? '';
    final progress = maxQty > 0 ? currentQty / maxQty : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('消耗品追踪')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 消耗进度
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${currentQty.toStringAsFixed(0)} / ${maxQty.toStringAsFixed(0)} $unit',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    color: progress < 0.2 ? Colors.red : progress < 0.5 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已使用 ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 编辑表单
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('更新数量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxQuantityController,
                    decoration: const InputDecoration(
                      labelText: '最大存储量',
                      hintText: '例如: 100',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: '当前数量',
                      hintText: '例如: 50',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: '单位',
                      hintText: '个, 瓶, 卷, 包',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reorderThresholdController,
                    decoration: const InputDecoration(
                      labelText: '补货阈值',
                      hintText: '低于此数量时提醒',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _updateConsumption,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('更新'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
