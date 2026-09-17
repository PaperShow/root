class GroupExpense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy; // Name of person who paid
  final List<String> splitAmong; // Names of people who share the expense
  final DateTime date;
  final String? note;

  const GroupExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
    required this.date,
    this.note,
  });

  double get sharePerPerson =>
      splitAmong.isNotEmpty ? amount / splitAmong.length : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitAmong': splitAmong,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory GroupExpense.fromMap(Map<String, dynamic> map) {
    return GroupExpense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      paidBy: map['paidBy'] as String,
      splitAmong: (map['splitAmong'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}

class SplitGroup {
  final String id;
  final String name;
  final String icon;
  final List<String> members;
  final DateTime createdAt;

  const SplitGroup({
    required this.id,
    required this.name,
    this.icon = '👥',
    required this.members,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'members': members,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SplitGroup.fromMap(Map<String, dynamic> map) {
    return SplitGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? '👥',
      members: (map['members'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['You'],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
