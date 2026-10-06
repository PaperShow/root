import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debt.dart';
import '../models/expense.dart';
import '../models/split_group.dart';
import '../services/ai_service.dart';

class ExpenseProvider extends ChangeNotifier {
  static const String _storageKey = 'root_super_app_expenses';
  static const String _budgetKey = 'root_super_app_monthly_budget';
  static const String _debtsKey = 'root_super_app_debts';
  static const String _splitGroupsKey = 'root_super_app_split_groups';
  static const String _groupExpensesKey = 'root_super_app_group_expenses';
  static const String _currencySymbolKey = 'root_super_app_currency_symbol';
  static const String _currencyCodeKey = 'root_super_app_currency_code';

  List<ExpenseItem> _items = [];
  List<DebtItem> _debts = [];
  List<SplitGroup> _splitGroups = [];
  List<GroupExpense> _groupExpenses = [];

  double _monthlyBudget = 25000.0;
  String _currencySymbol = '₹'; // Rupee as default
  String _currencyCode = 'INR';
  bool _isInitialized = false;

  List<ExpenseItem> get items => List.unmodifiable(_items);
  List<DebtItem> get debts => List.unmodifiable(_debts);
  List<SplitGroup> get splitGroups => List.unmodifiable(_splitGroups);
  List<GroupExpense> get groupExpenses => List.unmodifiable(_groupExpenses);

  double get monthlyBudget => _monthlyBudget;
  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currencySymbol = prefs.getString(_currencySymbolKey) ?? '₹';
      _currencyCode = prefs.getString(_currencyCodeKey) ?? 'INR';

      final budget = prefs.getDouble(_budgetKey);
      if (budget != null && budget > 0) {
        _monthlyBudget = budget;
      } else {
        _monthlyBudget = _currencySymbol == '₹' ? 25000.0 : 1500.0;
      }

