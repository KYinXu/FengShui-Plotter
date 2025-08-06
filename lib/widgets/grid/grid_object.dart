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
    // Get boundary configuration for proper styling
    final config = BoundaryRegistry.getConfig(boundary.type);
    final color = config?.color ?? (boundary.type == 'door' ? Colors.orange : Colors.blue);
    final thickness = config?.thickness ?? 3.0;
    
    // Use fixed pixel thickness instead of scaling with cellInchSize
    final fixedThickness = 8.0; // Fixed pixel thickness for consistent appearance
    
    // Calculate position and size using span information
    double left, top, width, height;
    
    switch (boundary.side) {
      case 'top':
        left = boundary.col * cellInchSize;
        top = 0;
        width = boundary.span * cellInchSize; // Span the full width
        height = fixedThickness; // Fixed pixel thickness
        break;
      case 'bottom':
        left = boundary.col * cellInchSize;
        top = (boundary.row * cellInchSize) - (fixedThickness / 2); // Center on the edge
        width = boundary.span * cellInchSize; // Span the full width
        height = fixedThickness; // Fixed pixel thickness
        break;
      case 'left':
        left = 0;
        top = boundary.row * cellInchSize;
        width = fixedThickness; // Fixed pixel thickness
        height = boundary.span * cellInchSize; // Span the full height
        break;
      case 'right':
        left = (boundary.col * cellInchSize) - (fixedThickness / 2); // Center on the edge
        top = boundary.row * cellInchSize;
        width = fixedThickness; // Fixed pixel thickness
        height = boundary.span * cellInchSize; // Span the full height
        break;
      default:
        left = boundary.col * cellInchSize;
        top = boundary.row * cellInchSize;
        width = cellInchSize;
        height = cellInchSize;
    }
    
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: 2,
          ),
          shape: BoxShape.rectangle,
          color: color.withValues(alpha: 0.3),
        ),
        child: Center(
          child: Icon(
            boundary.icon,
            size: min(width, height) * 0.8,
            color: color,
          ),
        ),
      ),
    );
  }
} 