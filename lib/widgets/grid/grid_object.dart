import 'package:flutter/material.dart';
import '../../models/grid_model.dart';
import '../objects/object_item.dart';
import 'dart:math';
import 'grid_helpers.dart';

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
    final bounds = getPolygonBounds(poly);
    final double left = bounds['minX']! * cellInchSize;
    final double top = bounds['minY']! * cellInchSize;
    final double objWidth = (bounds['maxX']! - bounds['minX']!) * cellInchSize;
    final double objHeight = (bounds['maxY']! - bounds['minY']!) * cellInchSize;
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
        child: Center(
          child: Icon(obj.icon, size: objWidth * 0.6, color: Colors.black),
        ),
      ),
    );
  }
} 