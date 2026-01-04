import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/company.dart';
import '../models/block.dart';
import '../models/place.dart';
import '../models/node_db.dart';
import '../models/edge_db.dart';

/// API Service for communicating with the VAVI backend API
/// Base URL: http://10.0.2.2:3000 (for Android Emulator)
class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // ==================== COMPANY METHODS ====================

  /// Get all companies
  static Future<List<Company>> getCompanies() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/companies'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Company.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load companies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching companies: $e');
    }
  }

  /// Get a specific company by ID
  static Future<Company> getCompany(String companyID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/companies/$companyID'));
      
      if (response.statusCode == 200) {
        return Company.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load company: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching company: $e');
    }
  }

  /// Create a new company
  static Future<Company> createCompany(Company company) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/companies'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(company.toJson()),
      );
      
      if (response.statusCode == 201) {
        return Company.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create company: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating company: $e');
    }
  }

  // ==================== BLOCK METHODS ====================

  /// Get all blocks
  static Future<List<Block>> getBlocks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blocks'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Block.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load blocks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching blocks: $e');
    }
  }

  /// Get a specific block by ID
  static Future<Block> getBlock(String blockID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blocks/$blockID'));
      
      if (response.statusCode == 200) {
        return Block.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load block: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching block: $e');
    }
  }

  /// Get blocks by company ID
  static Future<List<Block>> getBlocksByCompany(String companyID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/blocks/company/$companyID'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Block.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load blocks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching blocks: $e');
    }
  }

  /// Create a new block
  static Future<Block> createBlock(Block block) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/blocks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(block.toJson()),
      );
      
      if (response.statusCode == 201) {
        return Block.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create block: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating block: $e');
    }
  }

  // ==================== PLACE METHODS ====================

  /// Get all places
  static Future<List<Place>> getPlaces() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/places'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Place.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching places: $e');
    }
  }

  /// Get a specific place by ID
  static Future<Place> getPlace(String placeID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/places/$placeID'));
      
      if (response.statusCode == 200) {
        return Place.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load place: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching place: $e');
    }
  }

  /// Get places by block ID
  static Future<List<Place>> getPlacesByBlock(String blockID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/places/block/$blockID'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Place.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching places: $e');
    }
  }

  /// Create a new place
  static Future<Place> createPlace(Place place) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/places'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(place.toJson()),
      );
      
      if (response.statusCode == 201) {
        return Place.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create place: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating place: $e');
    }
  }

  // ==================== NODE METHODS ====================

  /// Get all nodes
  static Future<List<NodeDB>> getNodes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/nodes'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => NodeDB.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load nodes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching nodes: $e');
    }
  }

  /// Get a specific node by ID
  static Future<NodeDB> getNode(String nodeID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/nodes/$nodeID'));
      
      if (response.statusCode == 200) {
        return NodeDB.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load node: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching node: $e');
    }
  }

  /// Get nodes by place ID
  static Future<List<NodeDB>> getNodesByPlace(String placeID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/nodes/place/$placeID'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => NodeDB.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load nodes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching nodes: $e');
    }
  }

  /// Create a new node
  static Future<NodeDB> createNode(NodeDB node) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nodes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(node.toJson()),
      );
      
      if (response.statusCode == 201) {
        return NodeDB.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create node: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating node: $e');
    }
  }

  // ==================== EDGE METHODS ====================

  /// Get all edges
  static Future<List<EdgeDB>> getEdges() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/edges'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => EdgeDB.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load edges: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching edges: $e');
    }
  }

  /// Get a specific edge by ID
  static Future<EdgeDB> getEdge(String edgeID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/edges/$edgeID'));
      
      if (response.statusCode == 200) {
        return EdgeDB.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load edge: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching edge: $e');
    }
  }

  /// Get edges connected to a node (as source or target)
  static Future<List<EdgeDB>> getEdgesByNode(String nodeID) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/edges/node/$nodeID'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => EdgeDB.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load edges: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching edges: $e');
    }
  }

  /// Create a new edge
  static Future<EdgeDB> createEdge(EdgeDB edge) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/edges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(edge.toJson()),
      );
      
      if (response.statusCode == 201) {
        return EdgeDB.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create edge: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating edge: $e');
    }
  }
}

