import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/graphView.dart';

import '../../core/api/api_client.dart';

class RelationshipPage extends ConsumerStatefulWidget {
  final String assetId;
  const RelationshipPage({super.key, required this.assetId});

  @override
  ConsumerState<RelationshipPage> createState() => _RelationshipPageState();
}

class _RelationshipPageState extends ConsumerState<RelationshipPage> {
  Map<String, dynamic>? _graphData;
  Map<String, dynamic>? _relationshipTypes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        client.get('/api/families/current/assets/relationship-graph'),
        client.get('/api/families/current/assets/relationship-types'),
      ]);
      setState(() {
        _graphData = results[0].data['data'];
        _relationshipTypes = results[1].data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关系图')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _graphData == null
              ? const Center(child: Text('暂无关系数据'))
              : _buildGraph(),
    );
  }

  Widget _buildGraph() {
    final nodes = _graphData!['nodes'] as List<dynamic>? ?? [];
    final edges = _graphData!['edges'] as List<dynamic>? ?? [];

    if (nodes.isEmpty) {
      return const Center(child: Text('暂无关系数据'));
    }

    final graph = Graph();
    final nodeMap = <String, Node>{};

    for (final node in nodes) {
      final id = node['id'] as String;
      final graphNode = Node.Id(id);
      nodeMap[id] = graphNode;
      graph.addNode(graphNode);
    }

    for (final edge in edges) {
      final source = nodeMap[edge['source']];
      final target = nodeMap[edge['target']];
      if (source != null && target != null) {
        graph.addEdge(source, target);
      }
    }

    final builder = FruchtermanReingoldAlgorithm(FruchtermanReingoldConfiguration());

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.5,
      maxScale: 2.0,
      child: SizedBox(
        width: 800,
        height: 600,
        child: GraphView(
          graph: graph,
          algorithm: builder,
          paint: Paint()
            ..color = Colors.grey
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final nodeData = nodes.firstWhere(
              (n) => n['id'] == node.key?.value,
              orElse: () => {'name': node.key?.value},
            );
            final isCurrent = node.key?.value == widget.assetId;
            return _buildNodeWidget(nodeData, isCurrent);
          },
        ),
      ),
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> node, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.grey,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getNatureIcon(node['nature']),
            color: isCurrent ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            node['name'] ?? '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
