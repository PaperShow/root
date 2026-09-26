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
        _habits = jsonList
            .map((str) => Habit.fromJson(str))
            .where((h) => !h.id.startsWith('sample_'))
            .toList();
      } catch (e) {
        _habits = [];
        await _save();
      }
    } else {
      _habits = [];
      await _save();
    }

    _initialized = true;
    notifyListeners();
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

  Future<void> reorderHabit(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _habits.length) return;
    if (newIndex < 0 || newIndex >= _habits.length) return;

    final habit = _habits.removeAt(oldIndex);
    _habits.insert(newIndex, habit);
    notifyListeners();
    await _save();
  }

  /// Calculates consecutive day streak ending today or yesterday
  int getStreak(Habit habit) {
    final now = DateTime.now();
    int streak = 0;
    DateTime checkDate = habit.isCompletedOn(now)
        ? now
        : now.subtract(const Duration(days: 1));

    while (habit.isCompletedOn(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Calculates best streak ever achieved for this habit
  int getBestStreak(Habit habit) {
    if (habit.completedDates.isEmpty) return 0;

    final sortedDates = habit.completedDates.map((d) => DateTime.parse(d)).toList()
      ..sort();

    int maxStreak = 0;
    int currentStreak = 0;
    DateTime? prev;

    for (final date in sortedDates) {
      if (prev == null) {
        currentStreak = 1;
      } else {
        final diff = date.difference(prev).inDays;
        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      }
      if (currentStreak > maxStreak) maxStreak = currentStreak;
      prev = date;
    }
    return maxStreak;
  }

  /// Returns today's completion progress: { 'completed': int, 'total': int }
  Map<String, int> getTodayProgress() {
    final now = DateTime.now();
    final completed = totalCompletionsOn(now);
    return {'completed': completed, 'total': _habits.length};
  }

  /// CLI: Mark habit done by name match for today
  Habit? markHabitDoneByName(String nameQuery) {
    final cleanQuery = nameQuery.trim().toLowerCase().replaceAll('_', ' ');
    final index = _habits.indexWhere((h) =>
        h.name.toLowerCase().replaceAll('_', ' ').contains(cleanQuery));

    if (index != -1) {
      final now = DateTime.now();
      final dateStr = _formatDate(now);
      final habit = _habits[index];
      final updatedDates = Set<String>.from(habit.completedDates)..add(dateStr);
      _habits[index] = habit.copyWith(completedDates: updatedDates);
      notifyListeners();
      _save();
      return _habits[index];
    }
    return null;
  }

  /// CLI: Mark habit undone by name match for today
  Habit? markHabitUndoneByName(String nameQuery) {
    final cleanQuery = nameQuery.trim().toLowerCase().replaceAll('_', ' ');
    final index = _habits.indexWhere((h) =>
        h.name.toLowerCase().replaceAll('_', ' ').contains(cleanQuery));

    if (index != -1) {
      final now = DateTime.now();
      final dateStr = _formatDate(now);
      final habit = _habits[index];
      final updatedDates = Set<String>.from(habit.completedDates)..remove(dateStr);
      _habits[index] = habit.copyWith(completedDates: updatedDates);
      notifyListeners();
      _save();
      return _habits[index];
    }
    return null;
  }

  /// CLI: Quick add habit from terminal
  Habit addHabitFromCli(String name, {String category = 'DAILY'}) {
    final newHabit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.toUpperCase().replaceAll(' ', '_'),
      scheduleDays: [1, 2, 3, 4, 5, 6, 7],
      reminderTime: '08:00 AM',
      category: category,
      targetDuration: '30 MIN',
      completedDates: {},
    );
    addHabit(newHabit);
    return newHabit;
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
