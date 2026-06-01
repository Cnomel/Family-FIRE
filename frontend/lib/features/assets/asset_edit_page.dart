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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 常见资产模板
        const Text('选择资产类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('点击选择，后续可在编辑中修改', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 16),
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
        // 显示已选择的类型
        if (_nature.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(64),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '已选择: ${_getTypeLabel(_nature)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getTypeLabel(String nature) {
    switch (nature) {
      case 'tangible': return '有形资产';
      case 'digital': return '数字资产';
      case 'financial': return '金融资产';
      case 'intangible': return '无形资产';
      case 'service': return '服务';
      default: return nature;
    }
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

  Widget _buildBasicInfoStep() {
    final isFinancial = _nature == 'financial';
    final isDepositOrCash = _instrumentType == 'cd' || _instrumentType == 'money_market';
    final showCodeInput = isFinancial && !isDepositOrCash;

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
    final needsShares = isFinancial && !isDepositOrCash;

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

    // 确保控制器存在
    if (!isDeposit && !isMoneyMarket && !_metadataControllers.containsKey('exchange')) {
      _metadataControllers['exchange'] = TextEditingController();
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

        // 存款类：显示提示
        if (isDeposit || isMoneyMarket) ...[
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
                    '${_getInstrumentTypeLabel(_instrumentType)}只需在上一步填写总金额即可',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 交易所（可选）
        if (!isDeposit && !isMoneyMarket) ...[
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

  IconData _getInstrumentTypeIcon(String type) {
    switch (type) {
      case 'fund': return Icons.pie_chart;
      case 'etf': return Icons.show_chart;
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
      case 'fund': return '如 110022（易方达蓝筹精选）';
      case 'etf': return '如 510300（华泰柏瑞沪深300ETF）';
      case 'stock': return '如 600519（贵州茅台）、AAPL';
      case 'bond': return '如国债、企业债代码';
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
