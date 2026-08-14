import 'dart:convert';

class Habit {
  final String id;
  final String name;
  final List<int> scheduleDays; // 1 = Mon, 7 = Sun
  final String reminderTime;
  final String category;
  final String targetDuration;
  final Set<String> completedDates; // Format: 'YYYY-MM-DD'
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.name,
    required this.scheduleDays,
    required this.reminderTime,
    required this.category,
    required this.targetDuration,
    required this.completedDates,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isCompletedOn(DateTime date) {
    final key = _formatDate(date);
    return completedDates.contains(key);
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'scheduleDays': scheduleDays,
      'reminderTime': reminderTime,
      'category': category,
      'targetDuration': targetDuration,
      'completedDates': completedDates.toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      scheduleDays: List<int>.from(map['scheduleDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      reminderTime: map['reminderTime'] ?? '08:00 AM',
      category: map['category'] ?? 'FITNESS',
      targetDuration: map['targetDuration'] ?? '30 MIN',
      completedDates: Set<String>.from(map['completedDates'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Habit.fromJson(String source) => Habit.fromMap(json.decode(source));

  Habit copyWith({
    String? id,
    String? name,
    List<int>? scheduleDays,
    String? reminderTime,
    String? category,
    String? targetDuration,
    Set<String>? completedDates,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      reminderTime: reminderTime ?? this.reminderTime,
      category: category ?? this.category,
      targetDuration: targetDuration ?? this.targetDuration,
      completedDates: completedDates ?? this.completedDates,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
