import 'package:flutter/material.dart';

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
          Center(
            child: Text(
              'No objects available yet',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
} 