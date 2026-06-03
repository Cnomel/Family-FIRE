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
  // Step 1: 分类选择
  String _nature = 'tangible';
  String _utility = 'essential';
  String _ownership = 'owned';
  String _liquidity = 'medium';
  String _instrumentType = 'fund'; // 金融工具类型

  // 分类标签映射
  static const _natureLabels = {
    'tangible': '有形资产',
    'digital': '数字资产',
    'financial': '金融资产',
    'intangible': '无形资产',
    'service': '服务',
  };
  static const _utilityLabels = {
    'productive': '生产性',
    'consumable': '消耗品',
    'protective': '防护性',
    'speculative': '投机性',
    'lifestyle': '生活方式',
    'essential': '必需品',
  };
  static const _ownershipLabels = {
    'owned': '自有',
    'mortgaged': '抵押',
    'leased': '租赁',
    'subscribed': '订阅',
    'licensed': '授权',
    'custodied': '托管',
  };
  static const _liquidityLabels = {
    'instant': '即时',
    'high': '高',
    'medium': '中',
    'low': '低',
    'fixed': '固定',
  };
  static const _instrumentTypeLabels = {
    'fund': '场外基金',
    'etf': '场内基金',
    'stock': '股票',
    'bond': '债券/国债',
    'money_market': '货币基金',
    'cd': '定期存款',
    'crypto': '加密货币',
  };

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
            if (key == 'instrument_type') {
              _instrumentType = value?.toString() ?? 'fund';
            } else {
              _metadataControllers[key] = TextEditingController(text: value?.toString() ?? '');
            }
          });
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final client = ref.read(apiClientProvider);

      // 金融资产：如果当前价格为空，先查询最新价格
      if (_nature == 'financial' && _metadataControllers['ticker']?.text.isNotEmpty == true) {
        final currentPrice = _metadataControllers['current_price']?.text;
        if (currentPrice == null || currentPrice.isEmpty || currentPrice == '0') {
          await _lookupInstrument(_instrumentType);
        }
      }

      // 构建metadata
      Map<String, dynamic>? metadata;
      if (_nature == 'financial') {
        metadata = {
          'instrument_type': _instrumentType,
          if (_metadataControllers['ticker']?.text.isNotEmpty == true)
            'ticker': _metadataControllers['ticker']!.text.trim(),
          if (_metadataControllers['exchange']?.text.isNotEmpty == true)
            'exchange': _metadataControllers['exchange']!.text.trim(),
          if (_metadataControllers['shares']?.text.isNotEmpty == true)
            'shares': double.tryParse(_metadataControllers['shares']!.text) ?? 0,
          if (_metadataControllers['current_price']?.text.isNotEmpty == true)
            'current_price': double.tryParse(_metadataControllers['current_price']!.text) ?? 0,
          if (_metadataControllers['expected_yield']?.text.isNotEmpty == true)
            'expected_yield': double.tryParse(_metadataControllers['expected_yield']!.text) ?? 0,
          if (_metadataControllers['annual_income']?.text.isNotEmpty == true)
            'annual_income': double.tryParse(_metadataControllers['annual_income']!.text) ?? 0,
        };
      } else if (_metadataControllers.isNotEmpty) {
        metadata = _metadataControllers.map((k, v) => MapEntry(k, v.text.trim()));
      }

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
        'metadata_type': _nature == 'financial' ? 'financial' : _metadataType,
        'metadata': metadata,
      };

      if (widget.assetId != null) {
        await client.put('/api/families/current/assets/${widget.assetId}', data: body);
      } else {
        await client.post('/api/families/current/assets', data: body);
      }

      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
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
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) {
            setState(() => _currentStep = step);
          },
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
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 3;
            final showBack = _currentStep > 0 || isLastStep;
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  if (showBack)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.grey[800],
                        ),
                        child: Text(isLastStep ? '取消' : '上一步'),
                      ),
                    ),
                  if (showBack) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : details.onStepContinue,
                      child: _isSaving && isLastStep
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isLastStep ? '完成' : '下一步'),
                    ),
                  ),
                ],
              ),
            );
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
    final isEditing = widget.assetId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 快速分类
        const Text('选择资产类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          isEditing ? '点击快速切换分类' : '点击选择，后续可在编辑中修改',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // 房产车辆
            _buildTemplateChip('房产', Icons.home, 'tangible', 'essential', 'owned', 'low'),
            _buildTemplateChip('汽车', Icons.directions_car, 'tangible', 'essential', 'owned', 'low'),
            // 金融投资
            _buildTemplateChip('股票', Icons.show_chart, 'financial', 'speculative', 'custodied', 'high', instrumentType: 'stock'),
            _buildTemplateChip('场外基金', Icons.account_balance_wallet, 'financial', 'productive', 'custodied', 'medium', instrumentType: 'fund'),
            _buildTemplateChip('场内基金', Icons.pie_chart, 'financial', 'productive', 'custodied', 'high', instrumentType: 'etf'),
            _buildTemplateChip('存款', Icons.savings, 'financial', 'protective', 'owned', 'instant', instrumentType: 'cd'),
            _buildTemplateChip('国债', Icons.account_balance, 'financial', 'protective', 'owned', 'fixed', instrumentType: 'bond'),
            _buildTemplateChip('保险', Icons.shield, 'service', 'protective', 'subscribed', 'fixed'),
            // 服饰鞋包
            _buildTemplateChip('服饰鞋包', Icons.checkroom, 'tangible', 'essential', 'owned', 'low'),
            // 珠宝配饰
            _buildTemplateChip('珠宝配饰', Icons.diamond, 'tangible', 'speculative', 'owned', 'low'),
            // 数码家电
            _buildTemplateChip('数码家电', Icons.devices, 'tangible', 'lifestyle', 'owned', 'medium'),
            // 生活用品
            _buildTemplateChip('生活用品', Icons.shopping_basket, 'tangible', 'consumable', 'owned', 'low'),
            // 会员订阅
            _buildTemplateChip('会员订阅', Icons.subscriptions, 'service', 'lifestyle', 'subscribed', 'instant'),
            // 其他
            _buildTemplateChip('收藏品', Icons.brush, 'tangible', 'speculative', 'owned', 'low'),
            _buildTemplateChip('虚拟账号', Icons.account_circle, 'digital', 'lifestyle', 'licensed', 'fixed'),
          ],
        ),

        // 显示已选择的分类
        if (_nature.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(64),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(64),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '当前分类',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildClassificationRow('性质', _nature, _natureLabels),
                const SizedBox(height: 6),
                _buildClassificationRow('用途', _utility, _utilityLabels),
                const SizedBox(height: 6),
                _buildClassificationRow('持有', _ownership, _ownershipLabels),
                const SizedBox(height: 6),
                _buildClassificationRow('流动', _liquidity, _liquidityLabels),
                if (_nature == 'financial') ...[
                  const SizedBox(height: 6),
                  _buildClassificationRow('工具', _instrumentType, _instrumentTypeLabels),
                ],
              ],
            ),
          ),
        ],

        // 编辑模式：显示详细分类
        if (isEditing) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('详细分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildDropdownWithHint('性质', _nature, [
            ('tangible', '有形资产', '实物存在的物品，如房产、车辆、家电'),
            ('digital', '数字资产', '数字空间的资产，如账号、数据、虚拟物品'),
            ('financial', '金融资产', '货币或证券形式，如股票、基金、存款'),
            ('intangible', '无形资产', '无实物但有价值的权利，如专利、商标'),
            ('service', '服务', '持续消费的服务，如保险、订阅、会员'),
          ], (v) {
            setState(() {
              _nature = v;
              if (v == 'financial' && !_isFinancialType(_instrumentType)) {
                _instrumentType = 'fund';
              }
            });
          }),
          const SizedBox(height: 16),
          _buildDropdownWithHint('用途', _utility, [
            ('productive', '生产性', '能产生收益，如出租房、投资组合'),
            ('consumable', '消耗品', '使用后会减少，如日用品、食品'),
            ('protective', '防护性', '提供保障，如保险、应急基金'),
            ('speculative', '投机性', '以增值为目的的高风险资产'),
            ('lifestyle', '生活方式', '提升生活品质但不产生收益'),
            ('essential', '必需品', '生活必需的基础设施'),
          ], (v) => setState(() => _utility = v)),
          const SizedBox(height: 16),
          _buildDropdownWithHint('持有方式', _ownership, [
            ('owned', '自有', '完全拥有所有权'),
            ('mortgaged', '抵押', '贷款购买，银行持有抵押权'),
            ('leased', '租赁', '租来的资产，不拥有所有权'),
            ('subscribed', '订阅', '定期付费获取使用权'),
            ('licensed', '授权', '通过授权/许可获得使用权'),
            ('custodied', '托管', '由第三方机构代为保管'),
          ], (v) => setState(() => _ownership = v)),
          const SizedBox(height: 16),
          _buildDropdownWithHint('流动性', _liquidity, [
            ('instant', '即时', '秒级变现，如活期存款、余额宝'),
            ('high', '高', '天级变现，如股票、ETF'),
            ('medium', '中', '周/月级变现，如理财产品'),
            ('low', '低', '月/年级变现，如房产、车辆'),
            ('fixed', '固定', '到期前无法变现，如定期存款'),
          ], (v) => setState(() => _liquidity = v)),
        ],
      ],
    );
  }

  Widget _buildClassificationRow(String label, String value, Map<String, String> labels) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            labels[value] ?? value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateChip(String label, IconData icon, String nature, String utility, String ownership, String liquidity, {String? instrumentType}) {
    final isSelected = _nature == nature && _utility == utility && _ownership == ownership && _liquidity == liquidity;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary),
      label: Text(label),
      backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
      labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : null),
      onPressed: () {
        setState(() {
          _nature = nature;
          _utility = utility;
          _ownership = ownership;
          _liquidity = liquidity;
          if (instrumentType != null) {
            _instrumentType = instrumentType;
          }
        });
      },
    );
  }

  Widget _buildDropdownWithHint(String label, String value, List<(String, String, String)> options, ValueChanged<String> onChanged) {
    final currentHint = options.where((o) => o.$1 == value).map((o) => o.$3).firstOrNull ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: options.map((opt) => DropdownMenuItem(
            value: opt.$1,
            child: Text(opt.$2),
          )).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        if (currentHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(currentHint, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
      ],
    );
  }

  bool _isFinancialType(String type) {
    return ['fund', 'etf', 'stock', 'bond', 'money_market', 'cd', 'crypto'].contains(type);
  }

  Widget _buildBasicInfoStep() {
    final isFinancial = _nature == 'financial';
    final isDepositOrCash = _instrumentType == 'cd' || _instrumentType == 'money_market';
    final isBond = _instrumentType == 'bond';
    final showCodeInput = isFinancial && !isDepositOrCash && !isBond; // 存款、货币基金、国债不需要证券代码

    // 确保控制器存在
    if (isFinancial && !_metadataControllers.containsKey('ticker')) {
      _metadataControllers['ticker'] = TextEditingController();
    }
    if (isFinancial && !_metadataControllers.containsKey('shares')) {
      _metadataControllers['shares'] = TextEditingController();
    }
    if (isFinancial && !_metadataControllers.containsKey('current_price')) {
      _metadataControllers['current_price'] = TextEditingController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 金融资产：证券代码查询（放在最前面，查询后自动填充名称）
        if (showCodeInput) ...[
          const Text('证券代码', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _metadataControllers['ticker'],
                    decoration: InputDecoration(
                      hintText: _instrumentType == 'fund' ? '如 110022' : _instrumentType == 'stock' ? '如 AAPL、600519' : '如 510300',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: ElevatedButton(
                    onPressed: () => _lookupInstrument(_instrumentType),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('查询'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange[600]),
              const SizedBox(width: 4),
              Text(
                '查询后自动填充名称和市场价',
                style: TextStyle(fontSize: 12, color: Colors.orange[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          // 查询结果
          if (_metadataControllers['current_price']?.text.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withAlpha(64)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '当前市场价: ${_currencyController.text == 'USD' ? '\$' : '¥'}${_metadataControllers['current_price']!.text}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // 资产名称
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '资产名称 *',
            hintText: showCodeInput ? '查询代码后自动填充' : null,
          ),
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
    final isFinancial = _nature == 'financial';
    final isDepositOrCash = _instrumentType == 'cd' || _instrumentType == 'money_market';
    final isBond = _instrumentType == 'bond';
    final needsShares = isFinancial && !isDepositOrCash && !isBond; // 存款、货币基金、国债不需要份额

    // 确保控制器存在
    if (needsShares && !_metadataControllers.containsKey('shares')) {
      _metadataControllers['shares'] = TextEditingController();
    }

    return Column(
      children: [
        TextFormField(
          controller: _purchasePriceController,
          decoration: InputDecoration(
            labelText: isFinancial ? '总投入金额' : '购买价格',
            prefixText: '¥',
            hintText: isFinancial ? '你总共投入的金额' : null,
          ),
          keyboardType: TextInputType.number,
        ),
        if (needsShares) ...[
          const SizedBox(height: 8),
          Text(
            '填写你实际投入的总金额，如买入20000份花了20000元',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
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
        // 金融资产：持有份额
        if (needsShares) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _metadataControllers['shares'],
            decoration: const InputDecoration(
              labelText: '持有份额',
              hintText: '如 1000',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            '填写你持有的份额数量',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataStep() {
    // 金融资产使用特殊表单
    if (_nature == 'financial') {
      return _buildFinancialMetadataStep();
    }

    // 其他资产使用通用字段
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

  Widget _buildFinancialMetadataStep() {
    final isDeposit = _instrumentType == 'cd';
    final isMoneyMarket = _instrumentType == 'money_market';
    final isBond = _instrumentType == 'bond';
    final isOpenEndFund = _instrumentType == 'fund'; // 场外基金
    final isEtf = _instrumentType == 'etf'; // 场内基金
    final needsYieldRate = isDeposit || isMoneyMarket || isBond; // 存款、货币基金、国债：输入收益率
    final needsIncomeAmount = isOpenEndFund || isEtf; // 基金：输入收益金额
    final needsExchange = isEtf || _instrumentType == 'stock' || _instrumentType == 'crypto'; // 场内基金/股票/加密货币需要交易所

    // 确保控制器存在
    if (needsExchange && !_metadataControllers.containsKey('exchange')) {
      _metadataControllers['exchange'] = TextEditingController();
    }
    if (needsYieldRate && !_metadataControllers.containsKey('expected_yield')) {
      _metadataControllers['expected_yield'] = TextEditingController();
    }
    if (needsIncomeAmount && !_metadataControllers.containsKey('annual_income')) {
      _metadataControllers['annual_income'] = TextEditingController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 显示已选择的类型
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(64),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(_getInstrumentTypeIcon(_instrumentType), size: 24, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选择：${_getInstrumentTypeLabel(_instrumentType)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _getInstrumentTypeHint(_instrumentType),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 收益率输入（存款、货币基金、国债）
        if (needsYieldRate) ...[
          const SizedBox(height: 20),
          TextFormField(
            controller: _metadataControllers['expected_yield'],
            decoration: const InputDecoration(
              labelText: '年化收益率',
              suffixText: '%',
              hintText: '如 2.5',
              helperText: '用于计算被动收入',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withAlpha(64)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '填写年化收益率后，系统将自动计算预计被动收入',
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 收益金额输入（基金）
        if (needsIncomeAmount) ...[
          const SizedBox(height: 20),
          TextFormField(
            controller: _metadataControllers['annual_income'],
            decoration: const InputDecoration(
              labelText: '年收益金额',
              prefixText: '¥',
              hintText: '如 5000',
              helperText: '填写每年实际收到的收益金额（分红等）',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withAlpha(64)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOpenEndFund
                        ? '场外基金每日更新净值，收益填写实际分红金额'
                        : '场内基金实时交易，收益填写实际分红金额',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 存款类/国债：显示提示
        if (isDeposit || isMoneyMarket || isBond) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withAlpha(64)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_getInstrumentTypeLabel(_instrumentType)}只需在上一步填写总金额，然后填写年化收益率即可',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 交易所（可选，仅股票/加密货币等显示）
        if (needsExchange) ...[
          const SizedBox(height: 24),
          TextFormField(
            controller: _metadataControllers['exchange'],
            decoration: const InputDecoration(
              labelText: '交易所（可选）',
              hintText: '如 NASDAQ、NYSE、上交所、深交所',
            ),
          ),
        ],
      ],
    );
  }

  String _getInstrumentTypeLabel(String type) {
    switch (type) {
      case 'fund': return '场外基金';
      case 'etf': return '场内基金';
      case 'stock': return '股票';
      case 'bond': return '国债';
      case 'money_market': return '货币基金';
      case 'cd': return '定期存款';
      case 'crypto': return '加密货币';
      default: return type;
    }
  }

  IconData _getInstrumentTypeIcon(String type) {
    switch (type) {
      case 'fund': return Icons.account_balance_wallet;
      case 'etf': return Icons.pie_chart;
      case 'stock': return Icons.trending_up;
      case 'bond': return Icons.account_balance;
      case 'money_market': return Icons.savings;
      case 'cd': return Icons.lock;
      case 'crypto': return Icons.currency_bitcoin;
      default: return Icons.attach_money;
    }
  }

  String _getInstrumentTypeHint(String type) {
    switch (type) {
      case 'fund': return '如 110022（易方达蓝筹精选）- 每日更新净值';
      case 'etf': return '如 510300（沪深300ETF）- 实时交易价格';
      case 'stock': return '如 600519（贵州茅台）、AAPL';
      case 'bond': return '如国债，填写年化收益率';
      case 'money_market': return '如余额宝、零钱通';
      case 'cd': return '银行定期存款';
      case 'crypto': return '如 BTC、ETH';
      default: return '';
    }
  }

  Future<void> _lookupInstrument(String instrumentType) async {
    final ticker = _metadataControllers['ticker']?.text.trim() ?? '';
    if (ticker.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入代码')));
      return;
    }

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/finance/lookup/$ticker', queryParams: {
        'instrument_type': instrumentType,
      });

      if (mounted) Navigator.pop(context); // 关闭加载对话框

      final data = response.data['data'];
      final price = data['price'] as double?;
      final name = data['name'] as String?;
      final currency = data['currency'] as String? ?? 'CNY';

      if (price != null) {
        final currencySymbol = currency == 'USD' ? '\$' : '¥';
        // 每次查询都更新名称（跟随代码变化）
        setState(() {
          if (name != null && name.isNotEmpty) {
            _nameController.text = name;
          }
          // 将当前价格存到metadata控制器中
          _metadataControllers['current_price']?.text = price.toString();
          // 更新货币
          _currencyController.text = currency;
        });

        if (mounted) {
          final nameInfo = name != null ? ' ($name)' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('查询成功$nameInfo: 当前市场价 $currencySymbol${price.toStringAsFixed(4)}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到价格信息，请手动输入')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 关闭加载对话框
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查询失败，请手动输入')),
        );
      }
    }
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
