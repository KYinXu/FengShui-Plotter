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
              feedback: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              childWhenDragging: Icon(icon, size: 28, color: Colors.grey.shade300),
              onDragStarted: onDragStarted,
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
} 