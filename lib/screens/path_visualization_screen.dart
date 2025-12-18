import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/node.dart';
import '../models/edge.dart';
import '../services/path_finder_service.dart';

/// Screen for visualizing the floor map and shortest path
class PathVisualizationScreen extends StatefulWidget {
  final List<Node> nodes;
  final List<Edge> edges;
  final List<String> path;
  final Node sourceNode;
  final Node targetNode;

  const PathVisualizationScreen({
    super.key,
    required this.nodes,
    required this.edges,
    required this.path,
    required this.sourceNode,
    required this.targetNode,
  });

  @override
  State<PathVisualizationScreen> createState() =>
      _PathVisualizationScreenState();
}

class _PathVisualizationScreenState extends State<PathVisualizationScreen> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Get path description as text
  String _getPathDescription() {
    if (widget.path.isEmpty) return 'No path found';

    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );
    final totalDistance = pathFinder.getPathDistance(widget.path);

    final buffer = StringBuffer();
    buffer.writeln('Route from ${widget.sourceNode.name} to ${widget.targetNode.name}');
    buffer.writeln('Total distance: ${totalDistance.toStringAsFixed(1)} meters');
    buffer.writeln('');
    buffer.writeln('Directions:');

    for (int i = 0; i < widget.path.length - 1; i++) {
      final currentNode = pathFinder.getNodeById(widget.path[i]);
      final nextNode = pathFinder.getNodeById(widget.path[i + 1]);
      final edge = pathFinder.getEdge(widget.path[i], widget.path[i + 1]);

      if (currentNode != null && nextNode != null && edge != null) {
        buffer.writeln(
          '${i + 1}. From ${currentNode.name}, go ${edge.distance.toStringAsFixed(1)} meters to ${nextNode.name}',
        );
      }
    }

    return buffer.toString();
  }

  /// Calculate bounds for all nodes
  Map<String, double> _calculateBounds() {
    if (widget.nodes.isEmpty) {
      return {'minX': 0, 'maxX': 100, 'minY': 0, 'maxY': 100};
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final node in widget.nodes) {
      if (node.pos.length >= 2) {
        minX = math.min(minX, node.pos[0]);
        maxX = math.max(maxX, node.pos[0]);
        minY = math.min(minY, node.pos[1]);
        maxY = math.max(maxY, node.pos[1]);
      }
    }

    return {
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
    };
  }

  /// Convert world coordinates to screen coordinates
  Offset _worldToScreen(double x, double y, Size canvasSize, Map<String, double> bounds) {
    final padding = 40.0;
    final width = canvasSize.width - 2 * padding;
    final height = canvasSize.height - 2 * padding;

    final scaleX = width / (bounds['maxX']! - bounds['minX']!);
    final scaleY = height / (bounds['maxY']! - bounds['minY']!);
    final scale = math.min(scaleX, scaleY);

    final screenX = padding + (x - bounds['minX']!) * scale;
    final screenY = padding + (bounds['maxY']! - y) * scale; // Flip Y axis

    return Offset(screenX, screenY);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _calculateBounds();
    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );
    final totalDistance = pathFinder.getPathDistance(widget.path);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Path Visualization',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Path Information'),
                  content: SingleChildScrollView(
                    child: Text(_getPathDescription()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Path details',
          ),
        ],
      ),
      body: Column(
        children: [
          // Path Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.sourceNode.name} → ${widget.targetNode.name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Distance: ${totalDistance.toStringAsFixed(1)} meters',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.stairs,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Steps: ${widget.path.length - 1}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map Visualization
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: CustomPaint(
                size: Size.infinite,
                painter: _MapPainter(
                  nodes: widget.nodes,
                  edges: widget.edges,
                  path: widget.path,
                  sourceNode: widget.sourceNode,
                  targetNode: widget.targetNode,
                  worldToScreen: (x, y, canvasSize) =>
                      _worldToScreen(x, y, canvasSize, bounds),
                ),
              ),
            ),
          ),

          // Path Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Directions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: SingleChildScrollView(
                    child: Text(
                      _getPathDescription(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing the map
class _MapPainter extends CustomPainter {
  final List<Node> nodes;
  final List<Edge> edges;
  final List<String> path;
  final Node sourceNode;
  final Node targetNode;
  final Offset Function(double x, double y, Size canvasSize) worldToScreen;

  _MapPainter({
    required this.nodes,
    required this.edges,
    required this.path,
    required this.sourceNode,
    required this.targetNode,
    required this.worldToScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all edges (corridors)
    final edgePaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final sourceNode = nodes.firstWhere(
        (n) => n.id == edge.source,
        orElse: () => Node(
          id: edge.source,
          name: '',
          type: '',
          pos: [0, 0, 0],
          floor: 1,
        ),
      );
      final targetNode = nodes.firstWhere(
        (n) => n.id == edge.target,
        orElse: () => Node(
          id: edge.target,
          name: '',
          type: '',
          pos: [0, 0, 0],
          floor: 1,
        ),
      );

      if (sourceNode.pos.length >= 2 && targetNode.pos.length >= 2) {
        final start = worldToScreen(sourceNode.pos[0], sourceNode.pos[1], size);
        final end = worldToScreen(targetNode.pos[0], targetNode.pos[1], size);
        canvas.drawLine(start, end, edgePaint);
      }
    }

    // Draw path edges (highlighted)
    if (path.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.length - 1; i++) {
        final sourceNode = nodes.firstWhere(
          (n) => n.id == path[i],
          orElse: () => Node(
            id: path[i],
            name: '',
            type: '',
            pos: [0, 0, 0],
            floor: 1,
          ),
        );
        final targetNode = nodes.firstWhere(
          (n) => n.id == path[i + 1],
          orElse: () => Node(
            id: path[i + 1],
            name: '',
            type: '',
            pos: [0, 0, 0],
            floor: 1,
          ),
        );

        if (sourceNode.pos.length >= 2 && targetNode.pos.length >= 2) {
          final start = worldToScreen(sourceNode.pos[0], sourceNode.pos[1], size);
          final end = worldToScreen(targetNode.pos[0], targetNode.pos[1], size);
          canvas.drawLine(start, end, pathPaint);
        }
      }
    }

    // Draw all nodes
    for (final node in nodes) {
      if (node.pos.length < 2) continue;

      final position = worldToScreen(node.pos[0], node.pos[1], size);
      final isInPath = path.contains(node.id);
      final isSource = node.id == sourceNode.id;
      final isTarget = node.id == targetNode.id;

      Color nodeColor;
      double nodeRadius;

      if (isSource) {
        nodeColor = Colors.green;
        nodeRadius = 8;
      } else if (isTarget) {
        nodeColor = Colors.red;
        nodeRadius = 8;
      } else if (isInPath) {
        nodeColor = Colors.blue;
        nodeRadius = 6;
      } else {
        nodeColor = Colors.grey[400]!;
        nodeRadius = 4;
      }

      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, nodeRadius, nodePaint);

      // Draw node outline
      final outlinePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(position, nodeRadius, outlinePaint);

      // Draw node label for important nodes
      if (isSource || isTarget || (isInPath && node.name.isNotEmpty)) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.name,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            position.dx - textPainter.width / 2,
            position.dy + nodeRadius + 4,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

