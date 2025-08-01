import 'package:flutter/material.dart';

class ObjectItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onDragStarted;

  const ObjectItem({
    super.key,
    required this.label,
    required this.icon,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable(
              data: {'type': label, 'icon': icon},
              feedback: Icon(icon, size: 28, color: Colors.red),
              childWhenDragging: Icon(icon, size: 28, color: Colors.grey.shade300),
              onDragStarted: () {
            
                if (onDragStarted != null) onDragStarted!();
              },
              child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  static Map<String, int> getObjectDimensions(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        return {'width': 80, 'height': 60};
      case 'desk':
        return {'width': 48, 'height': 24};
      case 'door':
      case 'window':
        return {'width': 0, 'height': 0};
      default:
        return {'width': 1, 'height': 1};
    }
  }

  /// Returns a polygon (list of points) for the object's shape, origin at (0,0)
  static List<Offset> getObjectPolygon(String type) {
    switch (type.toLowerCase()) {
      case 'bed':
        // Rectangle: (0,0), (width,0), (width,height), (0,height)
        final dims = getObjectDimensions(type);
        return [
          const Offset(0, 0),
          Offset(dims['width']!.toDouble(), 0),
          Offset(dims['width']!.toDouble(), dims['height']!.toDouble()),
          Offset(0, dims['height']!.toDouble()),
        ];
      case 'desk':
        final dims = getObjectDimensions(type);
        return [
          const Offset(0, 0),
          Offset(dims['width']!.toDouble(), 0),
          Offset(dims['width']!.toDouble(), dims['height']!.toDouble()),
          Offset(0, dims['height']!.toDouble()),
        ];
      case 'door':
      case 'window':
        return [const Offset(0, 0)];
      default:
        return [
          const Offset(0, 0),
          const Offset(1, 0),
          const Offset(1, 1),
          const Offset(0, 1),
        ];
    }
  }
} 