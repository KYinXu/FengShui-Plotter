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

  @override
  Widget build(BuildContext context) {
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