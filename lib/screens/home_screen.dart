import 'package:feng_shui_plotter/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import '../widgets/grid_input_form.dart';
import '../widgets/grid/grid_widget.dart';
import '../widgets/objects/object_palette.dart';
import '../widgets/rotation_control_widget.dart';
import '../services/auto_placer_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Grid? _currentGrid;
  double _rotationZ = -0.7; // Initial Y rotation for the grid
  List<GridObject> _placedObjects = [];
  bool _isAutoPlacing = false;

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
      _placedObjects = [];
    });
  }

  void _handleObjectDropped(int row, int col, String type, IconData icon, [int rotation = 0]) {
    setState(() {
      final obj = GridObject(type: type, row: row, col: col, icon: icon, rotation: rotation);
      _placedObjects.add(obj);
      final poly = obj.getTransformedPolygon();
      final minX = poly.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final minY = poly.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxX = poly.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final maxY = poly.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      print('Placed object bounds: minX=$minX, minY=$minY, maxX=$maxX, maxY=$maxY');
      print('Placed objects: \\${_placedObjects.map((o) => 'type=\${o.type}, row=\${o.row}, col=\${o.col}, rot=\${o.rotation}').toList()}');
    });
  }

  void _onRotationChanged(double rotation) {
    setState(() {
      _rotationZ = rotation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const CustomTitleBar(),
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: GridInputForm(onGridCreated: _onGridCreated),
            ),
            if (_currentGrid != null) ...[
              const ObjectPalette(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto Place Objects'),
                  onPressed: () async {
                    if (_currentGrid == null) return;
                    setState(() => _isAutoPlacing = true);
                    try {
                      // Prepare grid data for the Python service
                      final gridData = {
                        'length': _currentGrid!.lengthInches,
                        'width': _currentGrid!.widthInches,
                        // Add more fields if needed
                      };
                      final placements = await AutoPlacerService.getPlacements(gridData);
                      setState(() {
                        _placedObjects = placements.map((p) => GridObject(
                          type: p['type'] ?? 'Unknown',
                          row: p['y'] ?? 0,
                          col: p['x'] ?? 0,
                          icon: Icons.auto_awesome, // Use a default icon or map type to icon
                        )).toList();
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Auto placement failed: $e')),
                      );
                    } finally {
                      setState(() => _isAutoPlacing = false);
                    }
                  },
                ),
              ),
              if (_isAutoPlacing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.defaultPadding,
                    0,
                    AppConstants.defaultPadding,
                    AppConstants.defaultPadding,
                  ),
                  child: RotationControlWidget(
                    initialRotation: -0.7,
                    onRotationChanged: _onRotationChanged,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: GridWidget(
                        grid: _currentGrid!,
                        rotationZ: _rotationZ,
                        objects: _placedObjects,
                        onObjectDropped: (row, col, type, icon, [rotation = 0]) => _handleObjectDropped(row, col, type, icon, rotation),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(child: SizedBox()),
            if (_currentGrid != null)
              RotationSlider(
                rotation: _rotationZ,
                onRotationChanged: _onRotationChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 40,
        color: Colors.transparent,
        child: Stack(
          children: [
            const Center(
              child: Text(
                AppConstants.appTitle,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Barriecito'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  alignment: Alignment.topRight,
                  icon: const Icon(Icons.minimize, color: Colors.white),
                  onPressed: () => windowManager.minimize(),
                  tooltip: 'Minimize',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    showConfirmationDialog(
                      context: context,
                      title: 'Confirm Quit',
                      content: const Text('Are you sure you want to quit?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            windowManager.close();
                          },
                          child: const Text('Yes'),
                        ),
                      ],
                    );
                  },
                  tooltip: 'Close',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 