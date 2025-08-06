import 'package:flutter/material.dart';
import '../models/grid_model.dart';

class BoundaryPlacerService {
  static const int _span = 12; // 12 grid spaces (1 foot)
  static const double _snapRadius = 2.5; // More generous snap radius (2.5 grid cells)
  static const double _edgeThreshold = 0.3; // More generous edge threshold for click placement

  /// Checks if a type is a boundary type
  static bool isBoundaryType(String type) {
    return type == 'door' || type == 'window';
  }

  /// Converts BoundaryElement to GridBoundary
  static GridBoundary boundaryElementToGridBoundary(BoundaryElement element, IconData icon) {
    return GridBoundary(
      type: element.type,
      row: element.row,
      col: element.col,
      side: element.side,
      icon: icon,
    );
  }

  /// Converts GridBoundary to BoundaryElement
  static BoundaryElement gridBoundaryToBoundaryElement(GridBoundary boundary) {
    return BoundaryElement(
      type: boundary.type,
      row: boundary.row,
      col: boundary.col,
      side: boundary.side,
    );
  }

  /// Converts list of BoundaryElements to GridBoundaries
  static List<GridBoundary> boundaryElementsToGridBoundaries(
    List<BoundaryElement> elements,
    IconData icon
  ) {
    return elements.map((e) => boundaryElementToGridBoundary(e, icon)).toList();
  }

  /// Converts list of GridBoundaries to BoundaryElements
  static List<BoundaryElement> gridBoundariesToBoundaryElements(List<GridBoundary> boundaries) {
    return boundaries.map((b) => gridBoundaryToBoundaryElement(b)).toList();
  }

  /// Finds the nearest border side to a given position
  static Map<String, dynamic>? findNearestBorderSide(
    double col, 
    double row, 
    int maxRow, 
    int maxCol
  ) {
    print('findNearestBorderSide: col=$col, row=$row, maxRow=$maxRow, maxCol=$maxCol');
    
    final borderChecks = [
      {'side': 'top', 'row': 0, 'col': col.round(), 'dist': (row - 0).abs()},
      {'side': 'bottom', 'row': maxRow - 1, 'col': col.round(), 'dist': (row - (maxRow - 1)).abs()},
      {'side': 'left', 'row': row.round(), 'col': 0, 'dist': (col - 0).abs()},
      {'side': 'right', 'row': row.round(), 'col': maxCol - 1, 'dist': (col - (maxCol - 1)).abs()},
    ];

    double minDist = double.infinity;
    String? nearestSide;
    int nearestRow = row.round();
    int nearestCol = col.round();

    for (final check in borderChecks) {
      final dist = check['dist'] as double;
      print('Checking ${check['side']}: distance=${dist.toStringAsFixed(2)}');
      if (dist < minDist) {
        minDist = dist;
        nearestSide = check['side'] as String;
        nearestRow = check['row'] as int;
        nearestCol = check['col'] as int;
      }
    }

    print('Nearest side: $nearestSide, distance: ${minDist.toStringAsFixed(2)}, snap radius: $_snapRadius');
    if (minDist > _snapRadius) {
      print('FAILED: Distance $minDist exceeds snap radius $_snapRadius');
      return null;
    }

    print('SUCCESS: Found border side $nearestSide at ($nearestCol, $nearestRow)');
    return {
      'side': nearestSide,
      'row': nearestRow,
      'col': nearestCol,
      'dist': minDist,
    };
  }

  /// Validates if boundary placement is possible for the given side and grid dimensions
  static bool canPlaceBoundary(String side, int maxRow, int maxCol, [String? boundaryType]) {
    // Use the actual boundary size from config, or fallback to _span
    int span = _span;
    if (boundaryType != null) {
      final config = BoundaryRegistry.getConfig(boundaryType);
      span = config?.length.round() ?? _span;
    }
    
    if ((side == 'top' || side == 'bottom') && maxCol < span) return false;
    if ((side == 'left' || side == 'right') && maxRow < span) return false;
    return true;
  }

  /// Calculates the starting position for a boundary segment
  static Map<String, int> calculateBoundaryStart(
    String side, 
    double cellRow, 
    double cellCol, 
    int maxRow, 
    int maxCol,
    [String? boundaryType]
  ) {
    int startRow = cellRow.round();
    int startCol = cellCol.round();
    
    // Use the actual boundary size from config, or fallback to _span
    int span = _span;
    if (boundaryType != null) {
      final config = BoundaryRegistry.getConfig(boundaryType);
      span = config?.length.round() ?? _span;
    }

    switch (side) {
      case 'top':
        if (startCol + span > maxCol) startCol = maxCol - span;
        break;
      case 'bottom':
        if (startCol + span > maxCol) startCol = maxCol - span;
        break;
      case 'left':
        if (startRow + span > maxRow) startRow = maxRow - span;
        break;
      case 'right':
        if (startRow + span > maxRow) startRow = maxRow - span;
        break;
    }

    return {'row': startRow, 'col': startCol};
  }

