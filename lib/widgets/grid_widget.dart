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
    return Expanded(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: grid.width,
          childAspectRatio: 1.0, // Square cells
        ),
        itemCount: grid.totalCells,
        itemBuilder: (context, index) {
          int row = index ~/ grid.width;
          int col = index % grid.width;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppConstants.gridBorderColor,
                width: 1.0,
              ),
              color: AppConstants.gridCellColor,
            ),
            child: Center(
              child: Text(
                '(${row + 1}, ${col + 1})',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
} 