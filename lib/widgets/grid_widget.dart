import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math';
import 'object_item.dart';
import 'grid_object.dart';

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
    setState(() {
      _previewCell = cell;
      _previewType = type;
      _previewIcon = icon;
    });
  }

  // Helper to check if a cell or area is occupied
  bool isAreaOccupied(int row, int col, int width, int height) {
    print("len: ${widget.grid.length} width: ${widget.grid.width} row: ${row} col: {$col}");
    if (row < 0 || col < 0) {
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
  Offset findNearestOpenCell(int startRow, int startCol, int width, int height) {
    double bestRow = 0.0;
    double bestCol = 0.0;
    int bestDist = 1 << 30; // large int
    if(!isAreaOccupied(startRow, startCol, width, height)) {
      return Offset(startCol.toDouble(), startRow.toDouble());
    }
    print("occupied");
    int row = startRow;
    int col = startCol;
    // int dx = 0;
    // int dy = 0;
    while (isAreaOccupied(row, col, width, height)) {
      row++;
      col++;
    }
    // double bestRow = row.toDouble();
    // double bestCol = col.toDouble();
    // while (true) {
    //   dy++;
    //   dx++;
    //   for (int cur_x = row - dx; row <= min(widget.grid.length - height, row + dx); cur_x++) {
        
    //   }
    //   for (int cur_y = col - dy; cur_y <= min(widget.grid.width - width, col + dy); cur_y++) {
    //   }
    // }


    // Search the entire grid for the nearest open spot
    // for (int row = 0; row <= widget.grid.length - height; row++) {
    //   for (int col = 0; col <= widget.grid.width - width; col++) {
    //     if (!isAreaOccupied(row, col, width, height)) {
    //       print("a best dist was searched");
    //       int dist = (row - startRow) * (row - startRow) + (col - startCol) * (col - startCol);
    //       if (dist < bestDist) {
            
    //         bestDist = dist;
    //         bestRow = row.toDouble();
    //         bestCol = col.toDouble();
    //       }
    //     }
    //   }
    // }
    
    return Offset(bestCol, bestRow);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const gridCellColor = Colors.transparent;
    final gridBorderColor = colorScheme.outline;
    final majorGridBorderColor = colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        //final double availableWidth = constraints.maxWidth;
        // Calculate the true visible width and height, accounting for partial cells
        int fullCols = widget.grid.width - 1;
        int fullRows = widget.grid.length - 1;
        double lastColInches = widget.grid.widthPartialPercentage > 0 ? widget.grid.widthPartialPercentage * 12.0 : 12.0;
        double lastRowInches = widget.grid.lengthPartialPercentage > 0 ? widget.grid.lengthPartialPercentage * 12.0 : 12.0;
        double totalColsInches = fullCols * 12.0 + lastColInches;
        double totalRowsInches = fullRows * 12.0 + lastRowInches;
        final double cellInchSizeW = constraints.maxWidth / totalColsInches;
        final double cellInchSizeH = constraints.maxHeight / totalRowsInches;
        final double cellInchSize = cellInchSizeW < cellInchSizeH ? cellInchSizeW : cellInchSizeH;
        //final double gridHeight = cellInchSize * totalRowsInches;

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
            final Offset snapped = findNearestOpenCell(row, col, dims['width']!, dims['height']!);
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
              // Snap to nearest open location
              final Offset snapped = findNearestOpenCell(row, col, dims['width']!, dims['height']!);
              if (isAreaOccupied(snapped.dy.toInt(), snapped.dx.toInt(), dims['width']!, dims['height']!)) {
                print("Snap if");
                _updatePreview(snapped, type, details.data['icon']);
                _snappedPreviewCell = null;
              } else {
                print("Snap else");
                _updatePreview(snapped, type, details.data['icon']);
                _snappedPreviewCell = snapped;
              }
            } else {
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
    bool isPartial = grid.isPartialCell(row, col);

    if (isPartial) {
      if (grid.isPartialCell(row, col)) {
        if (row == grid.length - 1 && grid.lengthPartialPercentage > 0) {
          cellHeight *= grid.lengthPartialPercentage;
        }
        if (col == grid.width - 1 && grid.widthPartialPercentage > 0) {
          cellWidth *= grid.widthPartialPercentage;
        }
      }
    }

    final backgroundPaint = Paint()..color = gridCellColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, cellWidth, cellHeight), backgroundPaint);

    // Draw borders for the potentially partial cell
    final borderPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = thinBorder
      ..style = PaintingStyle.stroke;
    // Only draw the right and bottom borders if this is not a partial cell, or if it is, only up to the partial size
    // Top border
    canvas.drawLine(const Offset(0, 0), Offset(cellWidth, 0), borderPaint);
    // Left border
    canvas.drawLine(const Offset(0, 0), Offset(0, cellHeight), borderPaint);
    // Bottom border (only if last row or not a partial row)
    if (row == grid.length - 1) {
      if (grid.lengthPartialPercentage > 0) {
        // Only draw up to the partial width for the last row
        canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), borderPaint);
      } else {
        // Full width
        canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), borderPaint);
      }
    } else {
      // Not last row, draw full bottom
      canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), borderPaint);
    }
    // Right border (only if last column or not a partial column)
    if (col == grid.width - 1) {
      if (grid.widthPartialPercentage > 0) {
        // Only draw up to the partial height for the last column
        canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), borderPaint);
      } else {
        // Full height
        canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), borderPaint);
      }
    } else {
      // Not last column, draw full right
      canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), borderPaint);
    }

    // Draw Major Grid Lines
    // Top (only for first row)
    if (row == 0 && row % 12 == 0) {
      canvas.drawLine(const Offset(0, 0), Offset(cellWidth, 0), thickPaint);
    }
    if (col == 0 && col % 12 == 0) {
      canvas.drawLine(const Offset(0, 0), Offset(0, cellHeight), thickPaint);
    }
    // Bottom major line (only for last row in a major block or last row overall, and only up to partial width if partial)
    if (((row + 1) % 12 == 0 && row == grid.length - 1) || (row + 1 == grid.length && (row + 1) % 12 != 0)) {
      canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), thickPaint);
    }
    // Right major line (only for last column in a major block or last column overall, and only up to partial height if partial)
    if (((col + 1) % 12 == 0 && col == grid.width - 1) || (col + 1 == grid.width && (col + 1) % 12 != 0)) {
      canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), thickPaint);
    }
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

    int rows = grid.length;
    int cols = grid.width;
    double lastRowPartial = grid.lengthPartialPercentage;
    double lastColPartial = grid.widthPartialPercentage;
    int fullCols = cols - 1;
    int fullRows = rows - 1;
    double lastColInches = lastColPartial > 0 ? lastColPartial * 12.0 : 12.0;
    double lastRowInches = lastRowPartial > 0 ? lastRowPartial * 12.0 : 12.0;

    // Calculate total grid size in inches for outline
    double totalColsInches = (cols - 1) * 12.0 + (lastColPartial > 0 ? lastColPartial * 12.0 : 12.0);
    double totalRowsInches = (rows - 1) * 12.0 + (lastRowPartial > 0 ? lastRowPartial * 12.0 : 12.0);

    // Draw global inch dividers (vertical)
    int totalInchesX = ((cols - 1) * 12 + (lastColPartial > 0 ? lastColPartial * 12 : 12)).round();
    int totalInchesY = ((rows - 1) * 12 + (lastRowPartial > 0 ? lastRowPartial * 12 : 12)).round();
    for (int i = 1; i < totalInchesX; i++) {
      double x = i * cellInchSize;
      canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), inchDividerPaint);
    }
    // Draw global inch dividers (horizontal)
    for (int i = 1; i < totalInchesY; i++) {
      double y = i * cellInchSize;
      canvas.drawLine(Offset(0, y), Offset(gridWidth, y), inchDividerPaint);
    }

    // Draw cells (backgrounds)
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        double w = (col == cols - 1) ? lastColInches * cellInchSize : 12.0 * cellInchSize;
        double h = (row == rows - 1) ? lastRowInches * cellInchSize : 12.0 * cellInchSize;
        double x = 0;
        for (int c = 0; c < col; c++) {
          x += (c == cols - 2 && lastColPartial > 0) ? lastColInches * cellInchSize : 12.0 * cellInchSize;
        }
        double y = 0;
        for (int r = 0; r < row; r++) {
          y += (r == rows - 2 && lastRowPartial > 0) ? lastRowInches * cellInchSize : 12.0 * cellInchSize;
        }
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), backgroundPaint);
      }
    }

    // Draw thin borders
    final bolderThickPaint = Paint()
      ..color = AppConstants.gridPink
      ..strokeWidth = AppConstants.gridMajorLineWidth;

    // Draw major (foot) grid lines from the top-left corner (0,0)
    Set<double> yLines = {};
    for (double y = 0; y <= gridHeight + 0.1; y += 12 * cellInchSize) {
      yLines.add(y);
      canvas.drawLine(Offset(0, y), Offset(gridWidth, y), bolderThickPaint);
    }
    if ((gridHeight / cellInchSize) % 12 != 0) {
      double y = gridHeight;
      if (!yLines.contains(y)) {
        canvas.drawLine(Offset(0, y), Offset(gridWidth, y), bolderThickPaint);
      }
    }
    Set<double> xLines = {};
    for (double x = 0; x <= gridWidth + 0.1; x += 12 * cellInchSize) {
      xLines.add(x);
      canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), bolderThickPaint);
    }
    if ((gridWidth / cellInchSize) % 12 != 0) {
      double x = gridWidth;
      if (!xLines.contains(x)) {
        canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), bolderThickPaint);
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