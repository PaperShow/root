import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../providers/theme_provider.dart';
import '../services/usage_tracker.dart';

class AppLauncher {
  static Future<void> launch(BuildContext context, AppInfo app, ThemeProvider themeProvider) async {
    UsageTracker.recordLaunch(app.packageName);

    if (themeProvider.isIntentWallEnabled) {
      // Show Intent Wall
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return IntentWallScreen(
            app: app,
            onComplete: () {
              Navigator.of(context).pop();
              InstalledApps.startApp(app.packageName);
            },
          );
        },
      );
    } else {
      InstalledApps.startApp(app.packageName);
    }
  }
}

class IntentWallScreen extends StatefulWidget {
  final AppInfo app;
  final VoidCallback onComplete;

  const IntentWallScreen({super.key, required this.app, required this.onComplete});

  @override
  State<IntentWallScreen> createState() => _IntentWallScreenState();
}

class _IntentWallScreenState extends State<IntentWallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Container(
                  width: 100 * _scaleAnimation.value,
                  height: 100 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 64),
            Text(
              'take a deep breath...',
              style: AppFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'opening ${widget.app.name.toLowerCase()}',
              style: AppFonts.inter(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 64),
            TextButton(
              onPressed: () {
                _controller.stop();
                Navigator.of(context).pop();
              },
              child: Text(
                'cancel',
                style: AppFonts.inter(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
