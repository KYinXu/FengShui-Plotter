import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math';
import 'object_item.dart';
import 'grid_object.dart';
import 'dart:async';

class GridWidget extends StatefulWidget {
  final Grid grid;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final List<GridObject> objects;
  final void Function(int row, int col, String type, IconData icon)? onObjectDropped;

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

  // Constants for 3D transformation
  static const double _additionalRotationX = 0.3;
  static const double _scale = 0.7;

  void _updatePreview(Offset? cell, String? type, IconData? icon) {
    // Only update if the preview state is actually changing
    if (_previewCell == cell && _previewType == type && _previewIcon == icon) {
      // No change, skip setState
      debugPrint('Preview unchanged, skipping setState');
      return;
    }
    debugPrint('Updating preview: cell= [32m$cell [0m, type= [32m$type [0m, icon= [32m$icon [0m');
    setState(() {
      _previewCell = cell;
      _previewType = type;
      _previewIcon = icon;
    });
  }

  // Helper to check if a cell or area is occupied
  bool isAreaOccupied(int row, int col, int width, int height) {
    print("len: ${GridObjectWidget.getTotalGridWidthInches(widget.grid)} width: ${GridObjectWidget.getTotalGridLengthInches(widget.grid)} row: ${row} col: {$col}");
    int totWidth = GridObjectWidget.getTotalGridWidthInches(widget.grid).floor();
    int totLength = GridObjectWidget.getTotalGridLengthInches(widget.grid).floor();
    if (row < 0 || col < 0 || row + height > totLength || col + width > totWidth) {
      return true;
    }
    for (final obj in widget.objects) {
      final dims = ObjectItem.getObjectDimensions(obj.type);
      final int objRow = obj.row;
      final int objCol = obj.col;
      final int objWidth = dims['width']!;
      final int objHeight = dims['height']!;
      // Check for rectangle overlap
      if (row < objRow + objHeight && row + height > objRow &&
          col < objCol + objWidth && col + width > objCol) {
        return true;
      }
    }
    return false;
  }

  // Helper to find the nearest open location for an object
  Offset? findNearestOpenCell(int startRow, int startCol, int width, int height, {int radius = 8}) {
    final int maxRows = widget.grid.lengthInches.floor();
    final int maxCols = widget.grid.widthInches.floor();
    if (!isAreaOccupied(startRow, startCol, width, height)) {
      return Offset(startCol.toDouble(), startRow.toDouble());
    }
    for (int dist = 1; dist <= radius; dist++) {
      for (int dRow = -dist; dRow <= dist; dRow++) {
        int dCol = dist - dRow.abs();
        for (int sign = -1; sign <= 1; sign += 2) {
          int row = startRow + dRow;
          int col = startCol + sign * dCol;
          if (row >= 0 && col >= 0 && row + height <= maxRows && col + width <= maxCols) {
            if (!isAreaOccupied(row, col, width, height)) {
              return Offset(col.toDouble(), row.toDouble());
            }
          }
        }
      }
    }
    // No open cell found in radius
    return null;
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
            final Offset? snapped = findNearestOpenCell(row, col, dims['width']!, dims['height']!);
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
              widget.onObjectDropped!(snappedRow, snappedCol, details.data['type'], details.data['icon']);
            }
            _updatePreview(null, null, null);
          },
          onMove: (details) {
            debugPrint('onMove called');
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset local = box.globalToLocal(details.offset);
            // Adjust for centering offset
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
            if (gridLocal != null && details.data['type'] is String && details.data['icon'] is IconData) {
              final String type = details.data['type'];
              final dims = ObjectItem.getObjectDimensions(type);
              int col = (gridLocal.dx / cellInchSize).floor();
              int row = (gridLocal.dy / cellInchSize).floor();
              col -= (dims['width']! / 2).floor();
              row -= (dims['height']! / 2).floor();
              debugPrint('Trying to snap: row=$row, col=$col, width=${dims['width']}, height=${dims['height']}');
              // Snap to nearest open location within a limited radius
              final Offset? snapped = findNearestOpenCell(row, col, dims['width']!, dims['height']!, radius: 8);
              if (snapped == null) {
                debugPrint('No open cell found for preview');
                _updatePreview(null, null, null);
                _snappedPreviewCell = null;
              } else {
                if (isAreaOccupied(snapped.dy.toInt(), snapped.dx.toInt(), dims['width']!, dims['height']!)) {
                  debugPrint('Snapped cell is still occupied');
                  _updatePreview(snapped, type, details.data['icon']);
                  _snappedPreviewCell = null;
                } else {
                  debugPrint('Snapped to open cell: $snapped');
                  _updatePreview(snapped, type, details.data['icon']);
                  _snappedPreviewCell = snapped;
                }
              }
            } else {
              debugPrint('Pointer not over grid or invalid data');
              _updatePreview(null, null, null);
              _snappedPreviewCell = null;
            }
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

        return Center(
          child: transformedGrid,
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
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