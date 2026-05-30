import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';

/// 多步骤资产编辑表单
class AssetEditPage extends ConsumerStatefulWidget {
  final String? assetId; // null = 创建模式
  const AssetEditPage({super.key, this.assetId});

  @override
  ConsumerState<AssetEditPage> createState() => _AssetEditPageState();
}

class _AssetEditPageState extends ConsumerState<AssetEditPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Step 1: 分类选择
  String _nature = 'tangible';
  String _utility = 'essential';
  String _ownership = 'owned';
  String _liquidity = 'medium';

  // Step 2: 基本信息
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _tags = [];

  // Step 3: 财务信息
  final _purchasePriceController = TextEditingController();
  DateTime? _purchaseDate;
  final _currencyController = TextEditingController(text: 'CNY');

  // Step 4: 元数据
  String? _metadataType;
  final Map<String, TextEditingController> _metadataControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.assetId != null) {
      _loadAsset();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _currencyController.dispose();
    for (final c in _metadataControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAsset() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/${widget.assetId}');
      final data = response.data['data'];

      setState(() {
        _nature = data['nature'] ?? 'tangible';
        _utility = data['utility'] ?? 'essential';
        _ownership = data['ownership'] ?? 'owned';
        _liquidity = data['liquidity'] ?? 'medium';
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _tags = data['tags'] != null ? (data['tags'] as List).cast<String>() : [];

        final financial = data['financial'] ?? {};
        _purchasePriceController.text = (financial['purchase_price'] ?? 0).toString();
        _currencyController.text = financial['currency'] ?? 'CNY';
        if (financial['purchase_date'] != null) {
          _purchaseDate = DateTime.parse(financial['purchase_date']);
        }

        _metadataType = data['metadata_type'];
        if (data['metadata'] != null) {
          (data['metadata'] as Map<String, dynamic>).forEach((key, value) {
            _metadataControllers[key] = TextEditingController(text: value?.toString() ?? '');
          });
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final body = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'nature': _nature,
        'utility': _utility,
        'ownership': _ownership,
        'liquidity': _liquidity,
        'tags': _tags.isEmpty ? null : _tags,
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'purchase_date': _purchaseDate?.toIso8601String(),
        'currency': _currencyController.text.trim(),
        'metadata_type': _metadataType,
        'metadata': _metadataControllers.isNotEmpty
            ? _metadataControllers.map((k, v) => MapEntry(k, v.text.trim()))
            : null,
      };

      if (widget.assetId != null) {
        await client.put('/api/families/current/assets/${widget.assetId}', data: body);
      } else {
        await client.post('/api/families/current/assets', data: body);
      }

      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.assetId != null ? '编辑资产' : '添加资产')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assetId != null ? '编辑资产' : '添加资产'),
        actions: [
          if (_currentStep == 3)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
            } else {
              _save();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          steps: [
            Step(
              title: const Text('选择分类'),
              content: _buildClassificationStep(),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('基本信息'),
              content: _buildBasicInfoStep(),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('财务信息'),
              content: _buildFinancialStep(),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('详细信息'),
              content: _buildMetadataStep(),
              isActive: _currentStep >= 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown('性质', _nature, [
          ('tangible', '有形资产'), ('digital', '数字资产'), ('financial', '金融资产'),
          ('intangible', '无形资产'), ('service', '服务'),
        ], (v) => setState(() => _nature = v)),
        const SizedBox(height: 16),
        _buildDropdown('用途', _utility, [
          ('productive', '生产性'), ('consumable', '消耗品'), ('protective', '防护性'),
          ('speculative', '投机性'), ('lifestyle', '生活方式'), ('essential', '必需品'),
        ], (v) => setState(() => _utility = v)),
        const SizedBox(height: 16),
        _buildDropdown('持有方式', _ownership, [
          ('owned', '自有'), ('mortgaged', '抵押'), ('leased', '租赁'),
          ('subscribed', '订阅'), ('licensed', '授权'), ('custodied', '托管'),
        ], (v) => setState(() => _ownership = v)),
        const SizedBox(height: 16),
        _buildDropdown('流动性', _liquidity, [
          ('instant', '即时'), ('high', '高'), ('medium', '中'), ('low', '低'), ('fixed', '固定'),
        ], (v) => setState(() => _liquidity = v)),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '资产名称 *'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '请输入资产名称';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: '描述'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        // 标签输入
        Wrap(
          spacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('添加标签'),
              onPressed: () => _addTag(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialStep() {
    return Column(
      children: [
        TextFormField(
          controller: _purchasePriceController,
          decoration: const InputDecoration(labelText: '购买价格', prefixText: '¥'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('购买日期'),
          subtitle: Text(_purchaseDate != null
              ? '${_purchaseDate!.year}-${_purchaseDate!.month.toString().padLeft(2, '0')}-${_purchaseDate!.day.toString().padLeft(2, '0')}'
              : '点击选择'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _purchaseDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) setState(() => _purchaseDate = date);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _currencyController,
          decoration: const InputDecoration(labelText: '货币代码'),
        ),
      ],
    );
  }

  Widget _buildMetadataStep() {
    // 根据分类动态生成元数据字段
    final fields = _getMetadataFields();
    if (fields.isEmpty) {
      return const Text('当前分类无需额外信息');
    }

    return Column(
      children: fields.map((field) {
        if (!_metadataControllers.containsKey(field.$1)) {
          _metadataControllers[field.$1] = TextEditingController();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _metadataControllers[field.$1],
            decoration: InputDecoration(labelText: field.$2),
            keyboardType: field.$3 == 'number' ? TextInputType.number : TextInputType.text,
          ),
        );
      }).toList(),
    );
  }

  List<(String, String, String)> _getMetadataFields() {
    // 根据nature+utility返回适当的元数据字段
    switch (_nature) {
      case 'tangible':
        if (_utility == 'essential') {
          return [
            ('type', '类型', 'text'),
            ('brand', '品牌', 'text'),
            ('model', '型号', 'text'),
            ('year', '年份', 'number'),
          ];
        }
        return [
          ('type', '类型', 'text'),
          ('brand', '品牌', 'text'),
          ('model', '型号', 'text'),
        ];
      case 'financial':
        return [
          ('instrument_type', '金融工具类型', 'text'),
          ('ticker', '代码', 'text'),
          ('exchange', '交易所', 'text'),
          ('shares', '份额', 'number'),
        ];
      case 'service':
        return [
          ('type', '类型', 'text'),
          ('provider', '服务商', 'text'),
          ('billing_cycle', '计费周期', 'text'),
          ('billing_amount', '费用', 'number'),
        ];
      default:
        return [
          ('type', '类型', 'text'),
          ('notes', '备注', 'text'),
        ];
    }
  }

  Widget _buildDropdown(String label, String value, List<(String, String)> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: options.map((opt) => DropdownMenuItem(value: opt.$1, child: Text(opt.$2))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
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
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('添加')),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }
}
