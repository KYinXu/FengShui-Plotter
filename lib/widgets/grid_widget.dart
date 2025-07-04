import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class GridWidget extends StatefulWidget {
  final Grid grid;
  final double rotationZ;
  final List<GridObject> objects;
  final void Function(int row, int col, String type, IconData icon)? onObjectDropped;

  const GridWidget({
    super.key,
    required this.grid,
    this.rotationZ = -0.7,
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

  // Constants for 3D transformation
  static const double _additionalRotationX = 0.8;
  static const double _scale = 0.7;

  void _updatePreview(Offset? cell, String? type, IconData? icon) {
    setState(() {
      _previewCell = cell;
      _previewType = type;
      _previewIcon = icon;
    });
  }

  // Helper to get object dimensions in grid cells
  Map<String, int> getObjectDimensions(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        return {'width': 12, 'height': 12};
      default:
        return {'width': 1, 'height': 1};
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const gridCellColor = Colors.transparent;
    final gridBorderColor = colorScheme.outline;
    final majorGridBorderColor = colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        // Calculate the true visible width and height, accounting for partial cells
        int fullCols = widget.grid.width - 1;
        int fullRows = widget.grid.length - 1;
        double lastColInches = widget.grid.widthPartialPercentage > 0 ? widget.grid.widthPartialPercentage * 12.0 : 12.0;
        double lastRowInches = widget.grid.lengthPartialPercentage > 0 ? widget.grid.lengthPartialPercentage * 12.0 : 12.0;
        double totalColsInches = fullCols * 12.0 + lastColInches;
        double totalRowsInches = fullRows * 12.0 + lastRowInches;
        final double cellInchSize = availableWidth / totalColsInches;
        final double gridHeight = cellInchSize * totalRowsInches;

        final gridWidth = cellInchSize * totalColsInches;
        final gridHeightPx = cellInchSize * totalRowsInches;
        final gridContent = DragTarget<Map<String, dynamic>>(
          onAcceptWithDetails: (details) {
            print('DragTarget: onAcceptWithDetails with data: \\${details.data} at offset: \\${details.offset}');
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset local = box.globalToLocal(details.offset);

            // Use inverse transform for accurate picking
            final Offset? gridLocal = _pickGridCell3D(
              pointer: local,
              gridWidth: gridWidth,
              gridHeight: gridHeightPx,
              cellInchSize: cellInchSize,
              rotationZ: widget.rotationZ,
              scale: _scale,
              rotateX: _additionalRotationX,
            );
            if (gridLocal == null) {
              print('Warning: Could not invert transform matrix');
              return;
            }
            final String type = details.data['type'];
            final dims = getObjectDimensions(type);
            int col = (gridLocal.dx / cellInchSize).floor();
            int row = (gridLocal.dy / cellInchSize).floor();
            col -= (dims['width']! / 2).floor();
            row -= (dims['height']! / 2).floor();
            final double left = col * cellInchSize;
            final double top = row * cellInchSize;
            final double right = left + cellInchSize;
            final double bottom = top + cellInchSize;
            print('Calculated drop cell: row=\\$row, col=\\$col, bounding box: (left=\\$left, top=\\$top, right=\\$right, bottom=\\$bottom)');
            if (widget.onObjectDropped != null &&
                details.data['type'] is String &&
                details.data['icon'] is IconData) {
              widget.onObjectDropped!(row, col, details.data['type'], details.data['icon']);
            }
            _updatePreview(null, null, null);
          },
          onMove: (details) {
            print('DragTarget: onMove with data: \\${details.data} at offset: \\${details.offset}');
            final RenderBox box = context.findRenderObject() as RenderBox;
            final Offset local = box.globalToLocal(details.offset);
            final Offset? gridLocal = _pickGridCell3D(
              pointer: local,
              gridWidth: gridWidth,
              gridHeight: gridHeightPx,
              cellInchSize: cellInchSize,
              rotationZ: widget.rotationZ,
              scale: _scale,
              rotateX: _additionalRotationX,
            );
            if (gridLocal != null && details.data['type'] is String && details.data['icon'] is IconData) {
              final String type = details.data['type'];
              final dims = getObjectDimensions(type);
              int col = (gridLocal.dx / cellInchSize).floor();
              int row = (gridLocal.dy / cellInchSize).floor();
              col -= (dims['width']! / 2).floor();
              row -= (dims['height']! / 2).floor();
              _updatePreview(Offset(col.toDouble(), row.toDouble()), type, details.data['icon']);
            } else {
              _updatePreview(null, null, null);
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
                        width: cellInchSize * (getObjectDimensions(_previewType!)['width'] ?? 1),
                        height: cellInchSize * (getObjectDimensions(_previewType!)['height'] ?? 1),
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
                ...widget.objects.map((obj) {
                  final dims = getObjectDimensions(obj.type);
                  final double left = obj.col * cellInchSize;
                  final double top = obj.row * cellInchSize;
                  final double objWidth = cellInchSize * dims['width']!;
                  final double objHeight = cellInchSize * dims['height']!;
                  return Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: objWidth,
                      height: objHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange, width: 3),
                        shape: BoxShape.rectangle,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      child: Icon(obj.icon, size: objWidth * 0.6, color: Colors.black),
                    ),
                  );
                }),
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
          ..rotateX(_additionalRotationX)
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

        if (gridHeight < constraints.maxHeight) {
          // If the grid is smaller than the container, center it.
          return Center(
            child: transformedGrid,
          );
        }

        // If the grid is larger, make it scrollable.
        return SingleChildScrollView(
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
  }) {
    final vm.Matrix4 transform = vm.Matrix4.identity()
      ..translate(gridWidth / 2, gridHeight / 2)
      ..rotateZ(rotationZ)
      ..rotateX(rotateX)
      ..scale(scale)
      ..translate(-gridWidth / 2, -gridHeight / 2);
    final vm.Matrix4? inverse = vm.Matrix4.tryInvert(transform);
    print('');
    print('Pointer: \\${pointer.dx}, \\${pointer.dy}');
    if (inverse == null) return null;
    final vm.Vector3 pointer3 = vm.Vector3(pointer.dx, pointer.dy, 0);
    final vm.Vector4 pointer4 = vm.Vector4(pointer.dx, pointer.dy, 0, 1);
    final vm.Vector4 local4 = inverse.transform(pointer4);
    final vm.Vector3 local3 = vm.Vector3(local4.x, local4.y, local4.z);
    print('Mapped to grid local: \\${local3.x}, \\${local3.y}');
    print('');
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