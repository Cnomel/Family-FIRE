import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/formatters/date.dart';
import '../../shared/formatters/number.dart';
import '../../shared/theme/colors.dart';
import '../../shared/widgets/amount_text.dart';

class TradePage extends ConsumerStatefulWidget {
  final String assetId;
  final String? initialAction; // 'buy' or 'sell'

  const TradePage({super.key, required this.assetId, this.initialAction});

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> {
  Map<String, dynamic>? _asset;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _error;

  // 当前持仓信息
  double _currentShares = 0;
  double _currentPrice = 0;
  double _avgCost = 0;
  double _totalCost = 0;

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

      // 并行加载资产信息和交易记录
      final results = await Future.wait([
        client.get('/api/families/current/assets/${widget.assetId}'),
        client.get('/api/families/current/finance/transactions', queryParams: {
          'asset_id': widget.assetId,
          'page_size': 100,
        }),
      ]);

      final assetData = results[0].data['data'];
      final txData = results[1].data['data'];

      // 从metadata获取持仓信息
      final metadata = assetData['metadata'] ?? {};
      final financial = assetData['financial'] ?? {};
      final ticker = metadata['ticker'] ?? '';
      final instrumentType = metadata['instrument_type'] ?? 'fund';

      // 如果有ticker，查询最新价格
      double currentPrice = (metadata['current_price'] ?? 0).toDouble();
      if (ticker.isNotEmpty) {
        try {
          final lookupResp = await client.get(
            '/api/families/current/finance/lookup/$ticker',
            queryParams: {'instrument_type': instrumentType},
          );
          final lookupData = lookupResp.data['data'];
          if (lookupData['price'] != null) {
            currentPrice = (lookupData['price'] as num).toDouble();
          }
        } catch (e) {
          // 查询失败使用metadata中的价格
        }
      }

      setState(() {
        _asset = assetData;
        _transactions = txData?['transactions'] ?? [];

        _currentShares = (metadata['shares'] ?? 0).toDouble();
        _currentPrice = currentPrice;
        _totalCost = (financial['purchase_price'] ?? 0).toDouble();
        _avgCost = _currentShares > 0 ? _totalCost / _currentShares : 0;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('交易')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('交易')),
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
      final name = asset['name'] ?? '';
      final marketValue = _currentShares * _currentPrice;
    final profit = marketValue - _totalCost;
    final profitRate = _totalCost > 0 ? (profit / _totalCost * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$name 持仓'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 收益概览
          _buildProfitCard(marketValue, profit, profitRate),
          const SizedBox(height: 16),

          // 持仓信息
          _buildHoldingInfo(),
          const SizedBox(height: 16),

          // 交易按钮
          _buildTradeButtons(),
          const SizedBox(height: 24),

          // 交易明细
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildProfitCard(double marketValue, double profit, double profitRate) {
    final isPositive = profit >= 0;
    final profitColor = isPositive ? Colors.red : Colors.green; // 红涨绿跌

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 累计收益
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('累计收益 ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  formatCurrency(profit),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: profitColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 浮盈/浮亏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: profitColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${isPositive ? "浮盈" : "浮亏"} ${profitRate.toStringAsFixed(2)}%',
                style: TextStyle(color: profitColor, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            // 详细数据
            Row(
              children: [
                Expanded(child: _buildStatItem('当前', marketValue, suffix: '')),
                Expanded(child: _buildStatItem('成本', _totalCost, suffix: '')),
                Expanded(child: _buildStatItem('盈利', profit, suffix: '')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, {String suffix = ''}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        AmountText(amount: value, fontSize: 16, fontWeight: FontWeight.w600),
        if (suffix.isNotEmpty)
          Text(suffix, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHoldingInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('持仓信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildInfoRow('持有份额', formatNumber(_currentShares)),
            _buildInfoRow('买入均价', formatCurrency(_avgCost)),
            _buildInfoRow('当前价格', formatCurrency(_currentPrice)),
            _buildInfoRow('市值', formatCurrency(_currentShares * _currentPrice)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTradeButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showTradeDialog('buy'),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('买入'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.loss,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentShares > 0 ? () => _showTradeDialog('sell') : null,
            icon: const Icon(Icons.sell),
            label: const Text('卖出'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.profit,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    // 按日期分组
    final Map<String, List<dynamic>> groupedTx = {};
    for (final tx in _transactions) {
      final date = tx['date'] != null ? DateTime.parse(tx['date']) : null;
      final dateKey = date != null ? formatDateShort(date) : '未知日期';
      groupedTx.putIfAbsent(dateKey, () => []).add(tx);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('交易明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('共 ${_transactions.length} 条', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey))),
              )
            else
              ...groupedTx.entries.map((entry) => _buildDateGroup(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGroup(String dateLabel, List<dynamic> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            dateLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ),
        // 该日期下的交易
        ...transactions.map((tx) => _buildTransactionItem(tx)),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['type'] ?? '';
    final isBuy = type == 'buy';
    final quantity = (tx['quantity'] ?? 0).toDouble();
    final price = (tx['price'] ?? 0).toDouble();
    final total = (tx['total'] ?? 0).toDouble();
    final date = tx['date'] != null ? DateTime.parse(tx['date']) : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 类型标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isBuy ? Colors.red.withAlpha(20) : Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isBuy ? '买入' : '卖出',
              style: TextStyle(
                fontSize: 12,
                color: isBuy ? Colors.red : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 详情
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatNumber(quantity)} 份 × ${formatCurrency(price)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (date != null)
                  Text(
                    formatDateShort(date),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          // 金额
          Text(
            '${isBuy ? "-" : "+"}${formatCurrency(total)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isBuy ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTradeDialog(String action) async {
    final isBuy = action == 'buy';
    final sharesController = TextEditingController();
    final priceController = TextEditingController(text: _currentPrice.toStringAsFixed(4));
    DateTime tradeDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final shares = double.tryParse(sharesController.text) ?? 0;
          final price = double.tryParse(priceController.text) ?? 0;
          final total = shares * price;

          return AlertDialog(
            title: Text(isBuy ? '确认买入' : '确认卖出'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 当前价格显示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('当前价格', style: TextStyle(color: Colors.grey)),
                        Text(formatCurrency(_currentPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 交易日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('交易日期'),
                    subtitle: Text(formatDateShort(tradeDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: tradeDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() => tradeDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 份额输入
                  TextField(
                    controller: sharesController,
                    decoration: InputDecoration(
                      labelText: '份额',
                      hintText: isBuy ? '输入买入份额' : '输入卖出份额',
                      suffixText: '份',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // 价格输入
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: '交易价格',
                      prefixText: '¥',
                      hintText: '输入交易价格',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),

                // 交易金额
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isBuy ? Colors.red : Colors.green).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isBuy ? '买入金额' : '卖出金额', style: const TextStyle(color: Colors.grey)),
                      Text(
                        formatCurrency(total),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isBuy ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                // 卖出时显示可卖份额
                if (!isBuy) ...[
                  const SizedBox(height: 8),
                  Text(
                    '可卖出份额: ${formatNumber(_currentShares)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final shares = double.tryParse(sharesController.text) ?? 0;
                  final price = double.tryParse(priceController.text) ?? 0;

                  if (shares <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入有效份额')),
                    );
                    return;
                  }
                  if (price <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入有效价格')),
                    );
                    return;
                  }
                  if (!isBuy && shares > _currentShares) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('卖出份额不能超过持有份额')),
                    );
                    return;
                  }

                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBuy ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(isBuy ? '确认买入' : '确认卖出'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final shares = double.tryParse(sharesController.text) ?? 0;
      final price = double.tryParse(priceController.text) ?? 0;
      await _executeTrade(action, shares, price, tradeDate);
    }
  }

  Future<void> _executeTrade(String action, double shares, double price, DateTime tradeDate) async {
    try {
      final client = ref.read(apiClientProvider);
      final total = shares * price;

      await client.post('/api/families/current/finance/transactions', data: {
        'asset_id': widget.assetId,
        'type': action,
        'quantity': shares,
        'price': price,
        'total': total,
        'date': tradeDate.toIso8601String(),
        'notes': action == 'buy' ? '买入' : '卖出',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${action == "buy" ? "买入" : "卖出"}成功')),
        );
        _loadData(); // 刷新数据
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('交易失败: $e')),
        );
      }
    }
  }
}
