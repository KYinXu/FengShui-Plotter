import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:feng_shui_plotter/widgets/objects/object_item.dart';
import 'dart:math';

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
  final List<BoundaryElement> boundaries;

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

  Grid addBoundary(BoundaryElement boundary) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: objects,
      boundaries: [...boundaries, boundary],
    );
  }

  Grid removeBoundary(BoundaryElement boundary) {
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
    List<BoundaryElement>? boundaries,
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