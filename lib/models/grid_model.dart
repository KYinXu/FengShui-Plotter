import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GridObject {
  final String type;
  final int row;
  final int col;
  final IconData icon;

  GridObject({
    required this.type,
    required this.row,
    required this.col,
    required this.icon,
  });
}

class Grid extends Equatable {
  final double lengthInches;
  final double widthInches;
  final List<GridObject> objects;

  const Grid({
    required this.lengthInches,
    required this.widthInches,
    this.objects = const [],
  });

  Grid addObject(GridObject object) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: [...objects, object],
    );
  }

  Grid removeObject(GridObject object) {
    return Grid(
      lengthInches: lengthInches,
      widthInches: widthInches,
      objects: objects.where((o) => o != object).toList(),
    );
  }

  @override
  String toString() {
    return 'Grid(lengthInches: $lengthInches, widthInches: $widthInches)';
  }
  
  @override
  List<Object?> get props => [lengthInches, widthInches, objects];
} 