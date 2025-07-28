import 'package:flutter/material.dart';
import '../models/grid_model.dart';

class BoundaryPlacerService {
  static const int _span = 12; // 12 grid spaces (1 foot)
  static const double _snapRadius = 1.0; // Within 1 grid cell
  static const double _edgeThreshold = 0.2; // For click placement

  /// Checks if a type is a boundary type
  static bool isBoundaryType(String type) {
    return type == 'door' || type == 'window';
  }

  /// Finds the nearest border side to a given position
  static Map<String, dynamic>? findNearestBorderSide(
    double col, 
    double row, 
    int maxRow, 
    int maxCol
  ) {
    final borderChecks = [
      {'side': 'top', 'row': 0, 'col': col.floor(), 'dist': (row - 0).abs()},
      {'side': 'bottom', 'row': maxRow - 1, 'col': col.floor(), 'dist': (row - (maxRow - 1)).abs()},
      {'side': 'left', 'row': row.floor(), 'col': 0, 'dist': (col - 0).abs()},
      {'side': 'right', 'row': row.floor(), 'col': maxCol - 1, 'dist': (col - (maxCol - 1)).abs()},
    ];

    double minDist = double.infinity;
    String? nearestSide;
    int nearestRow = row.floor();
    int nearestCol = col.floor();

    for (final check in borderChecks) {
      final dist = check['dist'] as double;
      if (dist < minDist) {
        minDist = dist;
        nearestSide = check['side'] as String;
        nearestRow = check['row'] as int;
        nearestCol = check['col'] as int;
      }
    }

    if (minDist > _snapRadius) return null;

    return {
      'side': nearestSide,
      'row': nearestRow,
      'col': nearestCol,
      'dist': minDist,
    };
  }

  /// Validates if boundary placement is possible for the given side and grid dimensions
  static bool canPlaceBoundary(String side, int maxRow, int maxCol) {
    if ((side == 'top' || side == 'bottom') && maxCol < _span) return false;
    if ((side == 'left' || side == 'right') && maxRow < _span) return false;
    return true;
  }

  /// Calculates the starting position for a boundary segment
  static Map<String, int> calculateBoundaryStart(
    String side, 
    int cellRow, 
    int cellCol, 
    int maxRow, 
    int maxCol
  ) {
    int startRow = cellRow;
    int startCol = cellCol;

    switch (side) {
      case 'top':
        if (startCol + _span > maxCol) startCol = maxCol - _span;
        break;
      case 'bottom':
        if (startCol + _span > maxCol) startCol = maxCol - _span;
        break;
      case 'left':
        if (startRow + _span > maxRow) startRow = maxRow - _span;
        break;
      case 'right':
        if (startRow + _span > maxRow) startRow = maxRow - _span;
        break;
    }

    return {'row': startRow, 'col': startCol};
  }

  /// Checks if a position is on the outer edge of the grid
  static bool isOuterEdge(String side, int cellRow, int cellCol, int maxRow, int maxCol) {
    switch (side) {
      case 'top':
        return cellRow == 0;
      case 'bottom':
        return cellRow == maxRow - 1;
      case 'left':
        return cellCol == 0;
      case 'right':
        return cellCol == maxCol - 1;
      default:
        return false;
    }
  }

  /// Creates a boundary segment for the given parameters
  static List<BoundaryElement> createBoundarySegment(
    String type, 
    String side, 
    int startRow, 
    int startCol
  ) {
    List<BoundaryElement> segment = [];
    
    for (int i = 0; i < _span; i++) {
      switch (side) {
        case 'top':
        case 'bottom':
          segment.add(BoundaryElement(
            type: type, 
            row: startRow, 
            col: startCol + i, 
            side: side
          ));
          break;
        case 'left':
        case 'right':
          segment.add(BoundaryElement(
            type: type, 
            row: startRow + i, 
            col: startCol, 
            side: side
          ));
          break;
      }
    }
    
    return segment;
  }

  /// Handles boundary placement from drag and drop
  static BoundaryPlacementResult? handleBoundaryDrop(
    String type,
    double col,
    double row,
    int maxRow,
    int maxCol,
    List<BoundaryElement> existingBoundaries
  ) {
    final borderInfo = findNearestBorderSide(col, row, maxRow, maxCol);
    if (borderInfo == null) return null;

    final side = borderInfo['side'] as String;
    final nearestRow = borderInfo['row'] as int;
    final nearestCol = borderInfo['col'] as int;

    if (!canPlaceBoundary(side, maxRow, maxCol)) return null;

    final startPos = calculateBoundaryStart(side, nearestRow, nearestCol, maxRow, maxCol);
    final segment = createBoundarySegment(type, side, startPos['row']!, startPos['col']!);

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    
    return BoundaryPlacementResult(
      segment: segment,
      shouldRemove: allExist,
    );
  }

  /// Handles boundary placement from click
  static BoundaryPlacementResult? handleBoundaryClick(
    String type,
    double col,
    double row,
    int maxRow,
    int maxCol,
    List<BoundaryElement> existingBoundaries
  ) {
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Find nearest edge
    double minDist = 1.0;
    String? side;
    if (dx < _edgeThreshold) { minDist = dx; side = 'left'; }
    if (1 - dx < minDist) { minDist = 1 - dx; side = 'right'; }
    if (dy < minDist) { minDist = dy; side = 'top'; }
    if (1 - dy < minDist) { minDist = 1 - dy; side = 'bottom'; }

    if (side == null || minDist >= _edgeThreshold) return null;

    if (!canPlaceBoundary(side, maxRow, maxCol)) return null;

    if (!isOuterEdge(side, cellRow, cellCol, maxRow, maxCol)) return null;

    final startPos = calculateBoundaryStart(side, cellRow, cellCol, maxRow, maxCol);
    final segment = createBoundarySegment(type, side, startPos['row']!, startPos['col']!);

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    
    return BoundaryPlacementResult(
      segment: segment,
      shouldRemove: allExist,
    );
  }

  /// Calculates preview position for boundary placement
  static BoundaryPreviewInfo? calculateBoundaryPreview(
    double col,
    double row,
    int maxRow,
    int maxCol,
    double cellInchSize
  ) {
    final borderInfo = findNearestBorderSide(col, row, maxRow, maxCol);
    if (borderInfo == null) return null;

    final side = borderInfo['side'] as String;
    final nearestRow = borderInfo['row'] as int;
    final nearestCol = borderInfo['col'] as int;

    if (!canPlaceBoundary(side, maxRow, maxCol)) return null;

    final startPos = calculateBoundaryStart(side, nearestRow, nearestCol, maxRow, maxCol);
    
    final x = startPos['col']! * cellInchSize;
    final y = startPos['row']! * cellInchSize;
    final x2 = (side == 'top' || side == 'bottom') ? (startPos['col']! + _span) * cellInchSize : x;
    final y2 = (side == 'left' || side == 'right') ? (startPos['row']! + _span) * cellInchSize : y;

    return BoundaryPreviewInfo(
      side: side,
      x: x,
      y: y,
      x2: x2,
      y2: y2,
    );
  }
}

/// Result of boundary placement operation
class BoundaryPlacementResult {
  final List<BoundaryElement> segment;
  final bool shouldRemove;

  const BoundaryPlacementResult({
    required this.segment,
    required this.shouldRemove,
  });
}

/// Information for boundary preview
class BoundaryPreviewInfo {
  final String side;
  final double x;
  final double y;
  final double x2;
  final double y2;

  const BoundaryPreviewInfo({
    required this.side,
    required this.x,
    required this.y,
    required this.x2,
    required this.y2,
  });
} 