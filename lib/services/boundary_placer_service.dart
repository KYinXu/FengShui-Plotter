import 'package:flutter/material.dart';
import '../models/grid_model.dart';

class BoundaryPlacerService {
  static const int _span = 12; // 12 grid spaces (1 foot)
  static const double _snapRadius = 5.0; // More generous snap radius (5 grid cells)
  static const double _edgeThreshold = 0.3; // More generous edge threshold for click placement
  static const int _gridCellSize = 12; // 12 inches per grid cell

  /// Checks if a type is a boundary type
  static bool isBoundaryType(String type) {
    return type == 'door' || type == 'window';
  }

  /// Converts inches to grid cells (1 grid cell = 1 inch)
  static int inchesToGridCells(double inches) {
    return inches.round();
  }

  /// Converts BoundaryElement to GridBoundary
  static GridBoundary boundaryElementToGridBoundary(BoundaryElement element, IconData icon) {
    return GridBoundary(
      type: element.type,
      row: element.row,
      col: element.col,
      side: element.side,
      icon: icon,
      span: element.span,
    );
  }

  /// Converts GridBoundary to BoundaryElement
  static BoundaryElement gridBoundaryToBoundaryElement(GridBoundary boundary) {
    return BoundaryElement(
      type: boundary.type,
      row: boundary.row,
      col: boundary.col,
      side: boundary.side,
      span: boundary.span,
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
      if (dist < minDist) {
        minDist = dist;
        nearestSide = check['side'] as String;
        nearestRow = check['row'] as int;
        nearestCol = check['col'] as int;
      }
    }

    if (minDist > _snapRadius) {
      return null;
    }

    return {
      'side': nearestSide,
      'row': nearestRow,
      'col': nearestCol,
      'dist': minDist,
    };
  }

  /// Validates if boundary placement is possible for the given side and grid dimensions
  static bool canPlaceBoundary(String side, int maxRow, int maxCol, [String? boundaryType]) {
    // Use the actual boundary size from config, converting inches to grid cells
    int span = _span;
    if (boundaryType != null) {
      final config = BoundaryRegistry.getConfig(boundaryType);
      if (config != null) {
        span = inchesToGridCells(config.length);
      }
    }
    
    if ((side == 'top' || side == 'bottom') && maxCol < span) return false;
    if ((side == 'left' || side == 'right') && maxRow < span) return false;
    return true;
  }

  /// Checks if a boundary would overlap with existing objects
  static bool wouldOverlapWithObjects(
    String side,
    int startRow,
    int startCol,
    String boundaryType,
    List<GridObject> existingObjects
  ) {
    final config = BoundaryRegistry.getConfig(boundaryType);
    final int span = config != null ? inchesToGridCells(config.length) : _span;
    
    // Check each cell that the boundary would occupy across its entire span
    for (int i = 0; i < span; i++) {
      int checkRow, checkCol;
      
      switch (side) {
        case 'top':
        case 'bottom':
          checkRow = side == 'top' ? 0 : startRow;
          checkCol = startCol + i;
          break;
        case 'left':
        case 'right':
          checkRow = startRow + i;
          checkCol = side == 'left' ? 0 : startCol;
          break;
        default:
          return false;
      }
      
      // Check if any object occupies this cell
      for (final obj in existingObjects) {
        if (obj.row == checkRow && obj.col == checkCol) {
          return true; // Overlap detected
        }
      }
    }
    
    return false; // No overlap
  }

