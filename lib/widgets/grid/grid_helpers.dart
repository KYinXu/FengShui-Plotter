import 'package:flutter/material.dart';
import '../objects/object_item.dart';
import 'dart:math';

// Helper: check if two polygons intersect (simple SAT, assumes convex)
// O(n + m): where n and m are the sides of each polygon ???
// For now O(1)
bool polygonsIntersect(List<Offset> polyA, List<Offset> polyB) {
  bool separatingAxis(List<Offset> poly1, List<Offset> poly2) {
    for (int i = 0; i < poly1.length; i++) {
      final p1 = poly1[i];
      final p2 = poly1[(i + 1) % poly1.length];
      final axis = Offset(-(p2.dy - p1.dy), p2.dx - p1.dx); // perpendicular
      double minA = double.infinity, maxA = -double.infinity;
      for (final p in poly1) {
        final proj = p.dx * axis.dx + p.dy * axis.dy;
        minA = proj < minA ? proj : minA;
        maxA = proj > maxA ? proj : maxA;
      }
      double minB = double.infinity, maxB = -double.infinity;
      for (final p in poly2) {
        final proj = p.dx * axis.dx + p.dy * axis.dy;
        minB = proj < minB ? proj : minB;
        maxB = proj > maxB ? proj : maxB;
      }
      if (maxA <= minB || maxB <= minA) return false;
    }
    return true;
  }
  return separatingAxis(polyA, polyB) && separatingAxis(polyB, polyA);
}

// Helper: check if polygon is within grid bounds
// O(1)
bool polygonInBounds(List<Offset> poly, int gridW, int gridH) {
  for (final p in poly) {
    if (p.dx < 0 || p.dy < 0 || p.dx > gridW || p.dy > gridH) return false;
  }
  return true;
}

// Get the current bounding box for a given object
// INPUT: [string, int, int, int] Object's properties (type, position, rotation)
// OUTPUT: [List<Offset>] Final transformed polygon bounding object
// // O(1)
List<Offset> getTransformedPolygon(String type, int row, int col, int rotation) {
  final poly = ObjectItem.getObjectPolygon(type);
  final double angleRad = (rotation % 360) * pi / 180.0;
  final double cosA = cos(angleRad);
  final double sinA = sin(angleRad);
  return poly.map((p) {
    final double x = p.dx;
    final double y = p.dy;
    final double rx = x * cosA - y * sinA;
    final double ry = x * sinA + y * cosA;
    return Offset(rx + col, ry + row);
  }).toList();
}

// Helper: get preview grid position so the polygon is centered at the pointer
Offset getPreviewGridPosition(int col, int row, List<Offset> poly) {
  final bounds = getPolygonBounds(poly);
  double centerX = (bounds['minX']! + bounds['maxX']!) / 2;
  double centerY = (bounds['minY']! + bounds['maxY']!) / 2;
  return Offset((col - centerX).toDouble(), (row - centerY).toDouble());
}

// Helper: get centering offset (center of bounding box) for a polygon
Offset getCenteringOffset(List<Offset> poly) {
  final bounds = getPolygonBounds(poly);
  double centerX = (bounds['minX']! + bounds['maxX']!) / 2;
  double centerY = (bounds['minY']! + bounds['maxY']!) / 2;
  return Offset(centerX, centerY);
}

// Helper: get bounding box of a polygon
Map<String, double> getPolygonBounds(List<Offset> poly) {
  double minX = poly.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
  double minY = poly.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
  double maxX = poly.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
  double maxY = poly.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
  return {'minX': minX, 'minY': minY, 'maxX': maxX, 'maxY': maxY};
}

// Helper: clamp a polygon's position so it stays fully in grid bounds
Offset clampPolygonToGrid(String type, int row, int col, int rotation, int gridW, int gridH) {

  //polygon at proper position
  final poly = getTransformedPolygon(type, row, col, rotation);

  //Get bounding vars
  final bounds = getPolygonBounds(poly);

  //Check if out of bounds, and shift by a constant amount along x and y until in bounds
  int shiftX = 0, shiftY = 0;
  if (bounds['minX']! < 0) shiftX = -bounds['minX']!.ceil();
  if (bounds['maxX']! > gridW) shiftX = -(bounds['maxX']! - gridW).ceil();
  if (bounds['minY']! < 0) shiftY = -bounds['minY']!.ceil();
  if (bounds['maxY']! > gridH) shiftY = -(bounds['maxY']! - gridH).ceil();
  return Offset((col + shiftX).toDouble(), (row + shiftY).toDouble());
}
