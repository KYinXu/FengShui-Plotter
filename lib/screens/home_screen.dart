import 'package:feng_shui_plotter/widgets/confirmation_dialog.dart';
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
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: GridInputForm(onGridCreated: _onGridCreated),
          ),
          if (_currentGrid != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.defaultPadding,
                  0,
                  AppConstants.defaultPadding,
                  AppConstants.defaultPadding,
                ),
                child: GridWidget(grid: _currentGrid!),
              ),
            )
          else
            const Expanded(child: SizedBox()),
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