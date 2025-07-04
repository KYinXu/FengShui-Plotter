import 'package:flutter/material.dart';
import '../models/grid_model.dart';
import 'object_item.dart';

class GridObjectWidget extends StatelessWidget {
  final GridObject obj;
  final double cellInchSize;

  const GridObjectWidget({
    Key? key,
    required this.obj,
    required this.cellInchSize,
  }) : super(key: key);

  /// Returns the total grid width in inches
  static double getTotalGridWidthInches(Grid grid) {
    return (grid.width - 1) * 12.0 +
        (grid.widthPartialPercentage > 0 ? grid.widthPartialPercentage * 12.0 : 12.0);
  }

  /// Returns the total grid length in inches
  static double getTotalGridLengthInches(Grid grid) {
    return (grid.length - 1) * 12.0 +
        (grid.lengthPartialPercentage > 0 ? grid.lengthPartialPercentage * 12.0 : 12.0);
  }

  @override
  Widget build(BuildContext context) {
    //dimensions defined here with cellInchSize
    final dims = ObjectItem.getObjectDimensions(obj.type);
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
  }
} 