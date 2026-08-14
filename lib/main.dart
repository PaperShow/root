import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal apps often run in full screen, hiding system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load saved theme preferences before rendering
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(MinimalLauncherApp(themeProvider: themeProvider));
}

class MinimalLauncherApp extends StatefulWidget {
  final ThemeProvider themeProvider;

  const MinimalLauncherApp({super.key, required this.themeProvider});

  @override
  State<MinimalLauncherApp> createState() => _MinimalLauncherAppState();
}

class _MinimalLauncherAppState extends State<MinimalLauncherApp> {
  @override
  void dispose() {
    widget.themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RootL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: HomeScreen(themeProvider: widget.themeProvider),
    );
  }
}
