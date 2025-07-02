import 'package:flutter/material.dart';

class AppConstants {
  // App Colors
  // static const Color primaryColor = Colors.blue;
  // static const Color secondaryColor = Colors.blueAccent;
static const Color bgColor = Color.fromARGB(255, 255, 186, 215);

  // App Text
  static const String appTitle = 'Feng Shui Plotter';
  static const String lengthLabel = 'Length (inches)';
  static const String widthLabel = 'Width (inches)';
  static const String createGridButton = 'Create Grid';
  static const String enterLengthError = 'Enter length';
  static const String enterWidthError = 'Enter width';
  static const String positiveIntegerError = 'Enter a positive number';

  // Spacing
  static const double defaultPadding = 16.0;
  static const double defaultSpacing = 24.0;
  static const double gridCellMargin = 2.0;

  // Border Widths
  static const double thinBorderWidth = 0.5;
  static const double thickBorderWidth = 1.5;

  // Validation
  static const int minGridSize = 1;
  static const int maxGridSize = 50;

  // Grid style constants
  static const double gridInchDividerOpacity = 0.5;
  static const double gridInchDividerWidth = 0.7;
  static const double gridMajorLineWidth = 5.0;
  static const double gridOutlineWidth = 3.0;

  // Main grid pink color (for outline and foot dividers)
  static const Color gridPink = bgColor;

  // Helper for semi-transparent inch divider color
  static Color inchDividerColor(Color base) => base.withAlpha((gridInchDividerOpacity * 255).round());
} 