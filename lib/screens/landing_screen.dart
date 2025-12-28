import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../services/data_loader_service.dart';
import '../services/path_finder_service.dart';
import '../services/voice_input_service.dart';
import 'path_visualization_screen.dart';
import 'camera_location_screen.dart';

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
  int? _selectedSourceFloor; // null means "all floors"
  int? _selectedTargetFloor; // null means "all floors"
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;
  
  // Voice input
  final VoiceInputService _voiceInputService = VoiceInputService();
  bool _isListeningSource = false;
  bool _isListeningTarget = false;
  String? _recognizedText;

  @override
  void initState() {
    super.initState();
    // Start loading immediately but ensure UI renders first
    Future.microtask(() {
      _loadData();
      _initializeVoiceInput();
    });
  }

  /// Initialize voice input service
  Future<void> _initializeVoiceInput() async {
    await _voiceInputService.initialize();
  }

  @override
  void dispose() {
    _voiceInputService.dispose();
    super.dispose();
  }

  /// Load nodes and edges from JSON files
  Future<void> _loadData() async {
    // Ensure UI has rendered before starting heavy operations
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      // Load both in parallel for better performance
      final results = await Future.wait([
        DataLoaderService.loadNodes(),
        DataLoaderService.loadEdges(),
      ]);

      if (mounted) {
        setState(() {
          _availableNodes = results[0] as List<Node>;
          _edges = results[1] as List<Edge>;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load map data: ${e.toString()}';
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
        return const Color(0xFF1B3C53); // Dark muted blue from palette
      case 'office':
        return const Color(0xFF234C6A); // Primary blue from palette
      case 'connection':
        return const Color(0xFF456882); // Medium blue-grey from palette
      default:
        return const Color(0xFF456882); // Medium blue-grey from palette
    }
  }

  /// Get list of available floors from nodes
  List<int> _getAvailableFloors() {
    final floors = _availableNodes
        .where((node) => 
            node.type.toLowerCase() != 'corridor' && 
            node.type.toLowerCase() != 'connection')
        .map((node) => node.floor)
        .toSet()
        .toList();
    floors.sort();
    return floors;
  }

  /// Get filtered nodes based on floor filter and type filter
  List<Node> _getFilteredNodes(int? floorFilter) {
    return _availableNodes.where((node) {
      // Filter out corridors and connections
      if (node.type.toLowerCase() == 'corridor' || 
          node.type.toLowerCase() == 'connection') {
        return false;
      }
      // Filter by floor if a floor is selected
      if (floorFilter != null && node.floor != floorFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Handle source floor filter change
  void _onSourceFloorFilterChanged(int? floor) {
    setState(() {
      _selectedSourceFloor = floor;
      
      // Clear source selection if it's not on the selected floor
      if (_selectedSourceNode != null && 
          floor != null && 
          _selectedSourceNode!.floor != floor) {
        _selectedSourceNode = null;
      }
      
      if (floor != null) {
        HapticFeedback.lightImpact();
      }
    });
  }

  /// Handle target floor filter change
  void _onTargetFloorFilterChanged(int? floor) {
    setState(() {
      _selectedTargetFloor = floor;
      
      // Clear target selection if it's not on the selected floor
      if (_selectedTargetNode != null && 
          floor != null && 
          _selectedTargetNode!.floor != floor) {
        _selectedTargetNode = null;
      }
      
      if (floor != null) {
        HapticFeedback.lightImpact();
      }
    });
  }

  /// Open camera screen to find location
  Future<void> _findMyLocation() async {
    HapticFeedback.mediumImpact();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraLocationScreen(
          availableNodes: _availableNodes,
        ),
      ),
    );

    if (result != null && result is Node) {
      setState(() {
        _selectedSourceNode = result;
      });
      
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location detected: ${result.name}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// Handle voice input for source node
  Future<void> _handleVoiceInputSource() async {
    if (_isListeningSource || _isListeningTarget) {
      await _voiceInputService.stopListening();
      setState(() {
        _isListeningSource = false;
        _isListeningTarget = false;
        _recognizedText = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    // Check permission
    if (!await _voiceInputService.hasPermission()) {
      final granted = await _voiceInputService.requestPermission();
      if (!granted) {
        _showError('Microphone permission is required for voice input');
        return;
      }
    }


    setState(() {
      _isListeningSource = true;
      _recognizedText = null;
    });

    try {
      final recognizedText = await _voiceInputService.startListening(
        localeId: 'en_US',
        listenDuration: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _isListeningSource = false;
          _recognizedText = recognizedText;
        });

        if (recognizedText != null && recognizedText.isNotEmpty) {
          // Show what was recognized for debugging
          print('Recognized text: $recognizedText');
          
          // Find matching node
          final matchedNode = _voiceInputService.findMatchingNode(
            recognizedText,
            _getFilteredNodes(_selectedSourceFloor),
          );

          if (matchedNode != null) {
            setState(() {
              _selectedSourceNode = matchedNode;
            });
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected: ${matchedNode.name}'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            _showError('Could not find location "$recognizedText". Please try speaking the room number clearly (e.g., "A114").');
          }
        } else {
          _showError('No speech detected. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListeningSource = false;
        });
        _showError('Voice input error: ${e.toString()}');
      }
    }
  }

  /// Handle voice input for target node
  Future<void> _handleVoiceInputTarget() async {
    if (_isListeningSource || _isListeningTarget) {
      await _voiceInputService.stopListening();
      setState(() {
        _isListeningSource = false;
        _isListeningTarget = false;
        _recognizedText = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    // Check permission
    if (!await _voiceInputService.hasPermission()) {
      final granted = await _voiceInputService.requestPermission();
      if (!granted) {
        _showError('Microphone permission is required for voice input');
        return;
      }
    }

    setState(() {
      _isListeningTarget = true;
      _recognizedText = null;
    });

    try {
      final recognizedText = await _voiceInputService.startListening(
        localeId: 'en_US',
        listenDuration: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _isListeningTarget = false;
          _recognizedText = recognizedText;
        });

        if (recognizedText != null && recognizedText.isNotEmpty) {
          // Find matching node
          final matchedNode = _voiceInputService.findMatchingNode(
            recognizedText,
            _getFilteredNodes(_selectedTargetFloor),
          );

          if (matchedNode != null) {
            setState(() {
              _selectedTargetNode = matchedNode;
            });
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected: ${matchedNode.name}'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            _showError('Could not find location "$recognizedText". Please try again.');
          }
        } else {
          _showError('No speech detected. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListeningTarget = false;
        });
        _showError('Voice input error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading map data...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
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
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                          floorFilter: _selectedSourceFloor,
                          onNodeChanged: (Node? node) {
                            setState(() {
                              _selectedSourceNode = node;
                            });
                            if (node != null) {
                              HapticFeedback.lightImpact();
                            }
                          },
                          onFloorFilterChanged: _onSourceFloorFilterChanged,
                          onFindLocation: _findMyLocation,
                          onVoiceInput: _handleVoiceInputSource,
                          isListening: _isListeningSource,
                          recognizedText: _isListeningSource ? _recognizedText : null,
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
                          floorFilter: _selectedTargetFloor,
                          onNodeChanged: (Node? node) {
                            setState(() {
                              _selectedTargetNode = node;
                            });
                            if (node != null) {
                              HapticFeedback.lightImpact();
                            }
                          },
                          onFloorFilterChanged: _onTargetFloorFilterChanged,
                          onVoiceInput: _handleVoiceInputTarget,
                          isListening: _isListeningTarget,
                          recognizedText: _isListeningTarget ? _recognizedText : null,
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
    int? floorFilter,
    required ValueChanged<int?> onFloorFilterChanged,
    VoidCallback? onFindLocation,
    VoidCallback? onVoiceInput,
    bool isListening = false,
    String? recognizedText,
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
              // Floor Filter for this selector
              _buildInlineFloorFilter(
                floorFilter: floorFilter,
                onFloorFilterChanged: onFloorFilterChanged,
              ),
              const SizedBox(height: 12),
              // Action buttons row
              Row(
                children: [
                  // Find My Location button (only for source node)
                  if (onFindLocation != null) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Find my location using camera',
                        hint: 'Double tap to open camera and detect your current location',
                        child: OutlinedButton.icon(
                          onPressed: onFindLocation,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Find My Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Voice Input button
                  if (onVoiceInput != null) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: isListening 
                            ? 'Stop listening for voice input' 
                            : 'Start voice input for $label location',
                        hint: isListening
                            ? 'Double tap to stop listening'
                            : 'Double tap to speak your destination',
                        child: OutlinedButton.icon(
                          onPressed: onVoiceInput,
                          icon: isListening
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                  ),
                                )
                              : const Icon(Icons.mic),
                          label: Text(isListening ? 'Listening...' : 'Voice'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isListening
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: isListening
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Show recognized text when listening or after recognition
              if (recognizedText != null && recognizedText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isListening
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isListening ? Icons.record_voice_over : Icons.check_circle,
                        size: 16,
                        color: isListening
                            ? Theme.of(context).colorScheme.primary
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isListening
                              ? 'Listening: "$recognizedText"'
                              : 'Recognized: "$recognizedText"',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isListening
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownMenu<Node>(
                initialSelection: selectedNode,
                dropdownMenuEntries: _getFilteredNodes(floorFilter)
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

  /// Build inline floor filter widget (compact version for node selector)
  Widget _buildInlineFloorFilter({
    int? floorFilter,
    required ValueChanged<int?> onFloorFilterChanged,
  }) {
    final availableFloors = _getAvailableFloors();
    
    return Row(
      children: [
        Icon(
          Icons.layers,
          size: 18,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          'Floor:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownMenu<int?>(
            initialSelection: floorFilter,
            dropdownMenuEntries: [
              const DropdownMenuEntry<int?>(
                value: null,
                label: 'All Floors',
              ),
              ...availableFloors.map((floor) => DropdownMenuEntry<int?>(
                    value: floor,
                    label: 'Floor $floor',
                  )),
            ],
            onSelected: onFloorFilterChanged,
            textStyle: const TextStyle(fontSize: 14),
            menuStyle: MenuStyle(
              backgroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(4),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            hintText: 'All Floors',
          ),
        ),
      ],
    );
  }
}
