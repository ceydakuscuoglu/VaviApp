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
    buffer.writeln('Step-by-step directions:');

    for (int i = 0; i < widget.path.length - 1; i++) {
      final currentNode = pathFinder.getNodeById(widget.path[i]);
      final nextNode = pathFinder.getNodeById(widget.path[i + 1]);
      final edge = pathFinder.getEdge(widget.path[i], widget.path[i + 1]);

      if (currentNode != null && nextNode != null && edge != null) {
        String direction = '';
        String edgeTypeDescription = '';
        
        switch (edge.type.toLowerCase()) {
          case 'corridor':
            edgeTypeDescription = 'through the corridor';
            break;
          case 'connection':
            edgeTypeDescription = 'via connection';
            break;
          case 'vertical_connection':
            edgeTypeDescription = 'via elevator/stairs';
            break;
          default:
            edgeTypeDescription = '';
        }
        
        if (edgeTypeDescription.isNotEmpty) {
          direction = '${i + 1}. From ${currentNode.name}, go ${edge.distance.toStringAsFixed(1)} meters ${edgeTypeDescription} to ${nextNode.name}';
        } else {
          direction = '${i + 1}. From ${currentNode.name}, go ${edge.distance.toStringAsFixed(1)} meters to ${nextNode.name}';
        }
        
        buffer.writeln(direction);
      }
    }

    return buffer.toString();
  }

  /// Get nodes and edges for the current floor(s) in the path
  List<Node> _getRelevantNodes() {
    // Get all floors in the path
    final Set<int> pathFloors = {};
    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );
    
    for (final nodeId in widget.path) {
      final node = pathFinder.getNodeById(nodeId);
      if (node != null) {
        pathFloors.add(node.floor);
      }
    }
    
    // If path is on single floor, filter to that floor
    // Otherwise show all floors in path
    return widget.nodes.where((node) => pathFloors.contains(node.floor)).toList();
  }

  /// Get edges connecting relevant nodes
  List<Edge> _getRelevantEdges() {
    final relevantNodes = _getRelevantNodes();
    final relevantNodeIds = relevantNodes.map((n) => n.id).toSet();
    
    return widget.edges.where((edge) {
      return relevantNodeIds.contains(edge.source) && 
             relevantNodeIds.contains(edge.target);
    }).toList();
  }

  /// Calculate bounds for relevant nodes only (with 90-degree rotation applied)
  Map<String, double> _calculateBounds() {
    final relevantNodes = _getRelevantNodes();
    
    if (relevantNodes.isEmpty) {
      return {'minX': 0, 'maxX': 100, 'minY': 0, 'maxY': 100};
    }

    // Calculate bounds with rotated coordinates (swap X and Y, flip Y)
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final node in relevantNodes) {
      if (node.pos.length >= 2) {
        // Apply 90-degree clockwise rotation: (x, y) -> (y, -x)
        final rotatedX = node.pos[1];
        final rotatedY = -node.pos[0];
        
        minX = math.min(minX, rotatedX);
        maxX = math.max(maxX, rotatedX);
        minY = math.min(minY, rotatedY);
        maxY = math.max(maxY, rotatedY);
      }
    }

    // Add padding
    final padding = 5.0;
    return {
      'minX': minX - padding,
      'maxX': maxX + padding,
      'minY': minY - padding,
      'maxY': maxY + padding,
    };
  }

  /// Convert world coordinates to screen coordinates (with 90-degree rotation)
  Offset _worldToScreen(double x, double y, Size canvasSize, Map<String, double> bounds) {
    final padding = 40.0;
    final width = math.max(1.0, canvasSize.width - 2 * padding);
    final height = math.max(1.0, canvasSize.height - 2 * padding);

    final rangeX = bounds['maxX']! - bounds['minX']!;
    final rangeY = bounds['maxY']! - bounds['minY']!;
    
    // Avoid division by zero
    final scaleX = rangeX > 0 ? width / rangeX : 1.0;
    final scaleY = rangeY > 0 ? height / rangeY : 1.0;
    final scale = math.min(scaleX, scaleY);

    // Apply 90-degree clockwise rotation: (x, y) -> (y, -x)
    final rotatedX = y;
    final rotatedY = -x;

    // Calculate scaled dimensions
    final scaledWidth = rangeX * scale;
    final scaledHeight = rangeY * scale;
    
    // Calculate centering offsets
    final offsetX = (width - scaledWidth) / 2;
    final offsetY = (height - scaledHeight) / 2;

    final screenX = padding + offsetX + (rotatedX - bounds['minX']!) * scale;
    final screenY = padding + offsetY + (bounds['maxY']! - rotatedY) * scale; // Flip Y axis

    // Clamp to canvas bounds
    return Offset(
      math.max(0.0, math.min(canvasSize.width, screenX)).toDouble(),
      math.max(0.0, math.min(canvasSize.height, screenY)).toDouble(),
    );
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _MapPainter(
                      nodes: _getRelevantNodes(),
                      edges: _getRelevantEdges(),
                      path: widget.path,
                      sourceNode: widget.sourceNode,
                      targetNode: widget.targetNode,
                      worldToScreen: (x, y, canvasSize) =>
                          _worldToScreen(x, y, canvasSize, bounds),
                    ),
                  );
                },
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
    // Create a set of path edges for quick lookup
    final Set<String> pathEdges = {};
    for (int i = 0; i < path.length - 1; i++) {
      pathEdges.add('${path[i]}_${path[i + 1]}');
      pathEdges.add('${path[i + 1]}_${path[i]}'); // Bidirectional
    }

    // Draw all edges - non-path edges in darker grey for better visibility
    final edgePaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final edgeKey1 = '${edge.source}_${edge.target}';
      final edgeKey2 = '${edge.target}_${edge.source}';
      
      // Skip path edges here - they'll be drawn with highlight later
      if (pathEdges.contains(edgeKey1) || pathEdges.contains(edgeKey2)) {
        continue;
      }

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
        
        // Only draw edges that are reasonably visible (not too short)
        final distance = (end - start).distance;
        if (distance > 2) {
          canvas.drawLine(start, end, edgePaint);
        }
      }
    }

    // Draw path edges (highlighted) - including all types (corridor, connection, vertical_connection)
    if (path.length > 1) {
      // Draw path edges with different colors based on type
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
          
          // Find the edge to get its type
          Edge? pathEdge;
          try {
            pathEdge = edges.firstWhere(
              (e) =>
                  (e.source == path[i] && e.target == path[i + 1]) ||
                  (e.source == path[i + 1] && e.target == path[i]),
            );
          } catch (e) {
            // Edge not found, use default
          }

          // Choose color based on edge type - darker and more visible
          Color pathColor;
          double strokeWidth;
          
          if (pathEdge != null) {
            switch (pathEdge.type.toLowerCase()) {
              case 'corridor':
                pathColor = Colors.blue[700]!; // Darker blue
                strokeWidth = 6;
                break;
              case 'connection':
                pathColor = Colors.green[700]!; // Darker green
                strokeWidth = 6;
                break;
              case 'vertical_connection':
                pathColor = Colors.orange[700]!; // Darker orange
                strokeWidth = 7;
                break;
              default:
                pathColor = Colors.blue[700]!; // Darker blue
                strokeWidth = 6;
            }
          } else {
            pathColor = Colors.blue[700]!; // Darker blue
            strokeWidth = 6;
          }

          final pathPaint = Paint()
            ..color = pathColor
            ..strokeWidth = strokeWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(start, end, pathPaint);
          
          // Draw arrow indicator in the middle of longer path edges
          final edgeLength = (end - start).distance;
          if (edgeLength > 15) {
            final midPoint = Offset(
              (start.dx + end.dx) / 2,
              (start.dy + end.dy) / 2,
            );
            
            // Calculate angle
            final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
            
            // Draw arrow
            final arrowPaint = Paint()
              ..color = pathColor
              ..style = PaintingStyle.fill;
            
            final arrowPath = Path();
            final arrowSize = 7.0;
            arrowPath.moveTo(midPoint.dx, midPoint.dy);
            arrowPath.lineTo(
              midPoint.dx - arrowSize * math.cos(angle - math.pi / 6),
              midPoint.dy - arrowSize * math.sin(angle - math.pi / 6),
            );
            arrowPath.lineTo(
              midPoint.dx - arrowSize * math.cos(angle + math.pi / 6),
              midPoint.dy - arrowSize * math.sin(angle + math.pi / 6),
            );
            arrowPath.close();
            canvas.drawPath(arrowPath, arrowPaint);
          }
        }
      }
    }

    // Draw all nodes - filter to show only important ones to reduce clutter
    for (final node in nodes) {
      if (node.pos.length < 2) continue;

      final position = worldToScreen(node.pos[0], node.pos[1], size);
      final isInPath = path.contains(node.id);
      final isSource = node.id == sourceNode.id;
      final isTarget = node.id == targetNode.id;

      // Only show nodes that are in path or are important landmarks
      final isImportant = isSource || 
                         isTarget || 
                         isInPath || 
                         (node.type != 'corridor' && node.name.isNotEmpty);

      if (!isImportant) continue;

      Color nodeColor;
      double nodeRadius;

      if (isSource) {
        nodeColor = Colors.green;
        nodeRadius = 10;
      } else if (isTarget) {
        nodeColor = Colors.red;
        nodeRadius = 10;
      } else if (isInPath) {
        nodeColor = Colors.blue;
        nodeRadius = 7;
      } else {
        nodeColor = Colors.grey[500]!;
        nodeRadius = 5;
      }

      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, nodeRadius, nodePaint);

      // Draw node outline
      final outlinePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(position, nodeRadius, outlinePaint);

      // Draw node label only for source, target, and named path nodes (not corridors)
      if ((isSource || isTarget || (isInPath && node.type != 'corridor')) && 
          node.name.isNotEmpty) {
        // Clean node name - remove any invalid characters that might cause rendering issues
        final cleanName = node.name.trim().replaceAll(RegExp(r'[^\w\s\-\.]'), '');
        if (cleanName.isEmpty) continue;
        
        // Draw background for text to improve readability
        final textPainter = TextPainter(
          text: TextSpan(
            text: cleanName,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.white,
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '...',
        );
        textPainter.layout(maxWidth: 120);
        
        // Calculate text position
        final textX = position.dx - textPainter.width / 2;
        final textY = position.dy + nodeRadius + 2;
        
        // Clamp text position to canvas bounds
        final clampedX = math.max(4.0, math.min(size.width - textPainter.width - 4.0, textX)).toDouble();
        final clampedY = math.max(4.0, math.min(size.height - textPainter.height - 4.0, textY)).toDouble();
        
        // Draw text background
        final bgPaint = Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill;
        
        final bgRect = Rect.fromLTWH(
          clampedX - 4,
          clampedY - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        );
        
        // Only draw if within bounds
        if (bgRect.left >= 0 && bgRect.top >= 0 && 
            bgRect.right <= size.width && bgRect.bottom <= size.height) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
            bgPaint,
          );
          
          // Draw text
          textPainter.paint(
            canvas,
            Offset(clampedX, clampedY),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

