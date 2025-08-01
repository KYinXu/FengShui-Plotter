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
          color: Colors.white.withValues(alpha: 0.8),
        ),
        child: Center(
          child: Icon(obj.icon, size: objWidth * 0.6, color: Colors.black),
        ),
      ),
    );
  }
}

class GridBoundaryWidget extends StatelessWidget {
  final GridBoundary boundary;
  final double cellInchSize;

  const GridBoundaryWidget({
    super.key,
    required this.boundary,
    required this.cellInchSize,
  });

  @override
  Widget build(BuildContext context) {
    // Use polygon geometry for rendering boundaries
    final poly = boundary.getTransformedPolygon();
    final bounds = getPolygonBounds(poly);
    final double left = bounds['minX']! * cellInchSize;
    final double top = bounds['minY']! * cellInchSize;
    final double boundaryWidth = (bounds['maxX']! - bounds['minX']!) * cellInchSize;
    final double boundaryHeight = (bounds['maxY']! - bounds['minY']!) * cellInchSize;
    
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: boundaryWidth,
        height: boundaryHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: boundary.type == 'door' ? Colors.orange : Colors.blue,
            width: 2,
          ),
          shape: BoxShape.rectangle,
          color: boundary.type == 'door' 
            ? Colors.orange.withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.3),
        ),
        child: Center(
          child: Icon(
            boundary.icon,
            size: min(boundaryWidth, boundaryHeight) * 0.8,
            color: boundary.type == 'door' ? Colors.orange : Colors.blue,
          ),
        ),
      ),
    );
  }
} 