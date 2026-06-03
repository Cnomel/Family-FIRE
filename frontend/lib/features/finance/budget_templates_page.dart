import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class BudgetTemplatesPage extends ConsumerStatefulWidget {
  const BudgetTemplatesPage({super.key});

  @override
  ConsumerState<BudgetTemplatesPage> createState() => _BudgetTemplatesPageState();
}

class _BudgetTemplatesPageState extends ConsumerState<BudgetTemplatesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _expenseTemplates = [];
  List<dynamic> _incomeTemplates = [];
  bool _isLoading = true;
  bool _showSystemTemplates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        client.get('/api/families/current/finance/expense-templates'),
        client.get('/api/families/current/finance/income-templates'),
      ]);

      setState(() {
        _expenseTemplates = results[0].data['data'] ?? [];
        _incomeTemplates = results[1].data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收支项管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出项'),
            Tab(text: '收入项'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateList('expense'),
                _buildTemplateList('income'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTemplateList(String type) {
    final templates = type == 'expense' ? _expenseTemplates : _incomeTemplates;
    final systemTemplates = templates.where((t) => t['is_system'] == true).toList();
    final customTemplates = templates.where((t) => t['is_system'] != true && t['is_fixed'] == true).toList();
    final tempTemplates = templates.where((t) => t['is_system'] != true && t['is_fixed'] != true).toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _getItemCount(systemTemplates, customTemplates, tempTemplates),
      onReorder: (oldIndex, newIndex) => _handleReorder(oldIndex, newIndex, type),
      itemBuilder: (context, index) {
        return _buildItemByIndex(index, systemTemplates, customTemplates, tempTemplates, type);
      },
    );
  }

  int _getItemCount(List system, List custom, List temp) {
    int count = 0;
    if (system.isNotEmpty) {
      count += 1; // Section header
      if (_showSystemTemplates) count += system.length;
    }
    if (custom.isNotEmpty) {
      count += 1; // Section header
      count += custom.length;
    }
    if (temp.isNotEmpty) {
      count += 1; // Section header
      count += temp.length;
    }
    return count;
  }

  Widget _buildItemByIndex(int index, List system, List custom, List temp, String type) {
    int currentIndex = 0;

    // System templates section
    if (system.isNotEmpty) {
      if (index == currentIndex) {
        return _buildSystemSectionHeader(key: const ValueKey('system_header'));
      }
      currentIndex++;
      if (_showSystemTemplates) {
        if (index < currentIndex + system.length) {
          final template = system[index - currentIndex];
          return _buildTemplateCard(template, type, isSystem: true, key: ValueKey('system_${template['id']}'));
        }
        currentIndex += system.length;
      }
    }

    // Custom fixed templates section
    if (custom.isNotEmpty) {
      if (index == currentIndex) {
        return _buildSectionHeader('自定义固定项', Icons.push_pin, Colors.blue, key: const ValueKey('custom_header'));
      }
      currentIndex++;
      if (index < currentIndex + custom.length) {
        final template = custom[index - currentIndex];
        return _buildTemplateCard(template, type, key: ValueKey('custom_${template['id']}'));
      }
      currentIndex += custom.length;
    }

    // Temporary templates section
    if (temp.isNotEmpty) {
      if (index == currentIndex) {
        return _buildSectionHeader('临时项', Icons.trending_up, Colors.orange, key: const ValueKey('temp_header'));
      }
      currentIndex++;
      if (index < currentIndex + temp.length) {
        final template = temp[index - currentIndex];
        return _buildTemplateCard(template, type, key: ValueKey('temp_${template['id']}'));
      }
    }

    return const SizedBox.shrink(key: ValueKey('empty'));
  }

  Future<void> _handleReorder(int oldIndex, int newIndex, String type) async {
    // 获取当前类型的模板列表
    final templates = type == 'expense' ? _expenseTemplates : _incomeTemplates;
    final customTemplates = templates.where((t) => t['is_system'] != true && t['is_fixed'] == true).toList();
    final tempTemplates = templates.where((t) => t['is_system'] != true && t['is_fixed'] != true).toList();

    // 计算实际的索引（跳过section header）
    int customStart = _showSystemTemplates ? (templates.where((t) => t['is_system'] == true).length + 1) : 1;
    int tempStart = customStart + customTemplates.length + 1;

    // 只允许在同类型内排序
    if (oldIndex >= customStart && oldIndex < customStart + customTemplates.length &&
        newIndex >= customStart && newIndex < customStart + customTemplates.length) {
      // Custom templates reorder
      final adjustedOld = oldIndex - customStart;
      final adjustedNew = newIndex - customStart;
      if (adjustedNew > adjustedOld) {
        // Moving down - adjust for the item being removed
        await _updateSortOrder(customTemplates, adjustedOld, adjustedNew - 1, type);
      } else {
        await _updateSortOrder(customTemplates, adjustedOld, adjustedNew, type);
      }
    } else if (oldIndex >= tempStart && oldIndex < tempStart + tempTemplates.length &&
               newIndex >= tempStart && newIndex < tempStart + tempTemplates.length) {
      // Temp templates reorder
      final adjustedOld = oldIndex - tempStart;
      final adjustedNew = newIndex - tempStart;
      if (adjustedNew > adjustedOld) {
        await _updateSortOrder(tempTemplates, adjustedOld, adjustedNew - 1, type);
      } else {
        await _updateSortOrder(tempTemplates, adjustedOld, adjustedNew, type);
      }
    }
  }

  Future<void> _updateSortOrder(List<dynamic> templates, int oldIndex, int newIndex, String type) async {
    try {
      final client = ref.read(apiClientProvider);
      final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
      
      // 更新被移动项的排序
      final movedItem = templates[oldIndex];
      await client.put(
        '/api/families/current/finance/$endpoint/${movedItem['id']}',
        data: {'sort_order': newIndex},
      );
      
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('排序失败: $e')),
        );
      }
    }
  }

  Widget _buildSystemSectionHeader({Key? key}) {
    return ListTile(
      key: key,
      leading: const Icon(Icons.lock, size: 16, color: Colors.grey),
      title: const Text(
        '系统固定项',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: Icon(
          _showSystemTemplates ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() => _showSystemTemplates = !_showSystemTemplates);
        },
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {Key? key}) {
    return ListTile(
      key: key,
      leading: Icon(icon, size: 16, color: color),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template, String type, {bool isSystem = false, Key? key}) {
    final name = template['name'] ?? '';
    final expectedMin = (template['expected_min'] ?? 0).toDouble();
    final expectedMax = (template['expected_max'] ?? 0).toDouble();
    final isFixed = template['is_fixed'] == true;
    final hasRange = expectedMin > 0 || expectedMax > 0;

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getIconData(template['icon']),
          color: type == 'expense' ? Colors.red : Colors.green,
        ),
        title: Text(name),
        subtitle: type == 'expense'
            ? Text(
                hasRange
                    ? '预期: ¥${expectedMin.toStringAsFixed(0)} - ¥${expectedMax.toStringAsFixed(0)}'
                    : '点击设置支出范围',
                style: TextStyle(
                  fontSize: 12,
                  color: hasRange ? null : Colors.grey,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'expense')
              IconButton(
                icon: const Icon(Icons.tune, size: 20),
                onPressed: () => _showRangeDialog(template, type),
                tooltip: '设置支出范围',
              ),
            if (!isSystem)
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  if (!isFixed)
                    const PopupMenuItem(value: 'upgrade', child: Text('升级为固定项')),
                  if (isFixed && !isSystem)
                    const PopupMenuItem(value: 'downgrade', child: Text('设为临时项')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') _editTemplate(template, type);
                  if (value == 'upgrade') _updateFixed(template, type, true);
                  if (value == 'downgrade') _updateFixed(template, type, false);
                  if (value == 'delete') _deleteTemplate(template, type);
                },
              ),
            if (isSystem)
              const Icon(Icons.lock, color: Colors.grey, size: 20),
          ],
        ),
        onTap: type == 'expense' ? () => _showRangeDialog(template, type) : null,
      ),
    );
  }

  Future<void> _showRangeDialog(Map<String, dynamic> template, String type) async {
    final minController = TextEditingController(
      text: (template['expected_min'] ?? 0).toString(),
    );
    final maxController = TextEditingController(
      text: (template['expected_max'] ?? 0).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置支出范围 - ${template['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置每月预期支出范围，用于FIRE计算',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minController,
                decoration: const InputDecoration(
                  labelText: '最小值',
                  prefixText: '¥',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxController,
                decoration: const InputDecoration(
                  labelText: '最大值',
                  prefixText: '¥',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FIRE计算使用平均值: ¥${_calculateAverage(minController.text, maxController.text)}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final client = ref.read(apiClientProvider);
        final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
        await client.put(
          '/api/families/current/finance/$endpoint/${template['id']}',
          data: {
            'expected_min': double.tryParse(minController.text) ?? 0,
            'expected_max': double.tryParse(maxController.text) ?? 0,
          },
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
    }
  }

  String _calculateAverage(String min, String max) {
    final minVal = double.tryParse(min) ?? 0;
    final maxVal = double.tryParse(max) ?? 0;
    return ((minVal + maxVal) / 2).toStringAsFixed(0);
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final minController = TextEditingController();
    final maxController = TextEditingController();
    bool isFixed = true;
    String type = _tabController.index == 0 ? 'expense' : 'income';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('添加${type == 'expense' ? '支出' : '收入'}项'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                if (type == 'expense') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: minController,
                    decoration: const InputDecoration(labelText: '预期最小值', prefixText: '¥'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxController,
                    decoration: const InputDecoration(labelText: '预期最大值', prefixText: '¥'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('固定项'),
                  subtitle: const Text('每月自动显示'),
                  value: isFixed,
                  onChanged: (v) => setDialogState(() => isFixed = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
        await client.post('/api/families/current/finance/$endpoint', data: {
          'name': nameController.text.trim(),
          'expected_min': double.tryParse(minController.text) ?? 0,
          'expected_max': double.tryParse(maxController.text) ?? 0,
          'is_fixed': isFixed,
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _editTemplate(Map<String, dynamic> template, String type) async {
    final nameController = TextEditingController(text: template['name']);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final client = ref.read(apiClientProvider);
        final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
        await client.put(
          '/api/families/current/finance/$endpoint/${template['id']}',
          data: {'name': nameController.text.trim()},
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateFixed(Map<String, dynamic> template, String type, bool isFixed) async {
    try {
      final client = ref.read(apiClientProvider);
      final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
      await client.put(
        '/api/families/current/finance/$endpoint/${template['id']}',
        data: {'is_fixed': isFixed},
      );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFixed ? '已升级为固定项' : '已设为临时项')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> template, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${template['name']}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
        final endpoint = type == 'expense' ? 'expense-templates' : 'income-templates';
        await client.delete('/api/families/current/finance/$endpoint/${template['id']}');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'bolt':
        return Icons.bolt;
      case 'phone':
        return Icons.phone;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'security':
        return Icons.security;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'movie':
        return Icons.movie;
      case 'work':
        return Icons.work;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'trending_up':
        return Icons.trending_up;
      case 'business_center':
        return Icons.business_center;
      default:
        return Icons.category;
    }
  }
}
