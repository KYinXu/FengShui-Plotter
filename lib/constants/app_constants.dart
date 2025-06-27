import 'package:flutter/material.dart';

class AppConstants {
  // App Colors
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.blueAccent;
  static const Color backgroundColor = Colors.white;
  static const Color gridCellColor = Color(0xFFE3F2FD);
  static const Color gridBorderColor = Colors.grey;

  // App Text
  static const String appTitle = 'Feng Shui Plotter';
  static const String lengthLabel = 'Length (inches)';
  static const String widthLabel = 'Width (inches)';
  static const String createGridButton = 'Create Grid';
  static const String enterLengthError = 'Enter length';
  static const String enterWidthError = 'Enter width';
  static const String positiveIntegerError = 'Enter a positive integer';

  // Spacing
  static const double defaultPadding = 16.0;
  static const double defaultSpacing = 24.0;
  static const double gridCellMargin = 2.0;

  // Validation
  static const int minGridSize = 1;
  static const int maxGridSize = 50;
} 