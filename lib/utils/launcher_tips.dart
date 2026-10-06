import '../providers/theme_provider.dart';

/// A short "how to use" blurb for a theme (or for gestures that work
/// everywhere), shared between the per-theme tip sheet and the walkthrough.
class ThemeTip {
  final String title;
  final List<String> bullets;

  const ThemeTip({required this.title, required this.bullets});
}

const Map<LauncherThemeType, ThemeTip> kThemeTips = {
  LauncherThemeType.terminal: ThemeTip(
    title: 'terminal / command shell',
    bullets: [
      'start typing to filter apps instantly',
      'ask AI any question directly in terminal',
      'try commands: call, msg, note, calc, search, sys, setkey',
      'swipe left to access your Habit Tracker commit board',
    ],
  ),
  LauncherThemeType.standard: ThemeTip(
    title: 'original / standard phone',
    bullets: [
      'authentic phone app grid with quick search bar',
      'tap an app to open it, or long-press to pin it to dock',
      'customize grid columns (3-5), app labels, and icons in settings',
    ],
  ),
};

const kUniversalTips = ThemeTip(
  title: 'everywhere',
  bullets: [
    'swipe left on terminal screen to open Habit Tracker',
    'long-press the clock to switch between Terminal and Standard Phone launcher',
    'double-tap anywhere to lock the screen',
    'open settings (gear icon) for launcher customization options',
  ],
);
