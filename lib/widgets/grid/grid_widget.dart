import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/grid_model.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math';
import '../objects/object_item.dart';
import 'grid_object.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'grid_helpers.dart';

class GridWidget extends StatefulWidget {
  final Grid grid;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final List<GridObject> objects;
  final void Function(int row, int col, String type, IconData icon, [int rotation])? onObjectDropped;
  final String boundaryMode; // 'none', 'door', 'window'
  final void Function(BoundaryElement boundary)? onAddBoundary;
  final void Function(BoundaryElement boundary)? onRemoveBoundary;

  const GridWidget({
    super.key,
    required this.grid,
    this.rotationX = 0.3,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
    this.objects = const [],
    this.onObjectDropped,
    this.boundaryMode = 'none',
    this.onAddBoundary,
    this.onRemoveBoundary,
  });

  @override
  State<GridWidget> createState() => GridWidgetState();
}

class GridWidgetState extends State<GridWidget> {
  final snappingRadius = 20;
  Offset? _previewCell;
  String? _previewType;
  IconData? _previewIcon;
  final FocusNode _focusNode = FocusNode();

  // Constants for 3D transformation
  //static const double _additionalRotationX = 0.3;
  static const double _scale = 0.7;

  int _dragRotation = 0; // Only for the current preview/drag
  int _searchToken = 0;

  // Add fields to store last preview drag data and pointer offset
  Map<String, dynamic>? _lastPreviewData;
  Offset? _lastPreviewPointerOffset;
  double? _lastPreviewOffsetX;
  double? _lastPreviewOffsetY;
  double? _lastPreviewGridWidth;
  double? _lastPreviewGridHeightPx;
  double? _lastPreviewCellInchSize;


// Sets the state of the preview according to any new updates
  void _updatePreview(Offset? cell, String? type, IconData? icon, [int? rotation]) {
    if (_previewCell == cell && _previewType == type && _previewIcon == icon && (rotation == null || _dragRotation == rotation)) {
      return;
    }
    setState(() {
      _previewCell = cell;
      _previewType = type;
      _previewIcon = icon;
      if (rotation != null) _dragRotation = rotation;
    });
  }



  // Polygon-based area occupied check
  // O(n) for number of objects
  bool isAreaOccupied(int row, int col, String type, int rotation) {
    final poly = getTransformedPolygon(type, row, col, rotation);
    final gridW = widget.grid.widthInches.floor();
    final gridH = widget.grid.lengthInches.floor();
    if (!polygonInBounds(poly, gridW, gridH)) return true;
    for (final obj in widget.objects) {
      final objPoly = obj.getTransformedPolygon();
      if (polygonsIntersect(poly, objPoly)) return true;
    }
    return false;
  }

  // Find nearest open cell
  Offset? findNearestOpenCell(int startRow, int startCol, String type, int rotation, int radius) {
    final gridW = widget.grid.widthInches.floor();
    final gridH = widget.grid.lengthInches.floor();
    // Try the initial position first
    final poly = getTransformedPolygon(type, startRow, startCol, rotation);
      bool collision = false;
      for (final obj in widget.objects) {
        if (polygonsIntersect(poly, obj.getTransformedPolygon())) {
          collision = true;
          break;
        }
      }
      if (!collision) return Offset(startCol.toDouble(), startRow.toDouble());

    // Spiral search for nearest open cell
    for (int dist = 1; dist <= radius; dist++) {
      for (int dRow = -dist; dRow <= dist; dRow++) {
        int dCol = dist - dRow.abs();
        for (int sign = -1; sign <= 1; sign += 2) {
          int row = startRow + dRow;
          int col = startCol + sign * dCol;
          final candidatePoly = getTransformedPolygon(type, row, col, rotation);
          if (polygonInBounds(candidatePoly, gridW, gridH)) {
            bool collision = false;
            for (final obj in widget.objects) {
              if (polygonsIntersect(candidatePoly, obj.getTransformedPolygon())) {
                collision = true;
                break;
              }
            }
            if (!collision) {
              return Offset(col.toDouble(), row.toDouble());
            }
          }
        }
      }
    }
    return null;
  }

  // Add a helper function to check if any part of the polygon is in bounds
  bool polygonIntersectsGrid(List<Offset> poly, int gridW, int gridH) {
    for (final p in poly) {
      if (p.dx >= 0 && p.dy >= 0 && p.dx <= gridW && p.dy <= gridH) return true;
    }
    return false;
  }

  // Helper to check if a type is a boundary
  bool isBoundaryType(String type) {
    // You can expand this list if you add more boundary types
    return type == 'door' || type == 'window';
  }

