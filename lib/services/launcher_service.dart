import 'package:flutter/services.dart';

class LauncherService {
  static const MethodChannel _channel = MethodChannel('com.example.root/launcher');

  static Future<bool> isDefaultLauncher() async {
    try {
      final bool result = await _channel.invokeMethod('isDefaultLauncher');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openLauncherSettings() async {
    try {
      await _channel.invokeMethod('openLauncherSettings');
    } on PlatformException {
      // Handle error implicitly
    }
  }

  /// Sets a solid wallpaper.
  /// [which]: 1 = home screen only, 2 = lock screen only, 3 = both
  /// [color]: ARGB color int; defaults to solid black when omitted.
  static Future<bool> setBlackWallpaper({int which = 3, int? color}) async {
    try {
      final bool result = await _channel.invokeMethod(
        'setBlackWallpaper',
        {'which': which, 'color': color},
      );
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> canSetWallpaper() async {
    try {
      final bool result = await _channel.invokeMethod('canSetWallpaper');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Retrieves system info from native Android for the neofetch/sys command.
  /// Returns a map with keys:
  ///   networkType, wifiSsid, screenTimeMinutes,
  ///   nextEventTitle, nextEventTime, deviceModel, androidVersion
  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final result = await _channel.invokeMethod('getSystemInfo');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException {
      return {};
    }
  }

  /// Lock the screen (turns off the display).
  /// Requires Device Admin to be enabled. Prompts user if not enabled.
  static Future<void> lockScreen() async {
    try {
      await _channel.invokeMethod('lockScreen');
    } on PlatformException {
      // Ignored
    }
  }
}
