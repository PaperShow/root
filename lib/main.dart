import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/expense_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/super_app_hub_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'styles/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full screen, hiding system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize Google Sign-In
  await AuthService().initialize();

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
  final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

  runApp(
    RootSuperApp(
      themeProvider: themeProvider,
      habitProvider: habitProvider,
      expenseProvider: expenseProvider,
      hasSeenWelcome: hasSeenWelcome || isLoggedIn,
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
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: hasSeenWelcome
                ? SuperAppHubScreen(themeProvider: themeProvider)
                : WelcomeScreen(themeProvider: themeProvider),
          );
        },
      ),
    );
  }
}