  // Update preview/placement logic to use polygon system
  // TODO: 180 degree rotations x < 0 and 270 degree rotations x < 0 y < 0 are bugged here, all others work and placements work
  void _handlePreviewMove(Map<String, dynamic> data, Offset pointerOffset, double offsetX, double offsetY, double gridWidth, double gridHeightPx, double cellInchSize) {
    // Store last preview drag data and pointer offset for rotation snapping
    _lastPreviewData = data;
    _lastPreviewPointerOffset = pointerOffset;
    _lastPreviewOffsetX = offsetX;
    _lastPreviewOffsetY = offsetY;
    _lastPreviewGridWidth = gridWidth;
    _lastPreviewGridHeightPx = gridHeightPx;
    _lastPreviewCellInchSize = cellInchSize;
    final int myToken = ++_searchToken;
    Future(() {
      if (data['type'] is! String || data['icon'] is! IconData) return;
      final String type = data['type'];
      // Special case for boundary types: always show preview at pointer
      if (isBoundaryType(type)) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final Offset local = box.globalToLocal(pointerOffset);
        final Offset gridLocalPointer = local - Offset(offsetX, offsetY);
        final Offset? gridLocal = _pickGridCell3D(
          pointer: gridLocalPointer,
          gridWidth: gridWidth,
          gridHeight: gridHeightPx,
          cellInchSize: cellInchSize,
          rotationZ: widget.rotationZ,
          scale: _scale,
          rotateX: widget.rotationX,
          rotateY: widget.rotationY,
        );
        if (gridLocal != null) {
          double col = gridLocal.dx / cellInchSize;
          double row = gridLocal.dy / cellInchSize;
          final gridW = widget.grid.widthInches.floor();
          final gridH = widget.grid.lengthInches.floor();
          // Snap to nearest edge
          double minDist = double.infinity;
          String? nearestSide;
          double snappedCol = col;
          double snappedRow = row;
          final edgeChecks = [
            {'side': 'top', 'dist': (row - 0).abs(), 'col': col, 'row': 0.0},
            {'side': 'bottom', 'dist': (row - (gridH)).abs(), 'col': col, 'row': gridH.toDouble()},
            {'side': 'left', 'dist': (col - 0).abs(), 'col': 0.0, 'row': row},
            {'side': 'right', 'dist': (col - (gridW)).abs(), 'col': gridW.toDouble(), 'row': row},
          ];
          for (final check in edgeChecks) {
            final dist = check['dist'] as double;
            if (dist < minDist) {
              minDist = dist;
              nearestSide = check['side'] as String;
              snappedCol = check['col'] as double;
              snappedRow = check['row'] as double;
            }
          }
          // Only show preview if close enough to an edge (within 30 cells)
          if (minDist > 30.0) {
            _updatePreview(null, null, null);
            return;
          }
          _updatePreview(Offset(snappedCol, snappedRow), type, data['icon']);
          // Diagnostic print for boundaries during drag
          print('Boundaries during drag:');
          for (final b in widget.grid.boundaries) {
            print(b);
          }
        } else {
          _updatePreview(null, null, null);
        }
        return;
      }
      // Prevent preview if object is larger than grid
      final gridW = widget.grid.widthInches.floor();
      final gridH = widget.grid.lengthInches.floor();
      final dims = ObjectItem.getObjectDimensions(type);
      final objW = dims['width'] ?? 1;
      final objH = dims['height'] ?? 1;
      if (objW > gridW || objH > gridH) {
        _updatePreview(null, null, null);
        return;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final Offset local = box.globalToLocal(pointerOffset);
      final Offset gridLocalPointer = local - Offset(offsetX, offsetY);
      final Offset? gridLocal = _pickGridCell3D(
        pointer: gridLocalPointer,
        gridWidth: gridWidth,
        gridHeight: gridHeightPx,
        cellInchSize: cellInchSize,
        rotationZ: widget.rotationZ,
        scale: _scale,
        rotateX: widget.rotationX,
        rotateY: widget.rotationY,
      );
      if (gridLocal != null) {
        double col = gridLocal.dx / cellInchSize;
        double row = gridLocal.dy / cellInchSize;
        final rotatedPoly = getTransformedPolygon(type, 0, 0, _dragRotation);
        Offset centerOffset = getCenteringOffset(rotatedPoly);
        double unclampedCol = col - centerOffset.dx;
        double unclampedRow = row - centerOffset.dy;
        final gridW = widget.grid.widthInches.floor();
        final gridH = widget.grid.lengthInches.floor();
        Offset clamped = clampPolygonToGrid(type, unclampedRow.floor(), unclampedCol.floor(), _dragRotation, gridW, gridH);
        final previewPoly = getTransformedPolygon(type, clamped.dy.toInt(), clamped.dx.toInt(), _dragRotation);
        if (!polygonIntersectsGrid(previewPoly, gridW, gridH)) {
          _updatePreview(null, null, null);
          return;
        }
        int snapCol = clamped.dx.toInt();
        int snapRow = clamped.dy.toInt();
        bool valid = !isAreaOccupied(snapRow, snapCol, type, _dragRotation);
        Offset? snapped = valid
          ? Offset(snapCol.toDouble(), snapRow.toDouble())
          : findNearestOpenCell(snapRow, snapCol, type, _dragRotation, snappingRadius);
        if (myToken != _searchToken) return;
        if (snapped == null) {
          _updatePreview(null, null, null);
        } else {
          // Pass the center position for the preview
          final center = Offset(snapped.dx + centerOffset.dx, snapped.dy + centerOffset.dy);
          _updatePreview(center, type, data['icon']);
        }
      } else {
        if (myToken != _searchToken) return;
        _updatePreview(null, null, null);
      }
    });
  }

