import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';

class GridWidget extends StatelessWidget {
  final Grid grid;
  final double rotationZ;

  const GridWidget({
    super.key,
    required this.grid,
    this.rotationZ = -0.7,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridCellColor = Colors.transparent;
    final gridBorderColor = colorScheme.outline;
    final majorGridBorderColor = colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        // Calculate the true visible width and height, accounting for partial cells
        int fullCols = grid.width - 1;
        int fullRows = grid.length - 1;
        double lastColInches = grid.widthPartialPercentage > 0 ? grid.widthPartialPercentage * 12.0 : 12.0;
        double lastRowInches = grid.lengthPartialPercentage > 0 ? grid.lengthPartialPercentage * 12.0 : 12.0;
        double totalColsInches = fullCols * 12.0 + lastColInches;
        double totalRowsInches = fullRows * 12.0 + lastRowInches;
        final double cellInchSize = availableWidth / totalColsInches;
        final double gridHeight = cellInchSize * totalRowsInches;

        final gridWidth = cellInchSize * totalColsInches;
        final gridHeightPx = cellInchSize * totalRowsInches;
        final gridContainer = SizedBox(
          width: gridWidth,
          height: gridHeightPx,
          child: CustomPaint(
            painter: GridAreaPainter(
              grid: grid,
              cellInchSize: cellInchSize,
              gridCellColor: gridCellColor,
              gridBorderColor: gridBorderColor,
              majorGridBorderColor: majorGridBorderColor,
              gridWidth: gridWidth,
              gridHeight: gridHeightPx,
            ),
          ),
        );

        // Calculate translation to move the center of the visible grid to the origin
        final double gridW = cellInchSize * totalColsInches;
        final double gridH = cellInchSize * totalRowsInches;
        final Matrix4 centerMatrix = Matrix4.identity()
          ..translate(-gridW / 2, -gridH / 2);
        final Matrix4 uncenterMatrix = Matrix4.identity()
          ..translate(gridW / 2, gridH / 2);

        final Matrix4 transform = Matrix4.identity()
          ..translate(gridW / 2, gridH / 2)
          ..scale(0.7)
          ..rotateX(1.0)
          ..rotateZ(rotationZ)
          ..translate(-gridW / 2, -gridH / 2);

        final transformedGrid = Center(
          child: Transform(
            alignment: Alignment.topLeft,
            transform: transform,
            child: gridContainer,
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
    canvas.drawLine(Offset(0, 0), Offset(cellWidth, 0), borderPaint);
    // Left border
    canvas.drawLine(Offset(0, 0), Offset(0, cellHeight), borderPaint);
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
      ..color = Colors.white
      ..strokeWidth = 0.7;

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

    // Draw thin borders (make them more visible)
    final visibleThinPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2;

    // Draw major grid lines (make them bolder)
    final bolderThickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5.0;

    // Draw thin borders
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
        // Top (only for first row, but skip if outline will cover it)
        if (row != 0) {
          canvas.drawLine(Offset(x, y), Offset(x + w, y), visibleThinPaint);
        }
        // Left (only for first column, but skip if outline will cover it)
        if (col != 0) {
          canvas.drawLine(Offset(x, y), Offset(x, y + h), visibleThinPaint);
        }
        // Bottom (only for last row, but skip if outline will cover it)
        if (row != rows - 1) {
          canvas.drawLine(Offset(x, y + h), Offset(x + w, y + h), visibleThinPaint);
        }
        // Right (only for last column, but skip if outline will cover it)
        if (col != cols - 1) {
          canvas.drawLine(Offset(x + w, y), Offset(x + w, y + h), visibleThinPaint);
        }
      }
    }

    // Draw major grid lines
    // Horizontal
    for (int row = 0; row <= rows; row++) {
      if (row % 12 == 0) {
        double y = row * cellInchSize;
        double w = cellInchSize * (cols - 1) + (lastColInches > 0 ? cellInchSize * lastColInches : cellInchSize);
        if (row == rows && lastRowInches > 0) y = (rows - 1) * cellInchSize + cellInchSize * lastRowInches;
        canvas.drawLine(Offset(0, y), Offset(w, y), bolderThickPaint);
      }
    }
    // Vertical
    for (int col = 0; col <= cols; col++) {
      if (col % 12 == 0) {
        double x = col * cellInchSize;
        double h = cellInchSize * (rows - 1) + (lastRowInches > 0 ? cellInchSize * lastRowInches : cellInchSize);
        if (col == cols && lastColInches > 0) x = (cols - 1) * cellInchSize + cellInchSize * lastColInches;
        canvas.drawLine(Offset(x, 0), Offset(x, h), bolderThickPaint);
      }
    }

    // Draw a single outline around the entire grid
    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
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