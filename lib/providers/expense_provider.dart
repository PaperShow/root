import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debt.dart';
import '../models/expense.dart';
import '../models/split_group.dart';

class ExpenseProvider extends ChangeNotifier {
  static const String _storageKey = 'root_super_app_expenses';
  static const String _budgetKey = 'root_super_app_monthly_budget';
  static const String _debtsKey = 'root_super_app_debts';
  static const String _splitGroupsKey = 'root_super_app_split_groups';
  static const String _groupExpensesKey = 'root_super_app_group_expenses';

  List<ExpenseItem> _items = [];
  List<DebtItem> _debts = [];
  List<SplitGroup> _splitGroups = [];
  List<GroupExpense> _groupExpenses = [];

  double _monthlyBudget = 1500.0;
  bool _isInitialized = false;

  List<ExpenseItem> get items => List.unmodifiable(_items);
  List<DebtItem> get debts => List.unmodifiable(_debts);
  List<SplitGroup> get splitGroups => List.unmodifiable(_splitGroups);
  List<GroupExpense> get groupExpenses => List.unmodifiable(_groupExpenses);

  double get monthlyBudget => _monthlyBudget;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble(_budgetKey);
      if (budget != null && budget > 0) {
        _monthlyBudget = budget;
      }

      // Load personal expenses
      final rawData = prefs.getString(_storageKey);
      if (rawData != null && rawData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawData);
        _items = decoded
            .map((item) => ExpenseItem.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        _items.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _items = _generateInitialSamples();
      }

      // Load debts / lending
      final rawDebts = prefs.getString(_debtsKey);
      if (rawDebts != null && rawDebts.isNotEmpty) {
        final List<dynamic> decodedDebts = jsonDecode(rawDebts);
        _debts = decodedDebts
            .map((d) => DebtItem.fromMap(Map<String, dynamic>.from(d as Map)))
            .toList();
        _debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _debts = _generateInitialDebts();
      }

      // Load split groups
      final rawGroups = prefs.getString(_splitGroupsKey);
      if (rawGroups != null && rawGroups.isNotEmpty) {
        final List<dynamic> decodedGroups = jsonDecode(rawGroups);
        _splitGroups = decodedGroups
            .map((g) => SplitGroup.fromMap(Map<String, dynamic>.from(g as Map)))
            .toList();
      } else {
        _splitGroups = _generateInitialGroups();
      }

      // Load group expenses
      final rawGroupExpenses = prefs.getString(_groupExpensesKey);
      if (rawGroupExpenses != null && rawGroupExpenses.isNotEmpty) {
        final List<dynamic> decodedGExpenses = jsonDecode(rawGroupExpenses);
        _groupExpenses = decodedGExpenses
            .map((ge) => GroupExpense.fromMap(Map<String, dynamic>.from(ge as Map)))
            .toList();
        _groupExpenses.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _groupExpenses = _generateInitialGroupExpenses();
      }

