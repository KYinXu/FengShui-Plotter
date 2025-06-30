import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'constants/app_constants.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    center: true
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  final Color seed = const Color.fromARGB(255, 248, 207, 226);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: seed);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appTitle,
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
          scaffoldBackgroundColor: AppConstants.bgColor,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
