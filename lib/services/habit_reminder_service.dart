import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class HabitReminderService {
  static const _reminderPrefix = 'habit_reminder_enabled_';

  static Future<bool> isReminderEnabled(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_reminderPrefix$habitId') ?? true;
  }

  static Future<void> toggleReminder(String habitId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_reminderPrefix$habitId', enabled);
  }

  /// Formats reminder notification text in terminal telemetry style
  static String formatReminderText(Habit habit) {
    return '[SYS_REMINDER] Time for ${habit.name} (${habit.targetDuration})';
  }

  /// Show in-app reminder toast / banner when habit reminder fires
  static void showInAppReminder(BuildContext context, Habit habit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF101010),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF69FF94), width: 1.2),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFF69FF94), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '// HABIT_REMINDER',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: Color(0xFF69FF94),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Time for ${habit.name.replaceAll('_', ' ')} • ${habit.targetDuration}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
