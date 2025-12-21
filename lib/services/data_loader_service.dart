import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/node.dart';
import '../models/edge.dart';

/// Service for loading nodes and edges from JSON files
class DataLoaderService {
  /// Load nodes from JSON file
  static Future<List<Node>> loadNodes() async {
    try {
      // Load JSON string
      final String jsonString =
          await rootBundle.loadString('assets/data/nodes.json');
      
      // Parse JSON asynchronously to avoid blocking
      await Future.delayed(Duration.zero); // Yield to event loop
      
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Node.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load nodes: $e');
    }
  }

  /// Load edges from JSON file
  static Future<List<Edge>> loadEdges() async {
    try {
      // Load JSON string
      final String jsonString =
          await rootBundle.loadString('assets/data/edges.json');
      
      // Parse JSON asynchronously to avoid blocking
      await Future.delayed(Duration.zero); // Yield to event loop
      
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Edge.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load edges: $e');
    }
  }
}

