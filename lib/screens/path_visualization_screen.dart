import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/node.dart';
import '../models/edge.dart';
import '../services/path_finder_service.dart';
import '../services/tts_service.dart';

/// Floor segment data structure
class FloorSegment {
  final int floor;
  final List<String> pathSegment;
  final Node? elevatorEntry; // Elevator node where we enter this floor
  final Node? elevatorExit; // Elevator node where we exit this floor
  final Node? startNode; // First node on this floor
  final Node? endNode; // Last node on this floor

  FloorSegment({
    required this.floor,
    required this.pathSegment,
    this.elevatorEntry,
    this.elevatorExit,
    this.startNode,
    this.endNode,
  });
}

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

/// Grouped path segment for navigation instructions
class _GroupedPathSegment {
  final List<int> edgeIndices; // Indices in the path
  final double totalDistance;
  final String? turnDirection; // 'left', 'right', or null for straight
  final Node startNode;
  final Node endNode;
  final bool isVerticalConnection;
  final bool isLandmark; // True if end node is a landmark (room, office, etc.)

  _GroupedPathSegment({
    required this.edgeIndices,
    required this.totalDistance,
    this.turnDirection,
    required this.startNode,
    required this.endNode,
    this.isVerticalConnection = false,
    this.isLandmark = false,
  });
}

