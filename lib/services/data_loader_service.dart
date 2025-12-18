import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/node.dart';
import '../models/edge.dart';

/// Service for loading nodes and edges from JSON files
class DataLoaderService {
  /// Load nodes from JSON file
  static Future<List<Node>> loadNodes() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/nodes.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Node.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // Return empty list if file not found (for development)
      return [];
    }
  }

  /// Load edges from JSON file
  static Future<List<Edge>> loadEdges() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/edges.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => Edge.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // Return empty list if file not found (for development)
      return [];
    }
  }
}

