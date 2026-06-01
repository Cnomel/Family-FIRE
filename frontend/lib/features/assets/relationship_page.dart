import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';

class RelationshipPage extends ConsumerStatefulWidget {
  final String assetId;
  const RelationshipPage({super.key, required this.assetId});

  @override
  ConsumerState<RelationshipPage> createState() => _RelationshipPageState();
}

class _RelationshipPageState extends ConsumerState<RelationshipPage> {
  Map<String, dynamic>? _graphData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/api/families/current/assets/relationship-graph');
      if (mounted) {
        setState(() {
          _graphData = response.data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载关系图失败';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关系图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '列表视图',
            onPressed: () => _showListView(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _graphData == null
                  ? _buildEmptyView()
                  : _buildGraphView(),
    );
  }

  void _showListView() {
    final allNodes = _graphData?['nodes'] as List<dynamic>? ?? [];
    final allEdges = _graphData?['edges'] as List<dynamic>? ?? [];

    // 只保留与当前资产相关的节点
    final relatedNodeIds = <String>{widget.assetId};
    for (final edge in allEdges) {
      if (edge['source'] == widget.assetId) relatedNodeIds.add(edge['target'] as String);
      if (edge['target'] == widget.assetId) relatedNodeIds.add(edge['source'] as String);
    }
    final nodes = allNodes.where((n) => relatedNodeIds.contains(n['id'])).toList();

    if (nodes.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('所有资产 (${nodes.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: nodes.length,
                itemBuilder: (_, index) {
                  final node = nodes[index];
                  final isCurrent = node['id'] == widget.assetId;
                  return ListTile(
                    leading: Icon(_getNatureIcon(node['nature']), color: isCurrent ? Theme.of(context).colorScheme.primary : null),
                    title: Text(node['name'] ?? '', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(_getNatureLabel(node['nature'])),
                    trailing: isCurrent ? const Chip(label: Text('当前', style: TextStyle(fontSize: 11))) : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isCurrent) context.push('/assets/${node['id']}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _loadData();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无关系数据', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 8),
          Text('在资产详情页点击 + 按钮创建资产关系', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    final allNodes = _graphData!['nodes'] as List<dynamic>? ?? [];
    final allEdges = _graphData!['edges'] as List<dynamic>? ?? [];

    if (allNodes.isEmpty) return _buildEmptyView();

    // 只保留与当前资产相关的节点和边
    final relatedNodeIds = <String>{widget.assetId};
    for (final edge in allEdges) {
      if (edge['source'] == widget.assetId) relatedNodeIds.add(edge['target'] as String);
      if (edge['target'] == widget.assetId) relatedNodeIds.add(edge['source'] as String);
    }

    final nodes = allNodes.where((n) => relatedNodeIds.contains(n['id'])).toList();
    final edges = allEdges.where((e) =>
      relatedNodeIds.contains(e['source']) && relatedNodeIds.contains(e['target'])
    ).toList();

    if (nodes.isEmpty) return _buildEmptyView();

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(500),
          minScale: 0.3,
          maxScale: 2.0,
          child: _GraphCanvas(
            nodes: nodes,
            edges: edges,
            currentAssetId: widget.assetId,
            canvasSize: Size(
              max(constraints.maxWidth, nodes.length * 120.0),
              max(constraints.maxHeight, nodes.length * 100.0),
            ),
            onNodeTap: (assetId) => context.push('/assets/$assetId'),
          ),
        );
      },
    );
  }

  IconData _getNatureIcon(String? nature) {
    switch (nature) {
      case 'tangible': return Icons.home;
      case 'digital': return Icons.computer;
      case 'financial': return Icons.account_balance;
      case 'intangible': return Icons.description;
      case 'service': return Icons.cloud;
      default: return Icons.category;
    }
  }

  String _getNatureLabel(String? nature) {
    switch (nature) {
      case 'tangible': return '实物资产';
      case 'digital': return '数字资产';
      case 'financial': return '金融资产';
      case 'intangible': return '无形资产';
      case 'service': return '服务';
      default: return '';
    }
  }
}

class _GraphCanvas extends StatelessWidget {
  final List<dynamic> nodes;
  final List<dynamic> edges;
  final String currentAssetId;
  final Size canvasSize;
  final Function(String assetId) onNodeTap;

  const _GraphCanvas({
    required this.nodes,
    required this.edges,
    required this.currentAssetId,
    required this.canvasSize,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final positions = _calculatePositions();

    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: Stack(
        children: [
          // 绘制边
          CustomPaint(
            size: canvasSize,
            painter: _EdgePainter(
              edges: edges,
              positions: positions,
            ),
          ),
          // 绘制节点
          ...nodes.map((node) {
            final id = node['id'] as String;
            final pos = positions[id] ?? Offset.zero;
            final isCurrent = id == currentAssetId;

            return Positioned(
              left: pos.dx - 55,
              top: pos.dy - 35,
              child: GestureDetector(
                onTap: () => onNodeTap(id),
                child: _NodeWidget(
                  name: node['name'] ?? '',
                  nature: node['nature'],
                  isCurrent: isCurrent,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Map<String, Offset> _calculatePositions() {
    final positions = <String, Offset>{};
    final nodeCount = nodes.length;

    if (nodeCount == 0) return positions;

    // 计算每个节点的连接数
    final connectionCount = <String, int>{};
    for (final node in nodes) {
      connectionCount[node['id'] as String] = 0;
    }
    for (final edge in edges) {
      final source = edge['source'] as String?;
      final target = edge['target'] as String?;
      if (source != null) connectionCount[source] = (connectionCount[source] ?? 0) + 1;
      if (target != null) connectionCount[target] = (connectionCount[target] ?? 0) + 1;
    }

    // 布局：当前节点在中心，直接关联的节点在第一圈，其他在第二圈
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    // 找出直接关联的节点
    final directNeighbors = <String>{};
    for (final edge in edges) {
      if (edge['source'] == currentAssetId) directNeighbors.add(edge['target'] as String);
      if (edge['target'] == currentAssetId) directNeighbors.add(edge['source'] as String);
    }

    // 放置当前节点
    positions[currentAssetId] = Offset(centerX, centerY);

    // 放置直接关联节点（内圈）
    final innerNodes = nodes.where((n) => directNeighbors.contains(n['id'])).toList();
    final innerRadius = 150.0;
    for (int i = 0; i < innerNodes.length; i++) {
      final angle = (2 * pi * i / innerNodes.length) - pi / 2;
      positions[innerNodes[i]['id'] as String] = Offset(
        centerX + innerRadius * cos(angle),
        centerY + innerRadius * sin(angle),
      );
    }

    // 放置其他节点（外圈）
    final outerNodes = nodes.where((n) => n['id'] != currentAssetId && !directNeighbors.contains(n['id'])).toList();
    final outerRadius = 300.0;
    for (int i = 0; i < outerNodes.length; i++) {
      final angle = (2 * pi * i / outerNodes.length) - pi / 2;
      positions[outerNodes[i]['id'] as String] = Offset(
        centerX + outerRadius * cos(angle),
        centerY + outerRadius * sin(angle),
      );
    }

    return positions;
  }
}

class _EdgePainter extends CustomPainter {
  final List<dynamic> edges;
  final Map<String, Offset> positions;

  _EdgePainter({required this.edges, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final sourcePos = positions[edge['source']];
      final targetPos = positions[edge['target']];
      if (sourcePos == null || targetPos == null) continue;

      canvas.drawLine(sourcePos, targetPos, paint);

      // 绘制箭头
      final dx = targetPos.dx - sourcePos.dx;
      final dy = targetPos.dy - sourcePos.dy;
      final length = sqrt(dx * dx + dy * dy);
      if (length < 1) continue;

      final ux = dx / length;
      final uy = dy / length;

      // 箭头位置（目标节点边缘）
      final arrowX = targetPos.dx - ux * 40;
      final arrowY = targetPos.dy - uy * 40;

      final path = Path()
        ..moveTo(arrowX, arrowY)
        ..lineTo(arrowX - ux * 10 - uy * 5, arrowY - uy * 10 + ux * 5)
        ..lineTo(arrowX - ux * 10 + uy * 5, arrowY - uy * 10 - ux * 5)
        ..close();

      canvas.drawPath(path, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NodeWidget extends StatelessWidget {
  final String name;
  final String? nature;
  final bool isCurrent;

  const _NodeWidget({
    required this.name,
    this.nature,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isCurrent ? 40 : 15),
            blurRadius: isCurrent ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getNatureIcon(nature),
            color: isCurrent ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? Colors.white : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getNatureIcon(String? nature) {
    switch (nature) {
      case 'tangible': return Icons.home;
      case 'digital': return Icons.computer;
      case 'financial': return Icons.account_balance;
      case 'intangible': return Icons.description;
      case 'service': return Icons.cloud;
      default: return Icons.category;
    }
  }
}
