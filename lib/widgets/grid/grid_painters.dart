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
    } else {
      paint = Paint()
        ..color = Colors.blue // fully opaque
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;
    }
    
    // Use the actual calculated coordinates instead of fixed preview length
    final startX = x;
    final startY = y;
    final endX = x2;
    final endY = y2;
    
    // Calculate the actual size of the preview area
    final previewWidth = endX - startX;
    final previewHeight = endY - startY;
    
    // Draw the preview using the actual calculated size
    if (type == 'door') {
      // Solid line for doors
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint
      );
    } else {
      // Dashed line for windows
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
      
      drawDashedLine(Offset(startX, startY), Offset(endX, endY));
    }
  }

  @override
  bool shouldRepaint(covariant BoundaryPreviewPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.side != side || oldDelegate.x != x || oldDelegate.y != y || oldDelegate.x2 != x2 || oldDelegate.y2 != y2;
  }
} 