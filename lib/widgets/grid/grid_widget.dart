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
import 'grid_painters.dart';
import '../../services/boundary_placer_service.dart';

class GridWidget extends StatefulWidget {
  final Grid grid;
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  final void Function(int row, int col, String type, IconData icon, [int rotation])? onObjectDropped;
  final String boundaryMode; // 'none', 'door', 'window'
  final void Function(GridBoundary boundary)? onAddBoundary;
  final void Function(GridBoundary boundary)? onRemoveBoundary;

  const GridWidget({
    super.key,
    required this.grid,
    this.rotationX = 0.3,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
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
    for (final obj in widget.grid.objects) {
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
      for (final obj in widget.grid.objects) {
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
            for (final obj in widget.grid.objects) {
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
      if (BoundaryPlacerService.isBoundaryType(type)) {
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
          
          final previewInfo = BoundaryPlacerService.calculateBoundaryPreview(
            col, row, gridH, gridW, cellInchSize
          );
          
          if (previewInfo != null) {
            // For boundaries, use the cursor position for preview
            _updatePreview(Offset(col, row), type, data['icon']);
            // Diagnostic print for boundaries during drag
            print('Boundaries during drag:');
            for (final b in widget.grid.boundaries) {
              print(b);
            }
          } else {
            _updatePreview(null, null, null);
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
            if (BoundaryPlacerService.isBoundaryType(details.data['type'])) {
              final String type = details.data['type'];
              final int maxRow = widget.grid.lengthInches.floor();
              final int maxCol = widget.grid.widthInches.floor();
              final double col = gridLocal.dx / cellInchSize;
              final double row = gridLocal.dy / cellInchSize;
              
              final result = BoundaryPlacerService.handleGridBoundaryDrop(
                type, col, row, maxRow, maxCol, widget.grid.boundaries, details.data['icon']
              );
              
              if (result != null) {
                if (result.shouldRemove) {
                  if (widget.onRemoveBoundary != null) {
                    for (final b in result.segment) {
                      widget.onRemoveBoundary!(b);
                      print('Removed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                    }
                  }
                } else {
                  if (widget.onAddBoundary != null) {
                    for (final b in result.segment) {
                      if (!widget.grid.boundaries.contains(b)) {
                        widget.onAddBoundary!(b);
                        print('Boundary added: $b');
                      }
                    }
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
                    boundaries: widget.grid.boundaries,
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
                        
                        final previewInfo = BoundaryPlacerService.calculateBoundaryPreview(
                          col, row, gridH, gridW, cellInchSize
                        );
                        
                        if (previewInfo != null) {
                          return Positioned(
                            left: 0,
                            top: 0,
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: Size(gridW * cellInchSize, gridH * cellInchSize),
                                painter: BoundaryPreviewPainter(
                                  type: _previewType!,
                                  side: previewInfo.side,
                                  x: previewInfo.x,
                                  y: previewInfo.y,
                                  x2: previewInfo.x2,
                                  y2: previewInfo.y2,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
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
                ...widget.grid.objects.map((obj) => GridObjectWidget(obj: obj, cellInchSize: cellInchSize)),
                // Placed boundaries
                ...widget.grid.boundaries.map((boundary) => GridBoundaryWidget(boundary: boundary, cellInchSize: cellInchSize)),
              ],
            );
          },
        );

        // Overlay GestureDetector for edge clicks in boundary mode
        if (widget.boundaryMode != 'none' || true) {
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
                final type = widget.boundaryMode == 'door' ? 'door' : 'window';
                
                final result = BoundaryPlacerService.handleGridBoundaryClick(
                  type, col, row, maxRow, maxCol, widget.grid.boundaries, Icons.door_front_door
                );
                
                if (result != null) {
                  if (result.shouldRemove) {
                    if (widget.onRemoveBoundary != null || true) {
                      for (final b in result.segment) {
                        widget.onRemoveBoundary!(b);
                        print('Removed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                      }
                    }
                  } else {
                    if (widget.onAddBoundary != null || true) {
                      for (final b in result.segment) {
                        if (!widget.grid.boundaries.contains(b)) {
                          widget.onAddBoundary!(b);
                          print('Placed ${b.type} at row=${b.row}, col=${b.col}, side=${b.side}');
                        }
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

        // final vm.Matrix4 centerMatrix = vm.Matrix4.identity()
        //   ..translate(-gridW / 2, -gridH / 2);
        // final vm.Matrix4 uncenterMatrix = vm.Matrix4.identity()
        //   ..translate(gridW / 2, gridH / 2);
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