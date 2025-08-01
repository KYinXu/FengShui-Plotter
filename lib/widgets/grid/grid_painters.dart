// grid_painters.dart
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/grid_model.dart';

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
    double cellWidth = size.width;
    double cellHeight = size.height;
    final backgroundPaint = Paint()..color = gridCellColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, cellWidth, cellHeight), backgroundPaint);
    final borderPaint = Paint()
      ..color = gridBorderColor
      ..strokeWidth = AppConstants.thinBorderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), Offset(cellWidth, 0), borderPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cellHeight), borderPaint);
    canvas.drawLine(Offset(0, cellHeight), Offset(cellWidth, cellHeight), borderPaint);
    canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, cellHeight), borderPaint);
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

class GridAreaPainter extends CustomPainter {
  final Grid grid;
  final double cellInchSize;
  final Color gridCellColor;
  final Color gridBorderColor;
  final Color majorGridBorderColor;
  final double gridWidth;
  final double gridHeight;
  final List<GridBoundary> boundaries;

  GridAreaPainter({
    required this.grid,
    required this.cellInchSize,
    required this.gridCellColor,
    required this.gridBorderColor,
    required this.majorGridBorderColor,
    required this.gridWidth,
    required this.gridHeight,
    required this.boundaries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inchDividerPaint = Paint()
      ..color = AppConstants.inchDividerColor(const Color(0x88D72660))
      ..strokeWidth = AppConstants.gridInchDividerWidth;
    final majorDividerPaint = Paint()
      ..color = AppConstants.gridPink
      ..strokeWidth = AppConstants.gridMajorLineWidth;
    double totalRowsInches = grid.lengthInches;
    double totalColsInches = grid.widthInches;
    int totalInchesX = totalColsInches.round();
    int totalInchesY = totalRowsInches.round();
    for (int i = 1; i < totalInchesX; i++) {
      double x = i * cellInchSize;
      if (i % 12 == 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), majorDividerPaint);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, gridHeight), inchDividerPaint);
      }
    }
    for (int i = 1; i < totalInchesY; i++) {
      double y = i * cellInchSize;
      if (i % 12 == 0) {
        canvas.drawLine(Offset(0, y), Offset(gridWidth, y), majorDividerPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(gridWidth, y), inchDividerPaint);
      }
    }
    final outlinePaint = Paint()
      ..color = AppConstants.gridPink
      ..strokeWidth = AppConstants.gridOutlineWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cellInchSize * totalColsInches, cellInchSize * totalRowsInches),
      outlinePaint,
    );
    for (final boundary in boundaries) {
      final double x = boundary.col * cellInchSize;
      final double y = boundary.row * cellInchSize;
      final double x2 = (boundary.col + 1) * cellInchSize;
      final double y2 = (boundary.row + 1) * cellInchSize;
      Paint paint;
      if (boundary.type == 'door') {
        paint = Paint()
          ..color = Colors.orange
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke;
      } else {
        paint = Paint()
          ..color = Colors.blue
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke;
      }
      if (boundary.type == 'door') {
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
        oldDelegate.gridHeight != gridHeight ||
        oldDelegate.boundaries != boundaries;
  }
}

class BoundaryPreviewPainter extends CustomPainter {
  final String type;
  final String side;
  final double x, y, x2, y2;
  BoundaryPreviewPainter({required this.type, required this.side, required this.x, required this.y, required this.x2, required this.y2});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint;
    if (type == 'door') {
      paint = Paint()
        ..color = Colors.orange // fully opaque
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
      // Draw a larger preview line centered in the preview area
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final previewLength = 80.0; // Larger preview length
      
      switch (side) {
        case 'top':
        case 'bottom':
          canvas.drawLine(
            Offset(centerX - previewLength / 2, centerY),
            Offset(centerX + previewLength / 2, centerY),
            paint
          );
          break;
        case 'left':
        case 'right':
          canvas.drawLine(
            Offset(centerX, centerY - previewLength / 2),
            Offset(centerX, centerY + previewLength / 2),
            paint
          );
          break;
      }
    } else {
      paint = Paint()
        ..color = Colors.blue // fully opaque
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;
      
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final previewLength = 80.0; // Larger preview length
      
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
      
      switch (side) {
        case 'top':
        case 'bottom':
          drawDashedLine(
            Offset(centerX - previewLength / 2, centerY),
            Offset(centerX + previewLength / 2, centerY)
          );
          break;
        case 'left':
        case 'right':
          drawDashedLine(
            Offset(centerX, centerY - previewLength / 2),
            Offset(centerX, centerY + previewLength / 2)
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoundaryPreviewPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.side != side || oldDelegate.x != x || oldDelegate.y != y || oldDelegate.x2 != x2 || oldDelegate.y2 != y2;
  }
} 