      await _saveAll();
    } catch (e) {
      if (kDebugMode) {
        print('ExpenseProvider init error: $e');
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ─── INITIAL SAMPLES ──────────────────────────────────────────

  List<ExpenseItem> _generateInitialSamples() {
    final now = DateTime.now();
    return [
      ExpenseItem(
        id: 'sample-1',
        title: 'Cloud VPS Hosting',
        amount: 24.50,
        categoryId: 'utilities',
        type: ExpenseType.expense,
        date: now.subtract(const Duration(hours: 4)),
        note: 'Monthly development server',
      ),
      ExpenseItem(
        id: 'sample-2',
        title: 'Espresso & Bakery',
        amount: 8.75,
        categoryId: 'food',
        type: ExpenseType.expense,
        date: now.subtract(const Duration(hours: 9)),
        note: 'Morning fuel',
      ),
      ExpenseItem(
        id: 'sample-3',
        title: 'Consulting Payout',
        amount: 750.00,
        categoryId: 'salary',
        type: ExpenseType.income,
        date: now.subtract(const Duration(days: 2)),
        note: 'Client sprint milestone',
      ),
      ExpenseItem(
        id: 'sample-4',
        title: 'Subway Pass',
        amount: 45.00,
        categoryId: 'transport',
        type: ExpenseType.expense,
        date: now.subtract(const Duration(days: 3)),
        note: 'Commuter monthly refill',
      ),
    ];
  }

  List<DebtItem> _generateInitialDebts() {
    final now = DateTime.now();
    return [
      DebtItem(
        id: 'debt-1',
        personName: 'Alex',
        totalAmount: 100.0,
        paidAmount: 30.0,
        type: DebtType.lent,
        createdAt: now.subtract(const Duration(days: 5)),
        dueDate: now.add(const Duration(days: 10)),
        note: 'Weekend concert ticket',
        repayments: [
          DebtRepayment(
            id: 'rep-1',
            amount: 30.0,
            date: now.subtract(const Duration(days: 1)),
            note: 'UPI partial return',
          ),
        ],
      ),
      DebtItem(
        id: 'debt-2',
        personName: 'Sam',
        totalAmount: 50.0,
        paidAmount: 0.0,
        type: DebtType.borrowed,
        createdAt: now.subtract(const Duration(days: 3)),
        note: 'Shared cab fare',
      ),
    ];
  }

  List<SplitGroup> _generateInitialGroups() {
    final now = DateTime.now();
    return [
      SplitGroup(
        id: 'group-1',
        name: 'Weekend Trip',
        icon: '🏖️',
        members: ['You', 'Alex', 'Sam', 'Priya'],
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      SplitGroup(
        id: 'group-2',
        name: 'Flatmates',
        icon: '🏠',
        members: ['You', 'Rahul', 'John'],
        createdAt: now.subtract(const Duration(days: 14)),
      ),
    ];
  }

  List<GroupExpense> _generateInitialGroupExpenses() {
    final now = DateTime.now();
    return [
      GroupExpense(
        id: 'ge-1',
        groupId: 'group-1',
        title: 'Resort Booking',
        amount: 120.0,
        paidBy: 'You',
        splitAmong: ['You', 'Alex', 'Sam', 'Priya'],
        date: now.subtract(const Duration(days: 2)),
        note: 'Paid upfront',
      ),
      GroupExpense(
        id: 'ge-2',
        groupId: 'group-1',
        title: 'Highway Tolls & Snacks',
        amount: 40.0,
        paidBy: 'Alex',
        splitAmong: ['You', 'Alex', 'Sam', 'Priya'],
        date: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  Future<void> _saveAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_items.map((e) => e.toMap()).toList()));
      await prefs.setDouble(_budgetKey, _monthlyBudget);
      await prefs.setString(_debtsKey, jsonEncode(_debts.map((e) => e.toMap()).toList()));
      await prefs.setString(_splitGroupsKey, jsonEncode(_splitGroups.map((e) => e.toMap()).toList()));
      await prefs.setString(_groupExpensesKey, jsonEncode(_groupExpenses.map((e) => e.toMap()).toList()));
    } catch (e) {
      if (kDebugMode) {
        print('ExpenseProvider save error: $e');
      }
    }
  }

  // ─── PERSONAL EXPENSES CRUD ───────────────────────────────────

  Future<void> addExpense(ExpenseItem item) async {
    _items.insert(0, item);
    _items.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveAll();
  }

  Future<void> updateExpense(ExpenseItem updatedItem) async {
    final index = _items.indexWhere((e) => e.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      _items.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
      await _saveAll();
    }
  }

  Future<void> deleteExpense(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveAll();
  }

  Future<void> setMonthlyBudget(double budget) async {
    _monthlyBudget = budget;
    notifyListeners();
    await _saveAll();
  }

  // ─── DEBT & LENDING MANAGEMENT ────────────────────────────────

  double get totalToReceive {
    return _debts
        .where((d) => d.type == DebtType.lent && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  double get totalToPay {
    return _debts
        .where((d) => d.type == DebtType.borrowed && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  Future<void> addDebt(DebtItem debt) async {
    _debts.insert(0, debt);
    _debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
    await _saveAll();
  }

  Future<void> recordDebtRepayment(String debtId, double amount, String? note) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final old = _debts[index];
      final newPaid = (old.paidAmount + amount).clamp(0.0, old.totalAmount);
      final newRepayments = List<DebtRepayment>.from(old.repayments)
        ..insert(
          0,
          DebtRepayment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: amount,
            date: DateTime.now(),
            note: note,
          ),
        );
      final isNowSettled = newPaid >= old.totalAmount;

      _debts[index] = old.copyWith(
        paidAmount: newPaid,
        repayments: newRepayments,
        isSettled: isNowSettled,
      );
      notifyListeners();
      await _saveAll();
    }
  }

  Future<void> settleDebt(String debtId) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final old = _debts[index];
      final remaining = old.remainingAmount;
      final newRepayments = List<DebtRepayment>.from(old.repayments);
      if (remaining > 0) {
        newRepayments.insert(
          0,
          DebtRepayment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: remaining,
            date: DateTime.now(),
            note: 'Final full settlement',
          ),
        );
      }
      _debts[index] = old.copyWith(
        paidAmount: old.totalAmount,
        repayments: newRepayments,
        isSettled: true,
      );
      notifyListeners();
      await _saveAll();
    }
  }

  Future<void> deleteDebt(String debtId) async {
    _debts.removeWhere((d) => d.id == debtId);
    notifyListeners();
    await _saveAll();
  }

  // ─── SPLITWISE GROUPS MANAGEMENT ──────────────────────────────

  Future<void> createSplitGroup(SplitGroup group) async {
    _splitGroups.insert(0, group);
    notifyListeners();
    await _saveAll();
  }

  Future<void> deleteSplitGroup(String groupId) async {
    _splitGroups.removeWhere((g) => g.id == groupId);
    _groupExpenses.removeWhere((ge) => ge.groupId == groupId);
    notifyListeners();
    await _saveAll();
  }

  Future<void> addGroupExpense(GroupExpense expense) async {
    _groupExpenses.insert(0, expense);
    _groupExpenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveAll();
  }

  Future<void> deleteGroupExpense(String expenseId) async {
    _groupExpenses.removeWhere((ge) => ge.id == expenseId);
    notifyListeners();
    await _saveAll();
  }

  List<GroupExpense> getExpensesForGroup(String groupId) {
    return _groupExpenses.where((ge) => ge.groupId == groupId).toList();
  }

  double getGroupTotalSpent(String groupId) {
    return getExpensesForGroup(groupId).fold(0.0, (sum, ge) => sum + ge.amount);
  }

  /// Calculates net balance (+ is owed to member, - is owed by member)
  Map<String, double> getGroupMemberBalances(String groupId) {
    final matches = _splitGroups.where((g) => g.id == groupId);
    if (matches.isEmpty) return {};
    final group = matches.first;
    final expenses = getExpensesForGroup(groupId);
    final Map<String, double> balances = {};

    for (final member in group.members) {
      balances[member] = 0.0;
    }

    for (final exp in expenses) {
      // Payer gets credit
      balances[exp.paidBy] = (balances[exp.paidBy] ?? 0.0) + exp.amount;
      // Split participants get debited their share
      final share = exp.sharePerPerson;
      for (final person in exp.splitAmong) {
        balances[person] = (balances[person] ?? 0.0) - share;
      }
    }

    return balances;
  }

  // ─── COMPUTED GETTERS (PERSONAL) ──────────────────────────────

  List<ExpenseItem> get thisMonthItems {
    final now = DateTime.now();
    return _items.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
  }

  double get totalExpenseThisMonth {
    return thisMonthItems
        .where((e) => e.type == ExpenseType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalIncomeThisMonth {
    return thisMonthItems
        .where((e) => e.type == ExpenseType.income)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get netBalanceThisMonth {
    return totalIncomeThisMonth - totalExpenseThisMonth;
  }

  double get todayExpense {
    final now = DateTime.now();
    return _items
        .where((e) =>
            e.type == ExpenseType.expense &&
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get budgetProgressRatio {
    if (_monthlyBudget <= 0) return 0.0;
    return (totalExpenseThisMonth / _monthlyBudget).clamp(0.0, 1.0);
  }

  Map<String, double> get categoryBreakdownThisMonth {
    final Map<String, double> breakdown = {};
    for (final item in thisMonthItems) {
      if (item.type == ExpenseType.expense) {
        breakdown[item.categoryId] = (breakdown[item.categoryId] ?? 0.0) + item.amount;
      }
    }
    return breakdown;
  }
}
