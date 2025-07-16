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

  const GridWidget({
    super.key,
    required this.grid,
    this.rotationX = 0.3,
    this.rotationY = 0.0,
    this.rotationZ = 0.0,
    this.objects = const [],
    this.onObjectDropped,
  });

  @override
  State<GridWidget> createState() => _GridWidgetState();
}

class _GridWidgetState extends State<GridWidget> {
  Offset? _previewCell;
  String? _previewType;
  IconData? _previewIcon;
  Offset? _snappedPreviewCell;
  int _previewRotation = 0; // 0, 90, 180, 270
  final FocusNode _focusNode = FocusNode();

  // Constants for 3D transformation
  static const double _additionalRotationX = 0.3;
  static const double _scale = 0.7;

  void _updatePreview(Offset? cell, String? type, IconData? icon, [int? rotation]) {
    if (_previewCell == cell && _previewType == type && _previewIcon == icon && (rotation == null || _previewRotation == rotation)) {
      return;
    }
    debugPrint('Updating preview: cell= [32m$cell [0m, type= [32m$type [0m, icon= [32m$icon [0m, rot= [32m${rotation ?? _previewRotation} [0m');
    setState(() {
      _previewCell = cell;
      _previewType = type;
      _previewIcon = icon;
      if (rotation != null) _previewRotation = rotation;
    });
  }

  int _searchToken = 0;

  // Polygon-based area occupied check
  bool isAreaOccupiedPolygon(int row, int col, String type, int rotation) {
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

  // Polygon-based nearest open cell
  Offset? findNearestOpenCellPolygon(int startRow, int startCol, String type, int rotation, {int radius = 8}) {
    final gridW = widget.grid.widthInches.floor();
    final gridH = widget.grid.lengthInches.floor();
    if (!isAreaOccupiedPolygon(startRow, startCol, type, rotation)) {
      return Offset(startCol.toDouble(), startRow.toDouble());
    }
    for (int dist = 1; dist <= radius; dist++) {
      for (int dRow = -dist; dRow <= dist; dRow++) {
        int dCol = dist - dRow.abs();
        for (int sign = -1; sign <= 1; sign += 2) {
          int row = startRow + dRow;
          int col = startCol + sign * dCol;
          if (row >= 0 && col >= 0 && row <= gridH && col <= gridW) {
            if (!isAreaOccupiedPolygon(row, col, type, rotation)) {
              return Offset(col.toDouble(), row.toDouble());
            }
          }
        }
      }
    }
    return null;
  }

  // Update preview/placement logic to use polygon system
  void _handlePreviewMove(Map<String, dynamic> data, Offset pointerOffset, double offsetX, double offsetY, double gridWidth, double gridHeightPx, double cellInchSize) {
    final int myToken = ++_searchToken;
    Future(() {
      if (data['type'] is! String || data['icon'] is! IconData) return;
      final String type = data['type'];
      final dims = ObjectItem.getObjectDimensions(type);
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
        int col = (gridLocal.dx / cellInchSize).floor();
        int row = (gridLocal.dy / cellInchSize).floor();
        // Center polygon at pointer
        final poly = ObjectItem.getObjectPolygon(type);
        double minX = poly.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
        double minY = poly.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
        double maxX = poly.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
        double maxY = poly.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
        int w = (maxX - minX).round();
        int h = (maxY - minY).round();
        col -= (w / 2).floor();
        row -= (h / 2).floor();
        final Offset? snapped = findNearestOpenCellPolygon(row, col, type, _previewRotation, radius: 8);
        if (myToken != _searchToken) return; // Outdated, ignore result
        if (snapped == null) {
          _updatePreview(null, null, null);
          _snappedPreviewCell = null;
        } else {
          if (isAreaOccupiedPolygon(snapped.dy.toInt(), snapped.dx.toInt(), type, _previewRotation)) {
            _updatePreview(snapped, type, data['icon']);
            _snappedPreviewCell = null;
          } else {
            _updatePreview(snapped, type, data['icon']);
            _snappedPreviewCell = snapped;
          }
        }
      } else {
        if (myToken != _searchToken) return;
        _updatePreview(null, null, null);
        _snappedPreviewCell = null;
      }
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
        final gridContent = DragTarget<Map<String, dynamic>>(
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
            final String type = details.data['type'];
            final dims = ObjectItem.getObjectDimensions(type);
            int col = (gridLocal.dx / cellInchSize).floor();
            int row = (gridLocal.dy / cellInchSize).floor();
            col -= (dims['width']! / 2).floor();
            row -= (dims['height']! / 2).floor();
            // Snap to nearest open location
            final Offset? snapped = findNearestOpenCellPolygon(row, col, type, _previewRotation, radius: 8);
            if (snapped == null) {
              _updatePreview(null, null, null);
              _snappedPreviewCell = null;
              return;
            }
            final int snappedRow = snapped.dy.toInt();
            final int snappedCol = snapped.dx.toInt();
            // if (isAreaOccupied(snappedRow, snappedCol, dims['width']!, dims['height']!)) {
            //   _updatePreview(null, null, null);
            //   return;
            // }
            // final double left = snappedCol * cellInchSize;
            // final double top = snappedRow * cellInchSize;
            //final double right = left + cellInchSize;
            //final double bottom = top + cellInchSize;
            if (widget.onObjectDropped != null &&
                details.data['type'] is String &&
                details.data['icon'] is IconData) {
              widget.onObjectDropped!(snappedRow, snappedCol, details.data['type'], details.data['icon'], _previewRotation);
            }
            _updatePreview(null, null, null);
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
                  Positioned(
                    left: _previewCell!.dx * cellInchSize,
                    top: _previewCell!.dy * cellInchSize,
                    child: Opacity(
                      opacity: 0.5,
                      child: Transform.rotate(
                        angle: (_previewRotation % 360) * 3.1415926535897932 / 180.0,
                        child: Container(
                          width: cellInchSize * (ObjectItem.getObjectDimensions(_previewType!)['width'] ?? 1),
                          height: cellInchSize * (ObjectItem.getObjectDimensions(_previewType!)['height'] ?? 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 3),
                            shape: BoxShape.rectangle,
                            color: Colors.red.withOpacity(0.2),
                          ),
                          child: Icon(_previewIcon, size: cellInchSize * 8, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                // Placed objects
                ...widget.objects.map((obj) => GridObjectWidget(obj: obj, cellInchSize: cellInchSize)),
              ],
            );
          },
        );

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
          child: RawKeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKey: (event) {
              if (event is RawKeyEvent && event is! RawKeyUpEvent && event.logicalKey.keyLabel.toLowerCase() == 'r') {
                setState(() {
                  _previewRotation = (_previewRotation + 90) % 360;
                });
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
    const thinBorder = AppConstants.thinBorderWidth;
    const thickBorder = AppConstants.thickBorderWidth;
    final thinPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = thinBorder;
    final thickPaint = Paint()
      ..color = majorGridBorderColor
      ..strokeWidth = thickBorder;

    // Draw cell background
    double cellWidth = size.width;
    double cellHeight = size.height;
    // No partial cells logic needed

    final backgroundPaint = Paint()..color = gridCellColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, cellWidth, cellHeight), backgroundPaint);

    // Draw borders for the cell
    final borderPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = thinBorder
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
    const thinBorder = AppConstants.thinBorderWidth;
    const thickBorder = AppConstants.thickBorderWidth;
    final thinPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = thinBorder;
    final thickPaint = Paint()
      ..color = majorGridBorderColor
      ..strokeWidth = thickBorder;
    final backgroundPaint = Paint()..color = gridCellColor;

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