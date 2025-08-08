import 'package:flutter/material.dart';

/// Centralized object configuration that matches Python definitions
class ObjectConfig {
  /// Object dimensions in inches
  static const Map<String, Map<String, int>> dimensions = {
    'bed': {'width': 80, 'height': 60},
    'desk': {'width': 48, 'height': 24},
    'door': {'width': 30, 'height': 0},  // Door is a boundary, not a regular object
    'window': {'width': 24, 'height': 0},  // Window is a boundary, not a regular object
  };

  /// Object icons
  static const Map<String, IconData> icons = {
    'bed': Icons.bed,
    'desk': Icons.desk,
    'door': Icons.door_front_door,
    'window': Icons.window,
  };

  /// Get object dimensions
  static Map<String, int> getDimensions(String type) {
    return dimensions[type.toLowerCase()] ?? {'width': 1, 'height': 1};
  }

  /// Get object icon
  static IconData getIcon(String type) {
    return icons[type.toLowerCase()] ?? Icons.auto_awesome;
  }

  /// Convert inches to grid cells (1 grid cell = 12 inches)
  static Map<String, int> getGridDimensions(String type) {
    final dims = getDimensions(type);
    return {
      'width': (dims['width']! / 12).ceil(),
      'height': (dims['height']! / 12).ceil(),
    };
  }

  /// Get all available object types
  static List<String> getAvailableTypes() {
    return dimensions.keys.toList();
  }

  /// Check if object is a boundary (door/window)
  static bool isBoundary(String type) {
    return type.toLowerCase() == 'door' || type.toLowerCase() == 'window';
  }
} 