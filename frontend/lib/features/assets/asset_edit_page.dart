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

      // 金融资产：如果有单价和份额，计算总金额
      if (_nature == 'financial') {
        final shares = double.tryParse(_metadataControllers['shares']?.text ?? '');
        final currentPrice = double.tryParse(_metadataControllers['current_price']?.text ?? '');
        
        // 如果有市场价和份额，用 市场价 × 份额 作为总金额
        // 否则用用户输入的购买价格作为总金额
        if (shares != null && shares > 0 && currentPrice != null && currentPrice > 0) {
          _purchasePriceController.text = (shares * currentPrice).toString();
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
        // 常见资产模板
        const Text('快速选择', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('点击即可自动填充分类', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTemplateChip('房产', Icons.home, 'tangible', 'essential', 'owned', 'low'),
            _buildTemplateChip('汽车', Icons.directions_car, 'tangible', 'essential', 'owned', 'low'),
            _buildTemplateChip('股票', Icons.show_chart, 'financial', 'speculative', 'custodied', 'high', instrumentType: 'stock'),
            _buildTemplateChip('基金', Icons.pie_chart, 'financial', 'productive', 'custodied', 'high', instrumentType: 'fund'),
            _buildTemplateChip('存款', Icons.savings, 'financial', 'protective', 'owned', 'instant', instrumentType: 'cd'),
            _buildTemplateChip('理财产品', Icons.trending_up, 'financial', 'productive', 'custodied', 'medium', instrumentType: 'fund'),
            _buildTemplateChip('保险', Icons.shield, 'service', 'protective', 'subscribed', 'fixed'),
            _buildTemplateChip('订阅服务', Icons.subscriptions, 'service', 'lifestyle', 'subscribed', 'instant'),
            _buildTemplateChip('家电', Icons.kitchen, 'tangible', 'lifestyle', 'owned', 'low'),
            _buildTemplateChip('数码产品', Icons.devices, 'tangible', 'lifestyle', 'owned', 'medium'),
            _buildTemplateChip('消耗品', Icons.shopping_basket, 'tangible', 'consumable', 'owned', 'low'),
            _buildTemplateChip('收藏品', Icons.brush, 'tangible', 'speculative', 'owned', 'low'),
            _buildTemplateChip('虚拟账号', Icons.account_circle, 'digital', 'lifestyle', 'licensed', 'fixed'),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // 手动选择
        const Text('手动分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            // 如果选择金融资产，确保instrumentType有值
            if (v == 'financial' && !_isFinancialType(_instrumentType)) {
              _instrumentType = 'fund'; // 默认基金
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
    final isFinancial = _nature == 'financial';
    final isDepositOrCash = _instrumentType == 'cd' || _instrumentType == 'money_market';
    final needsShares = isFinancial && !isDepositOrCash;

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
    // 确保控制器存在
    if (!_metadataControllers.containsKey('ticker')) {
      _metadataControllers['ticker'] = TextEditingController();
    }
    if (!_metadataControllers.containsKey('shares')) {
      _metadataControllers['shares'] = TextEditingController();
    }

    final isDeposit = _instrumentType == 'cd';
    final isMoneyMarket = _instrumentType == 'money_market';
    final showCodeInput = !isDeposit && !isMoneyMarket;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 金融工具类型选择
        const Text('选择类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        // 类型选择网格
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _buildTypeChip('基金', 'fund'),
            _buildTypeChip('ETF', 'etf'),
            _buildTypeChip('股票', 'stock'),
            _buildTypeChip('债券', 'bond'),
            _buildTypeChip('货币基金', 'money_market'),
            _buildTypeChip('定期存款', 'cd'),
            _buildTypeChip('加密货币', 'crypto'),
          ],
        ),
        const SizedBox(height: 24),

        // 存款类：显示提示
        if (isDeposit || isMoneyMarket)
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
                    '${_getInstrumentTypeLabel(_instrumentType)}只需在"财务信息"步骤填写总金额即可',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // 非存款类：显示代码和份额输入
        if (showCodeInput) ...[
          const Text('证券代码', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // 代码输入 + 查询按钮
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _metadataControllers['ticker'],
                    decoration: const InputDecoration(
                      hintText: '如 110022',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          Text(
            '输入代码点击查询，自动填充名称和获取市场价',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange[600]),
              const SizedBox(width: 4),
              Text(
                '名称会自动填写，无需手动输入',
                style: TextStyle(fontSize: 12, color: Colors.orange[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),

          // 查询结果
          if (_metadataControllers['current_price']?.text.isNotEmpty == true) ...[
            const SizedBox(height: 16),
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

          const SizedBox(height: 24),
          const Text('持有份额', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _metadataControllers['shares'],
            decoration: const InputDecoration(
              hintText: '如 1000',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _instrumentType == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _instrumentType = value);
        }
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
        fontWeight: isSelected ? FontWeight.w600 : null,
      ),
    );
  }

  String _getInstrumentTypeLabel(String type) {
    switch (type) {
      case 'fund': return '基金';
      case 'etf': return 'ETF';
      case 'stock': return '股票';
      case 'bond': return '债券';
      case 'money_market': return '货币基金';
      case 'cd': return '定期存款';
      case 'crypto': return '加密货币';
      default: return type;
    }
  }

  bool _isFinancialType(String type) {
    return ['fund', 'etf', 'stock', 'bond', 'money_market', 'cd', 'crypto'].contains(type);
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
