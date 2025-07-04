import 'package:feng_shui_plotter/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import '../widgets/grid_input_form.dart';
import '../widgets/grid_widget.dart';
import '../widgets/object_palette.dart';
import '../widgets/rotation_control_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Grid? _currentGrid;
  double _rotationZ = -0.7; // Initial Y rotation for the grid
  List<GridObject> _placedObjects = [];

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
      _placedObjects = [];
    });
  }

  void _handleObjectDropped(int row, int col, String type, IconData icon) {
    setState(() {
      _placedObjects.add(GridObject(type: type, row: row, col: col, icon: icon));
      print('Placed objects: \\${_placedObjects.map((o) => 'type=\\${o.type}, row=\\${o.row}, col=\\${o.col}').toList()}');
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
                        onObjectDropped: _handleObjectDropped,
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