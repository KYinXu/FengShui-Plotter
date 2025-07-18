import 'package:flutter/material.dart';
import 'object_item.dart';

class ObjectPalette extends StatelessWidget {
  final String mode; // 'object' or 'border'
  final String selectedBoundaryType; // 'door' or 'window'
  final void Function(String type)? onBoundaryTypeSelected;

  const ObjectPalette({
    super.key,
    this.mode = 'object',
    this.selectedBoundaryType = 'door',
    this.onBoundaryTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == 'border') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Draggable(
            data: {'type': 'door', 'icon': Icons.door_front_door},
            feedback: Icon(Icons.door_front_door, size: 32, color: Colors.brown),
            childWhenDragging: Icon(Icons.door_front_door, size: 32, color: Colors.brown[100]),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown, width: 2),
              ),
              child: Column(
                children: const [
                  Icon(Icons.door_front_door, size: 32, color: Colors.brown),
                  SizedBox(height: 4),
                  Text('Door'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Draggable(
            data: {'type': 'window', 'icon': Icons.window},
            feedback: Icon(Icons.window, size: 32, color: Colors.blue),
            childWhenDragging: Icon(Icons.window, size: 32, color: Colors.blue[100]),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                children: const [
                  Icon(Icons.window, size: 32, color: Colors.blue),
                  SizedBox(height: 4),
                  Text('Window'),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Object mode: show bed and desk
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          ObjectItem(label: 'Bed', icon: Icons.bed),
          SizedBox(width: 16),
          ObjectItem(label: 'Desk', icon: Icons.chair),
        ],
      );
    }
  }
} 