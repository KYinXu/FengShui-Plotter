import 'package:equatable/equatable.dart';

class Grid extends Equatable {
  final double lengthInches;
  final double widthInches;

  const Grid({
    required this.lengthInches,
    required this.widthInches,
  });

  // Calculate grid dimensions based on 12-inch increments
  int get length => (lengthInches / 12).ceil();
  int get width => (widthInches / 12).ceil();
  int get totalCells => length * width;

  // Calculate partial percentages for the last cells in each dimension
  double get lengthPartialPercentage => (lengthInches % 12) / 12;
  double get widthPartialPercentage => (widthInches % 12) / 12;

  // Check if a cell is partial (last cell in its row/column)
  bool isPartialCell(int row, int col) {
    bool isLastRow = row == length - 1;
    bool isLastCol = col == width - 1;
    
    // Check if there are partial inches in this dimension
    bool hasLengthPartial = lengthPartialPercentage > 0;
    bool hasWidthPartial = widthPartialPercentage > 0;
    
    return (isLastRow && hasLengthPartial) || (isLastCol && hasWidthPartial);
  }

  // Get the partial percentage for a specific cell
  double getPartialPercentage(int row, int col) {
    if (!isPartialCell(row, col)) return 1.0;
    
    bool isLastRow = row == length - 1;
    bool isLastCol = col == width - 1;
    
    if (isLastRow && isLastCol) {
      // Corner cell - return the smaller of the two partials
      return (lengthPartialPercentage * widthPartialPercentage);
    } else if (isLastRow) {
      return lengthPartialPercentage;
    } else if (isLastCol) {
      return widthPartialPercentage;
    }
    
    return 1.0;
  }

  @override
  String toString() {
    return 'Grid(lengthInches: $lengthInches, widthInches: $widthInches)';
  }
  
  @override
  List<Object?> get props => [lengthInches, widthInches];
} 