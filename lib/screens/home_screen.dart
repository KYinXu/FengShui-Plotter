import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import '../services/auto_placer_service.dart';
import '../services/feng_shui_scoring_service.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/feng_shui_score_bar.dart';
import '../widgets/grid/grid_widget.dart';
import '../widgets/grid_input_form.dart';
import '../widgets/objects/object_palette.dart';
import '../widgets/objects/object_item.dart';
import '../widgets/rotation_control_widget.dart';
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
  double? _currentFengShuiScore;
  String? _currentScoreMessage;

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
      _placedObjects = [];
      _boundaries = [];
      _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
      _currentFengShuiScore = null;
    });
    
    // Calculate initial Feng Shui score (will be null for empty grid)
    _calculateCurrentFengShuiScore();
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
      
      // Calculate Feng Shui score for current layout
      _calculateCurrentFengShuiScore();
    });
  }

  void _calculateCurrentFengShuiScore() async {
    // Use live scoring service for real-time Feng Shui calculation
    if (_currentGrid == null || (_placedObjects.isEmpty && _boundaries.isEmpty)) {
      setState(() {
        _currentFengShuiScore = null;
        _currentScoreMessage = null;
      });
      return;
    }

    try {
      // Test server connection first
      final serverConnected = await FengShuiScoringService.testServerConnection();
      if (!serverConnected) {
        print('WARNING: Python server is not running!');
        print('Please start the server with: cd scripts && python run_server.py');
        setState(() {
          _currentFengShuiScore = 0.0;
          _currentScoreMessage = 'Server not running';
        });
        return;
      }

      // Convert placed objects to the format expected by the Python service
      final placements = <Map<String, dynamic>>[];
      
      // Add furniture objects
      for (final obj in _placedObjects) {
        placements.add({
          'type': obj.type,
          'x': obj.col,
          'y': obj.row,
        });
      }
      
      // Add boundary objects (doors and windows)
      for (final boundary in _boundaries) {
        placements.add({
          'type': boundary.type,
          'x': boundary.col,
          'y': boundary.row,
        });
      }

      final gridWidth = _currentGrid!.widthInches.floor();
      final gridHeight = _currentGrid!.lengthInches.floor();

      final result = await FengShuiScoringService.calculateLiveScore(
        placements: placements,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
      );

      setState(() {
        _currentFengShuiScore = result['score']?.toDouble() ?? 0.0;
        _currentScoreMessage = result['message'];
      });

      // Print score breakdown for debugging
      if (result['breakdown'] != null) {
        print('=== LIVE SCORE BREAKDOWN ===');
        print('Total Score: ${result['score']}');
        print('Bagua Scores: ${result['breakdown']['bagua_scores']}');
        print('Command Position: ${result['breakdown']['command_position']}');
        print('Chi Flow: ${result['breakdown']['chi_flow']}');
        print('Layout Bonus: ${result['breakdown']['layout_bonus']}');
        print('Wall Bonuses: ${result['breakdown']['wall_bonuses']}');
        print('Feng Shui Penalties: ${result['breakdown']['feng_shui_penalties']}');
        print('Door Blocked: ${result['breakdown']['door_blocked']}');
        print('Furniture Overlap: ${result['breakdown']['furniture_overlap']}');
        print('Message: ${result['message']}');
        if (result['recommendations'] != null) {
          print('Recommendations: ${result['recommendations']}');
        }
        print('===========================');
      }

    } catch (e) {
      print('Error calculating live score: $e');
      // Fallback to a simple score if the service is unavailable
      setState(() {
        _currentFengShuiScore = _placedObjects.length * 10.0;
        _currentScoreMessage = 'Error calculating score';
      });
    }
  }


  void _handleAddBoundary(GridBoundary boundary) {
    setState(() {
      if (!_boundaries.contains(boundary)) {
        _boundaries.add(boundary);
        _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
        _calculateCurrentFengShuiScore();
      }
    });
  }

  void _handleRemoveBoundary(GridBoundary boundary) {
    setState(() {
      _boundaries.remove(boundary);
      _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
      _calculateCurrentFengShuiScore();
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Auto Place'),
                          onPressed: _isAutoPlacing
                              ? null
                              : () async {
                                  setState(() => _isAutoPlacing = true);
                                  try {
                                    // Prepare grid data for the Python service (use actual inch values)
                                    final gridData = {
                                      'grid_width': _currentGrid!.widthInches.floor(),
                                      'grid_height': _currentGrid!.lengthInches.floor(),
                                    };
                                    final response = await AutoPlacerService.getPlacements(gridData);
                                    
                                    setState(() {
                                      // Clear the grid first
                                      _placedObjects = [];
                                      _boundaries = [];
                                      
                                      // Place new objects and boundaries
                                      final placements = response['placements'] as List<dynamic>;
                                      
                                      for (final p in placements) {
                                        final placement = p as Map<String, dynamic>;
                                        final type = placement['type'] ?? 'Unknown';
                                        final x = (placement['x'] ?? 0) as int;
                                        final y = (placement['y'] ?? 0) as int;
                                        
                                        if (ObjectConfig.isBoundary(type)) {
                                          // Place as boundary with proper span and side calculation
                                          final boundaryConfig = BoundaryRegistry.getConfig(type);
                                          final span = boundaryConfig?.length.round() ?? 30; // Use actual inch value
                                          
                                          // Determine side based on position
                                          String side;
                                          if (x == 0) side = 'left';
                                          else if (x == _currentGrid!.widthInches.floor() - 1) side = 'right';
                                          else if (y == 0) side = 'top';
                                          else if (y == _currentGrid!.lengthInches.floor() - 1) side = 'bottom';
                                          else side = 'right'; // Fallback
                                          
                                          final boundary = GridBoundary(
                                            type: type,
                                            row: y,
                                            col: x,
                                            side: side,
                                            icon: ObjectConfig.getIcon(type),
                                            span: span,
                                          );
                                          _boundaries.add(boundary);
                                        } else {
                                          // Place as regular object
                                          final obj = GridObject(
                                            type: type,
                                            row: y,
                                            col: x,
                                            icon: ObjectConfig.getIcon(type),
                                          );
                                          _placedObjects.add(obj);
                                        }
                                      }
                                      
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
                                    
                                    // Calculate Feng Shui score for the new layout
                                    _calculateCurrentFengShuiScore();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Auto placement failed: $e')),
                                    );
                                  } finally {
                                    setState(() => _isAutoPlacing = false);
                                  }
                                },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.psychology),
                          label: const Text('Feng Shui'),
                          onPressed: _isAutoPlacing
                              ? null
                              : () async {
                                  setState(() => _isAutoPlacing = true);
                                  try {
                                    // Prepare grid data for the Feng Shui optimizer
                                    final gridData = {
                                      'grid_width': _currentGrid!.widthInches.floor(),
                                      'grid_height': _currentGrid!.lengthInches.floor(),
                                    };
                                    
                                    // Call Feng Shui optimizer
                                    final response = await AutoPlacerService.getFengShuiOptimizedPlacements(
                                      gridData,
                                      objects: ['bed', 'desk', 'door', 'window'],
                                    );
                                    
                                    setState(() {
                                      // Clear the grid first
                                      _placedObjects = [];
                                      _boundaries = [];
                                      
                                      // Place optimized objects and boundaries
                                      final placements = response['placements'] as List<dynamic>;
                                      
                                      for (final p in placements) {
                                        final placement = p as Map<String, dynamic>;
                                        final type = placement['type'] ?? 'Unknown';
                                        final x = (placement['x'] ?? 0) as int;
                                        final y = (placement['y'] ?? 0) as int;
                                        
                                        if (ObjectConfig.isBoundary(type)) {
                                          // Place as boundary with proper span and side calculation
                                          final boundaryConfig = BoundaryRegistry.getConfig(type);
                                          final span = boundaryConfig?.length.round() ?? 30;
                                          
                                          // Determine side based on position
                                          String side;
                                          if (x == 0) side = 'left';
                                          else if (x == _currentGrid!.widthInches.floor() - 1) side = 'right';
                                          else if (y == 0) side = 'top';
                                          else if (y == _currentGrid!.lengthInches.floor() - 1) side = 'bottom';
                                          else side = 'right';
                                          
                                          final boundary = GridBoundary(
                                            type: type,
                                            row: y,
                                            col: x,
                                            side: side,
                                            icon: ObjectConfig.getIcon(type),
                                            span: span,
                                          );
                                          _boundaries.add(boundary);
                                        } else {
                                          // Place as regular object
                                          final obj = GridObject(
                                            type: type,
                                            row: y,
                                            col: x,
                                            icon: ObjectConfig.getIcon(type),
                                          );
                                          _placedObjects.add(obj);
                                        }
                                      }
                                      
                                      // Print Feng Shui analysis
                                      final fengShuiScore = response['feng_shui_score'] as double?;
                                      final analysis = response['analysis'] as Map<String, dynamic>?;
                                      
                                      print('=== FENG SHUI OPTIMIZATION COMPLETED ===');
                                      print('Grid Dimensions: ${_currentGrid!.widthInches.floor()}x${_currentGrid!.lengthInches.floor()}');
                                      print('Feng Shui Score: ${fengShuiScore?.toStringAsFixed(2) ?? 'N/A'}');
                                      
                                      if (analysis != null) {
                                        print('');
                                        print('FENG SHUI ANALYSIS:');
                                        print('  Total Score: ${analysis['total_score']?.toStringAsFixed(2) ?? 'N/A'}');
                                        print('  Command Position Score: ${analysis['energy_flow']?['command_position_score']?.toStringAsFixed(2) ?? 'N/A'}');
                                        print('  Chi Flow Score: ${analysis['energy_flow']?['chi_flow_score']?.toStringAsFixed(2) ?? 'N/A'}');
                                        
                                        final recommendations = analysis['recommendations'] as List<dynamic>?;
                                        if (recommendations != null && recommendations.isNotEmpty) {
                                          print('');
                                          print('RECOMMENDATIONS:');
                                          for (final rec in recommendations) {
                                            print('  - $rec');
                                          }
                                        }
                                      }
                                      
                                      print('');
                                      print('OPTIMIZED PLACEMENTS:');
                                      for (int i = 0; i < _placedObjects.length; i++) {
                                        final obj = _placedObjects[i];
                                        print('${i + 1}. ${obj.type.toUpperCase()}: Position (${obj.col}, ${obj.row})');
                                      }
                                      for (int i = 0; i < _boundaries.length; i++) {
                                        final boundary = _boundaries[i];
                                        print('${i + 1}. ${boundary.type.toUpperCase()}: Position (${boundary.col}, ${boundary.row}) - Side: ${boundary.side}');
                                      }
                                      print('=== TOTAL OBJECTS: ${_placedObjects.length} | TOTAL BOUNDARIES: ${_boundaries.length} ===');
                                    });
                                    
                                    // Calculate Feng Shui score for the optimized layout
                                    _calculateCurrentFengShuiScore();
                                    
                                    // Show success message with Feng Shui score
                                    final fengShuiScore = response['feng_shui_score'] as double?;
                                    if (fengShuiScore != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Feng Shui optimization completed! Score: ${fengShuiScore.toStringAsFixed(2)}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Feng Shui optimization failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } finally {
                                    setState(() => _isAutoPlacing = false);
                                  }
                                },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Grid'),
                          onPressed: () {
                            setState(() {
                              _placedObjects = [];
                              _boundaries = [];
                              _currentFengShuiScore = null;
                              _gridWidgetKey = UniqueKey(); // Force GridWidget to rebuild
                            });
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ToggleButtons(
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
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.category, size: 16),
                                    SizedBox(width: 4),
                                    Text('Object', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.border_outer, size: 16),
                                    SizedBox(width: 4),
                                    Text('Border', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                      Container(
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
                          fengShuiScore: _currentFengShuiScore,
                          fengShuiMessage: _currentScoreMessage,
                        ),
                      ),
                      if (_isAutoPlacing)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Optimizing layout...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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