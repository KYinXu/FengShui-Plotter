import 'package:flutter/material.dart';
import 'object_item.dart';

class ObjectPalette extends StatelessWidget {
  const ObjectPalette({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          ObjectItem(
            label: 'Bed',
            icon: Icons.bed,
          ),
          ObjectItem(
            label: 'Desk',
            icon: Icons.event_seat, // Chose a desk-like icon
          ),
        ],
      ),
    );
  }
} 