      // Load personal expenses
      final rawData = prefs.getString(_storageKey);
      if (rawData != null && rawData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawData);
        _items = decoded
            .map((item) => ExpenseItem.fromMap(Map<String, dynamic>.from(item as Map)))
            .where((item) => !item.id.startsWith('sample-'))
            .toList();
        _items.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _items = [];
      }

      // Load debts / lending
      final rawDebts = prefs.getString(_debtsKey);
      if (rawDebts != null && rawDebts.isNotEmpty) {
        final List<dynamic> decodedDebts = jsonDecode(rawDebts);
        _debts = decodedDebts
            .map((d) => DebtItem.fromMap(Map<String, dynamic>.from(d as Map)))
            .where((d) => !d.id.startsWith('debt-'))
            .toList();
        _debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _debts = [];
      }

      // Load split groups
      final rawGroups = prefs.getString(_splitGroupsKey);
      if (rawGroups != null && rawGroups.isNotEmpty) {
        final List<dynamic> decodedGroups = jsonDecode(rawGroups);
        _splitGroups = decodedGroups
            .map((g) => SplitGroup.fromMap(Map<String, dynamic>.from(g as Map)))
            .where((g) => !g.id.startsWith('group-'))
            .toList();
      } else {
        _splitGroups = [];
      }

      // Load group expenses
      final rawGroupExpenses = prefs.getString(_groupExpensesKey);
      if (rawGroupExpenses != null && rawGroupExpenses.isNotEmpty) {
        final List<dynamic> decodedGExpenses = jsonDecode(rawGroupExpenses);
        _groupExpenses = decodedGExpenses
            .map((ge) => GroupExpense.fromMap(Map<String, dynamic>.from(ge as Map)))
            .where((ge) => !ge.id.startsWith('ge-'))
            .toList();
        _groupExpenses.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _groupExpenses = [];
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

  // ─── CURRENCY PREFERENCE ──────────────────────────────────────
  Future<void> setCurrency(String symbol, String code) async {
    _currencySymbol = symbol;
    _currencyCode = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencySymbolKey, symbol);
      await prefs.setString(_currencyCodeKey, code);
    } catch (_) {}
    notifyListeners();
  }

  String formatAmount(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    if (_currencySymbol == '₹') {
      final whole = absAmount.round();
      final str = whole.toString();
      String formatted;
      if (str.length <= 3) {
        formatted = str;
      } else {
        final lastThree = str.substring(str.length - 3);
        final otherNumbers = str.substring(0, str.length - 3);
        final regex = RegExp(r'\B(?=(\d{2})+(?!\d))');
        formatted = '${otherNumbers.replaceAll(regex, ',')},$lastThree';
      }
      return '${isNegative ? "- " : ""}$_currencySymbol$formatted';
    } else {
      final formatted = absAmount.toStringAsFixed(absAmount.truncateToDouble() == absAmount ? 0 : 2);
      return '${isNegative ? "- " : ""}$_currencySymbol$formatted';
    }
  }

  // ─── NATURAL LANGUAGE & VOICE EXPENSE LOGGING ─────────────────
  Future<ExpenseItem?> parseAndLogNaturalLanguageExpense(String text, {String? apiKey}) async {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    // 1. Try AI-powered structured extraction if API key provided
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final prompt = 'Extract expense from text: "$raw". Output ONLY valid JSON: {"amount": double, "title": string, "category": string, "type": "expense"|"income"}. Categories: Food & Dining, Groceries, Transportation, Shopping, Bills & Utilities, Entertainment, Health, Income / Salary, General.';
        final response = await AiService.askAi(prompt: prompt, apiKey: apiKey);
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
        if (jsonMatch != null) {
          final decoded = jsonDecode(jsonMatch.group(0)!);
          final parsedAmount = (decoded['amount'] as num?)?.toDouble();
          if (parsedAmount != null && parsedAmount > 0) {
            final title = decoded['title']?.toString() ?? raw;
            final category = decoded['category']?.toString() ?? 'General';
            final typeStr = decoded['type']?.toString().toLowerCase();
            final type = typeStr == 'income' ? ExpenseType.income : ExpenseType.expense;
            String catId = 'other';
            final catLower = category.toLowerCase();
            if (catLower.contains('food') || catLower.contains('dining')) {
              catId = 'food';
            } else if (catLower.contains('trans')) {
              catId = 'transport';
            } else if (catLower.contains('shop') || catLower.contains('groc')) {
              catId = 'shopping';
            } else if (catLower.contains('util') || catLower.contains('bill')) {
              catId = 'utilities';
            } else if (catLower.contains('entert')) {
              catId = 'entertainment';
            } else if (catLower.contains('health') || catLower.contains('med')) {
              catId = 'health';
            } else if (catLower.contains('educ')) {
              catId = 'education';
            } else if (catLower.contains('sal') || catLower.contains('inc')) {
              catId = 'salary';
            }

            final item = ExpenseItem(
              id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
              title: title.isEmpty ? 'Quick Expense' : title,
              amount: parsedAmount,
              categoryId: catId,
              date: DateTime.now(),
              type: type,
              note: 'Quick logged: "$raw"',
            );
            await addExpense(item);
            return item;
          }
        }
      } catch (_) {
        // Fall back seamlessly to local regex NLP engine
      }
    }

    // 2. High-speed local NLP regex parser
    final amountRegex = RegExp(
      r'(?:₹|\$|rs\.?|inr|usd|€|£)?\s*(\d+(?:[.,]\d+)?)\s*(?:₹|\$|rs\.?|inr|usd|€|£|bucks|rupees)?',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(raw);
    if (match == null) return null;

    final numStr = match.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(numStr ?? '');
    if (amount == null || amount <= 0) return null;

    final lower = raw.toLowerCase();
    final isIncome = lower.contains('salary') ||
        lower.contains('credited') ||
        lower.contains('income') ||
        lower.contains('earned') ||
        lower.contains('received') ||
        lower.contains('dividend') ||
        lower.contains('refund') ||
        lower.contains('cashback') ||
        lower.contains('freelance');

    String category = 'General';
    if (lower.contains('food') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast') ||
        lower.contains('coffee') ||
        lower.contains('cafe') ||
        lower.contains('tea') ||
        lower.contains('chai') ||
        lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('subway') ||
        lower.contains('restaurant')) {
      category = 'Food & Dining';
    } else if (lower.contains('grocery') ||
        lower.contains('groceries') ||
        lower.contains('zepto') ||
        lower.contains('blinkit') ||
        lower.contains('instamart') ||
        lower.contains('milk') ||
        lower.contains('vegetable') ||
        lower.contains('fruit') ||
        lower.contains('supermart') ||
        lower.contains('dmart')) {
      category = 'Groceries';
    } else if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('rapido') ||
        lower.contains('cab') ||
        lower.contains('taxi') ||
        lower.contains('metro') ||
        lower.contains('bus') ||
        lower.contains('petrol') ||
        lower.contains('fuel') ||
        lower.contains('diesel') ||
        lower.contains('parking') ||
        lower.contains('toll') ||
        lower.contains('flight') ||
        lower.contains('train') ||
        lower.contains('auto')) {
      category = 'Transportation';
    } else if (lower.contains('bill') ||
        lower.contains('electricity') ||
        lower.contains('recharge') ||
        lower.contains('wifi') ||
        lower.contains('internet') ||
        lower.contains('broadband') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('cylinder') ||
        lower.contains('rent')) {
      category = 'Bills & Utilities';
    } else if (lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('myntra') ||
        lower.contains('shopping') ||
        lower.contains('clothes') ||
        lower.contains('shoes') ||
        lower.contains('shirt') ||
        lower.contains('dress')) {
      category = 'Shopping';
    } else if (lower.contains('movie') ||
        lower.contains('cinema') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('prime') ||
        lower.contains('game') ||
        lower.contains('concert') ||
        lower.contains('outing')) {
      category = 'Entertainment';
    } else if (lower.contains('medicine') ||
        lower.contains('pharmacy') ||
        lower.contains('doctor') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('gym') ||
        lower.contains('protein')) {
      category = 'Health';
    } else if (isIncome) {
      category = 'Income / Salary';
    }

    var title = raw
        .replaceAll(match.group(0)!, '')
        .replaceAll(RegExp(r'\b(spent|paid|for|on|at|rs\.?|rupees|inr|usd|bucks)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();

    if (title.isEmpty) {
      title = category == 'General' ? 'Quick Expense' : category;
    } else {
      title = title.split(' ').where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase() + s.substring(1)).join(' ');
    }

    String categoryId = 'other';
    if (category == 'Food & Dining') {
      categoryId = 'food';
    } else if (category == 'Groceries' || category == 'Shopping') {
      categoryId = 'shopping';
    } else if (category == 'Transport') {
      categoryId = 'transport';
    } else if (category == 'Utilities') {
      categoryId = 'utilities';
    } else if (category == 'Entertainment') {
      categoryId = 'entertainment';
    } else if (category == 'Health') {
      categoryId = 'health';
    } else if (category == 'Education') {
      categoryId = 'education';
    } else if (isIncome || category == 'Income / Salary') {
      categoryId = 'salary';
    }

    final item = ExpenseItem(
      id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      amount: amount,
      categoryId: categoryId,
      date: DateTime.now(),
      type: isIncome ? ExpenseType.income : ExpenseType.expense,
      note: 'Quick logged: "$raw"',
    );

    await addExpense(item);
    return item;
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
