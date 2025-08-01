import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:feng_shui_plotter/widgets/objects/object_item.dart';
import 'dart:math';

/// Configuration for different boundary types
class BoundaryConfig {
  final String type;
  final double length; // Length in inches
  final double thickness; // Thickness in inches
  final IconData icon;
  final Color color;

  const BoundaryConfig({
    required this.type,
    required this.length,
    required this.thickness,
    required this.icon,
    required this.color,
  });
}

/// Registry of boundary configurations
class BoundaryRegistry {
  static const Map<String, BoundaryConfig> _configs = {
    'door': BoundaryConfig(
      type: 'door',
      length: 30.0, // 30 inches
      thickness: 0.1, // Thin line
      icon: Icons.door_front_door,
      color: Colors.orange,
    ),
    'window': BoundaryConfig(
      type: 'window',
      length: 24.0, // 24 inches
      thickness: 0.1, // Thin line
      icon: Icons.window,
      color: Colors.blue,
    ),
    'large_door': BoundaryConfig(
      type: 'large_door',
      length: 36.0, // 36 inches
      thickness: 0.1, // Thin line
      icon: Icons.door_front_door,
      color: Colors.orange,
    ),
    'small_window': BoundaryConfig(
      type: 'small_window',
      length: 18.0, // 18 inches
      thickness: 0.1, // Thin line
      icon: Icons.window,
      color: Colors.blue,
    ),
  };

  /// Get boundary configuration by type
  static BoundaryConfig? getConfig(String type) {
    return _configs[type];
  }

  /// Get all available boundary types
  static List<String> getAvailableTypes() {
    return _configs.keys.toList();
  }

  /// Add a new boundary configuration
  static void addConfig(BoundaryConfig config) {
    _configs[config.type] = config;
  }
}

class GridObject {
  final String type;
  final int row;
  final int col;
  final IconData icon;
  final int rotation; // degrees, e.g., 0, 90, 180, 270

  GridObject({
    required this.type,
    required this.row,
    required this.col,
    required this.icon,
    this.rotation = 0,
  });

  /// Returns the polygon for this object, transformed for rotation and position
  List<Offset> getTransformedPolygon() {
    final poly = ObjectItem.getObjectPolygon(type);
    final double angleRad = (rotation % 360) * 3.1415926535897932 / 180.0;
    final double cosA = cos(angleRad);
    final double sinA = sin(angleRad);
    // Transform: rotate around (0,0), then translate to (col, row)
    return poly.map((p) {
      final double x = p.dx;
      final double y = p.dy;
      final double rx = x * cosA - y * sinA;
      final double ry = x * sinA + y * cosA;
      return Offset(rx + col, ry + row);
    }).toList();
  }
}

class GridBoundary {
  final String type; // 'door' or 'window'
  final int row;
  final int col;
  final String side; // 'top', 'bottom', 'left', 'right'
  final IconData icon;

  const GridBoundary({
    required this.type,
    required this.row,
    required this.col,
    required this.side,
    required this.icon,
  });

  /// Returns the polygon for this boundary (a line segment)
  List<Offset> getTransformedPolygon() {
    final config = BoundaryRegistry.getConfig(type);
    if (config == null) {
      // Fallback to default values
      const double thickness = 0.1;
      const double length = 30.0;
      return _createPolygon(length, thickness);
    }
    
    return _createPolygon(config.length, config.thickness);
  }

  /// Creates a polygon with the given dimensions
  List<Offset> _createPolygon(double length, double thickness) {
    List<Offset> poly;
    switch (side) {
      case 'top':
        poly = [
          Offset(0, 0),
          Offset(length, 0),
          Offset(length, thickness),
          Offset(0, thickness),
        ];
        break;
      case 'bottom':
        poly = [
          Offset(0, 1 - thickness),
          Offset(length, 1 - thickness),
          Offset(length, 1),
          Offset(0, 1),
        ];
        break;
      case 'left':
        poly = [
          Offset(0, 0),
          Offset(thickness, 0),
          Offset(thickness, length),
          Offset(0, length),
        ];
        break;
      case 'right':
        poly = [
          Offset(1 - thickness, 0),
          Offset(1, 0),
          Offset(1, length),
          Offset(1 - thickness, length),
        ];
        break;
      default:
        poly = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
    }
    
    // Translate to position
    return poly.map((p) => Offset(p.dx + col, p.dy + row)).toList();
  }

  @override
  String toString() => 'GridBoundary(type: $type, row: $row, col: $col, side: $side)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridBoundary &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          row == other.row &&
          col == other.col &&
          side == other.side;

  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ col.hashCode ^ side.hashCode;
}

// Keep BoundaryElement for backward compatibility with existing services
class BoundaryElement {
  final String type; // 'door' or 'window'
  final int row;
  final int col;
  final String side; // 'top', 'bottom', 'left', 'right'

  const BoundaryElement({
    required this.type,
    required this.row,
    required this.col,
    required this.side,
  });

  @override
  String toString() => 'BoundaryElement(type: $type, row: $row, col: $col, side: $side)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundaryElement &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          row == other.row &&
          col == other.col &&
          side == other.side;

  @override
  int get hashCode => type.hashCode ^ row.hashCode ^ col.hashCode ^ side.hashCode;
}

class Grid extends Equatable {
  final double lengthInches;
  final double widthInches;
  final List<GridObject> objects;
  final List<GridBoundary> boundaries;

  const Grid({
    required this.lengthInches,
    required this.widthInches,
    this.objects = const [],
    this.boundaries = const [],
  });

  Grid addObject(GridObject object) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: [...objects, object],
      boundaries: boundaries,
    );
  }

  Grid removeObject(GridObject object) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: objects.where((o) => o != object).toList(),
      boundaries: boundaries,
    );
  }

  Grid addBoundary(GridBoundary boundary) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: objects,
      boundaries: [...boundaries, boundary],
    );
  }

  Grid removeBoundary(GridBoundary boundary) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: objects,
      boundaries: boundaries.where((b) => b != boundary).toList(),
    );
  }

  Grid copyWith({
    double? lengthInches,
    double? widthInches,
    List<GridObject>? objects,
    List<GridBoundary>? boundaries,
  }) {
    return Grid(
      lengthInches: lengthInches ?? this.lengthInches,
      widthInches: widthInches ?? this.widthInches,
      objects: objects ?? this.objects,
      boundaries: boundaries ?? this.boundaries,
    );
  }

  @override
  String toString() {
    return 'Grid(lengthInches: $lengthInches, widthInches: $widthInches, boundaries: $boundaries)';
  }
  
  @override
  List<Object?> get props => [lengthInches, widthInches, objects, boundaries];
} 