  /// Checks if a boundary would overlap with existing boundaries
  static bool wouldOverlapWithBoundaries(
    String side,
    int startRow,
    int startCol,
    String boundaryType,
    List<GridBoundary> existingBoundaries
  ) {
    final config = BoundaryRegistry.getConfig(boundaryType);
    final int span = config != null ? inchesToGridCells(config.length) : _span;
    
    // Check each cell that the boundary would occupy across its entire span
    for (int i = 0; i < span; i++) {
      int checkRow, checkCol;
      
      switch (side) {
        case 'top':
        case 'bottom':
          checkRow = side == 'top' ? 0 : startRow;
          checkCol = startCol + i;
          break;
        case 'left':
        case 'right':
          checkRow = startRow + i;
          checkCol = side == 'left' ? 0 : startCol;
          break;
        default:
          return false;
      }
      
      // Check if any boundary occupies this cell
      for (final boundary in existingBoundaries) {
        // Check if the boundary spans this cell
        bool boundaryOccupiesCell = false;
        
        for (int j = 0; j < boundary.span; j++) {
          int boundaryRow, boundaryCol;
          
          switch (boundary.side) {
            case 'top':
            case 'bottom':
              boundaryRow = boundary.side == 'top' ? 0 : boundary.row;
              boundaryCol = boundary.col + j;
              break;
            case 'left':
            case 'right':
              boundaryRow = boundary.row + j;
              boundaryCol = boundary.side == 'left' ? 0 : boundary.col;
              break;
            default:
              continue;
          }
          
          if (boundaryRow == checkRow && boundaryCol == checkCol) {
            boundaryOccupiesCell = true;
            break;
          }
        }
        
        if (boundaryOccupiesCell) {
          return true; // Overlap detected
        }
      }
    }
    
    return false; // No overlap
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

  /// Adjusts the starting position to ensure the boundary fits within the grid
  static Map<String, int> adjustBoundaryPosition(
    String side,
    double cellRow,
    double cellCol,
    int maxRow,
    int maxCol,
    String? boundaryType
  ) {
    int startRow = cellRow.round();
    int startCol = cellCol.round();
    
    // Use the actual boundary size from config, converting inches to grid cells
    int span = _span;
    if (boundaryType != null) {
      final config = BoundaryRegistry.getConfig(boundaryType);
      if (config != null) {
        span = inchesToGridCells(config.length);
      }
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
        return cellRow <= 1.0; // More permissive - within 1 cell of top
      case 'bottom':
        return cellRow >= maxRow - 1.0; // More permissive - within 1 cell of bottom
      case 'left':
        return cellCol <= 1.0; // More permissive - within 1 cell of left
      case 'right':
        return cellCol >= maxCol - 1.0; // More permissive - within 1 cell of right
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
    
    // Use the actual boundary size from config, converting inches to grid cells
    final config = BoundaryRegistry.getConfig(type);
    final int span = config != null ? inchesToGridCells(config.length) : _span;
    
    // Create a single boundary element that represents the entire span
    // For top/bottom boundaries, use the starting column
    // For left/right boundaries, use the starting row
    switch (side) {
      case 'top':
      case 'bottom':
        segment.add(BoundaryElement(
          type: type, 
          row: startRow, 
          col: startCol, // Use starting column for the entire span
          side: side,
          span: span
        ));
        break;
      case 'left':
      case 'right':
        segment.add(BoundaryElement(
          type: type, 
          row: startRow, // Use starting row for the entire span
          col: startCol, 
          side: side,
          span: span
        ));
        break;
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
    
    // Use the actual boundary size from config, converting inches to grid cells
    final config = BoundaryRegistry.getConfig(type);
    final int span = config != null ? inchesToGridCells(config.length) : _span;
    
    // Create a single boundary that represents the entire span
    // For top/bottom boundaries, use the starting column
    // For left/right boundaries, use the starting row
    switch (side) {
      case 'top':
      case 'bottom':
        segment.add(GridBoundary(
          type: type, 
          row: startRow, 
          col: startCol, // Use starting column for the entire span
          side: side,
          icon: icon,
          span: span, // Include the span information
        ));
        break;
      case 'left':
      case 'right':
        segment.add(GridBoundary(
          type: type, 
          row: startRow, // Use starting row for the entire span
          col: startCol, 
          side: side,
          icon: icon,
          span: span, // Include the span information
        ));
        break;
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
    IconData icon,
    [List<GridObject>? existingObjects]
  ) {
    // Snap to nearest grid cell for placement
    final int snappedCol = col.round();
    final int snappedRow = row.round();
    
    // Use the same edge detection logic as preview
    final gridCol = snappedCol;
    final gridRow = snappedRow;
    
    // Calculate distances to each edge (same logic as preview)
    final leftDist = gridCol;
    final rightDist = maxCol - 1 - gridCol;
    final topDist = gridRow;
    final bottomDist = maxRow - 1 - gridRow;
    
    // Find the minimum distance
    final minDist = [leftDist, rightDist, topDist, bottomDist].reduce((a, b) => a < b ? a : b);
    
    String side;
    int nearestRow;
    int nearestCol;
    
    if (minDist == leftDist) {
      side = 'left';
      nearestRow = gridRow;
      nearestCol = 0;
    } else if (minDist == rightDist) {
      side = 'right';
      nearestRow = gridRow;
      nearestCol = maxCol - 1;
    } else if (minDist == topDist) {
      side = 'top';
      nearestRow = 0;
      nearestCol = gridCol;
    } else {
      side = 'bottom';
      nearestRow = maxRow - 1;
      nearestCol = gridCol;
    }

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      return null;
    }

    final startPos = calculateBoundaryStart(side, nearestRow.toDouble(), nearestCol.toDouble(), maxRow, maxCol, type);
    
    // Check for object collisions if objects are provided
    if (existingObjects != null && existingObjects.isNotEmpty) {
      if (wouldOverlapWithObjects(side, startPos['row']!, startPos['col']!, type, existingObjects)) {
        return null;
      }
    }
    
    // Check for boundary collisions
    if (existingBoundaries.isNotEmpty) {
      if (wouldOverlapWithBoundaries(side, startPos['row']!, startPos['col']!, type, existingBoundaries)) {
        return null;
      }
    }
    
    final segment = createGridBoundarySegment(type, side, startPos['row']!, startPos['col']!, icon);

    // Check if this exact boundary already exists (same type, side, position, and span)
    final config = BoundaryRegistry.getConfig(type);
    final int span = config != null ? inchesToGridCells(config.length) : _span;
    final exactMatch = existingBoundaries.any((existing) => 
      existing.type == type && 
      existing.side == side && 
      existing.row == startPos['row'] && 
      existing.col == startPos['col'] &&
      existing.span == span
    );
    
    return GridBoundaryPlacementResult(
      segment: segment,
      shouldRemove: exactMatch, // Only remove if exact same boundary exists
    );
  }

  /// Handles boundary placement from click
  static BoundaryPlacementResult? handleBoundaryClick(
    String type,
    double col,
    double row,
    int maxRow,
    int maxCol,
    List<BoundaryElement> existingBoundaries,
    [List<GridObject>? existingObjects]
  ) {
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Use the same edge detection logic as preview
    final gridCol = cellCol;
    final gridRow = cellRow;
    
    // Calculate distances to each edge (same logic as preview)
    final leftDist = gridCol;
    final rightDist = maxCol - 1 - gridCol;
    final topDist = gridRow;
    final bottomDist = maxRow - 1 - gridRow;
    
    // Find the minimum distance
    final minDist = [leftDist, rightDist, topDist, bottomDist].reduce((a, b) => a < b ? a : b);
    
    String side;
    if (minDist == leftDist) {
      side = 'left';
    } else if (minDist == rightDist) {
      side = 'right';
    } else if (minDist == topDist) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      return null;
    }

    if (!isOuterEdge(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol)) {
      return null;
    }

    final startPos = calculateBoundaryStart(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol, type);
    
    // Check for object collisions if objects are provided
    if (existingObjects != null && existingObjects.isNotEmpty) {
      if (wouldOverlapWithObjects(side, startPos['row']!, startPos['col']!, type, existingObjects)) {
        return null;
      }
    }
    
    // Check for boundary collisions (convert BoundaryElements to GridBoundaries for checking)
    if (existingBoundaries.isNotEmpty) {
      final gridBoundaries = existingBoundaries.map((e) => GridBoundary(
        type: e.type,
        row: e.row,
        col: e.col,
        side: e.side,
        icon: Icons.door_front_door, // Default icon
        span: e.span,
      )).toList();
      
      if (wouldOverlapWithBoundaries(side, startPos['row']!, startPos['col']!, type, gridBoundaries)) {
        return null;
      }
    }
    
    final segment = createBoundarySegment(type, side, startPos['row']!, startPos['col']!);

    // Check if this exact boundary already exists (same type, side, and position)
    final exactMatch = existingBoundaries.any((existing) => 
      existing.type == type && 
      existing.side == side && 
      existing.row == startPos['row'] && 
      existing.col == startPos['col']
    );
    
    return BoundaryPlacementResult(
      segment: segment,
      shouldRemove: exactMatch, // Only remove if exact same boundary exists
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
    IconData icon,
    [List<GridObject>? existingObjects]
  ) {
    final cellCol = col.floor();
    final cellRow = row.floor();
    final dx = col - cellCol;
    final dy = row - cellRow;

    // Use the same edge detection logic as preview
    final gridCol = cellCol;
    final gridRow = cellRow;
    
    // Calculate distances to each edge (same logic as preview)
    final leftDist = gridCol;
    final rightDist = maxCol - 1 - gridCol;
    final topDist = gridRow;
    final bottomDist = maxRow - 1 - gridRow;
    
    // Find the minimum distance
    final minDist = [leftDist, rightDist, topDist, bottomDist].reduce((a, b) => a < b ? a : b);
    
    String side;
    if (minDist == leftDist) {
      side = 'left';
    } else if (minDist == rightDist) {
      side = 'right';
    } else if (minDist == topDist) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    if (!canPlaceBoundary(side, maxRow, maxCol, type)) {
      return null;
    }

    if (!isOuterEdge(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol)) {
      return null;
    }

    final startPos = calculateBoundaryStart(side, cellRow.toDouble(), cellCol.toDouble(), maxRow, maxCol, type);
    
    // Check for object collisions if objects are provided
    if (existingObjects != null && existingObjects.isNotEmpty) {
      if (wouldOverlapWithObjects(side, startPos['row']!, startPos['col']!, type, existingObjects)) {
        return null;
      }
    }
    
    // Check for boundary collisions
    if (existingBoundaries.isNotEmpty) {
      if (wouldOverlapWithBoundaries(side, startPos['row']!, startPos['col']!, type, existingBoundaries)) {
        return null;
      }
    }
    
    final segment = createGridBoundarySegment(type, side, startPos['row']!, startPos['col']!, icon);

    // Check if this exact boundary already exists (same type, side, and position)
    final exactMatch = existingBoundaries.any((existing) => 
      existing.type == type && 
      existing.side == side && 
      existing.row == startPos['row'] && 
      existing.col == startPos['col']
    );
    
    return GridBoundaryPlacementResult(
      segment: segment,
      shouldRemove: exactMatch, // Only remove if exact same boundary exists
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

    // Find nearest edge - simplified for snapped coordinates
    String? side;
    
    // Since we're using snapped coordinates, determine side based on grid position
    final gridCol = col.round();
    final gridRow = row.round();
    
    // Determine which edge is closest based on grid position
    // Check all edges and pick the closest one
    final leftDist = gridCol;
    final rightDist = maxCol - 1 - gridCol;
    final topDist = gridRow;
    final bottomDist = maxRow - 1 - gridRow;
    
    // Find the minimum distance
    final minDist = [leftDist, rightDist, topDist, bottomDist].reduce((a, b) => a < b ? a : b);
    
    if (minDist == leftDist) {
      side = 'left';
    } else if (minDist == rightDist) {
      side = 'right';
    } else if (minDist == topDist) {
      side = 'top';
    } else {
      side = 'bottom';
    }

    // Calculate start position (simplified)
    int startCol = cellCol;
    int startRow = cellRow;
    
    // Adjust if boundary would go outside grid
    final int span = inchesToGridCells(config.length);
    if (side == 'top' || side == 'bottom') {
      if (startCol + span > maxCol) startCol = maxCol - span;
      if (startCol < 0) startCol = 0;
    } else {
      if (startRow + span > maxRow) startRow = maxRow - span;
      if (startRow < 0) startRow = 0;
    }
    
    // Use fixed pixel thickness to match placement
    final fixedThickness = 8.0;
    
    // Calculate pixel coordinates directly
    double x, y, x2, y2;
    switch (side) {
      case 'top':
        x = startCol * cellInchSize;
        y = 0;
        x2 = (startCol + span) * cellInchSize;
        y2 = fixedThickness;
        break;
      case 'bottom':
        x = startCol * cellInchSize;
        y = (maxRow - 1) * cellInchSize - (fixedThickness / 2); // Center on the edge
        x2 = (startCol + span) * cellInchSize;
        y2 = y + fixedThickness;
        break;
      case 'left':
        x = 0;
        y = startRow * cellInchSize;
        x2 = fixedThickness;
        y2 = (startRow + span) * cellInchSize;
        break;
      case 'right':
        x = (maxCol - 1) * cellInchSize - (fixedThickness / 2); // Center on the edge
        y = startRow * cellInchSize;
        x2 = x + fixedThickness;
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