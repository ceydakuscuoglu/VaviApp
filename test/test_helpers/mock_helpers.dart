import 'package:vavi_app/models/node.dart';
import 'package:vavi_app/models/edge.dart';

/// Mock data and helper functions for testing
class MockHelpers {
  /// Create mock nodes for testing
  static List<Node> createMockNodes() {
    return [
      Node(
        id: 'node1',
        name: 'Room 101',
        type: 'room',
        pos: [0.0, 0.0, 0.0],
        floor: 1,
      ),
      Node(
        id: 'node2',
        name: 'Room 102',
        type: 'room',
        pos: [10.0, 0.0, 0.0],
        floor: 1,
      ),
      Node(
        id: 'node3',
        name: 'Elevator A',
        type: 'elevator',
        pos: [5.0, 0.0, 0.0],
        floor: 1,
      ),
      Node(
        id: 'node4',
        name: 'Staircase 1',
        type: 'staircase',
        pos: [15.0, 0.0, 0.0],
        floor: 1,
      ),
      Node(
        id: 'node5',
        name: 'Room 201',
        type: 'room',
        pos: [0.0, 0.0, 3.0],
        floor: 2,
      ),
    ];
  }

  /// Create mock edges for testing
  static List<Edge> createMockEdges() {
    return [
      Edge(
        source: 'node1',
        target: 'node2',
        distance: 10.0,
        type: 'horizontal_connection',
      ),
      Edge(
        source: 'node2',
        target: 'node3',
        distance: 5.0,
        type: 'horizontal_connection',
      ),
      Edge(
        source: 'node3',
        target: 'node5',
        distance: 3.0,
        type: 'vertical_connection',
      ),
      Edge(
        source: 'node2',
        target: 'node4',
        distance: 5.0,
        type: 'horizontal_connection',
      ),
    ];
  }

  /// Create mock Wi-Fi scan results
  static List<Map<String, dynamic>> createMockWiFiScanResults() {
    return [
      {
        'bssid': '00:11:22:33:44:55',
        'ssid': 'AP1',
        'rssi': -45,
        'frequency': 2400,
      },
      {
        'bssid': '00:11:22:33:44:56',
        'ssid': 'AP2',
        'rssi': -60,
        'frequency': 2400,
      },
      {
        'bssid': '00:11:22:33:44:57',
        'ssid': 'AP3',
        'rssi': -75,
        'frequency': 5000,
      },
    ];
  }

  /// Create mock IMU readings
  static Map<String, dynamic> createMockIMUReading() {
    return {
      'acceleration': {'x': 0.1, 'y': 0.2, 'z': 9.8},
      'gyroscope': {'x': 0.01, 'y': 0.02, 'z': 0.03},
      'magnetometer': {'x': 20.0, 'y': 30.0, 'z': 40.0},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Create mock YOLO detection results
  static List<Map<String, dynamic>> createMockYOLODetections() {
    return [
      {
        'class': 'person',
        'confidence': 0.95,
        'bbox': {'x': 100, 'y': 150, 'width': 200, 'height': 300},
        'position': 'left',
      },
      {
        'class': 'person',
        'confidence': 0.88,
        'bbox': {'x': 500, 'y': 150, 'width': 200, 'height': 300},
        'position': 'right',
      },
    ];
  }

  /// Create normalized RSSI list
  static List<double> createNormalizedRSSI() {
    return [1.0, 0.75, 0.5, 0.25, 0.1];
  }
}

