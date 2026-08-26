import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LauncherThemeType { terminal, standard }

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'launcher_theme';
  static const _intentWallKey = 'intent_wall_enabled';
  static const _pinnedAppsKey = 'pinned_apps';
  static const _iconsEnabledKey = 'icons_enabled';
  static const _statusStripKey = 'status_strip_enabled';
  static const _standardColumnsKey = 'standard_columns';
  static const _showAppLabelsKey = 'show_app_labels';
  static const _groqApiKey = 'groq_api_key';
  static const _groqAiModelKey = 'groq_ai_model';
  static const _groqWhisperModelKey = 'groq_whisper_model';
  static const _walkthroughKey = 'has_seen_walkthrough';
  static const _seenThemeTipsKey = 'seen_theme_tips';

  LauncherThemeType _currentTheme = LauncherThemeType.terminal;
  bool _isIntentWallEnabled = true;
  bool _isIconsEnabled = true;
  bool _isStatusStripEnabled = true;
  int _standardGridColumns = 4;
  bool _showAppLabels = true;
  String _groqApiKeyVal = '';
  String _groqAiModelVal = 'groq/compound';
  String _groqWhisperModelVal = 'whisper-large-v3';
  List<String> _pinnedApps = [];
  bool _hasSeenWalkthrough = false;
  Set<String> _seenThemeTips = {};
  bool _initialized = false;

  LauncherThemeType get currentTheme => _currentTheme;
  bool get isIntentWallEnabled => _isIntentWallEnabled;
  bool get isIconsEnabled => _isIconsEnabled;
  bool get isStatusStripEnabled => _isStatusStripEnabled;
  int get standardGridColumns => _standardGridColumns;
  bool get showAppLabels => _showAppLabels;
  String get groqApiKey => _groqApiKeyVal;
  String get groqAiModel => _groqAiModelVal;
  String get groqWhisperModel => _groqWhisperModelVal;
  List<String> get pinnedApps => List.unmodifiable(_pinnedApps);
  bool get hasSeenWalkthrough => _hasSeenWalkthrough;
  bool get isInitialized => _initialized;

  /// Load saved preferences from disk. Call once at app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < LauncherThemeType.values.length) {
      _currentTheme = LauncherThemeType.values[themeIndex];
    } else {
      _currentTheme = LauncherThemeType.terminal;
    }

    _isIntentWallEnabled = prefs.getBool(_intentWallKey) ?? true;
    _isIconsEnabled = prefs.getBool(_iconsEnabledKey) ?? true;
    _isStatusStripEnabled = prefs.getBool(_statusStripKey) ?? true;
    _standardGridColumns = prefs.getInt(_standardColumnsKey) ?? 4;
    _showAppLabels = prefs.getBool(_showAppLabelsKey) ?? true;
    _groqApiKeyVal = prefs.getString(_groqApiKey) ?? '';
    _groqAiModelVal = prefs.getString(_groqAiModelKey) ?? 'groq/compound';
    _groqWhisperModelVal =
        prefs.getString(_groqWhisperModelKey) ?? 'whisper-large-v3';
    _pinnedApps = prefs.getStringList(_pinnedAppsKey) ?? [];
    _hasSeenWalkthrough = prefs.getBool(_walkthroughKey) ?? false;
    _seenThemeTips = (prefs.getStringList(_seenThemeTipsKey) ?? []).toSet();

    _initialized = true;
    notifyListeners();
  }

  void setTheme(LauncherThemeType theme) {
    _currentTheme = theme;
    notifyListeners();
    _save();
  }

  void nextTheme() {
    final nextIndex = (_currentTheme.index + 1) % LauncherThemeType.values.length;
    _currentTheme = LauncherThemeType.values[nextIndex];
    notifyListeners();
    _save();
  }

  void toggleIntentWall(bool value) {
    _isIntentWallEnabled = value;
    notifyListeners();
    _save();
  }

  void toggleIcons(bool value) {
    _isIconsEnabled = value;
    notifyListeners();
    _save();
  }

  void toggleStatusStrip(bool value) {
    _isStatusStripEnabled = value;
    notifyListeners();
    _save();
  }

  void setStandardGridColumns(int columns) {
    _standardGridColumns = columns;
    notifyListeners();
    _save();
  }

  void toggleShowAppLabels(bool value) {
    _showAppLabels = value;
    notifyListeners();
    _save();
  }

  void setGroqApiKey(String key) {
    _groqApiKeyVal = key.trim();
    notifyListeners();
    _save();
  }

  void setGroqAiModel(String model) {
    _groqAiModelVal = model.trim();
    notifyListeners();
    _save();
  }

  void setGroqWhisperModel(String model) {
    _groqWhisperModelVal = model.trim();
    notifyListeners();
    _save();
  }

  static const int maxDockApps = 10;

  bool isPinned(String packageName) => _pinnedApps.contains(packageName);

  /// Returns true if newly pinned, false if unpinned or reached maxDockApps limit.
  bool togglePinned(String packageName) {
    final updated = List<String>.of(_pinnedApps);
    if (updated.contains(packageName)) {
      updated.remove(packageName);
      _pinnedApps = updated;
      notifyListeners();
      _save();
      return false;
    } else {
      if (updated.length >= maxDockApps) {
        return false;
      }
      updated.add(packageName);
      _pinnedApps = updated;
      notifyListeners();
      _save();
      return true;
    }
  }

  void reorderPinned(int oldIndex, int newIndex) {
    final updated = List<String>.of(_pinnedApps);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    _pinnedApps = updated;
    notifyListeners();
    _save();
  }

  bool hasSeenThemeTip(LauncherThemeType theme) => _seenThemeTips.contains(theme.name);

  void markThemeTipSeen(LauncherThemeType theme) {
    _seenThemeTips = Set<String>.of(_seenThemeTips)..add(theme.name);
    notifyListeners();
    _save();
  }

  void markWalkthroughSeen() {
    _hasSeenWalkthrough = true;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _currentTheme.index);
    await prefs.setBool(_intentWallKey, _isIntentWallEnabled);
    await prefs.setBool(_iconsEnabledKey, _isIconsEnabled);
    await prefs.setBool(_statusStripKey, _isStatusStripEnabled);
    await prefs.setInt(_standardColumnsKey, _standardGridColumns);
    await prefs.setBool(_showAppLabelsKey, _showAppLabels);
    await prefs.setString(_groqApiKey, _groqApiKeyVal);
    await prefs.setString(_groqAiModelKey, _groqAiModelVal);
    await prefs.setString(_groqWhisperModelKey, _groqWhisperModelVal);
    await prefs.setStringList(_pinnedAppsKey, _pinnedApps);
    await prefs.setBool(_walkthroughKey, _hasSeenWalkthrough);
    await prefs.setStringList(_seenThemeTipsKey, _seenThemeTips.toList());
  }
}