  void resetPreviewRotation() {
    setState(() {
      _dragRotation = 0;
      _updatePreview(null, null, null);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const gridCellColor = Colors.transparent;
    final gridBorderColor = colorScheme.outline;
    final majorGridBorderColor = colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the grid's width and length in inches directly
        final double totalColsInches = widget.grid.widthInches;
        final double totalRowsInches = widget.grid.lengthInches;
        final double cellInchSizeW = constraints.maxWidth / totalColsInches;
        final double cellInchSizeH = constraints.maxHeight / totalRowsInches;
        final double cellInchSize = cellInchSizeW < cellInchSizeH ? cellInchSizeW : cellInchSizeH;

        final gridWidth = cellInchSize * totalColsInches;
        final gridHeightPx = cellInchSize * totalRowsInches;
        // Calculate centering offset
        final double offsetX = (constraints.maxWidth - gridWidth) / 2;
        final double offsetY = (constraints.maxHeight - gridHeightPx) / 2;

        Widget gridContent = DragTarget<Map<String, dynamic>>(
          onWillAccept: (data) {
            print('onWillAccept called with data:');
            print(data);
            return true;
          },
          onAcceptWithDetails: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset local = box.globalToLocal(details.offset);
            // Adjust for centering offset
            final Offset gridLocalPointer = local - Offset(offsetX, offsetY);
            // Use inverse transform for accurate picking
            final Offset? gridLocal = _pickGridCell3D(
              pointer: gridLocalPointer,
              gridWidth: gridWidth,
              gridHeight: gridHeightPx,
              cellInchSize: cellInchSize,
              rotationZ: widget.rotationZ,
              scale: _scale,
              rotateX: widget.rotationX,
              rotateY: widget.rotationY,
            );
            if (gridLocal == null) {
              return;
            }
            // Border mode: handle door/window drop
            if (isBoundaryType(details.data['type'])) {
              final String type = details.data['type'];
              // Snap to nearest border wall within a radius
              final int maxRow = widget.grid.lengthInches.floor();
              final int maxCol = widget.grid.widthInches.floor();
              final double col = gridLocal.dx / cellInchSize;
              final double row = gridLocal.dy / cellInchSize;
              final int cellCol = col.floor();
              final int cellRow = row.floor();
              final double dx = col - cellCol;
              final double dy = row - cellRow;
              // Find nearest border wall and side
              double minDist = double.infinity;
              String? nearestSide;
              int nearestRow = cellRow;
              int nearestCol = cellCol;
              // Check all four borders
              final borderChecks = [
                {'side': 'top', 'row': 0, 'col': cellCol, 'dist': (row - 0).abs()},
                {'side': 'bottom', 'row': maxRow - 1, 'col': cellCol, 'dist': (row - (maxRow - 1)).abs()},
                {'side': 'left', 'row': cellRow, 'col': 0, 'dist': (col - 0).abs()},
                {'side': 'right', 'row': cellRow, 'col': maxCol - 1, 'dist': (col - (maxCol - 1)).abs()},
              ];
              for (final check in borderChecks) {
                final dist = check['dist'];
                if (dist != null && (dist as double) < minDist) {
                  minDist = dist as double;
                  nearestSide = check['side'] as String;
                  nearestRow = check['row'] as int;
                  nearestCol = check['col'] as int;
                }
              }
              // Only snap if within radius (e.g., 1.0 grid cell)
              if (minDist > 1.0) return;
              // Place the boundary at the nearest border
              // Reuse the 12-segment logic from onTapDown
              int span = 12;
              int startRow = nearestRow;
              int startCol = nearestCol;
              if ((nearestSide == 'top' || nearestSide == 'bottom') && maxCol < span) return;
              if ((nearestSide == 'left' || nearestSide == 'right') && maxRow < span) return;
              switch (nearestSide) {
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
              List<BoundaryElement> segment = [];
              for (int i = 0; i < span; i++) {
                switch (nearestSide) {
                  case 'top':
                  case 'bottom':
                    segment.add(BoundaryElement(type: type, row: startRow, col: startCol + i, side: nearestSide!));
                    break;
                  case 'left':
                  case 'right':
                    segment.add(BoundaryElement(type: type, row: startRow + i, col: startCol, side: nearestSide!));
                    break;
                }
              }
              final allExist = segment.every((b) => widget.grid.boundaries.contains(b));
              if (allExist) {
                if (widget.onRemoveBoundary != null) {
                  for (final b in segment) {
                    widget.onRemoveBoundary!(b);
                    print('Removed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                  }
                }
              } else {
                if (widget.onAddBoundary != null) {
                  for (final b in segment) {
                    print('Checking if boundary exists: $b');
                    print('Current boundaries:');
                    for (final boundary in widget.grid.boundaries) {
                      print(boundary);
                    }
                    if (!widget.grid.boundaries.contains(b)) {
                      widget.onAddBoundary!(b);
                      print('Boundary added: $b');
                    }
                  }
                  print('Boundaries after drop:');
                  for (final boundary in widget.grid.boundaries) {
                    print(boundary);
                  }
                }
              }
              return;
            }
            final String type = details.data['type'];
            // Use rotated polygon for centering offset (fixes placement for rotated objects)
            final rotatedPoly = getTransformedPolygon(type, 0, 0, _dragRotation);
            Offset centerOffset = getCenteringOffset(rotatedPoly);
            double col = gridLocal.dx / cellInchSize;
            double row = gridLocal.dy / cellInchSize;
            double unclampedCol = col - centerOffset.dx;
            double unclampedRow = row - centerOffset.dy;
            final gridW = widget.grid.widthInches.floor();
            final gridH = widget.grid.lengthInches.floor();
            // Clamp placement position to grid
            Offset clamped = clampPolygonToGrid(type, unclampedRow.floor(), unclampedCol.floor(), _dragRotation, gridW, gridH);
            int snapCol = clamped.dx.toInt();
            int snapRow = clamped.dy.toInt();
            // If clamped position is not valid, snap to nearest open cell
            bool valid = !isAreaOccupied(snapRow, snapCol, type, _dragRotation);
            Offset? snapped = valid
              ? Offset(snapCol.toDouble(), snapRow.toDouble())
              : findNearestOpenCell(snapRow, snapCol, type, _dragRotation, snappingRadius);
            if (snapped == null) {
              _updatePreview(null, null, null);
              return;
            }
            snapRow = snapped.dy.toInt();
            snapCol = snapped.dx.toInt();
            if (widget.onObjectDropped != null &&
                details.data['type'] is String &&
                details.data['icon'] is IconData) {
              widget.onObjectDropped!(snapRow, snapCol, details.data['type'], details.data['icon'], _dragRotation);
            }
            _updatePreview(null, null, null);
            _dragRotation = 0;
          },
          onMove: (details) {
            // Use async+token approach for preview update
            _handlePreviewMove(details.data, details.offset, offsetX, offsetY, gridWidth, gridHeightPx, cellInchSize);
          },
          onLeave: (data) {
            _updatePreview(null, null, null);
          },
          builder: (context, candidateData, rejectedData) {
            return Stack(
              children: [
                CustomPaint(
                  painter: GridAreaPainter(
                    grid: widget.grid,
                    cellInchSize: cellInchSize,
                    gridCellColor: gridCellColor,
                    gridBorderColor: gridBorderColor,
                    majorGridBorderColor: majorGridBorderColor,
                    gridWidth: gridWidth,
                    gridHeight: gridHeightPx,
                  ),
                ),
                // Preview overlay
                if (_previewCell != null && _previewType != null && _previewIcon != null)
                  Builder(
                    builder: (context) {
                      // Always show a line preview for door/window types
                      if (_previewType == 'door' || _previewType == 'window') {
                        final gridW = widget.grid.widthInches.floor();
                        final gridH = widget.grid.lengthInches.floor();
                        final double col = _previewCell!.dx;
                        final double row = _previewCell!.dy;
                        final int cellCol = col.floor();
                        final int cellRow = row.floor();
                        final double dx = col - cellCol;
                        final double dy = row - cellRow;
                        double minDist = double.infinity;
                        String? nearestSide;
                        int nearestRow = cellRow;
                        int nearestCol = cellCol;
                        final borderChecks = [
                          {'side': 'top', 'row': 0, 'col': cellCol, 'dist': (row - 0).abs()},
                          {'side': 'bottom', 'row': gridH - 1, 'col': cellCol, 'dist': (row - (gridH - 1)).abs()},
                          {'side': 'left', 'row': cellRow, 'col': 0, 'dist': (col - 0).abs()},
                          {'side': 'right', 'row': cellRow, 'col': gridW - 1, 'dist': (col - (gridW - 1)).abs()},
                        ];
                        for (final check in borderChecks) {
                          final dist = check['dist'];
                          if (dist != null && (dist as double) < minDist) {
                            minDist = dist as double;
                            nearestSide = check['side'] as String;
                            nearestRow = check['row'] as int;
                            nearestCol = check['col'] as int;
                          }
                        }
                        if (minDist > 1.0) return const SizedBox.shrink();
                        int span = 12;
                        int startRow = nearestRow;
                        int startCol = nearestCol;
                        if ((nearestSide == 'top' || nearestSide == 'bottom') && gridW < span) return const SizedBox.shrink();
                        if ((nearestSide == 'left' || nearestSide == 'right') && gridH < span) return const SizedBox.shrink();
                        switch (nearestSide) {
                          case 'top':
                          case 'bottom':
                            if (startCol + span > gridW) startCol = gridW - span;
                            break;
                          case 'left':
                          case 'right':
                            if (startRow + span > gridH) startRow = gridH - span;
                            break;
                        }
                        final double x = startCol * cellInchSize;
                        final double y = startRow * cellInchSize;
                        final double x2 = (nearestSide == 'top' || nearestSide == 'bottom') ? (startCol + span) * cellInchSize : x;
                        final double y2 = (nearestSide == 'left' || nearestSide == 'right') ? (startRow + span) * cellInchSize : y;
                        return Positioned(
                          left: 0,
                          top: 0,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: Size(gridW * cellInchSize, gridH * cellInchSize),
                              painter: _BoundaryPreviewPainter(
                                type: _previewType!,
                                side: nearestSide!,
                                x: x,
                                y: y,
                                x2: x2,
                                y2: y2,
                              ),
                            ),
                          ),
                        );
                      }
                      // Default object preview
                      final width = cellInchSize * (ObjectItem.getObjectDimensions(_previewType!)['width'] ?? 1);
                      final height = cellInchSize * (ObjectItem.getObjectDimensions(_previewType!)['height'] ?? 1);
                      return Positioned(
                        left: _previewCell!.dx * cellInchSize,
                        top: _previewCell!.dy * cellInchSize,
                        child: Opacity(
                          opacity: 0.5,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..translate(-width / 2, -height / 2)
                              ..rotateZ((_dragRotation % 360) * pi / 180.0),
                            child: Container(
                              width: width,
                              height: height,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green, width: 3),
                                shape: BoxShape.rectangle,
                                color: Colors.red.withOpacity(0.2),
                              ),
                              child: Icon(_previewIcon, size: cellInchSize * 8, color: Colors.red),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Placed objects
                ...widget.objects.map((obj) => GridObjectWidget(obj: obj, cellInchSize: cellInchSize)),
              ],
            );
          },
        );

        // Overlay GestureDetector for edge clicks in boundary mode
        if (widget.boundaryMode != 'none') {
          gridContent = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset local = box.globalToLocal(details.globalPosition);
              final Offset gridLocal = local - Offset(offsetX, offsetY);
              // Map to cell and edge
              final double col = gridLocal.dx / cellInchSize;
              final double row = gridLocal.dy / cellInchSize;
              final int cellCol = col.floor();
              final int cellRow = row.floor();
              final double dx = col - cellCol;
              final double dy = row - cellRow;
              // Find nearest edge
              double minDist = 1.0;
              String? side;
              if (dx < 0.2) { minDist = dx; side = 'left'; }
              if (1 - dx < minDist) { minDist = 1 - dx; side = 'right'; }
              if (dy < minDist) { minDist = dy; side = 'top'; }
              if (1 - dy < minDist) { minDist = 1 - dy; side = 'bottom'; }
              // Only allow if close enough to an edge
              if (side != null && minDist < 0.2) {
                final maxRow = widget.grid.lengthInches.floor();
                final maxCol = widget.grid.widthInches.floor();
                int span = 12; // 12 grid spaces (1 foot)
                // Prevent placement if grid is too small
                if ((side == 'top' || side == 'bottom') && maxCol < span) return;
                if ((side == 'left' || side == 'right') && maxRow < span) return;
                bool isOuter = false;
                int startRow = cellRow;
                int startCol = cellCol;
                // Adjust start so the 12-segment fits within the grid
                switch (side) {
                  case 'top':
                    isOuter = cellRow == 0;
                    if (cellCol + span > maxCol) startCol = maxCol - span;
                    break;
                  case 'bottom':
                    isOuter = cellRow == maxRow - 1;
                    if (cellCol + span > maxCol) startCol = maxCol - span;
                    break;
                  case 'left':
                    isOuter = cellCol == 0;
                    if (cellRow + span > maxRow) startRow = maxRow - span;
                    break;
                  case 'right':
                    isOuter = cellCol == maxCol - 1;
                    if (cellRow + span > maxRow) startRow = maxRow - span;
                    break;
                }
                if (!isOuter) return;
                // Use the type from the drag data
                final type = widget.boundaryMode == 'door' ? 'door' : 'window';
                // Build the 12-segment boundary
                List<BoundaryElement> segment = [];
                for (int i = 0; i < span; i++) {
                  switch (side) {
                    case 'top':
                    case 'bottom':
                      segment.add(BoundaryElement(type: type, row: startRow, col: startCol + i, side: side));
                      break;
                    case 'left':
                    case 'right':
                      segment.add(BoundaryElement(type: type, row: startRow + i, col: startCol, side: side));
                      break;
                  }
                }
                // Check if the segment already exists (all 12 present)
                final allExist = segment.every((b) => widget.grid.boundaries.contains(b));
                if (allExist) {
                  // Remove all
                  if (widget.onRemoveBoundary != null) {
                    for (final b in segment) {
                      widget.onRemoveBoundary!(b);
                      print('Removed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                    }
                  }
                } else {
                  // Add all
                  if (widget.onAddBoundary != null) {
                    for (final b in segment) {
                      if (!widget.grid.boundaries.contains(b)) {
                        widget.onAddBoundary!(b);
                        print('Placed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                      }
                    }
                  }
                }
              }
            },
            child: gridContent,
          );
        }

        // Calculate translation to move the center of the visible grid to the origin
        final double gridW = cellInchSize * totalColsInches;
        final double gridH = cellInchSize * totalRowsInches;
        // final vm.Matrix4 centerMatrix = vm.Matrix4.identity()
        //   ..translate(-gridW / 2, -gridH / 2);
        // final vm.Matrix4 uncenterMatrix = vm.Matrix4.identity()
        //   ..translate(gridW / 2, gridH / 2);

        final vm.Matrix4 transform = vm.Matrix4.identity()
          ..translate(gridW / 2, gridH / 2)
          ..rotateZ(widget.rotationZ)
          ..rotateX(widget.rotationX)
          ..rotateY(widget.rotationY)
          ..scale(_scale)
          ..translate(-gridW / 2, -gridH / 2);

        final vm.Matrix4 centerMatrix = vm.Matrix4.identity()
          ..translate(-gridW / 2, -gridH / 2);
        final vm.Matrix4 uncenterMatrix = vm.Matrix4.identity()
          ..translate(gridW / 2, gridH / 2);
        final transformedGrid = Center(
          child: Transform(
            alignment: Alignment.topLeft,
            transform: transform,
            child: SizedBox(
              width: gridWidth,
              height: gridHeightPx,
              child: gridContent,
            ),
          ),
        );

        // Wrap in RawKeyboardListener only (no Focus)
        return Center(
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey.keyLabel.toLowerCase() == 'r') {
                setState(() {
                  _dragRotation = (_dragRotation + 90) % 360;
                });
                // Check if preview is blocked after rotation
                if (_lastPreviewData != null) {
                  final type = _lastPreviewData!['type'];
                  final gridW = widget.grid.widthInches.floor();
                  final gridH = widget.grid.lengthInches.floor();
                  final dims = ObjectItem.getObjectDimensions(type);
                  final objW = dims['width'] ?? 1;
                  final objH = dims['height'] ?? 1;
                  if (objW > gridW || objH > gridH) {
                    print('Rotation blocked: object too large for grid after rotation.');
                  } else {
                    print('Rotated object to ${_dragRotation} degrees');
                  }
                } else {
                  print('Rotated object to ${_dragRotation} degrees');
                }
                // If there is a preview in progress, re-trigger preview snapping after rotation
                if (_lastPreviewData != null && _lastPreviewPointerOffset != null &&
                    _lastPreviewOffsetX != null && _lastPreviewOffsetY != null &&
                    _lastPreviewGridWidth != null && _lastPreviewGridHeightPx != null && _lastPreviewCellInchSize != null) {
                  _handlePreviewMove(
                    _lastPreviewData!,
                    _lastPreviewPointerOffset!,
                    _lastPreviewOffsetX!,
                    _lastPreviewOffsetY!,
                    _lastPreviewGridWidth!,
                    _lastPreviewGridHeightPx!,
                    _lastPreviewCellInchSize!
                  );
                }
              }
            },
            child: transformedGrid,
          ),
        );
      },
    );
  }

  // Helper function for pointer-to-grid mapping using inverse of rendering transform
  Offset? _pickGridCell3D({
    required Offset pointer,
    required double gridWidth,
    required double gridHeight,
    required double cellInchSize,
    required double rotationZ,
    required double scale,
    required double rotateX,
    required double rotateY,
  }) {
    final vm.Matrix4 transform = vm.Matrix4.identity()
      ..translate(gridWidth / 2, gridHeight / 2)
      ..rotateZ(rotationZ)
      ..rotateX(rotateX)
      ..rotateY(rotateY)
      ..scale(scale)
      ..translate(-gridWidth / 2, -gridHeight / 2);
    final vm.Matrix4? inverse = vm.Matrix4.tryInvert(transform);
    if (inverse == null) return null;
    final vm.Vector3 pointer3 = vm.Vector3(pointer.dx, pointer.dy, 0);
    final vm.Vector4 pointer4 = vm.Vector4(pointer.dx, pointer.dy, 0, 1);
    final vm.Vector4 local4 = inverse.transform(pointer4);
    final vm.Vector3 local3 = vm.Vector3(local4.x, local4.y, local4.z);
    return Offset(local3.x, local3.y);
  }
}

class CellPainter extends CustomPainter {
  final int row;
  final int col;
  final Grid grid;
  final Color gridCellColor;
  final Color gridBorderColor;
  final Color majorGridBorderColor;

  CellPainter({
    required this.row,
    required this.col,
    required this.grid,
    required this.gridCellColor,
    required this.gridBorderColor,
    required this.majorGridBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw cell background
    double cellWidth = size.width;
    double cellHeight = size.height;
    // No partial cells logic needed

    final backgroundPaint = Paint()..color = gridCellColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, cellWidth, cellHeight), backgroundPaint);

    // Draw borders for the cell
    final borderPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = AppConstants.thinBorderWidth
      ..style = PaintingStyle.stroke;
    // Top border
    canvas.drawLine(const Offset(0, 0), Offset(cellWidth, 0), borderPaint);
    // Left border
    canvas.drawLine(const Offset(0, 0), Offset(0, cellHeight), borderPaint);
    // Bottom border
    canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), borderPaint);
    // Right border
    canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), borderPaint);

    // Draw Major Grid Lines (if needed, can be based on every 12 inches)
    // ... (optional, can be re-added if you want major lines every 12 inches)
  }

  @override
  bool shouldRepaint(covariant CellPainter oldDelegate) {
    return oldDelegate.row != row ||
        oldDelegate.col != col ||
        oldDelegate.grid != grid ||
        oldDelegate.gridCellColor != gridCellColor ||
        oldDelegate.gridBorderColor != gridBorderColor ||
        oldDelegate.majorGridBorderColor != majorGridBorderColor;
  }
}

