import 'package:flutter_test/flutter_test.dart';
import 'package:vavi_app/services/path_finder_service.dart';
import 'package:vavi_app/models/node.dart';
import 'package:vavi_app/models/edge.dart';
import '../test_helpers/mock_helpers.dart';

/// Navigation Module Tests
/// TC-30 to TC-35
void main() {
  group('Navigation Module Tests', () {
    late List<Node> testNodes;
    late List<Edge> testEdges;
    late PathFinderService pathFinder;

    setUp(() {
      testNodes = MockHelpers.createMockNodes();
      testEdges = MockHelpers.createMockEdges();
      pathFinder = PathFinderService(nodes: testNodes, edges: testEdges);
    });

    // TC-30: Shortest path (correct)
    test('TC-30: Shortest path', () {
      // Expected: Correct
      final path = pathFinder.findShortestPath('node1', 'node2');
      
      expect(path, isNotEmpty);
      expect(path.first, equals('node1'));
      expect(path.last, equals('node2'));
      
      // Verify path distance
      final distance = pathFinder.getPathDistance(path);
      expect(distance, greaterThan(0));
    });

    // TC-31: Invalid node handling (error shown)
    test('TC-31: Invalid node handling', () {
      // Expected: Error shown
      final path = pathFinder.findShortestPath('invalid_node', 'node2');
      
      // Should return empty path for invalid nodes
      expect(path, isEmpty);
      
      // Test with both invalid
      final path2 = pathFinder.findShortestPath('invalid1', 'invalid2');
      expect(path2, isEmpty);
    });

    // TC-32: Multi-corridor path (correct)
    test('TC-32: Multi-corridor path', () {
      // Expected: Correct
      // Create a multi-corridor scenario
      final multiCorridorNodes = [
        Node(id: 'a', name: 'A', type: 'room', pos: [0.0, 0.0, 0.0], floor: 1),
        Node(id: 'b', name: 'B', type: 'room', pos: [10.0, 0.0, 0.0], floor: 1),
        Node(id: 'c', name: 'C', type: 'room', pos: [20.0, 0.0, 0.0], floor: 1),
        Node(id: 'd', name: 'D', type: 'room', pos: [30.0, 0.0, 0.0], floor: 1),
      ];
      
      final multiCorridorEdges = [
        Edge(source: 'a', target: 'b', distance: 10.0, type: 'horizontal_connection'),
        Edge(source: 'b', target: 'c', distance: 10.0, type: 'horizontal_connection'),
        Edge(source: 'c', target: 'd', distance: 10.0, type: 'horizontal_connection'),
      ];
      
      final multiPathFinder = PathFinderService(
        nodes: multiCorridorNodes,
        edges: multiCorridorEdges,
      );
      
      final path = multiPathFinder.findShortestPath('a', 'd');
      expect(path.length, greaterThan(2)); // Should go through multiple corridors
      expect(path, contains('a'));
      expect(path, contains('b'));
      expect(path, contains('c'));
      expect(path, contains('d'));
    });

    // TC-33: Deviate from route (recalculated)
    test('TC-33: Deviate from route', () {
      // Expected: Recalculated
      // Find initial path
      final initialPath = pathFinder.findShortestPath('node1', 'node5');
      
      // Simulate deviation - user is now at node2 instead of following path
      final recalculatedPath = pathFinder.findShortestPath('node2', 'node5');
      
      expect(recalculatedPath, isNotEmpty);
      expect(recalculatedPath.first, equals('node2'));
      expect(recalculatedPath.last, equals('node5'));
      
      // Recalculated path should be different from initial path
      expect(recalculatedPath, isNot(equals(initialPath)));
    });

    // TC-34: JSON loading (no errors)
    test('TC-34: JSON loading', () async {
      // Expected: No errors
      // Note: This test requires actual JSON files in assets/data/
      // For now, we test the parsing logic with mock data
      
      final mockNodesJson = testNodes.map((n) => n.toJson()).toList();
      final mockEdgesJson = testEdges.map((e) => e.toJson()).toList();
      
      // Verify JSON structure is valid
      expect(mockNodesJson, isNotEmpty);
      expect(mockEdgesJson, isNotEmpty);
      
      // Verify nodes can be parsed
      for (final nodeJson in mockNodesJson) {
        final node = Node.fromJson(nodeJson);
        expect(node.id, isNotEmpty);
        expect(node.name, isNotEmpty);
      }
      
      // Verify edges can be parsed
      for (final edgeJson in mockEdgesJson) {
        final edge = Edge.fromJson(edgeJson);
        expect(edge.source, isNotEmpty);
        expect(edge.target, isNotEmpty);
        expect(edge.distance, greaterThanOrEqualTo(0));
      }
    });

    // TC-35: Navigation accuracy (±2m)
    test('TC-35: Navigation accuracy', () {
      // Expected: ±2m
      const accuracyThreshold = 2.0; // meters
      
      // Calculate path distance
      final path = pathFinder.findShortestPath('node1', 'node2');
      final calculatedDistance = pathFinder.getPathDistance(path);
      
      // Get actual edge distance
      final actualEdge = testEdges.firstWhere(
        (e) => (e.source == 'node1' && e.target == 'node2') ||
               (e.source == 'node2' && e.target == 'node1'),
      );
      final actualDistance = actualEdge.distance;
      
      // Calculate error
      final error = (calculatedDistance - actualDistance).abs();
      
      expect(error, lessThanOrEqualTo(accuracyThreshold));
    });
  });
}

