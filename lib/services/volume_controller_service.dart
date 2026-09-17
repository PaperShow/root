import 'package:flutter/services.dart';

class VolumeStreamInfo {
  final int current;
  final int max;

  const VolumeStreamInfo({required this.current, required this.max});

  double get ratio => max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
  int get percent => (ratio * 100).round();
}

class VolumeLevels {
  final VolumeStreamInfo media;
  final VolumeStreamInfo ring;
  final VolumeStreamInfo notification;
  final VolumeStreamInfo alarm;
  final VolumeStreamInfo call;

  const VolumeLevels({
    required this.media,
    required this.ring,
    required this.notification,
    required this.alarm,
    required this.call,
  });

  factory VolumeLevels.fromMap(Map<dynamic, dynamic> map) {
    return VolumeLevels(
      media: VolumeStreamInfo(
        current: (map['media'] as num?)?.toInt() ?? 0,
        max: (map['mediaMax'] as num?)?.toInt() ?? 15,
      ),
      ring: VolumeStreamInfo(
        current: (map['ring'] as num?)?.toInt() ?? 0,
        max: (map['ringMax'] as num?)?.toInt() ?? 15,
      ),
      notification: VolumeStreamInfo(
        current: (map['notification'] as num?)?.toInt() ?? 0,
        max: (map['notificationMax'] as num?)?.toInt() ?? 15,
      ),
      alarm: VolumeStreamInfo(
        current: (map['alarm'] as num?)?.toInt() ?? 0,
        max: (map['alarmMax'] as num?)?.toInt() ?? 15,
      ),
      call: VolumeStreamInfo(
        current: (map['call'] as num?)?.toInt() ?? 0,
        max: (map['callMax'] as num?)?.toInt() ?? 5,
      ),
    );
  }
}

class VolumeControllerService {
  static const MethodChannel _channel = MethodChannel('com.example.root/launcher');

  static Future<bool> isOverlayPermissionGranted() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isOverlayPermissionGranted');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException {
      // Ignored
    }
  }

  static Future<bool> startVolumeOverlay() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('startVolumeOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stopVolumeOverlay() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('stopVolumeOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isVolumeOverlayRunning() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isVolumeOverlayRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<VolumeLevels?> getVolumeLevels() async {
    try {
      final result = await _channel.invokeMethod('getVolumeLevels');
      if (result is Map) {
        return VolumeLevels.fromMap(result);
      }
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> setVolumeLevel(String stream, int level) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'setVolumeLevel',
        {'stream': stream, 'level': level},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
