import 'package:flutter/material.dart';
import '../objects/object_item.dart';
import 'dart:math';

// Helper: check if two polygons intersect (simple SAT, assumes convex)
bool polygonsIntersect(List<Offset> polyA, List<Offset> polyB) {
  bool _separatingAxis(List<Offset> poly1, List<Offset> poly2) {
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
      if (maxA < minB || maxB < minA) return false;
    }
    return true;
  }
  return _separatingAxis(polyA, polyB) && _separatingAxis(polyB, polyA);
}

// Helper: check if polygon is within grid bounds
bool polygonInBounds(List<Offset> poly, int gridW, int gridH) {
  for (final p in poly) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= gridW || p.dy >= gridH) return false;
  }
  return true;
}

// Helper to get transformed polygon for preview
List<Offset> getTransformedPolygon(String type, int row, int col, int rotation) {
  final poly = ObjectItem.getObjectPolygon(type);
  final double angleRad = (rotation % 360) * 3.1415926535897932 / 180.0;
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
