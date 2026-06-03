import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/formatters/currency.dart';
import '../../shared/theme/colors.dart';

class AssetListPage extends ConsumerStatefulWidget {
  const AssetListPage({super.key});

  @override
  ConsumerState<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends ConsumerState<AssetListPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _assets = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  String? _error;
  String? _searchQuery;

  // 视图模式
  AssetViewMode _viewMode = AssetViewMode.groupByCategory;

  // 筛选条件
  String? _natureFilter;

  // 批量选择模式
  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadAssets(),
      _loadCategories(),
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'page': 1,
        'page_size': 100,
      };
      if (_natureFilter != null) params['nature'] = _natureFilter;
      if (_searchQuery != null && _searchQuery!.isNotEmpty) params['search'] = _searchQuery;

      final response = await client.get(
        '/api/families/current/assets',
        queryParams: params,
      );

      final data = response.data['data'];
      final List<dynamic> assets = data['assets'] ?? [];

      setState(() {
        _assets = assets.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，请重试';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 批量操作栏
        if (_isSelectionMode) _buildSelectionBar(),
        
        // 搜索和视图切换
        _buildHeader(),
        
        // 总览卡片
        if (!_isLoading && _assets.isNotEmpty && !_isSelectionMode) _buildSummaryCard(),
        
        // 资产列表
        Expanded(
          child: _isLoading
              ? _buildLoadingView()
              : _error != null
                  ? _buildErrorView()
                  : _assets.isEmpty
                      ? _buildEmptyView()
                      : _buildAssetList(),
        ),
        
        // 添加按钮
        if (!_isSelectionMode) _buildAddButton(),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '已选择 ${_selectedAssetIds.length} 项',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('全选'),
          ),
          TextButton.icon(
            onPressed: _showSetCategoryDialog,
            icon: const Icon(Icons.category, size: 18),
            label: const Text('设置分类'),
          ),
          TextButton.icon(
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedAssetIds.clear();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
  }

  void _toggleAssetSelection(String assetId) {
    setState(() {
      if (_selectedAssetIds.contains(assetId)) {
        _selectedAssetIds.remove(assetId);
      } else {
        _selectedAssetIds.add(assetId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedAssetIds.length == _assets.length) {
        _selectedAssetIds.clear();
      } else {
        _selectedAssetIds.addAll(_assets.map((a) => a['id'] as String));
      }
    });
  }

  Future<void> _showSetCategoryDialog() async {
    if (_selectedAssetIds.isEmpty) return;

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/categories');
      final categories = response.data['data'] ?? [];

      if (!mounted) return;

      final categoryId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择分类'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Row(
                children: [
                  Icon(Icons.remove_circle_outline, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('清除分类'),
                ],
              ),
            ),
            ...categories.map((cat) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, cat['id']),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(cat['icon']),
                    color: _parseCategoryColor(cat['color']),
                  ),
                  const SizedBox(width: 12),
                  Text(cat['name']),
                ],
              ),
            )),
          ],
        ),
      );

      if (categoryId != null) {
        await _setCategoryForSelected(categoryId.isEmpty ? null : categoryId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分类失败: $e')),
        );
      }
    }
  }

  Future<void> _setCategoryForSelected(String? categoryId) async {
    try {
      final client = ref.read(apiClientProvider);
      
      // 批量更新资产分类
      for (final assetId in _selectedAssetIds) {
        await client.put('/api/families/current/assets/$assetId', data: {
          'category_id': categoryId,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已设置 ${_selectedAssetIds.length} 个资产的分类')),
        );
        _exitSelectionMode();
        // 重新加载资产和分类
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置分类失败: $e')),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索资产...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = null;
                          _loadAssets();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _searchQuery = v.trim().isEmpty ? null : v.trim();
                _loadAssets();
              },
            ),
          ),
          const SizedBox(width: 8),
          // 批量选择按钮
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.check_box : Icons.checklist),
            tooltip: _isSelectionMode ? '退出选择' : '批量选择',
            onPressed: _toggleSelectionMode,
          ),
          // 分类管理按钮
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: '分类管理',
            onPressed: () async {
              await context.push('/assets/categories');
              _loadAll();
            },
          ),
          // 视图切换
          PopupMenuButton<AssetViewMode>(
            icon: Icon(_getViewModeIcon()),
            tooltip: '视图模式',
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AssetViewMode.groupByCategory,
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('按分类分组'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: AssetViewMode.groupByNature,
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text('按性质分组'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: AssetViewMode.groupByValue,
                child: ListTile(
                  leading: Icon(Icons.sort),
                  title: Text('按价值排序'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: AssetViewMode.list,
                child: ListTile(
                  leading: Icon(Icons.list),
                  title: Text('列表视图'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double totalValue = 0;
    int totalCount = _assets.length;

    for (final asset in _assets) {
      final financial = asset['financial'];
      totalValue += financial != null ? toDouble(financial['current_value']) : 0.0;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '总资产',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(totalValue),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  '资产数量',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, _) => const AssetCardSkeleton(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAssets,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('暂无资产，点击添加第一个资产'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/assets/create');
              if (mounted) _loadAssets();
            },
            icon: const Icon(Icons.add),
            label: const Text('添加资产'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetList() {
    switch (_viewMode) {
      case AssetViewMode.groupByNature:
        return _buildGroupedByNature();
      case AssetViewMode.groupByCategory:
        return _buildGroupedByCategory();
      case AssetViewMode.groupByValue:
        return _buildSortedByValue();
      case AssetViewMode.list:
        return _buildSimpleList();
    }
  }

  // 按性质分组
  Widget _buildGroupedByNature() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final asset in _assets) {
      final nature = asset['nature'] ?? 'other';
      groups[nature] = [...(groups[nature] ?? []), asset];
    }

    final natureOrder = ['financial', 'tangible', 'digital', 'service', 'intangible', 'other'];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final aIndex = natureOrder.indexOf(a);
        final bIndex = natureOrder.indexOf(b);
        return aIndex.compareTo(bIndex);
      });

    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final nature = sortedKeys[index];
          final assets = groups[nature]!;
          return _buildNatureGroup(nature, assets);
        },
      ),
    );
  }

  Widget _buildNatureGroup(String nature, List<Map<String, dynamic>> assets) {
    final labels = {
      'tangible': '有形资产',
      'financial': '金融资产',
      'digital': '数字资产',
      'service': '服务',
      'intangible': '无形资产',
      'other': '其他',
    };
    final icons = {
      'tangible': Icons.home,
      'financial': Icons.account_balance,
      'digital': Icons.computer,
      'service': Icons.cloud,
      'intangible': Icons.description,
      'other': Icons.category,
    };
    final colors = {
      'tangible': Colors.blue,
      'financial': Colors.green,
      'digital': Colors.purple,
      'service': Colors.orange,
      'intangible': Colors.grey,
      'other': Colors.grey,
    };

    double totalValue = 0;
    for (final asset in assets) {
      final financial = asset['financial'];
      totalValue += financial != null ? toDouble(financial['current_value']) : 0.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icons[nature] ?? Icons.category, size: 16, color: colors[nature]),
              const SizedBox(width: 8),
              Text(
                labels[nature] ?? nature,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors[nature],
                ),
              ),
              const Spacer(),
              Text(
                formatCurrency(totalValue),
                style: TextStyle(
                  fontSize: 13,
                  color: colors[nature],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${assets.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: colors[nature]?.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
        _buildAssetGrid(assets),
      ],
    );
  }

  // 按自定义分类分组
  Widget _buildGroupedByCategory() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = _categories;
    
    final groups = <String, List<Map<String, dynamic>>>{};
    final categoryInfo = <String, Map<String, dynamic>>{};
    
    for (final cat in categories) {
      final id = cat['id'] as String;
      categoryInfo[id] = cat;
      groups[id] = [];
    }
    
    const uncategorizedId = '__uncategorized__';
    groups[uncategorizedId] = [];
    categoryInfo[uncategorizedId] = {
      'id': uncategorizedId,
      'name': '未分类',
      'icon': 'category',
      'color': '#9E9E9E',
    };

    for (final asset in _assets) {
      final categoryId = asset['category_id'] as String?;
      if (categoryId != null && groups.containsKey(categoryId)) {
        groups[categoryId]!.add(asset);
      } else {
        groups[uncategorizedId]!.add(asset);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == uncategorizedId) return 1;
        if (b == uncategorizedId) return -1;
        final aOrder = categoryInfo[a]?['sort_order'] ?? 999;
        final bOrder = categoryInfo[b]?['sort_order'] ?? 999;
        return aOrder.compareTo(bOrder);
      });

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final categoryId = sortedKeys[index];
          final assets = groups[categoryId]!;
          final info = categoryInfo[categoryId]!;
          return _buildUserCategoryGroup(info, assets);
        },
      ),
    );
  }

  Future<List<dynamic>> _loadCategories() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/categories');
      final categories = response.data['data'] ?? [];
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
      return categories;
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      return [];
    }
  }

  Widget _buildUserCategoryGroup(Map<String, dynamic> category, List<Map<String, dynamic>> assets) {
    final name = category['name'] ?? '未分类';
    final icon = _getCategoryIcon(category['icon']);
    final color = _parseCategoryColor(category['color']);

    double totalValue = 0;
    for (final asset in assets) {
      final financial = asset['financial'];
      totalValue += financial != null ? toDouble(financial['current_value']) : 0.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                formatCurrency(totalValue),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${assets.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildAssetGrid(assets),
      ],
    );
  }

  // 按价值排序
  Widget _buildSortedByValue() {
    final sorted = List<Map<String, dynamic>>.from(_assets);
    sorted.sort((a, b) {
      final aValue = a['financial'] != null ? toDouble(a['financial']['current_value']) : 0.0;
      final bValue = b['financial'] != null ? toDouble(b['financial']['current_value']) : 0.0;
      return bValue.compareTo(aValue);
    });

    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          return _buildAssetListItem(sorted[index], index);
        },
      ),
    );
  }

  // 简单列表
  Widget _buildSimpleList() {
    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _assets.length,
        itemBuilder: (context, index) {
          return _buildAssetCard(_assets[index]);
        },
      ),
    );
  }

  // 资产网格
  Widget _buildAssetGrid(List<Map<String, dynamic>> assets) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: assets.map((asset) => _buildCompactAssetCard(asset)).toList(),
      ),
    );
  }

  // 紧凑型资产卡片
  Widget _buildCompactAssetCard(Map<String, dynamic> asset) {
    final financial = asset['financial'];
    final currentValue = financial != null ? toDouble(financial['current_value']) : 0.0;
    final nature = asset['nature'] ?? 'other';
    final assetId = asset['id'] as String;
    final isSelected = _selectedAssetIds.contains(assetId);

    final icons = {
      'tangible': Icons.home,
      'financial': Icons.account_balance,
      'digital': Icons.computer,
      'service': Icons.cloud,
      'intangible': Icons.description,
    };

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleAssetSelection(assetId);
        } else {
          context.push('/assets/${asset['id']}').then((_) => _loadAssets());
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleAssetSelection(assetId);
        }
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 3,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(150)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant.withAlpha(128),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                else
                  Icon(
                    icons[nature] ?? Icons.category,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const Spacer(),
                if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (asset['tags'] as List).first.toString(),
                      style: TextStyle(
                        fontSize: 8,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              asset['name'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(currentValue),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.forChange(currentValue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 资产列表项（带排名）
  Widget _buildAssetListItem(Map<String, dynamic> asset, int index) {
    final financial = asset['financial'];
    final currentValue = financial != null ? toDouble(financial['current_value']) : 0.0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: index < 3
            ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][index]
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: index < 3 ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(asset['name'] ?? ''),
      subtitle: Text(_getNatureLabel(asset['nature'])),
      trailing: Text(
        formatCurrency(currentValue),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.forChange(currentValue),
        ),
      ),
      onTap: () async {
        await context.push('/assets/${asset['id']}');
        if (mounted) _loadAssets();
      },
    );
  }

  // 普通资产卡片
  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final financial = asset['financial'];
    final currentValue = financial != null ? toDouble(financial['current_value']) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _getNatureIcon(asset['nature']),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(asset['name'] ?? ''),
        subtitle: Text(_getNatureLabel(asset['nature'])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(currentValue),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.forChange(currentValue),
              ),
            ),
            if (asset['tags'] != null && (asset['tags'] as List).isNotEmpty)
              Text(
                (asset['tags'] as List).join(', '),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        onTap: () async {
          await context.push('/assets/${asset['id']}');
          if (mounted) _loadAssets();
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.push('/assets/create');
                if (mounted) _loadAssets();
              },
              icon: const Icon(Icons.add),
              label: const Text('添加资产'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () async {
              await context.push('/assets/scan');
              if (mounted) _loadAssets();
            },
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
    );
  }

  IconData _getViewModeIcon() {
    switch (_viewMode) {
      case AssetViewMode.groupByNature:
        return Icons.folder;
      case AssetViewMode.groupByCategory:
        return Icons.category;
      case AssetViewMode.groupByValue:
        return Icons.sort;
      case AssetViewMode.list:
        return Icons.list;
    }
  }

  IconData _getNatureIcon(String? nature) {
    switch (nature) {
      case 'tangible':
        return Icons.home;
      case 'digital':
        return Icons.computer;
      case 'financial':
        return Icons.account_balance;
      case 'intangible':
        return Icons.description;
      case 'service':
        return Icons.cloud;
      default:
        return Icons.category;
    }
  }

  String _getNatureLabel(String? nature) {
    switch (nature) {
      case 'tangible':
        return '有形资产';
      case 'digital':
        return '数字资产';
      case 'financial':
        return '金融资产';
      case 'intangible':
        return '无形资产';
      case 'service':
        return '服务';
      default:
        return '';
    }
  }

  Color _parseCategoryColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.grey;
    try {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
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
}

enum AssetViewMode {
  groupByNature,
  groupByCategory,
  groupByValue,
  list,
}
