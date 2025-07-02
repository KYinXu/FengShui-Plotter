import 'package:feng_shui_plotter/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import '../widgets/grid_input_form.dart';
import '../widgets/grid_widget.dart';
import 'package:flutter/gestures.dart';
import '../widgets/object_palette.dart';

const int kMiddleMouseButton = 0x04;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Grid? _currentGrid;
  double _rotationZ = -0.7; // Initial Y rotation for the grid
  bool _isMiddleMouseDown = false;
  double _lastPointerX = 0.0;

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
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
                  child: Stack(
                    children: [
                      Listener(
                        onPointerDown: (event) {
                          if (event.kind == PointerDeviceKind.mouse && event.buttons == kMiddleMouseButton) {
                            _isMiddleMouseDown = true;
                            _lastPointerX = event.position.dx;
                          }
                        },
                        onPointerMove: (event) {
                          if (_isMiddleMouseDown) {
                            final dx = event.position.dx - _lastPointerX;
                            _lastPointerX = event.position.dx;
                            setState(() {
                              _rotationZ = _rotationZ + dx * 0.01;
                              if (_rotationZ < -1.5) _rotationZ = -1.5;
                              if (_rotationZ > 1.5) _rotationZ = 1.5;
                            });
                          }
                        },
                        onPointerUp: (event) {
                          if (event.kind == PointerDeviceKind.mouse && event.buttons == 0) {
                            _isMiddleMouseDown = false;
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: GridWidget(grid: _currentGrid!, rotationZ: _rotationZ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: 'Reset Rotation',
                            onPressed: () {
                              setState(() {
                                _rotationZ = -0.7;
                                if (_rotationZ < -1.5) _rotationZ = -1.5;
                                if (_rotationZ > 1.5) _rotationZ = 1.5;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const Expanded(child: SizedBox()),
            if (_currentGrid != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.rotate_left),
                    Expanded(
                      child: Slider(
                        min: -1.5,
                        max: 1.5,
                        value: _rotationZ,
                        onChanged: (value) {
                          setState(() {
                            _rotationZ = value;
                          });
                        },
                      ),
                    ),
                    const Icon(Icons.rotate_right),
                  ],
                ),
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