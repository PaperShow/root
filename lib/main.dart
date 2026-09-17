import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/expense_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/super_app_hub_screen.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full screen, hiding system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  // Initialize habit provider
  final habitProvider = HabitProvider();
  await habitProvider.init();

  // Initialize expense provider
  final expenseProvider = ExpenseProvider();
  await expenseProvider.init();

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenWelcome = prefs.getBool('has_seen_welcome_screen') ?? false;

  runApp(
    RootSuperApp(
      themeProvider: themeProvider,
      habitProvider: habitProvider,
      expenseProvider: expenseProvider,
      hasSeenWelcome: hasSeenWelcome,
    ),
  );
}

class RootSuperApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final HabitProvider habitProvider;
  final ExpenseProvider expenseProvider;
  final bool hasSeenWelcome;

  const RootSuperApp({
    super.key,
    required this.themeProvider,
    required this.habitProvider,
    required this.expenseProvider,
    required this.hasSeenWelcome,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<HabitProvider>.value(value: habitProvider),
        ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return MaterialApp(
            title: 'RootL',
            debugShowCheckedModeBanner: false,
            themeMode: tp.appThemeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF6F7FA),
              canvasColor: const Color(0xFFF6F7FA),
              cardColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF10B981),
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF6F7FA),
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              canvasColor: Colors.black,
              cardColor: const Color(0xFF101010),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF69FF94),
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                elevation: 0,
              ),
            ),
            home: hasSeenWelcome
                ? SuperAppHubScreen(themeProvider: themeProvider)
                : WelcomeScreen(themeProvider: themeProvider),
          );
        },
      ),
    );
  }
}
