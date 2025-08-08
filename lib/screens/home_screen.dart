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
import '../widgets/objects/object_item.dart';
import '../constants/object_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Grid? _currentGrid;
  List<GridObject> _placedObjects = [];
  List<GridBoundary> _boundaries = [];
  bool _isAutoPlacing = false;
  Key _gridWidgetKey = UniqueKey();
  // Mode: 'object' or 'border'
  String _mode = 'object';
  // In border mode, track selected boundary type
  String _selectedBoundaryType = 'door';

  // Boundary mode: 'none', 'door', 'window'
  String _boundaryMode = 'none';

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
      _placedObjects = [];
      _boundaries = [];
      _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
    });
  }

  void _handleObjectDropped(int row, int col, String type, IconData icon, [int rotation = 0]) {
    // Prevent placement if object is larger than grid
    final gridW = _currentGrid?.widthInches.floor() ?? 0;
    final gridH = _currentGrid?.lengthInches.floor() ?? 0;
    final dims = ObjectItem.getObjectDimensions(type);
    final objW = dims['width'] ?? 1;
    final objH = dims['height'] ?? 1;
    if (objW > gridW || objH > gridH) return;
    setState(() {
      final obj = GridObject(type: type, row: row, col: col, icon: icon, rotation: rotation);
      _placedObjects.add(obj);
      final poly = obj.getTransformedPolygon();
      final minX = poly.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final minY = poly.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxX = poly.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final maxY = poly.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    });
  }



  void _handleAddBoundary(GridBoundary boundary) {
    setState(() {
      if (!_boundaries.contains(boundary)) {
        _boundaries.add(boundary);
        _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
      }
    });
  }

  void _handleRemoveBoundary(GridBoundary boundary) {
    setState(() {
      _boundaries.remove(boundary);
      _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
    });
  }

  void _handleBoundaryTypeSelected(String type) {
    setState(() {
      _selectedBoundaryType = type;
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
              ObjectPalette(
                mode: _mode,
                selectedBoundaryType: _selectedBoundaryType,
                onBoundaryTypeSelected: _handleBoundaryTypeSelected,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Auto Place Objects'),
                      onPressed: () async {
                        if (_currentGrid == null) return;
                        setState(() => _isAutoPlacing = true);
                        try {
                          // Prepare grid data for the Python service
                          final gridData = {
                            'grid_width': _currentGrid!.widthInches.floor(),
                            'grid_height': _currentGrid!.lengthInches.floor(),
                          };
                          final response = await AutoPlacerService.getPlacements(gridData);
                          
                          setState(() {
                            // Clear the grid first
                            _placedObjects = [];
                            _boundaries = [];
                            
                            // Place new objects
                            final placements = response['placements'] as List<dynamic>;
                            _placedObjects = placements.map((p) {
                              final placement = p as Map<String, dynamic>;
                              return GridObject(
                                type: placement['type'] ?? 'Unknown',
                                row: (placement['y'] ?? 0) as int,
                                col: (placement['x'] ?? 0) as int,
                                icon: ObjectConfig.getIcon(placement['type'] ?? 'Unknown'),
                              );
                            }).toList();
                            
                            // Print all placed objects and boundaries
                            print('=== AUTO PLACEMENT COMPLETED ===');
                            print('Grid Dimensions: ${_currentGrid!.widthInches.floor()}x${_currentGrid!.lengthInches.floor()}');
                            print('');
                            print('PLACED OBJECTS:');
                            for (int i = 0; i < _placedObjects.length; i++) {
                              final obj = _placedObjects[i];
                              print('${i + 1}. ${obj.type.toUpperCase()}: Position (${obj.col}, ${obj.row})');
                            }
                            print('');
                            print('PLACED BOUNDARIES:');
                            for (int i = 0; i < _boundaries.length; i++) {
                              final boundary = _boundaries[i];
                              print('${i + 1}. ${boundary.type.toUpperCase()}: Position (${boundary.col}, ${boundary.row}) - Side: ${boundary.side}');
                            }
                            print('=== TOTAL OBJECTS: ${_placedObjects.length} | TOTAL BOUNDARIES: ${_boundaries.length} ===');
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
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Grid'),
                      onPressed: () {
                        setState(() {
                          _placedObjects = [];
                          _boundaries = [];
                          _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    ToggleButtons(
                      isSelected: [
                        _mode == 'object',
                        _mode == 'border',
                      ],
                      onPressed: (int index) {
                        setState(() {
                          _mode = index == 0 ? 'object' : 'border';
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(Icons.category),
                              SizedBox(width: 6),
                              Text('Object'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(Icons.border_outer),
                              SizedBox(width: 6),
                              Text('Border'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: GridWidget(
                      key: _gridWidgetKey,
                      grid: _currentGrid!.copyWith(objects: _placedObjects, boundaries: _boundaries),
                      onObjectDropped: (row, col, type, icon, [rotation = 0]) => _handleObjectDropped(row, col, type, icon, rotation),
                      boundaryMode: _mode == 'object' ? 'none' : _selectedBoundaryType,
                      onAddBoundary: _handleAddBoundary,
                      onRemoveBoundary: _handleRemoveBoundary,
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(child: SizedBox()),

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