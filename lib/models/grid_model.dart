class Grid {
  final int length;
  final int width;

  const Grid({
    required this.length,
    required this.width,
  });

  int get totalCells => length * width;

  @override
  String toString() {
    return 'Grid(length: $length, width: $width)';
  }
} 