// New painter for the entire grid
class GridAreaPainter extends CustomPainter {
  final Grid grid;
  final double cellInchSize;
  final Color gridCellColor;
  final Color gridBorderColor;
  final Color majorGridBorderColor;
  final double gridWidth;
  final double gridHeight;

  GridAreaPainter({
    required this.grid,
    required this.cellInchSize,
    required this.gridCellColor,
    required this.gridBorderColor,
    required this.majorGridBorderColor,
    required this.gridWidth,
    required this.gridHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {

    // Paint for faint inch dividers
    final inchDividerPaint = Paint()
      ..color = AppConstants.inchDividerColor(const Color(0x88D72660))
      ..strokeWidth = AppConstants.gridInchDividerWidth;

    // Paint for major (12-inch) dividers
    final majorDividerPaint = Paint()
      ..color = AppConstants.gridPink
      ..strokeWidth = AppConstants.gridMajorLineWidth;

    double totalRowsInches = grid.lengthInches;
    double totalColsInches = grid.widthInches;

    // Draw global inch dividers (vertical)
    int totalInchesX = totalColsInches.round();
    int totalInchesY = totalRowsInches.round();
    for (int i = 1; i < totalInchesX; i++) {
      double x = i * cellInchSize;
      // Draw major divider every 12 inches
      if (i % 12 == 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), majorDividerPaint);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), inchDividerPaint);
      }
    }
    // Draw global inch dividers (horizontal)
    for (int i = 1; i < totalInchesY; i++) {
      double y = i * cellInchSize;
      // Draw major divider every 12 inches
      if (i % 12 == 0) {
        canvas.drawLine(Offset(0, y), Offset(gridWidth, y), majorDividerPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(gridWidth, y), inchDividerPaint);
      }
    }

    // Draw a single outline around the entire grid
    final outlinePaint = Paint()
      ..color = AppConstants.gridPink
      ..strokeWidth = AppConstants.gridOutlineWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cellInchSize * totalColsInches, cellInchSize * totalRowsInches),
      outlinePaint,
    );

    // Draw doors and windows (boundaries)
    for (final boundary in grid.boundaries) {
      final double x = boundary.col * cellInchSize;
      final double y = boundary.row * cellInchSize;
      final double x2 = (boundary.col + 1) * cellInchSize;
      final double y2 = (boundary.row + 1) * cellInchSize;
      Paint paint;
      if (boundary.type == 'door') {
        paint = Paint()
          ..color = Colors.brown
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke;
      } else {
        paint = Paint()
          ..color = Colors.blue
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke;
        // Dashed effect for window
        // We'll draw a dashed line manually below
      }
      if (boundary.type == 'door') {
        // Draw solid line for door
        switch (boundary.side) {
          case 'top':
            canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
            break;
          case 'bottom':
            canvas.drawLine(Offset(x, y2), Offset(x2, y2), paint);
            break;
          case 'left':
            canvas.drawLine(Offset(x, y), Offset(x, y2), paint);
            break;
          case 'right':
            canvas.drawLine(Offset(x2, y), Offset(x2, y2), paint);
            break;
        }
      } else {
        // Draw dashed line for window
        const dashWidth = 8.0;
        const dashSpace = 6.0;
        void drawDashedLine(Offset start, Offset end) {
          final totalLength = (end - start).distance;
          final direction = (end - start) / totalLength;
          double drawn = 0;
          while (drawn < totalLength) {
            final currentDash = drawn + dashWidth < totalLength ? dashWidth : totalLength - drawn;
            final p1 = start + direction * drawn;
            final p2 = start + direction * (drawn + currentDash);
            canvas.drawLine(p1, p2, paint);
            drawn += dashWidth + dashSpace;
          }
        }
        switch (boundary.side) {
          case 'top':
            drawDashedLine(Offset(x, y), Offset(x2, y));
            break;
          case 'bottom':
            drawDashedLine(Offset(x, y2), Offset(x2, y2));
            break;
          case 'left':
            drawDashedLine(Offset(x, y), Offset(x, y2));
            break;
          case 'right':
            drawDashedLine(Offset(x2, y), Offset(x2, y2));
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridAreaPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.cellInchSize != cellInchSize ||
        oldDelegate.gridCellColor != gridCellColor ||
        oldDelegate.gridBorderColor != gridBorderColor ||
        oldDelegate.majorGridBorderColor != majorGridBorderColor ||
        oldDelegate.gridWidth != gridWidth ||
        oldDelegate.gridHeight != gridHeight;
  }
}

class _BoundaryPreviewPainter extends CustomPainter {
  final String type;
  final String side;
  final double x, y, x2, y2;
  _BoundaryPreviewPainter({required this.type, required this.side, required this.x, required this.y, required this.x2, required this.y2});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint;
    if (type == 'door') {
      paint = Paint()
        ..color = Colors.brown // fully opaque
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, y), Offset(x2, y2), paint);
    } else {
      paint = Paint()
        ..color = Colors.blue // fully opaque
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;
      // Dashed effect for window
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      final totalLength = (Offset(x2, y2) - Offset(x, y)).distance;
      final direction = (Offset(x2, y2) - Offset(x, y)) / totalLength;
      double drawn = 0;
      while (drawn < totalLength) {
        final currentDash = drawn + dashWidth < totalLength ? dashWidth : totalLength - drawn;
        final p1 = Offset(x, y) + direction * drawn;
        final p2 = Offset(x, y) + direction * (drawn + currentDash);
        canvas.drawLine(p1, p2, paint);
        drawn += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoundaryPreviewPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.side != side || oldDelegate.x != x || oldDelegate.y != y || oldDelegate.x2 != x2 || oldDelegate.y2 != y2;
  }
} 