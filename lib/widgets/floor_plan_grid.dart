import 'package:flutter/material.dart';

class FloorPlan extends StatelessWidget {
  const FloorPlan({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
// import 'package:flutter/material.dart';

// class SquareGrid extends StatelessWidget {
//   final int n;

//   const SquareGrid({super.key, required this.n});

//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         // Use the smaller of width or height to ensure a square grid
//         final double size = constraints.maxWidth < constraints.maxHeight
//             ? constraints.maxWidth
//             : constraints.maxHeight;

//         final double tileSize = size / n;

//         return Center(
//           child: SizedBox(
//             width: tileSize * n,
//             height: tileSize * n,
//             child: GridView.builder(
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: n,
//                 childAspectRatio: 1.0, // Square tiles
//               ),
//               itemCount: n * n,
//               itemBuilder: (context, index) {
//                 return Container(
//                   margin: const EdgeInsets.all(1),
//                   color: Colors.teal[100 * ((index % 8) + 1)],
//                   child: Center(child: Text('${index + 1}')),
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }
// }