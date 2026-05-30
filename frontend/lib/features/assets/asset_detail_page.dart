import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/percent_badge.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/theme/colors.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/date.dart';
import '../../shared/formatters/number.dart';

class AssetDetailPage extends ConsumerStatefulWidget {
  final String assetId;
  const AssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  Map<String, dynamic>? _asset;
  Map<String, dynamic>? _lifecycle;
  List<dynamic> _relationships = [];
  List<dynamic> _valueHistory = [];
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final familyPath = '/api/families/current/assets/${widget.assetId}';

      // 并行加载
      final results = await Future.wait([
        client.get(familyPath),
        client.get('$familyPath/lifecycle'),
        client.get('$familyPath/relationships'),
        client.get('$familyPath/value-history', queryParams: {'months': 12}),
        client.get('/api/documents/asset/${widget.assetId}'),
      ]);

      setState(() {
        _asset = results[0].data['data'];
        _lifecycle = results[1].data['data'];
        _relationships = results[2].data['data'] ?? [];
        _valueHistory = results[3].data['data'] ?? [];
        _documents = results[4].data['data'] ?? [];
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('此操作不可撤销，确认删除该资产？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/families/current/assets/${widget.assetId}');
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? '加载失败'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final asset = _asset!;
    final financial = asset['financial'] ?? {};
    final currentValue = toDouble(financial['current_value']);
    final purchasePrice = toDouble(financial['purchase_price']);
    final change = purchasePrice > 0 ? (currentValue - purchasePrice) / purchasePrice * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/assets/${widget.assetId}/edit'),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'relationships', child: Text('关系图')),
              const PopupMenuItem(value: 'consumable', child: Text('消耗品追踪')),
              const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (value) {
              switch (value) {
                case 'relationships':
                  context.push('/assets/${widget.assetId}/relationships');
                  break;
                case 'consumable':
                  context.push('/assets/${widget.assetId}/consumable');
                  break;
                case 'delete':
                  _deleteAsset();
                  break;
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头部信息
            _buildHeader(asset, currentValue, purchasePrice, change),
            const SizedBox(height: 16),

            // 分类标签
            _buildClassificationChips(asset),
            const SizedBox(height: 16),

            // 价值历史图表
            if (_valueHistory.isNotEmpty) ...[
              _buildValueChart(),
              const SizedBox(height: 16),
            ],

            // 财务信息
            _buildFinancialInfo(financial),
            const SizedBox(height: 16),

            // 生命周期信息
            if (_lifecycle != null) ...[
              _buildLifecycleInfo(_lifecycle!),
              const SizedBox(height: 16),
            ],

            // 元数据
            if (asset['metadata'] != null) ...[
              _buildMetadata(asset['metadata'], asset['metadata_type']),
              const SizedBox(height: 16),
            ],

            // 关系
            if (_relationships.isNotEmpty) ...[
              _buildRelationships(),
              const SizedBox(height: 16),
            ],

            // 文档
            if (_documents.isNotEmpty) ...[
              _buildDocuments(),
              const SizedBox(height: 16),
            ],

            // 标签
            if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty) ...[
              _buildTags(asset['tags']),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> asset, double currentValue, double purchasePrice, double change) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CategoryIcon(nature: asset['nature'] ?? '', size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset['name'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (asset['description'] != null)
                        Text(
                          asset['description'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('当前价值', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    AmountText(amount: currentValue, fontSize: 22),
                  ],
                ),
                Column(
                  children: [
                    const Text('购买价格', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(formatCurrency(purchasePrice), style: const TextStyle(fontSize: 16)),
                  ],
                ),
                Column(
                  children: [
                    const Text('变动', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    PercentBadge(value: change),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationChips(Map<String, dynamic> asset) {
    final labels = {
      'nature': {'tangible': '有形', 'digital': '数字', 'financial': '金融', 'intangible': '无形', 'service': '服务'},
      'utility': {
        'productive': '生产性', 'consumable': '消耗品', 'protective': '防护性',
        'speculative': '投机性', 'lifestyle': '生活方式', 'essential': '必需品'
      },
      'ownership': {
        'owned': '自有', 'mortgaged': '抵押', 'leased': '租赁',
        'subscribed': '订阅', 'licensed': '授权', 'custodied': '托管'
      },
      'liquidity': {'instant': '即时', 'high': '高', 'medium': '中', 'low': '低', 'fixed': '固定'},
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ['nature', 'utility', 'ownership', 'liquidity'].map((dim) {
        final value = asset[dim] ?? '';
        final label = labels[dim]?[value] ?? value;
        return Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  Widget _buildValueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('价值历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _valueHistory.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          toDouble(entry.value['value']),
                        );
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfo(Map<String, dynamic> financial) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('财务信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildInfoRow('购买价格', formatCurrency(toDouble(financial['purchase_price']))),
            _buildInfoRow('购买日期', financial['purchase_date'] != null
                ? formatDateShort(DateTime.parse(financial['purchase_date']))
                : '-'),
            _buildInfoRow('当前价值', formatCurrency(toDouble(financial['current_value']))),
            _buildInfoRow('货币', financial['currency'] ?? 'CNY'),
            _buildInfoRow('总持有成本', formatCurrency(toDouble(financial['total_cost_of_ownership']))),
            _buildInfoRow('月持有成本', formatCurrency(toDouble(financial['monthly_carrying_cost']))),
          ],
        ),
      ),
    );
  }

  Widget _buildLifecycleInfo(Map<String, dynamic> lifecycle) {
    final trajectory = lifecycle['trajectory'] ?? '';
    final labels = {
      'depreciating': '折旧中',
      'consumable': '消耗品',
      'expiring': '即将到期',
      'volatile': '波动',
      'appreciating': '增值中',
      'stable': '稳定',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('生命周期', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _updateLifecycle(lifecycle),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('轨迹类型', labels[trajectory] ?? trajectory),
            if (lifecycle['computed_value'] != null)
              _buildInfoRow('计算价值', formatCurrency(toDouble(lifecycle['computed_value']))),
            // 显示轨迹特定配置
            if (trajectory == 'depreciating' && lifecycle['depreciation_config'] != null) ...[
              const Divider(),
              _buildInfoRow('折旧率', '${toDouble(lifecycle['depreciation_config']['rate']).toStringAsFixed(1)}%'),
              _buildInfoRow('残值', formatCurrency(toDouble(lifecycle['depreciation_config']['salvage_value']))),
            ],
            if (trajectory == 'consumable' && lifecycle['consumption_config'] != null) ...[
              const Divider(),
              _buildInfoRow('当前数量', '${lifecycle['consumption_config']['current_quantity'] ?? 0}'),
              _buildInfoRow('单位', lifecycle['consumption_config']['unit'] ?? ''),
            ],
            if (trajectory == 'expiring' && lifecycle['expiration_config'] != null) ...[
              const Divider(),
              _buildInfoRow('到期日期', lifecycle['expiration_config']['end_date'] ?? '-'),
              _buildInfoRow('自动续期', lifecycle['expiration_config']['auto_renew'] == true ? '是' : '否'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateLifecycle(Map<String, dynamic> lifecycle) async {
    final trajectory = lifecycle['trajectory'] ?? '';
    final Map<String, dynamic> configData = {};

    // 根据轨迹类型显示不同的编辑表单
    if (trajectory == 'depreciating') {
      final rateController = TextEditingController(
        text: (lifecycle['depreciation_config']?['rate'] ?? 0).toString(),
      );
      final salvageController = TextEditingController(
        text: (lifecycle['depreciation_config']?['salvage_value'] ?? 0).toString(),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('更新折旧配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: '年折旧率(%)', suffixText: '%'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salvageController,
                decoration: const InputDecoration(labelText: '残值', prefixText: '¥'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed == true) {
        configData['depreciation_config'] = {
          'rate': double.tryParse(rateController.text) ?? 0,
          'salvage_value': double.tryParse(salvageController.text) ?? 0,
        };
      }
    } else if (trajectory == 'consumable') {
      final qtyController = TextEditingController(
        text: (lifecycle['consumption_config']?['current_quantity'] ?? 0).toString(),
      );
      final unitController = TextEditingController(
        text: lifecycle['consumption_config']?['unit'] ?? '',
      );
      final thresholdController = TextEditingController(
        text: (lifecycle['consumption_config']?['reorder_threshold'] ?? 0).toString(),
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('更新消耗品配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qtyController, decoration: const InputDecoration(labelText: '当前数量'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: '单位')),
              const SizedBox(height: 12),
              TextField(controller: thresholdController, decoration: const InputDecoration(labelText: '补货阈值'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed == true) {
        configData['consumption_config'] = {
          'current_quantity': double.tryParse(qtyController.text) ?? 0,
          'unit': unitController.text.trim(),
          'reorder_threshold': double.tryParse(thresholdController.text) ?? 0,
        };
      }
    } else if (trajectory == 'expiring') {
      final endDateController = TextEditingController(
        text: lifecycle['expiration_config']?['end_date'] ?? '',
      );
      final autoRenew = lifecycle['expiration_config']?['auto_renew'] ?? false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('更新到期配置'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: endDateController, decoration: const InputDecoration(labelText: '到期日期 (YYYY-MM-DD)')),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('自动续期'),
                  value: autoRenew,
                  onChanged: (v) => setDialogState(() {}),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
            ],
          ),
        ),
      );
      if (confirmed == true) {
        configData['expiration_config'] = {
          'end_date': endDateController.text.trim(),
          'auto_renew': autoRenew,
        };
      }
    } else {
      // 其他类型不支持编辑
      return;
    }

    if (configData.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put(
          '/api/families/current/assets/${widget.assetId}/lifecycle',
          data: configData,
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新生命周期失败')));
        }
      }
    }
  }

  Widget _buildMetadata(Map<String, dynamic> metadata, String? type) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${type ?? "详细"}信息', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...metadata.entries
                .where((e) => e.value != null && e.value.toString().isNotEmpty)
                .map((e) => _buildInfoRow(e.key, e.value.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationships() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('关系', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _createRelationship(),
                    ),
                    TextButton(
                      onPressed: () => context.push('/assets/${widget.assetId}/relationships'),
                      child: const Text('查看关系图'),
                    ),
                  ],
                ),
              ],
            ),
            if (_relationships.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无关系', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._relationships.map((rel) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.link, size: 20),
                    title: Text(_relationshipTypeLabel(rel['type'] ?? '')),
                    subtitle: Text(rel['target_asset_name'] ?? rel['target_asset_id'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _deleteRelationship(rel['id']),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _relationshipTypeLabel(String type) {
    const labels = {
      'component_of': '组成部分',
      'contains': '包含',
      'requires': '需要',
      'manages': '管理',
      'provides': '提供',
      'protects': '保护',
      'funds': '资助',
      'secures': '担保',
      'accesses': '访问',
      'substitutes': '替代',
    };
    return labels[type] ?? type;
  }

  Future<void> _createRelationship() async {
    final targetIdController = TextEditingController();
    String relType = 'component_of';
    bool isOptional = true;
    bool lifecycleLinked = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创建关系'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: targetIdController,
                  decoration: const InputDecoration(labelText: '目标资产ID'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: relType,
                  decoration: const InputDecoration(labelText: '关系类型'),
                  items: const [
                    DropdownMenuItem(value: 'component_of', child: Text('组成部分')),
                    DropdownMenuItem(value: 'contains', child: Text('包含')),
                    DropdownMenuItem(value: 'requires', child: Text('需要')),
                    DropdownMenuItem(value: 'manages', child: Text('管理')),
                    DropdownMenuItem(value: 'provides', child: Text('提供')),
                    DropdownMenuItem(value: 'protects', child: Text('保护')),
                    DropdownMenuItem(value: 'funds', child: Text('资助')),
                    DropdownMenuItem(value: 'secures', child: Text('担保')),
                    DropdownMenuItem(value: 'accesses', child: Text('访问')),
                    DropdownMenuItem(value: 'substitutes', child: Text('替代')),
                  ],
                  onChanged: (v) => setDialogState(() => relType = v ?? relType),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('可选关系'),
                  value: isOptional,
                  onChanged: (v) => setDialogState(() => isOptional = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('生命周期关联'),
                  value: lifecycleLinked,
                  onChanged: (v) => setDialogState(() => lifecycleLinked = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
          ],
        ),
      ),
    );

    if (confirmed == true && targetIdController.text.trim().isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.post('/api/families/current/assets/${widget.assetId}/relationships', data: {
          'target_asset_id': targetIdController.text.trim(),
          'type': relType,
          'is_optional': isOptional,
          'lifecycle_linked': lifecycleLinked,
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建关系失败')));
        }
      }
    }
  }

  Future<void> _deleteRelationship(String relId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除关系'),
        content: const Text('确认删除该关系？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.delete('/api/families/current/assets/${widget.assetId}/relationships/$relId');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除关系失败')));
        }
      }
    }
  }

  Widget _buildDocuments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文档', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _documents.map((doc) {
                final isPdf = (doc['mime_type'] ?? '').contains('pdf');
                return ActionChip(
                  avatar: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, size: 18),
                  label: Text(
                    doc['file_name'] ?? '',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    if (isPdf) {
                      context.push('/documents/${doc['id']}/pdf');
                    } else {
                      context.push('/documents/${doc['id']}/image');
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(List<dynamic> tags) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _addTag(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeTag(tag),
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入标签名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('添加')),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.post('/api/families/current/assets/${widget.assetId}/tags', data: {'tag': tag});
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('添加标签失败')));
        }
      }
    }
  }

  Future<void> _removeTag(String tag) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/api/families/current/assets/${widget.assetId}/tags/$tag');
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除标签失败')));
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