class _PathVisualizationScreenState extends State<PathVisualizationScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final TtsService _ttsService = TtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  /// Calculate angle between two vectors in degrees
  double _calculateTurnAngle(double x1, double y1, double x2, double y2, double x3, double y3) {
    // Vector from point 1 to point 2
    final dx1 = x2 - x1;
    final dy1 = y2 - y1;
    
    // Vector from point 2 to point 3
    final dx2 = x3 - x2;
    final dy2 = y3 - y2;
    
    // Calculate angle using dot product and cross product
    final dot = dx1 * dx2 + dy1 * dy2;
    final det = dx1 * dy2 - dy1 * dx2;
    final angle = math.atan2(det, dot) * 180 / math.pi;
    
    return angle;
  }

  /// Get turn direction based on angle
  String? _getTurnDirection(double angle) {
    const threshold = 30.0; // Degrees threshold for considering it a turn
    
    if (angle.abs() < threshold) {
      return null; // Straight, no turn
    } else if (angle > 0) {
      return 'left';
    } else {
      return 'right';
    }
  }

  /// Check if a node is a landmark (room, office, elevator, stairs, etc.)
  bool _isLandmark(Node node) {
    final type = node.type.toLowerCase();
    final name = node.name.toLowerCase();
    
    // Elevators and stairs are always landmarks
    if (type == 'elevator' || type == 'staircase') {
      return true;
    }
    
    // Rooms and offices are landmarks
    if (type == 'room' || type == 'office' || name.contains('ofis') || 
        name.contains('lab') || name.contains('room')) {
      return true;
    }
    
    // Named locations (not just corridors)
    if (name.isNotEmpty && !name.contains('koridor') && !name.contains('corridor')) {
      return true;
    }
    
    return false;
  }

  /// Check if a node is a corridor
  bool _isCorridor(Node node) {
    final type = node.type.toLowerCase();
    final name = node.name.toLowerCase();
    return type == 'corridor' || name.contains('koridor');
  }

  /// Group path segments into meaningful navigation instructions
  List<_GroupedPathSegment> _groupPathSegments() {
    if (widget.path.length < 2) return [];

    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );

    final groups = <_GroupedPathSegment>[];
    List<int> currentGroupIndices = [0];
    double currentGroupDistance = 0.0;
    Node? currentGroupStartNode;
    Node? previousNode;
    int? previousFloor;
    String? previousTurnDirection;

    for (int i = 0; i < widget.path.length - 1; i++) {
      final currentNode = pathFinder.getNodeById(widget.path[i]);
      final nextNode = pathFinder.getNodeById(widget.path[i + 1]);
      final edge = pathFinder.getEdge(widget.path[i], widget.path[i + 1]);

      if (currentNode == null || nextNode == null || edge == null) continue;

      // Check if this is a vertical connection (elevator/stairs)
      final isVerticalConnection = edge.type.toLowerCase() == 'vertical_connection';
      
      // Calculate turn direction if we have previous segment
      String? turnDirection;
      if (i > 0 && previousNode != null && 
          currentNode.pos.length >= 2 && nextNode.pos.length >= 2 &&
          previousNode.pos.length >= 2) {
        if (previousNode.floor == currentNode.floor && 
            currentNode.floor == nextNode.floor &&
            !isVerticalConnection) {
          final angle = _calculateTurnAngle(
            previousNode.pos[0], previousNode.pos[1],
            currentNode.pos[0], currentNode.pos[1],
            nextNode.pos[0], nextNode.pos[1],
          );
          turnDirection = _getTurnDirection(angle);
        }
      }

      // Handle vertical connections separately - they always break groups
      if (isVerticalConnection) {
        // Save current group if it exists
        if (currentGroupIndices.isNotEmpty && currentGroupStartNode != null) {
          groups.add(_GroupedPathSegment(
            edgeIndices: List.from(currentGroupIndices),
            totalDistance: currentGroupDistance,
            turnDirection: previousTurnDirection,
            startNode: currentGroupStartNode,
            endNode: currentNode,
            isVerticalConnection: false,
            isLandmark: _isLandmark(currentNode),
          ));
        }

        // Add vertical connection as separate group
        groups.add(_GroupedPathSegment(
          edgeIndices: [i],
          totalDistance: edge.distance,
          turnDirection: null,
          startNode: currentNode,
          endNode: nextNode,
          isVerticalConnection: true,
          isLandmark: false,
        ));

        // Reset for next group after vertical connection
        currentGroupIndices = [];
        currentGroupDistance = 0.0;
        currentGroupStartNode = null;
        previousTurnDirection = null;
        previousNode = nextNode; // Update for next iteration
        previousFloor = nextNode.floor;
        continue; // Skip to next iteration
      }

      // Check if we should break the group (for non-vertical connections)
      bool shouldBreakGroup = false;

      // Break on floor changes
      if (previousFloor != null && currentNode.floor != previousFloor) {
        shouldBreakGroup = true;
      }
      // Break on significant turns (when turn direction changes)
      else if (turnDirection != null && previousTurnDirection != null && 
               turnDirection != previousTurnDirection) {
        shouldBreakGroup = true;
      }
      // Break when reaching a landmark
      else if (_isLandmark(nextNode)) {
        shouldBreakGroup = true;
      }
      // Break if current node is a landmark and we have a group started
      else if (currentGroupStartNode != null && _isLandmark(currentNode) && 
               currentGroupIndices.isNotEmpty) {
        shouldBreakGroup = true;
      }

      // If we should break, save current group and start new one
      if (shouldBreakGroup && currentGroupIndices.isNotEmpty && currentGroupStartNode != null) {
        // For the group we're breaking, the end node is the current node (where we are now)
        groups.add(_GroupedPathSegment(
          edgeIndices: List.from(currentGroupIndices),
          totalDistance: currentGroupDistance,
          turnDirection: previousTurnDirection,
          startNode: currentGroupStartNode,
          endNode: currentNode,
          isVerticalConnection: false,
          isLandmark: _isLandmark(currentNode),
        ));

        // Start new group - this edge will be the first in the new group
        currentGroupIndices = [i];
        currentGroupDistance = edge.distance;
        currentGroupStartNode = currentNode;
        previousTurnDirection = turnDirection;
      } else {
        // Continue current group
        if (currentGroupStartNode == null) {
          currentGroupStartNode = currentNode;
        }
        currentGroupIndices.add(i);
        currentGroupDistance += edge.distance;
        previousTurnDirection = turnDirection;
      }

      previousNode = currentNode;
      previousFloor = currentNode.floor;
    }

    // Add the last group if it exists
    if (currentGroupIndices.isNotEmpty && currentGroupStartNode != null) {
      final lastNode = pathFinder.getNodeById(widget.path.last);
      if (lastNode != null) {
        groups.add(_GroupedPathSegment(
          edgeIndices: List.from(currentGroupIndices),
          totalDistance: currentGroupDistance,
          turnDirection: previousTurnDirection,
          startNode: currentGroupStartNode,
          endNode: lastNode,
          isVerticalConnection: false,
          isLandmark: _isLandmark(lastNode),
        ));
      }
    }

    return groups;
  }

  /// Get node type description in natural language
  String _getNodeTypeDescription(Node node) {
    final type = node.type.toLowerCase();
    final name = node.name.toLowerCase();
    
    if (type == 'elevator' || name.contains('asansör') || name.contains('asansor')) {
      return 'the elevator';
    } else if (type == 'staircase' || name.contains('merdiven')) {
      return 'the stairs';
    } else if (type == 'lab' || name.contains('lab')) {
      return 'the laboratory';
    } else if (type == 'office' || name.contains('ofis')) {
      return 'the office';
    } else if (type == 'classroom' || name.contains('sınıf')) {
      return 'the classroom';
    } else if (_isCorridor(node)) {
      return 'the corridor';
    }
    return node.name;
  }

  /// Get path description as text with clear navigation instructions
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
    buffer.writeln('');

    // Get grouped path segments
    final groupedSegments = _groupPathSegments();
    
    if (groupedSegments.isEmpty) {
      buffer.writeln('Unable to generate directions for this path.');
      return buffer.toString();
    }

    int stepNumber = 1;
    bool previousWasVertical = false;
    bool isFirstSegment = true;

    for (int i = 0; i < groupedSegments.length; i++) {
      final segment = groupedSegments[i];
      
      if (segment.isVerticalConnection) {
        // Handle elevator/stairs
        final isElevator = (segment.startNode.type.toLowerCase() == 'elevator') ||
                          (segment.endNode.type.toLowerCase() == 'elevator');
        final isStaircase = (segment.startNode.type.toLowerCase() == 'staircase') ||
                           (segment.endNode.type.toLowerCase() == 'staircase');

        if (isElevator) {
          final floorDiff = (segment.endNode.floor - segment.startNode.floor).abs();
          if (segment.startNode.floor < segment.endNode.floor) {
            if (floorDiff == 1) {
              buffer.writeln('$stepNumber. Enter the elevator and go up one floor to Floor ${segment.endNode.floor}.');
            } else {
              buffer.writeln('$stepNumber. Enter the elevator and go up $floorDiff floors to Floor ${segment.endNode.floor}.');
            }
          } else if (segment.startNode.floor > segment.endNode.floor) {
            if (floorDiff == 1) {
              buffer.writeln('$stepNumber. Enter the elevator and go down one floor to Floor ${segment.endNode.floor}.');
            } else {
              buffer.writeln('$stepNumber. Enter the elevator and go down $floorDiff floors to Floor ${segment.endNode.floor}.');
            }
          } else {
            buffer.writeln('$stepNumber. Use the elevator on Floor ${segment.startNode.floor}.');
          }
        } else if (isStaircase) {
          final floorDiff = (segment.endNode.floor - segment.startNode.floor).abs();
          if (segment.startNode.floor < segment.endNode.floor) {
            if (floorDiff == 1) {
              buffer.writeln('$stepNumber. Go up the stairs one floor to Floor ${segment.endNode.floor}.');
            } else {
              buffer.writeln('$stepNumber. Go up the stairs $floorDiff floors to Floor ${segment.endNode.floor}.');
            }
          } else if (segment.startNode.floor > segment.endNode.floor) {
            if (floorDiff == 1) {
              buffer.writeln('$stepNumber. Go down the stairs one floor to Floor ${segment.endNode.floor}.');
            } else {
              buffer.writeln('$stepNumber. Go down the stairs $floorDiff floors to Floor ${segment.endNode.floor}.');
            }
          } else {
            buffer.writeln('$stepNumber. Use the stairs on Floor ${segment.startNode.floor}.');
          }
        }
        previousWasVertical = true;
        stepNumber++;
      } else {
        // Handle horizontal movement
        final distance = segment.totalDistance;
        final distanceStr = distance.toStringAsFixed(1);
        String instruction = '';

        // Handle first segment of the route
        if (isFirstSegment && !previousWasVertical) {
          // First instruction - provide starting context
          if (segment.turnDirection == null) {
            if (segment.isLandmark) {
              instruction = 'From ${segment.startNode.name}, go straight for $distanceStr meters until you reach ${segment.endNode.name}.';
            } else if (_isCorridor(segment.endNode)) {
              instruction = 'From ${segment.startNode.name}, go straight for $distanceStr meters along the corridor.';
            } else {
              instruction = 'From ${segment.startNode.name}, go straight for $distanceStr meters.';
            }
          } else {
            // First segment has a turn (unusual but possible)
            if (segment.turnDirection == 'left') {
              instruction = 'From ${segment.startNode.name}, go straight for $distanceStr meters, then turn left.';
            } else {
              instruction = 'From ${segment.startNode.name}, go straight for $distanceStr meters, then turn right.';
            }
          }
        }
        // If this is the first segment after exiting elevator/stairs, provide initial direction
        else if (previousWasVertical) {
          // Provide direction guidance after exiting
          if (segment.turnDirection == 'left') {
            if (segment.isLandmark) {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and turn left. Walk $distanceStr meters until you reach ${segment.endNode.name}.';
            } else {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and turn left. Continue walking $distanceStr meters along the corridor.';
            }
          } else if (segment.turnDirection == 'right') {
            if (segment.isLandmark) {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and turn right. Walk $distanceStr meters until you reach ${segment.endNode.name}.';
            } else {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and turn right. Continue walking $distanceStr meters along the corridor.';
            }
          } else {
            // Going straight after exit
            if (segment.isLandmark) {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and walk straight ahead for $distanceStr meters until you reach ${segment.endNode.name}.';
            } else if (_isCorridor(segment.endNode)) {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and walk straight ahead for $distanceStr meters along the corridor.';
            } else {
              instruction = 'Exit ${_getNodeTypeDescription(segment.startNode)} and walk straight ahead for $distanceStr meters.';
            }
          }
        } else {
          // Normal turn instruction
          if (segment.turnDirection == 'left') {
            if (segment.isLandmark) {
              instruction = 'Turn left and walk $distanceStr meters until you reach ${segment.endNode.name}.';
            } else {
              instruction = 'Turn left and continue walking $distanceStr meters along the corridor.';
            }
          } else if (segment.turnDirection == 'right') {
            if (segment.isLandmark) {
              instruction = 'Turn right and walk $distanceStr meters until you reach ${segment.endNode.name}.';
            } else {
              instruction = 'Turn right and continue walking $distanceStr meters along the corridor.';
            }
          } else {
            // Straight movement
            if (segment.isLandmark) {
              instruction = 'Continue straight ahead for $distanceStr meters until you reach ${segment.endNode.name}.';
            } else if (_isCorridor(segment.endNode)) {
              instruction = 'Continue walking straight along the corridor for $distanceStr meters.';
            } else {
              instruction = 'Continue straight ahead for $distanceStr meters.';
            }
          }
        }

        buffer.writeln('$stepNumber. $instruction');
        previousWasVertical = false;
        isFirstSegment = false;
        stepNumber++;
      }
    }

    buffer.writeln('');
    buffer.writeln('You have arrived at your destination: ${widget.targetNode.name}');

    return buffer.toString();
  }

  /// Get only the directions part (numbered steps) without headers
  String _getDirectionsOnly() {
    final fullDescription = _getPathDescription();
    final lines = fullDescription.split('\n');
    
    // Find the line that starts with "Step-by-step directions:"
    int startIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('Step-by-step directions:')) {
        startIndex = i + 2; // Start after the header line and empty line
        break;
      }
    }
    
    if (startIndex == -1) {
      // Fallback: return everything if we can't find the header
      return fullDescription;
    }
    
    // Extract only the numbered steps (skip empty lines and headers)
    final directionsLines = <String>[];
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      // Include numbered steps and the final arrival message
      if (line.isNotEmpty) {
        // Check if it's a numbered step (starts with digit followed by period)
        if (RegExp(r'^\d+\.').hasMatch(line)) {
          // Remove the step number prefix (e.g., "1. " or "10. ")
          final directionText = line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          directionsLines.add(directionText);
        } else if (line.contains('You have arrived')) {
          // Include the arrival message
          directionsLines.add(line);
        }
      }
    }
    
    return directionsLines.join('. ');
  }

  /// Speak the directions using TTS
  Future<void> _speakDirections() async {
    if (_isSpeaking) return;
    
    setState(() {
      _isSpeaking = true;
    });

    try {
      // Get only the directions part (numbered steps) without headers
      final directions = _getDirectionsOnly();
      
      if (directions.isEmpty) {
        setState(() {
          _isSpeaking = false;
        });
        return;
      }
      
      // Set slower speech rate for better comprehension (0.3 = slower than normal)
      await _ttsService.setSpeechRate(0.3);
      
      // Speak only the directions, not the headers
      await _ttsService.speakAndWait(directions);
    } catch (e) {
      print('Error speaking directions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  /// Stop speaking directions
  Future<void> _stopSpeaking() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    }
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

  /// Split path into floor segments
  List<FloorSegment> _splitPathByFloors() {
    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );

    if (widget.path.isEmpty) return [];

    final segments = <FloorSegment>[];
    int currentFloor = -1;
    List<String> currentSegment = [];
    Node? elevatorEntry;
    Node? elevatorExit;
    Node? segmentStart;

    for (int i = 0; i < widget.path.length; i++) {
      final node = pathFinder.getNodeById(widget.path[i]);
      if (node == null) continue;

      // If floor changed, save previous segment and start new one
      if (currentFloor != -1 && node.floor != currentFloor) {
        // Find the elevator/vertical connection node
        final lastNodeInPrevFloor = pathFinder.getNodeById(currentSegment.last);
        final firstNodeInNewFloor = node;

        if (currentSegment.isNotEmpty && lastNodeInPrevFloor != null) {
          segments.add(FloorSegment(
            floor: currentFloor,
            pathSegment: List.from(currentSegment),
            elevatorEntry: lastNodeInPrevFloor, // Enter elevator on this floor to go to next floor
            startNode: segmentStart,
            endNode: lastNodeInPrevFloor,
          ));
        }

        // Start new segment
        currentFloor = node.floor;
        currentSegment = [widget.path[i]];
        elevatorExit = firstNodeInNewFloor; // Exit elevator on this floor after arriving
        elevatorEntry = null; // Clear entry since we're on a new floor
        segmentStart = firstNodeInNewFloor;
      } else {
        // Same floor, continue segment
        if (currentFloor == -1) {
          currentFloor = node.floor;
          segmentStart = node;
        }
        currentSegment.add(widget.path[i]);
      }
    }

    // Add the last segment
    if (currentSegment.isNotEmpty) {
      final lastNode = pathFinder.getNodeById(currentSegment.last);
      segments.add(FloorSegment(
        floor: currentFloor,
        pathSegment: List.from(currentSegment),
        elevatorEntry: elevatorEntry,
        elevatorExit: elevatorExit,
        startNode: segmentStart,
        endNode: lastNode,
      ));
    }

    return segments;
  }

  /// Get nodes and edges for a specific floor
  List<Node> _getNodesForFloor(int floor) {
    return widget.nodes.where((node) => node.floor == floor).toList();
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
  Offset _worldToScreen(double x, double y, Size canvasSize, Map<String, double> bounds, {double padding = 20.0}) {
    // Reduce padding to minimize empty space around graph
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
    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );
    final totalDistance = pathFinder.getPathDistance(widget.path);
    final floorSegments = _splitPathByFloors();

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
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Distance: ${totalDistance.toStringAsFixed(1)} meters',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.stairs,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Steps: ${widget.path.length - 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.layers,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      floorSegments.length > 1 
                          ? 'Floors: ${floorSegments.length}'
                          : 'Floor: ${widget.sourceNode.floor}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Multi-floor visualization or single floor
          Expanded(
            child: floorSegments.length > 1
                ? _buildMultiFloorVisualization(floorSegments)
                : _buildSingleFloorVisualization(),
          ),

          // Path Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Directions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isSpeaking ? Icons.stop : Icons.volume_up,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _isSpeaking ? _stopSpeaking : _speakDirections,
                      tooltip: _isSpeaking ? 'Stop reading' : 'Tell me the directions',
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
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
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

  /// Build single floor visualization (rotated 90 degrees horizontally)
  Widget _buildSingleFloorVisualization() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // After rotation: height becomes width, width becomes height
          // We want to fill screen width, so before rotation height = screenWidth
          // We want to use ALL available height with minimal gaps
          final screenWidth = MediaQuery.of(context).size.width;
          final containerHeight = constraints.maxHeight.isFinite 
              ? constraints.maxHeight 
              : MediaQuery.of(context).size.height * 0.6;
          
          // Use the full container height to minimize gaps
          // After rotation: width becomes height, so we set width to containerHeight
          return SizedBox(
            height: screenWidth, // Becomes horizontal width after rotation (fills screen)
            width: containerHeight, // Becomes vertical height after rotation (uses full container)
            child: RotatedBox(
              quarterTurns: 1, // Rotate 90 degrees clockwise
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                child: LayoutBuilder(
                  builder: (context, rotatedConstraints) {
                    final bounds = _calculateBounds();
                    // Use minimal padding for single floor to maximize graph size
                    return CustomPaint(
                      size: Size(rotatedConstraints.maxWidth, rotatedConstraints.maxHeight),
                      painter: _MapPainter(
                        nodes: _getRelevantNodes(),
                        edges: _getRelevantEdges(),
                        path: widget.path,
                        sourceNode: widget.sourceNode,
                        targetNode: widget.targetNode,
                        worldToScreen: (x, y, canvasSize) =>
                            _worldToScreen(x, y, canvasSize, bounds, padding: 5.0),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build multi-floor visualization with separate graphs
  /// Only shows source floor (first) and target floor (last), skipping intermediate floors
  Widget _buildMultiFloorVisualization(List<FloorSegment> segments) {
    // Only show first (source) and last (target) floor segments
    final filteredSegments = <FloorSegment>[];
    if (segments.isNotEmpty) {
      filteredSegments.add(segments.first); // Source floor
      if (segments.length > 1 && segments.last.floor != segments.first.floor) {
        filteredSegments.add(segments.last); // Target floor (only if different from source)
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch to fill width
          children: [
            for (int index = 0; index < filteredSegments.length; index++)
              Flexible(
                child: _buildFloorCard(
                  filteredSegments[index],
                  index,
                  filteredSegments,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build a single floor card
  Widget _buildFloorCard(
    FloorSegment segment,
    int index,
    List<FloorSegment> allSegments,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: index == 0 
            ? const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              )
            : (index == allSegments.length - 1
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  )
                : BorderRadius.zero),
        boxShadow: index == 0 || index == allSegments.length - 1
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Floor header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: index == 0
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                  : BorderRadius.zero,
            ),
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(
                  Icons.layers,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Floor ${segment.floor}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (segment.elevatorEntry != null) ...[
                  Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Enter: ${segment.elevatorEntry!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (segment.elevatorExit != null) ...[
                  Icon(
                    Icons.arrow_upward,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Exit: ${segment.elevatorExit!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Floor graph visualization - rotated 90 degrees for vertical display
          Expanded(
            child: Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  // After rotation: height becomes width, width becomes height
                  // We want to fill screen width, so before rotation height = screenWidth
                  // We want to use available height, so before rotation width = available height
                  final screenWidth = MediaQuery.of(context).size.width;
                  final availableHeight = cardConstraints.maxHeight;
                  
                  return SizedBox(
                    height: screenWidth, // Becomes horizontal width after rotation (fills screen)
                    width: availableHeight, // Becomes vertical height after rotation (uses available space)
                    child: RotatedBox(
                      quarterTurns: 1, // Rotate 90 degrees clockwise
                      child: _buildFloorVisualization(segment),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build elevator connection widget between floors
  Widget _buildElevatorConnection(FloorSegment fromSegment, FloorSegment toSegment) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.elevator,
            size: 32,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take elevator from Floor ${fromSegment.floor} to Floor ${toSegment.floor}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${fromSegment.elevatorExit!.name} → ${toSegment.elevatorEntry!.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build visualization for a single floor segment
  Widget _buildFloorVisualization(FloorSegment segment) {
    final pathFinder = PathFinderService(
      nodes: widget.nodes,
      edges: widget.edges,
    );
    
    // Get nodes for this floor
    final floorNodes = _getNodesForFloor(segment.floor);
    
    // Get edges for this floor
    final floorNodeIds = floorNodes.map((n) => n.id).toSet();
    final floorEdges = widget.edges.where((edge) {
      return floorNodeIds.contains(edge.source) && 
             floorNodeIds.contains(edge.target);
    }).toList();
    
    // Calculate bounds for this floor
    final bounds = _calculateBoundsForNodes(floorNodes);
    
    // Determine source and target nodes for this segment
    final segmentSource = segment.startNode ?? pathFinder.getNodeById(segment.pathSegment.first);
    final segmentTarget = segment.endNode ?? pathFinder.getNodeById(segment.pathSegment.last);
    
    return SizedBox.expand(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _MapPainter(
                nodes: floorNodes,
                edges: floorEdges,
                path: segment.pathSegment,
                sourceNode: segmentSource ?? widget.sourceNode,
                targetNode: segmentTarget ?? widget.targetNode,
                worldToScreen: (x, y, canvasSize) =>
                    _worldToScreen(x, y, canvasSize, bounds),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Calculate bounds for specific nodes
  Map<String, double> _calculateBoundsForNodes(List<Node> nodes) {
    if (nodes.isEmpty) {
      return {'minX': 0, 'maxX': 100, 'minY': 0, 'maxY': 100};
    }

    // Calculate bounds with rotated coordinates (swap X and Y, flip Y)
    // This matches the rotation applied in _worldToScreen
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes) {
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
    // Minimal padding to reduce empty space
    final padding = 5.0;
    return {
      'minX': minX - padding,
      'maxX': maxX + padding,
      'minY': minY - padding,
      'maxY': maxY + padding,
    };
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

    // Draw all edges - non-path edges using palette color
    final edgePaint = Paint()
      ..color = const Color(0xFF456882).withOpacity(0.4) // Medium blue-grey from palette
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

          // Choose color based on edge type - using palette colors
          Color pathColor;
          double strokeWidth;
          
          if (pathEdge != null) {
            switch (pathEdge.type.toLowerCase()) {
              case 'corridor':
                pathColor = const Color(0xFF234C6A); // Primary blue from palette
                strokeWidth = 6;
                break;
              case 'connection':
                pathColor = const Color(0xFF1B3C53); // Dark muted blue from palette
                strokeWidth = 6;
                break;
              case 'vertical_connection':
                pathColor = const Color(0xFF456882); // Medium blue-grey from palette
                strokeWidth = 7;
                break;
              default:
                pathColor = const Color(0xFF234C6A); // Primary blue from palette
                strokeWidth = 6;
            }
          } else {
            pathColor = const Color(0xFF234C6A); // Primary blue from palette
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
        nodeColor = const Color(0xFF1B3C53); // Dark muted blue from palette for source
        nodeRadius = 10;
      } else if (isTarget) {
        nodeColor = Colors.red[700]!; // Keep red for target (accessibility)
        nodeRadius = 10;
      } else if (isInPath) {
        nodeColor = const Color(0xFF234C6A); // Primary blue from palette
        nodeRadius = 7;
      } else {
        nodeColor = const Color(0xFF456882); // Medium blue-grey from palette for non-path nodes
        nodeRadius = 5;
      }

      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, nodeRadius, nodePaint);

      // Draw node outline
      final outlinePaint = Paint()
        ..color = const Color(0xFFE3E3E3) // Light grey from palette
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
              color: Color(0xFF1B3C53), // Dark blue from palette for better contrast
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.white,
                  blurRadius: 2,
                  offset: Offset(0, 0),
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
        
        // Draw text background with better contrast
        final bgPaint = Paint()
          ..color = Colors.white.withOpacity(0.95) // White background for better contrast
          ..style = PaintingStyle.fill;
        
        // Draw border for better visibility
        final borderPaint = Paint()
          ..color = const Color(0xFF1B3C53).withOpacity(0.3) // Dark blue border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        
        final bgRect = Rect.fromLTWH(
          clampedX - 4,
          clampedY - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        );
        
        // Only draw if within bounds
        if (bgRect.left >= 0 && bgRect.top >= 0 && 
            bgRect.right <= size.width && bgRect.bottom <= size.height) {
          // Draw background
          canvas.drawRRect(
            RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
            bgPaint,
          );
          
          // Draw border
          canvas.drawRRect(
            RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
            borderPaint,
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

