import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/app_constants.dart';
import '../models/grid_model.dart';
import '../widgets/grid_input_form.dart';
import '../widgets/grid_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Grid? _currentGrid;

  void _onGridCreated(Grid grid) {
    setState(() {
      _currentGrid = grid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          GridInputForm(onGridCreated: _onGridCreated),
          const SizedBox(height: AppConstants.defaultSpacing),
          if (_currentGrid != null) GridWidget(grid: _currentGrid!),
        ],
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
        child: Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Text(
                  AppConstants.appTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.minimize, color: Colors.white),
              onPressed: () => windowManager.minimize(),
              tooltip: 'Minimize',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => windowManager.close(),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
} 