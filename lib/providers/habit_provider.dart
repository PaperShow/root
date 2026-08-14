import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

class HabitProvider extends ChangeNotifier {
  static const _habitsKey = 'user_habits';

  List<Habit> _habits = [];
  bool _initialized = false;

  List<Habit> get habits => List.unmodifiable(_habits);
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_habitsKey);

    if (jsonList != null && jsonList.isNotEmpty) {
      try {
        _habits = jsonList.map((str) => Habit.fromJson(str)).toList();
      } catch (e) {
        _habits = _getInitialSampleHabits();
        await _save();
      }
    } else {
      _habits = _getInitialSampleHabits();
      await _save();
    }

    _initialized = true;
    notifyListeners();
  }

  List<Habit> _getInitialSampleHabits() {
    final now = DateTime.now();
    final today = _formatDate(now);
    final yesterday = _formatDate(now.subtract(const Duration(days: 1)));
    final dayMinus2 = _formatDate(now.subtract(const Duration(days: 2)));
    final dayMinus3 = _formatDate(now.subtract(const Duration(days: 3)));
    final dayMinus4 = _formatDate(now.subtract(const Duration(days: 4)));

    return [
      Habit(
        id: 'sample_1',
        name: 'MORNING_RUN',
        scheduleDays: [1, 2, 3, 4, 5, 6, 7],
        reminderTime: '06:00 AM',
        category: 'FITNESS',
        targetDuration: '30 MIN',
        completedDates: {today, yesterday, dayMinus2, dayMinus4},
      ),
      Habit(
        id: 'sample_2',
        name: 'READ_30MIN',
        scheduleDays: [1, 2, 3, 4, 5],
        reminderTime: '09:00 PM',
        category: 'MIND',
        targetDuration: '30 MIN',
        completedDates: {today, dayMinus2, dayMinus3},
      ),
      Habit(
        id: 'sample_3',
        name: 'NO_DOOMSCROLL',
        scheduleDays: [1, 2, 3, 4, 5, 6, 7],
        reminderTime: '10:00 PM',
        category: 'MIND',
        targetDuration: '60 MIN',
        completedDates: {today, yesterday, dayMinus3, dayMinus4},
      ),
      Habit(
        id: 'sample_4',
        name: 'CODE_1HR',
        scheduleDays: [1, 2, 3, 4, 5],
        reminderTime: '04:00 PM',
        category: 'WORK',
        targetDuration: '60 MIN',
        completedDates: {today, yesterday, dayMinus2, dayMinus4},
      ),
      Habit(
        id: 'sample_5',
        name: 'COLD_DMS',
        scheduleDays: [1, 2, 3, 4, 5],
        reminderTime: '11:00 AM',
        category: 'WORK',
        targetDuration: '15 MIN',
        completedDates: {today, dayMinus2, dayMinus3, dayMinus4},
      ),
    ];
  }

  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
    notifyListeners();
    await _save();
  }

  Future<void> toggleHabitCompletion(String habitId, DateTime date) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;

    final habit = _habits[index];
    final dateStr = _formatDate(date);

    final updatedDates = Set<String>.from(habit.completedDates);
    if (updatedDates.contains(dateStr)) {
      updatedDates.remove(dateStr);
    } else {
      updatedDates.add(dateStr);
    }

    _habits[index] = habit.copyWith(completedDates: updatedDates);
    notifyListeners();
    await _save();
  }

  Future<void> deleteHabit(String habitId) async {
    _habits.removeWhere((h) => h.id == habitId);
    notifyListeners();
    await _save();
  }

  Future<void> updateHabit(Habit updatedHabit) async {
    final index = _habits.indexWhere((h) => h.id == updatedHabit.id);
    if (index != -1) {
      _habits[index] = updatedHabit;
      notifyListeners();
      await _save();
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calculates total completions across all habits for a specific date
  int totalCompletionsOn(DateTime date) {
    final dateStr = _formatDate(date);
    int count = 0;
    for (final h in _habits) {
      if (h.completedDates.contains(dateStr)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _habits.map((h) => h.toJson()).toList();
    await prefs.setStringList(_habitsKey, jsonList);
  }
}
