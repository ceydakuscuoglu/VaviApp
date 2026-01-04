import '../models/node.dart';
import '../models/edge.dart';

/// Service for finding shortest paths using Dijkstra's algorithm
class PathFinderService {
  final List<Node> nodes;
  final List<Edge> edges;

  PathFinderService({
    required this.nodes,
    required this.edges,
  });

  /// Get effective weight for an edge, preferring elevators over staircases
  /// For visually impaired users, staircases get a large penalty
  double _getEffectiveWeight(Edge edge) {
    // If it's a vertical connection, check if it's a staircase
    if (edge.type.toLowerCase() == 'vertical_connection') {
      final sourceNode = getNodeById(edge.source);
      final targetNode = getNodeById(edge.target);
      
      // Check if either node is a staircase
      final isStaircase = (sourceNode?.type.toLowerCase() == 'staircase') ||
                          (targetNode?.type.toLowerCase() == 'staircase');
      
      if (isStaircase) {
        // Add large penalty to staircases to prefer elevators
        // This makes the algorithm avoid staircases when elevators are available
        const staircasePenalty = 1000.0; // Large penalty in meters
        return edge.distance + staircasePenalty;
      }
    }
    
    // For elevators and other connections, use normal distance
    return edge.distance;
  }

  /// Find shortest path between source and target nodes
  /// Returns list of node IDs representing the path, or empty list if no path exists
  /// Prefers elevators over staircases for accessibility
  List<String> findShortestPath(String sourceId, String targetId) {
    if (sourceId == targetId) {
      return [sourceId];
    }

    // Build adjacency list with effective weights (preferring elevators)
    final Map<String, List<MapEntry<String, double>>> graph = {};
    
    for (final edge in edges) {
      final effectiveWeight = _getEffectiveWeight(edge);
      
      if (!graph.containsKey(edge.source)) {
        graph[edge.source] = [];
      }
      graph[edge.source]!.add(MapEntry(edge.target, effectiveWeight));

      // Make graph undirected
      if (!graph.containsKey(edge.target)) {
        graph[edge.target] = [];
      }
      graph[edge.target]!.add(MapEntry(edge.source, effectiveWeight));
    }

    // Dijkstra's algorithm
    final Map<String, double> distances = {};
    final Map<String, String?> previous = {};
    final Set<String> unvisited = {};

    for (final node in nodes) {
      distances[node.id] = double.infinity;
      previous[node.id] = null;
      unvisited.add(node.id);
    }

    distances[sourceId] = 0;

    while (unvisited.isNotEmpty) {
      // Find node with minimum distance
      String? currentNode;
      double minDistance = double.infinity;

      for (final nodeId in unvisited) {
        if (distances[nodeId]! < minDistance) {
          minDistance = distances[nodeId]!;
          currentNode = nodeId;
        }
      }

      if (currentNode == null || minDistance == double.infinity) {
        break; // No path exists
      }

      unvisited.remove(currentNode);

      if (currentNode == targetId) {
        break; // Reached target
      }

      // Update distances to neighbors
      final neighbors = graph[currentNode] ?? [];
      for (final neighbor in neighbors) {
        final neighborId = neighbor.key;
        final edgeWeight = neighbor.value;

        if (unvisited.contains(neighborId)) {
          final alt = distances[currentNode]! + edgeWeight;
          if (alt < distances[neighborId]!) {
            distances[neighborId] = alt;
            previous[neighborId] = currentNode;
          }
        }
      }
    }

    // Reconstruct path
    final List<String> path = [];
    String? current = targetId;

    while (current != null) {
      path.insert(0, current);
      current = previous[current];
    }

    // Check if path exists (source should be in path)
    if (path.isEmpty || path.first != sourceId) {
      return [];
    }

    return path;
  }

  /// Get total distance of a path
  double getPathDistance(List<String> path) {
    if (path.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      final edge = edges.firstWhere(
        (e) =>
            (e.source == path[i] && e.target == path[i + 1]) ||
            (e.source == path[i + 1] && e.target == path[i]),
        orElse: () => Edge(
          source: path[i],
          target: path[i + 1],
          distance: 0,
          type: 'unknown',
        ),
      );
      totalDistance += edge.distance;
    }
    return totalDistance;
  }

  /// Get node by ID
  Node? getNodeById(String id) {
    try {
      return nodes.firstWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get edge between two nodes
  Edge? getEdge(String sourceId, String targetId) {
    try {
      return edges.firstWhere(
        (e) =>
            (e.source == sourceId && e.target == targetId) ||
            (e.source == targetId && e.target == sourceId),
      );
    } catch (e) {
      return null;
    }
  }
}

