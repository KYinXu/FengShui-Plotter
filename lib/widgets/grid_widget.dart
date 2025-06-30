import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';

class GridWidget extends StatelessWidget {
  final Grid grid;

  const GridWidget({
    super.key,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridCellColor = colorScheme.surfaceVariant;
    final gridBorderColor = colorScheme.outline;
    final majorGridBorderColor = colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double gridHeight = (availableWidth / grid.width) * grid.length;

        final gridView = GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: grid.width,
            childAspectRatio: 1.0, // Square cells
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: grid.totalCells,
          itemBuilder: (context, index) {
            int row = index ~/ grid.width;
            int col = index % grid.width;

            return CustomPaint(
              painter: CellPainter(
                row: row,
                col: col,
                grid: grid,
                gridCellColor: gridCellColor,
                gridBorderColor: gridBorderColor,
                majorGridBorderColor: majorGridBorderColor,
              ),
            );
          },
        );

        final gridContainer = SizedBox(
          width: availableWidth,
          height: gridHeight,
          child: gridView,
        );

        if (gridHeight < constraints.maxHeight) {
          // If the grid is smaller than the container, center it.
          return Center(
            child: gridContainer,
          );
        }

        // If the grid is larger, make it scrollable.
        return SingleChildScrollView(
          child: gridContainer,
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
    final thinBorder = AppConstants.thinBorderWidth;
    final thickBorder = AppConstants.thickBorderWidth;
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
    canvas.drawRect(Rect.fromLTWH(0, 0, cellWidth, cellHeight), borderPaint);

    // Draw Major Grid Lines
    // Top
    if (row % 12 == 0) {
      canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), thickPaint);
    }
    // Left
    if (col % 12 == 0) {
      canvas.drawLine(const Offset(0, 0), Offset(0, size.height), thickPaint);
    }
    // Bottom
    if ((row + 1) % 12 == 0) {
      canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), thickPaint);
    }
    // Right
    if ((col + 1) % 12 == 0) {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), thickPaint);
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