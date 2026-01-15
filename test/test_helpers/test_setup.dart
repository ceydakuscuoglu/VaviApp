import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Common test setup utilities
class TestSetup {
  /// Create a test widget with MaterialApp wrapper
  static Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  /// Wait for async operations to complete
  static Future<void> waitForAsync() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Wait for a specific condition to be true
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (condition()) {
        return;
      }
      await Future.delayed(pollInterval);
    }
    throw TimeoutException('Condition not met within timeout');
  }

  /// Create a mock camera image (placeholder)
  static Map<String, dynamic> createMockCameraImage() {
    return {
      'width': 640,
      'height': 480,
      'format': 'yuv420',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

