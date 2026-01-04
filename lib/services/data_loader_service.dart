import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/node.dart';
import '../models/edge.dart';

/// Service for loading nodes and edges from JSON files
class DataLoaderService {
  /// Parse nodes from JSON string in background isolate
  static List<Node> _parseNodes(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList.map((json) => Node.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Parse edges from JSON string in background isolate
  static List<Edge> _parseEdges(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList.map((json) => Edge.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Load nodes from JSON file
  static Future<List<Node>> loadNodes() async {
    try {
      // Load JSON string (this is async and non-blocking)
      final String jsonString =
          await rootBundle.loadString('assets/data/nodes.json');
      
      // Parse JSON in background isolate to avoid blocking main thread
      return await compute(_parseNodes, jsonString);
    } catch (e) {
      throw Exception('Failed to load nodes: $e');
    }
  }

  /// Load edges from JSON file
  static Future<List<Edge>> loadEdges() async {
    try {
      // Load JSON string (this is async and non-blocking)
      final String jsonString =
          await rootBundle.loadString('assets/data/edges.json');
      
      // Parse JSON in background isolate to avoid blocking main thread
      return await compute(_parseEdges, jsonString);
    } catch (e) {
      throw Exception('Failed to load edges: $e');
    }
  }

  /// Search for nodes by name containing the given text (case-insensitive)
  /// 
  /// Returns the first matching node, or null if no match is found
  static Node? findNodeByName(List<Node> nodes, String searchText) {
    if (searchText.isEmpty) {
      return null;
    }
    
    // Normalize search text (uppercase, remove spaces/hyphens for flexible matching)
    final normalizedSearch = searchText.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    
    // First, try exact substring match (case-insensitive)
    for (final node in nodes) {
      final normalizedName = node.name.toUpperCase();
      if (normalizedName.contains(searchText.toUpperCase())) {
        return node;
      }
    }
    
    // If no exact match, try normalized matching (removing spaces/hyphens)
    for (final node in nodes) {
      final normalizedName = node.name.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
      if (normalizedName.contains(normalizedSearch)) {
        return node;
      }
    }
    
    return null;
  }
}

