import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../services/data_loader_service.dart';
import '../services/path_finder_service.dart';
import 'path_visualization_screen.dart';

/// Landing screen for VAVI app - Initial navigation setup screen
/// 
/// Modern, accessible UI for selecting source and target nodes
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  List<Node> _availableNodes = [];
  List<Edge> _edges = [];
  Node? _selectedSourceNode;
  Node? _selectedTargetNode;
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load nodes and edges from JSON files
  Future<void> _loadData() async {
    try {
      final nodes = await DataLoaderService.loadNodes();
      final edges = await DataLoaderService.loadEdges();

      if (mounted) {
        setState(() {
          _availableNodes = nodes;
          _edges = edges;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load map data: $e';
          _isLoadingData = false;
        });
      }
    }
  }

  /// Swap source and target nodes
  void _swapNodes() {
    setState(() {
      final temp = _selectedSourceNode;
      _selectedSourceNode = _selectedTargetNode;
      _selectedTargetNode = temp;
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Source and target nodes swapped'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Validate selections and find shortest path
  Future<void> _findShortestPath() async {
    // Validation
    if (_selectedSourceNode == null) {
      _showError('Please select a source node');
      return;
    }

    if (_selectedTargetNode == null) {
      _showError('Please select a target node');
      return;
    }

    if (_selectedSourceNode == _selectedTargetNode) {
      _showError('Source and target nodes must be different');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Calculate shortest path
    final pathFinder = PathFinderService(nodes: _availableNodes, edges: _edges);
    final path = pathFinder.findShortestPath(
      _selectedSourceNode!.id,
      _selectedTargetNode!.id,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (path.isEmpty) {
        _showError('No path found between selected nodes');
        return;
      }

      // Navigate to path visualization screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PathVisualizationScreen(
            nodes: _availableNodes,
            edges: _edges,
            path: path,
            sourceNode: _selectedSourceNode!,
            targetNode: _selectedTargetNode!,
          ),
        ),
      );
    }
  }

  /// Show error message
  void _showError(String message) {
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Get icon for node type
  IconData _getNodeTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'lab':
        return Icons.science;
      case 'office':
        return Icons.business;
      case 'connection':
        return Icons.alt_route;
      case 'corridor':
        return Icons.straighten;
      default:
        return Icons.place;
    }
  }

  /// Get color for node type
  Color _getNodeTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'lab':
        return Colors.purple;
      case 'office':
        return Colors.blue;
      case 'connection':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VAVI Navigation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map data...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.navigation,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Select Your Route',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose your starting point and destination to find the shortest path',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Source Node Section
                        _buildNodeSelector(
                          label: 'From',
                          icon: Icons.location_on,
                          selectedNode: _selectedSourceNode,
                          onNodeChanged: (Node? node) {
                            setState(() {
                              _selectedSourceNode = node;
                            });
                            if (node != null) {
                              HapticFeedback.lightImpact();
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Swap Button
                        Center(
                          child: Semantics(
                            button: true,
                            label: 'Swap source and target nodes',
                            child: IconButton(
                              onPressed: _swapNodes,
                              icon: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.swap_vert,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              tooltip: 'Swap locations',
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Target Node Section
                        _buildNodeSelector(
                          label: 'To',
                          icon: Icons.place,
                          selectedNode: _selectedTargetNode,
                          onNodeChanged: (Node? node) {
                            setState(() {
                              _selectedTargetNode = node;
                            });
                            if (node != null) {
                              HapticFeedback.lightImpact();
                            }
                          },
                        ),

                        const SizedBox(height: 32),

                        // Find Path Button
                        Semantics(
                          button: true,
                          label: 'Find shortest path',
                          hint: 'Double tap to calculate and display the shortest path',
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _findShortestPath,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.route, size: 24),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Find Shortest Path',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Build a modern node selector
  Widget _buildNodeSelector({
    required String label,
    required IconData icon,
    required Node? selectedNode,
    required ValueChanged<Node?> onNodeChanged,
  }) {
    return Semantics(
      label: '$label dropdown',
      hint: 'Double tap to open and select a location',
      value: selectedNode?.name ?? 'Not selected',
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownMenu<Node>(
                initialSelection: selectedNode,
                dropdownMenuEntries: _availableNodes
                    .map((node) => DropdownMenuEntry<Node>(
                          value: node,
                          label: node.name,
                          leadingIcon: Icon(
                            _getNodeTypeIcon(node.type),
                            color: _getNodeTypeColor(node.type),
                            size: 20,
                          ),
                        ))
                    .toList(),
                onSelected: onNodeChanged,
                width: MediaQuery.of(context).size.width - 72,
                textStyle: const TextStyle(fontSize: 16),
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white),
                  elevation: WidgetStateProperty.all(4),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                hintText: 'Select $label',
              ),
              if (selectedNode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getNodeTypeColor(selectedNode.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getNodeTypeIcon(selectedNode.type),
                        size: 16,
                        color: _getNodeTypeColor(selectedNode.type),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedNode.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getNodeTypeColor(selectedNode.type),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