  /// Checks if a position is on the outer edge of the grid
  static bool isOuterEdge(String side, double cellRow, double cellCol, int maxRow, int maxCol) {
    switch (side) {
      case 'top':
        return cellRow <= 0.5;
      case 'bottom':
        return cellRow >= maxRow - 0.5;
      case 'left':
        return cellCol <= 0.5;
      case 'right':
        return cellCol >= maxCol - 0.5;
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
    
    // Use the actual boundary size from config, or fallback to _span
    final config = BoundaryRegistry.getConfig(type);
    final int span = config?.length.round() ?? _span;
    
    for (int i = 0; i < span; i++) {
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

  /// Creates a GridBoundary segment for the given parameters
  static List<GridBoundary> createGridBoundarySegment(
    String type, 
    String side, 
    int startRow, 
    int startCol,
    IconData icon
  ) {
    List<GridBoundary> segment = [];
    
    // Use the actual boundary size from config, or fallback to _span
    final config = BoundaryRegistry.getConfig(type);
    final int span = config?.length.round() ?? _span;
    
    for (int i = 0; i < span; i++) {
      switch (side) {
        case 'top':
        case 'bottom':
          segment.add(GridBoundary(
            type: type, 
            row: startRow, 
            col: startCol + i, 
            side: side,
            icon: icon,
          ));
          break;
        case 'left':
        case 'right':
          segment.add(GridBoundary(
            type: type, 
            row: startRow + i, 
            col: startCol, 
            side: side,
            icon: icon,
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

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) return null;

    final startPos = calculateBoundaryStart(side, nearestRow.toDouble(), nearestCol.toDouble(), maxRow, maxCol, type);
    final segment = createBoundarySegment(type, side, startPos['row']!, startPos['col']!);

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    
    return BoundaryPlacementResult(
      segment: segment,
      shouldRemove: allExist,
    );
  }

  /// Handles boundary placement from drag and drop with GridBoundary objects
  static GridBoundaryPlacementResult? handleGridBoundaryDrop(
    String type,
    double col,
    double row,
    int maxRow,
    int maxCol,
    List<GridBoundary> existingBoundaries,
    IconData icon
  ) {
    print('=== ATTEMPTING BOUNDARY DROP PLACEMENT ===');
    print('Drop at col=$col, row=$row, type=$type');
    print('TEST PRINT - DROP METHOD CALLED');
    
    // Snap to nearest grid cell for placement
    final int snappedCol = col.round();
    final int snappedRow = row.round();
    print('Snapped to col=$snappedCol, row=$snappedRow');
    
    final borderInfo = findNearestBorderSide(snappedCol.toDouble(), snappedRow.toDouble(), maxRow, maxCol);
    if (borderInfo == null) {
      print('FAILED: No border side found for position ($snappedCol, $snappedRow)');
      return null;
    }

    final side = borderInfo['side'] as String;
    final nearestRow = borderInfo['row'] as int;
    final nearestCol = borderInfo['col'] as int;
    print('Found border side: $side at position ($nearestCol, $nearestRow)');

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      print('FAILED: Cannot place boundary on side $side');
      return null;
    }
    print('Can place boundary: true');

    final startPos = calculateBoundaryStart(side, nearestRow.toDouble(), nearestCol.toDouble(), maxRow, maxCol, type);
    print('Start position: row=${startPos['row']}, col=${startPos['col']}');
    
    final segment = createGridBoundarySegment(type, side, startPos['row']!, startPos['col']!, icon);
    print('Created segment with ${segment.length} boundaries');

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    print('All boundaries exist: $allExist');
    
    print('SUCCESS: Boundary drop placement completed');
    return GridBoundaryPlacementResult(
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
    print('=== ATTEMPTING BOUNDARY PLACEMENT ===');
    print('Click at col=$col, row=$row, type=$type');
    print('TEST PRINT - METHOD CALLED');
    
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Find nearest edge - use same logic as preview
    String? side;
    if (dx < dy && dx < (1 - dx) && dx < (1 - dy)) {
      side = 'left';
    } else if ((1 - dx) < dy && (1 - dx) < dx && (1 - dx) < (1 - dy)) {
      side = 'right';
    } else if (dy < (1 - dy)) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    if (side == null) {
      print('FAILED: No side detected');
      return null;
    }
    print('Side detected: $side');

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      print('FAILED: Cannot place boundary');
      return null;
    }
    print('Can place boundary: true');

    if (!isOuterEdge(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol)) {
      print('FAILED: Not on outer edge');
      return null;
    }
    print('Is outer edge: true');

    final startPos = calculateBoundaryStart(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol, type);
    final segment = createBoundarySegment(type, side, startPos['row']!, startPos['col']!);

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    
    print('SUCCESS: Boundary placement completed');
    return BoundaryPlacementResult(
      segment: segment,
      shouldRemove: allExist,
    );
  }

  /// Handles boundary placement from click with GridBoundary objects
  static GridBoundaryPlacementResult? handleGridBoundaryClick(
    String type,
    double col,
    double row,
    int maxRow,
    int maxCol,
    List<GridBoundary> existingBoundaries,
    IconData icon
  ) {
    print('=== ATTEMPTING GRID BOUNDARY PLACEMENT ===');
    print('Click at col=$col, row=$row, type=$type');
    print('TEST PRINT - GRID METHOD CALLED');
    
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Find nearest edge - use same logic as preview
    String? side;
    if (dx < dy && dx < (1 - dx) && dx < (1 - dy)) {
      side = 'left';
    } else if ((1 - dx) < dy && (1 - dx) < dx && (1 - dx) < (1 - dy)) {
      side = 'right';
    } else if (dy < (1 - dy)) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    if (side == null) {
      print('FAILED: No side detected');
      return null;
    }
    print('Side detected: $side');

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      print('FAILED: Cannot place boundary');
      return null;
    }
    print('Can place boundary: true');

    if (!isOuterEdge(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol)) {
      print('FAILED: Not on outer edge');
      return null;
    }
    print('Is outer edge: true');

    final startPos = calculateBoundaryStart(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol, type);
    final segment = createGridBoundarySegment(type, side, startPos['row']!, startPos['col']!, icon);

    final allExist = segment.every((b) => existingBoundaries.contains(b));
    
    // Print boundary placement info
    if (segment.isNotEmpty) {
      final config = BoundaryRegistry.getConfig(type);
      final span = config?.length.round() ?? 12;
      print('Boundary placed: type=$type, side=$side, startCol=${startPos['col']}, startRow=${startPos['row']}, span=$span cells, size=${span} inches');
    }
    
    print('SUCCESS: Grid boundary placement completed');
    return GridBoundaryPlacementResult(
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
    double cellInchSize,
    String boundaryType
  ) {
    // Get boundary configuration first
    final config = BoundaryRegistry.getConfig(boundaryType);
    if (config == null) return null;
    
    // For preview, be more permissive with edge detection
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Find nearest edge - be more permissive for preview
    String? side;
    if (dx < dy && dx < (1 - dx) && dx < (1 - dy)) {
      side = 'left';
    } else if ((1 - dx) < dy && (1 - dx) < dx && (1 - dx) < (1 - dy)) {
      side = 'right';
    } else if (dy < (1 - dy)) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    // Calculate start position (simplified)
    int startCol = cellCol;
    int startRow = cellRow;
    
    // Adjust if boundary would go outside grid
    final int span = config.length.round();
    if (side == 'top' || side == 'bottom') {
      if (startCol + span > maxCol) startCol = maxCol - span;
      if (startCol < 0) startCol = 0;
    } else {
      if (startRow + span > maxRow) startRow = maxRow - span;
      if (startRow < 0) startRow = 0;
    }
    
    // Calculate pixel coordinates directly
    double x, y, x2, y2;
    switch (side) {
      case 'top':
        x = startCol * cellInchSize;
        y = 0;
        x2 = (startCol + span) * cellInchSize;
        y2 = config.thickness * cellInchSize;
        break;
      case 'bottom':
        x = startCol * cellInchSize;
        y = (maxRow - 1) * cellInchSize;
        x2 = (startCol + span) * cellInchSize;
        y2 = y + (config.thickness * cellInchSize);
        break;
      case 'left':
        x = 0;
        y = startRow * cellInchSize;
        x2 = config.thickness * cellInchSize;
        y2 = (startRow + span) * cellInchSize;
        break;
      case 'right':
        x = (maxCol - 1) * cellInchSize;
        y = startRow * cellInchSize;
        x2 = x + (config.thickness * cellInchSize);
        y2 = (startRow + span) * cellInchSize;
        break;
      default:
        return null;
    }

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

/// Result of GridBoundary placement operation
class GridBoundaryPlacementResult {
  final List<GridBoundary> segment;
  final bool shouldRemove;

  const GridBoundaryPlacementResult({
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