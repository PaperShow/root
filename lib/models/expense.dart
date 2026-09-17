import 'package:flutter/material.dart';

enum ExpenseType {
  expense,
  income,
}

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      id: 'food',
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: Color(0xFFFF9F43),
    ),
    ExpenseCategory(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_car,
      color: Color(0xFF54A0FF),
    ),
    ExpenseCategory(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFFFF6B6B),
    ),
    ExpenseCategory(
      id: 'utilities',
      name: 'Bills & Utilities',
      icon: Icons.bolt,
      color: Color(0xFFFECA57),
    ),
    ExpenseCategory(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.sports_esports,
      color: Color(0xFF5F27CD),
    ),
    ExpenseCategory(
      id: 'health',
      name: 'Health & Medical',
      icon: Icons.favorite,
      color: Color(0xFFFF4D4D),
    ),
    ExpenseCategory(
      id: 'education',
      name: 'Education',
      icon: Icons.school,
      color: Color(0xFF48DBFB),
    ),
    ExpenseCategory(
      id: 'salary',
      name: 'Salary & Income',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF69FF94),
    ),
    ExpenseCategory(
      id: 'investment',
      name: 'Investment',
      icon: Icons.trending_up,
      color: Color(0xFF1DD1A1),
    ),
    ExpenseCategory(
      id: 'other',
      name: 'Other',
      icon: Icons.category_outlined,
      color: Color(0xFFC8D6E5),
    ),
  ];

  static ExpenseCategory findById(String id) {
    return defaultCategories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => defaultCategories.last,
    );
  }
}

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final ExpenseType type;
  final DateTime date;
  final String? note;

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.type,
    required this.date,
    this.note,
  });

  ExpenseCategory get category => ExpenseCategory.findById(categoryId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'type': type.name,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String? ?? 'other',
      type: (map['type'] as String?) == 'income'
          ? ExpenseType.income
          : ExpenseType.expense,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
