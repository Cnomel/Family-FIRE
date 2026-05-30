import 'package:flutter/material.dart';
import '../../shared/formatters/number.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../shared/widgets/asset_card.dart';
import '../../shared/widgets/skeleton.dart';
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
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  final int _pageSize = 20;

  // 批量操作
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 筛选条件
  String? _natureFilter;
  String? _utilityFilter;
  String? _ownershipFilter;
  String? _liquidityFilter;
  String? _searchQuery;
  List<dynamic> _allTags = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _loadTags();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/tags');
      setState(() {
        _allTags = response.data['data'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadAssets({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _assets = [];
    }

    setState(() {
      _isLoading = _page == 1;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'page': _page,
        'page_size': _pageSize,
      };
      if (_natureFilter != null) params['nature'] = _natureFilter;
      if (_utilityFilter != null) params['utility'] = _utilityFilter;
      if (_ownershipFilter != null) params['ownership'] = _ownershipFilter;
      if (_liquidityFilter != null) params['liquidity'] = _liquidityFilter;
      if (_searchQuery != null && _searchQuery!.isNotEmpty) params['search'] = _searchQuery;

      final response = await client.get(
        '/api/families/current/assets',
        queryParams: params,
      );

      final data = response.data['data'];
      final List<dynamic> assets = data['assets'] ?? [];
      final total = data['total'] ?? 0;

      setState(() {
        if (_page == 1) {
          _assets = assets.cast<Map<String, dynamic>>();
        } else {
          _assets.addAll(assets.cast<Map<String, dynamic>>());
        }
        _hasMore = _assets.length < total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，请重试';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      setState(() => _isLoadingMore = true);
      _page++;
      _loadAssets();
    }
  }

  void _applyFilter() {
    _loadAssets(refresh: true);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _assets.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_assets.map((a) => a['id'] as String));
      }
    });
  }

  Future<void> _bulkAction(String action) async {
    if (_selectedIds.isEmpty) return;

    String? tag;
    if (action == 'tag') {
      final controller = TextEditingController();
      tag = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('添加标签'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: '标签名')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('确认')),
          ],
        ),
      );
      if (tag == null || tag.isEmpty) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认操作'),
        content: Text('确认对 ${_selectedIds.length} 个资产执行${action == 'archive' ? '归档' : action == 'delete' ? '删除' : '打标签'}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.post('/api/families/current/assets/bulk', data: {
          'asset_ids': _selectedIds.toList(),
          'action': action,
          if (tag != null) 'tag': tag,
        });
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        _loadAssets(refresh: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 批量操作栏
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Text('已选 ${_selectedIds.length} 项'),
                const Spacer(),
                TextButton(onPressed: _selectAll, child: const Text('全选')),
                TextButton(
                  onPressed: () => _bulkAction('archive'),
                  child: const Text('归档'),
                ),
                TextButton(
                  onPressed: () => _bulkAction('tag'),
                  child: const Text('打标签'),
                ),
                TextButton(
                  onPressed: () => _bulkAction('delete'),
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSelectionMode,
                ),
              ],
            ),
          ),

        // 搜索栏
        Padding(
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
                              _applyFilter();
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
                    _applyFilter();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () async {
                  final result = await context.push<Map<String, String?>>('/assets/filter', extra: {
                    'nature': _natureFilter,
                    'utility': _utilityFilter,
                    'ownership': _ownershipFilter,
                    'liquidity': _liquidityFilter,
                  });
                  if (result != null) {
                    setState(() {
                      _natureFilter = result['nature'];
                      _utilityFilter = result['utility'];
                      _ownershipFilter = result['ownership'];
                      _liquidityFilter = result['liquidity'];
                    });
                    _applyFilter();
                  }
                },
              ),
              IconButton(
                icon: Icon(_isSelectionMode ? Icons.checklist : Icons.checklist_outlined),
                onPressed: _toggleSelectionMode,
                tooltip: '批量操作',
              ),
            ],
          ),
        ),

        // 筛选标签
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_natureFilter != null) _buildFilterChip('性质', _natureFilter!, () {
                    setState(() => _natureFilter = null);
                    _applyFilter();
                  }),
                  if (_utilityFilter != null) _buildFilterChip('用途', _utilityFilter!, () {
                    setState(() => _utilityFilter = null);
                    _applyFilter();
                  }),
                  if (_ownershipFilter != null) _buildFilterChip('持有', _ownershipFilter!, () {
                    setState(() => _ownershipFilter = null);
                    _applyFilter();
                  }),
                  if (_liquidityFilter != null) _buildFilterChip('流动性', _liquidityFilter!, () {
                    setState(() => _liquidityFilter = null);
                    _applyFilter();
                  }),
                ],
              ),
            ),
          ),

        // 资产列表
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => const AssetCardSkeleton(),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadAssets(refresh: true),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _assets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              const Text('暂无资产，点击添加第一个资产'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/assets/create'),
                                icon: const Icon(Icons.add),
                                label: const Text('添加资产'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadAssets(refresh: true),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _assets.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _assets.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final asset = _assets[index];
                              final financial = asset['financial'];
                              final isSelected = _selectedIds.contains(asset['id']);
                              return GestureDetector(
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode();
                                    _toggleSelection(asset['id']);
                                  }
                                },
                                child: AssetCard(
                                  name: asset['name'] ?? '',
                                  nature: asset['nature'] ?? '',
                                  currentValue: financial != null
                                      ? toDouble(financial['current_value'])
                                      : 0.0,
                                  tags: asset['tags'] != null
                                      ? (asset['tags'] as List).cast<String>()
                                      : null,
                                  onTap: _isSelectionMode
                                      ? () => _toggleSelection(asset['id'])
                                      : () => context.push('/assets/${asset['id']}'),
                                  isSelected: isSelected,
                                  showCheckbox: _isSelectionMode,
                                ),
                              );
                            },
                          ),
                        ),
        ),

        // 添加按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/assets/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('添加资产'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => context.push('/assets/scan'),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      _natureFilter != null || _utilityFilter != null || _ownershipFilter != null || _liquidityFilter != null;

  Widget _buildFilterChip(String label, String value, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDelete,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
