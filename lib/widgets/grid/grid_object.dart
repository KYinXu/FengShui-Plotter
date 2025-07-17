import 'package:flutter/material.dart';
import '../../models/grid_model.dart';
import '../objects/object_item.dart';
import 'dart:math';

class GridObjectWidget extends StatelessWidget {
  final GridObject obj;
  final double cellInchSize;

  const GridObjectWidget({
    super.key,
    required this.obj,
    required this.cellInchSize,
  });


  @override
  Widget build(BuildContext context) {
    // Use polygon geometry for rendering
    final poly = obj.getTransformedPolygon();
    final minX = poly.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final minY = poly.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxX = poly.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final maxY = poly.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final double left = minX * cellInchSize;
    final double top = minY * cellInchSize;
    final double objWidth = (maxX - minX) * cellInchSize;
    final double objHeight = (maxY - minY) * cellInchSize;
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: objWidth,
        height: objHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange, width: 3),
          shape: BoxShape.rectangle,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        child: Center(
          child: Icon(obj.icon, size: objWidth * 0.6, color: Colors.black),
        ),
      ),
    );
  }
} 