import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/formatters/currency.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/categories');
      setState(() {
        _categories = response.data['data'] ?? [];
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
        title: const Text('资产分类管理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyView()
              : _buildCategoryList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('暂无分类'),
          const SizedBox(height: 8),
          const Text(
            '点击右下角按钮创建分类',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      onReorder: (oldIndex, newIndex) {
        // TODO: 实现排序
      },
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildCategoryCard(category, index);
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final name = category['name'] ?? '';
    final icon = _getIconData(category['icon']);
    final color = _parseColor(category['color']);
    final assetCount = category['asset_count'] ?? 0;
    final totalValue = (category['total_value'] ?? 0).toDouble();
    final isSystem = category['is_system'] == true;

    return Card(
      key: ValueKey(category['id']),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Text(name),
            if (isSystem) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '系统',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$assetCount 个资产 · ${formatCurrency(totalValue)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isSystem
            ? const Icon(Icons.lock, color: Colors.grey, size: 20)
            : PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') _showEditDialog(category);
                  if (value == 'delete') _deleteCategory(category);
                },
              ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'category';
    String selectedColor = '#607D8B';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('创建分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '分类名称',
                    hintText: '如：投资、房产、收藏',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('选择图标', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconOptions.map((option) {
                    final isSelected = selectedIcon == option['icon'];
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = option['icon']!),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.withAlpha(50),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconData(option['icon']),
                          size: 20,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorOptions.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
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
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.post('/api/families/current/assets/categories', data: {
          'name': nameController.text.trim(),
          'icon': selectedIcon,
          'color': selectedColor,
        });
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> category) async {
    final nameController = TextEditingController(text: category['name']);
    String selectedIcon = category['icon'] ?? 'category';
    String selectedColor = category['color'] ?? '#607D8B';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '分类名称'),
                ),
                const SizedBox(height: 16),
                const Text('选择图标', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconOptions.map((option) {
                    final isSelected = selectedIcon == option['icon'];
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = option['icon']!),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.withAlpha(50),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconData(option['icon']),
                          size: 20,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorOptions.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
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
      ),
    );

    if (result == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put(
          '/api/families/current/assets/categories/${category['id']}',
          data: {
            'name': nameController.text.trim(),
            'icon': selectedIcon,
            'color': selectedColor,
          },
        );
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final assetCount = category['asset_count'] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          assetCount > 0
              ? '该分类下有 $assetCount 个资产，删除后这些资产将变为未分类。确定要删除吗？'
              : '确定要删除"${category['name']}"分类吗？',
        ),
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
        await client.delete('/api/families/current/assets/categories/${category['id']}');
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.grey;
    try {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'trending_up':
        return Icons.trending_up;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'security':
        return Icons.security;
      case 'diamond':
        return Icons.diamond;
      case 'devices':
        return Icons.devices;
      case 'weekend':
        return Icons.weekend;
      case 'category':
        return Icons.category;
      case 'savings':
        return Icons.savings;
      case 'account_balance':
        return Icons.account_balance;
      case 'show_chart':
        return Icons.show_chart;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'checkroom':
        return Icons.checkroom;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'brush':
        return Icons.brush;
      case 'subscriptions':
        return Icons.subscriptions;
      case 'cloud':
        return Icons.cloud;
      default:
        return Icons.category;
    }
  }

  static const _iconOptions = [
    {'icon': 'trending_up', 'label': '投资'},
    {'icon': 'home', 'label': '房产'},
    {'icon': 'directions_car', 'label': '车辆'},
    {'icon': 'security', 'label': '保险'},
    {'icon': 'diamond', 'label': '珠宝'},
    {'icon': 'devices', 'label': '数码'},
    {'icon': 'savings', 'label': '存款'},
    {'icon': 'account_balance', 'label': '银行'},
    {'icon': 'show_chart', 'label': '股票'},
    {'icon': 'pie_chart', 'label': '基金'},
    {'icon': 'checkroom', 'label': '服饰'},
    {'icon': 'shopping_basket', 'label': '购物'},
    {'icon': 'brush', 'label': '艺术'},
    {'icon': 'subscriptions', 'label': '订阅'},
    {'icon': 'weekend', 'label': '家居'},
    {'icon': 'cloud', 'label': '云端'},
    {'icon': 'category', 'label': '其他'},
  ];

  static const _colorOptions = [
    '#4CAF50', // 绿色
    '#2196F3', // 蓝色
    '#FF9800', // 橙色
    '#9C27B0', // 紫色
    '#E91E63', // 粉色
    '#00BCD4', // 青色
    '#795548', // 棕色
    '#607D8B', // 灰蓝
    '#F44336', // 红色
    '#3F51B5', // 靛蓝
    '#009688', // 蓝绿
    '#FF5722', // 深橙
    '#7B1FA2', // 深紫
    '#CDDC39', // 黄绿
    '#FFC107', // 琥珀
    '#1565C0', // 深蓝
  ];
}
