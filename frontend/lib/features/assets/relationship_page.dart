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
        title: const Text('资产关系图'),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '关联资产 (${nodes.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: nodes.length,
                  itemBuilder: (_, index) {
                    final node = nodes[index];
                    final isCurrent = node['id'] == widget.assetId;
                    return _buildListItem(node, isCurrent, ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> node, bool isCurrent, BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(100)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary.withAlpha(100)
              : Theme.of(context).colorScheme.outlineVariant.withAlpha(128),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : _getNatureColor(node['nature']).withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getNatureIcon(node['nature']),
            color: isCurrent ? Colors.white : _getNatureColor(node['nature']),
            size: 20,
          ),
        ),
        title: Text(
          node['name'] ?? '',
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _getNatureLabel(node['nature']),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isCurrent
            ? Chip(
                label: const Text('当前', style: TextStyle(fontSize: 11)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                labelStyle: const TextStyle(color: Colors.white),
                visualDensity: VisualDensity.compact,
              )
            : Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        onTap: () {
          Navigator.pop(ctx);
          if (!isCurrent) context.push('/assets/${node['id']}');
        },
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
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadData();
            },
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无关系数据',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '在资产详情页点击 + 按钮\n创建资产关系',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphView() {
    final allNodes = _graphData!['nodes'] as List<dynamic>? ?? [];
    final allEdges = _graphData!['edges'] as List<dynamic>? ?? [];

    if (allNodes.isEmpty) return _buildEmptyView();

    final relatedNodeIds = <String>{widget.assetId};
    for (final edge in allEdges) {
      if (edge['source'] == widget.assetId) relatedNodeIds.add(edge['target'] as String);
      if (edge['target'] == widget.assetId) relatedNodeIds.add(edge['source'] as String);
    }

    final nodes = allNodes.where((n) => relatedNodeIds.contains(n['id'])).toList();
    final edges = allEdges
        .where((e) => relatedNodeIds.contains(e['source']) && relatedNodeIds.contains(e['target']))
        .toList();

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
              max(constraints.maxWidth, nodes.length * 150.0),
              max(constraints.maxHeight, nodes.length * 120.0),
            ),
            onNodeTap: (assetId) => context.push('/assets/$assetId'),
          ),
        );
      },
    );
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

  Color _getNatureColor(String? nature) {
    switch (nature) {
      case 'tangible':
        return Colors.blue;
      case 'digital':
        return Colors.purple;
      case 'financial':
        return Colors.green;
      case 'intangible':
        return Colors.grey;
      case 'service':
        return Colors.orange;
      default:
        return Colors.grey;
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
          // 背景装饰
          CustomPaint(
            size: canvasSize,
            painter: _BackgroundPainter(),
          ),
          // 绘制边
          CustomPaint(
            size: canvasSize,
            painter: _EdgePainter(
              edges: edges,
              positions: positions,
              context: context,
            ),
          ),
          // 绘制节点
          ...nodes.map((node) {
            final id = node['id'] as String;
            final pos = positions[id] ?? Offset.zero;
            final isCurrent = id == currentAssetId;

            return Positioned(
              left: pos.dx - 60,
              top: pos.dy - 40,
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
    final innerRadius = 160.0;
    for (int i = 0; i < innerNodes.length; i++) {
      final angle = (2 * pi * i / innerNodes.length) - pi / 2;
      positions[innerNodes[i]['id'] as String] = Offset(
        centerX + innerRadius * cos(angle),
        centerY + innerRadius * sin(angle),
      );
    }

    // 放置其他节点（外圈）
    final outerNodes = nodes
        .where((n) => n['id'] != currentAssetId && !directNeighbors.contains(n['id']))
        .toList();
    final outerRadius = 320.0;
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

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制装饰性圆圈
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final center = Offset(size.width / 2, size.height / 2);

    // 内圈
    paint.color = Colors.grey.shade200;
    canvas.drawCircle(center, 160, paint);

    // 外圈
    paint.color = Colors.grey.shade100;
    canvas.drawCircle(center, 320, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EdgePainter extends CustomPainter {
  final List<dynamic> edges;
  final Map<String, Offset> positions;
  final BuildContext context;

  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final sourcePos = positions[edge['source']];
      final targetPos = positions[edge['target']];
      if (sourcePos == null || targetPos == null) continue;

      // 计算控制点（曲线）
      final midX = (sourcePos.dx + targetPos.dx) / 2;
      final midY = (sourcePos.dy + targetPos.dy) / 2;
      final dx = targetPos.dx - sourcePos.dx;
      final dy = targetPos.dy - sourcePos.dy;
      final controlPoint = Offset(midX - dy * 0.2, midY + dx * 0.2);

      // 绘制渐变曲线
      final path = Path()
        ..moveTo(sourcePos.dx, sourcePos.dy)
        ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, targetPos.dx, targetPos.dy);

      // 渐变色
      final gradient = LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary.withAlpha(150),
          Theme.of(context).colorScheme.primary.withAlpha(50),
        ],
      );

      paint.shader = gradient.createShader(
        Rect.fromPoints(sourcePos, targetPos),
      );

      canvas.drawPath(path, paint);

      // 绘制箭头
      final arrowPos = _getPointOnQuadraticBezier(
        sourcePos,
        controlPoint,
        targetPos,
        0.85,
      );
      final arrowAngle = atan2(
        targetPos.dy - arrowPos.dy,
        targetPos.dx - arrowPos.dx,
      );

      final arrowPath = Path()
        ..moveTo(arrowPos.dx, arrowPos.dy)
        ..lineTo(
          arrowPos.dx - 12 * cos(arrowAngle - 0.4),
          arrowPos.dy - 12 * sin(arrowAngle - 0.4),
        )
        ..lineTo(
          arrowPos.dx - 12 * cos(arrowAngle + 0.4),
          arrowPos.dy - 12 * sin(arrowAngle + 0.4),
        )
        ..close();

      paint.shader = null;
      paint.style = PaintingStyle.fill;
      paint.color = Theme.of(context).colorScheme.primary.withAlpha(150);
      canvas.drawPath(arrowPath, paint);
      paint.style = PaintingStyle.stroke;
    }
  }

  Offset _getPointOnQuadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final x = (1 - t) * (1 - t) * p0.dx + 2 * (1 - t) * t * p1.dx + t * t * p2.dx;
    final y = (1 - t) * (1 - t) * p0.dy + 2 * (1 - t) * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
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
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withAlpha(200),
                ],
              )
            : null,
        color: isCurrent ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary
              : _getNatureColor(nature).withAlpha(100),
          width: isCurrent ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? Theme.of(context).colorScheme.primary.withAlpha(50)
                : Colors.black.withAlpha(15),
            blurRadius: isCurrent ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.white.withAlpha(30)
                  : _getNatureColor(nature).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getNatureIcon(nature),
              color: isCurrent ? Colors.white : _getNatureColor(nature),
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
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

  Color _getNatureColor(String? nature) {
    switch (nature) {
      case 'tangible':
        return Colors.blue;
      case 'digital':
        return Colors.purple;
      case 'financial':
        return Colors.green;
      case 'intangible':
        return Colors.grey;
      case 'service':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
