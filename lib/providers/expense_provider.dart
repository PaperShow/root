import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debt.dart';
import '../models/expense.dart';
import '../models/split_group.dart';
import '../services/ai_service.dart';
import '../services/user_directory_service.dart';

/// A group action that was refused, with a message suitable for the user.
class GroupActionException implements Exception {
  final String message;
  const GroupActionException(this.message);
  @override
  String toString() => message;
}

class ExpenseProvider extends ChangeNotifier {
  static const String _storageKey = 'root_super_app_expenses';
  static const String _budgetKey = 'root_super_app_monthly_budget';
  static const String _debtsKey = 'root_super_app_debts';
  static const String _splitGroupsKey = 'root_super_app_split_groups';
  static const String _groupExpensesKey = 'root_super_app_group_expenses';
  static const String _currencySymbolKey = 'root_super_app_currency_symbol';
  static const String _currencyCodeKey = 'root_super_app_currency_code';

  List<ExpenseItem> _items = [];
  // Offline (guest) storage for lending & groups
  List<DebtItem> _debts = [];
  List<SplitGroup> _splitGroups = [];
  List<GroupExpense> _groupExpenses = [];

  // Shared storage once signed in
  User? _user;
  AppUserProfile? _profile;
  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<dynamic>> _cloudSubs = [];
  final Map<String, StreamSubscription<dynamic>> _expenseSubs = {};
  List<SplitGroup> _cloudGroups = [];
  final Map<String, List<GroupExpense>> _cloudGroupExpenses = {};
  List<SplitGroup> _invitesByUid = [];
  List<SplitGroup> _invitesByEmail = [];
  List<DebtItem> _cloudDebts = [];
  bool _isCloudLoading = false;
  String? _lastCloudError;

  double _monthlyBudget = 25000.0;
  String _currencySymbol = '₹'; // Rupee as default
  String _currencyCode = 'INR';
  bool _isInitialized = false;

  List<ExpenseItem> get items => List.unmodifiable(_items);
  List<DebtItem> get debts => List.unmodifiable(isCloudSync ? _cloudDebts : _debts);
  List<SplitGroup> get splitGroups => List.unmodifiable(isCloudSync ? _cloudGroups : _splitGroups);

  /// Groups the signed-in user has been invited to but not joined yet.
  List<SplitGroup> get groupInvites {
    final byId = {for (final g in [..._invitesByUid, ..._invitesByEmail]) g.id: g};
    return byId.values.where((g) => !_cloudGroups.any((c) => c.id == g.id)).toList();
  }

  bool get isCloudSync => _user != null;
  bool get isCloudLoading => _isCloudLoading;
  String? get lastCloudError => _lastCloudError;
  String? get currentUid => _user?.uid;
  AppUserProfile? get currentProfile => _profile;

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
      _listenToAuth();
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
    return debts
        .where((d) => d.type == DebtType.lent && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  double get totalToPay {
    return debts
        .where((d) => d.type == DebtType.borrowed && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// Adds a lending record. When signed in, [counterpartyUid] links it to
  /// another account (they see it immediately) and [counterpartyEmail] links it
  /// to someone who hasn't joined yet (they see it once they sign up).
  Future<void> addDebt(DebtItem debt) async {
    if (isCloudSync) {
      final record = DebtItem(
        id: debt.id,
        personName: debt.personName,
        totalAmount: debt.totalAmount,
        type: debt.type,
        createdAt: debt.createdAt,
        dueDate: debt.dueDate,
        note: debt.note,
        ownerUid: _user!.uid,
        ownerName: _myDisplayName,
        counterpartyUid: debt.counterpartyUid,
        counterpartyEmail: debt.counterpartyEmail,
      );
      await _cloudWrite(() => _debtsRef.doc(record.id).set(record.toMap()));
      return;
    }
    _debts.insert(0, debt);
    _debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
    await _saveAll();
  }

  Future<void> recordDebtRepayment(String debtId, double amount, String? note) async {
    await _updateDebt(debtId, (old) {
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
      return old.copyWith(
        paidAmount: newPaid,
        repayments: newRepayments,
        isSettled: newPaid >= old.totalAmount,
      );
    });
  }

  Future<void> settleDebt(String debtId) async {
    await _updateDebt(debtId, (old) {
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
      return old.copyWith(
        paidAmount: old.totalAmount,
        repayments: newRepayments,
        isSettled: true,
      );
    });
  }

  Future<void> _updateDebt(String debtId, DebtItem Function(DebtItem old) change) async {
    if (isCloudSync) {
      await _cloudWrite(() => _db.runTransaction((tx) async {
            final ref = _debtsRef.doc(debtId);
            final snap = await tx.get(ref);
            if (!snap.exists) return;
            final updated = change(DebtItem.fromMap({...snap.data()!, 'id': snap.id}));
            tx.update(ref, {
              'paidAmount': updated.paidAmount,
              'repayments': updated.repayments.map((r) => r.toMap()).toList(),
              'isSettled': updated.isSettled,
            });
          }));
      return;
    }
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index == -1) return;
    _debts[index] = change(_debts[index]);
    notifyListeners();
    await _saveAll();
  }

  Future<void> deleteDebt(String debtId) async {
    if (isCloudSync) {
      await _cloudWrite(() => _debtsRef.doc(debtId).delete());
      return;
    }
    _debts.removeWhere((d) => d.id == debtId);
    notifyListeners();
    await _saveAll();
  }

  // ─── SPLITWISE GROUPS MANAGEMENT ──────────────────────────────

  /// The member entry representing the signed-in user (or "You" offline).
  GroupMember get selfMember {
    final user = _user;
    if (user == null) {
      return const GroupMember(id: GroupMember.localSelfId, name: 'You', status: MemberStatus.active);
    }
    return GroupMember(
      id: user.uid,
      name: _myDisplayName,
      uid: user.uid,
      email: user.email?.toLowerCase(),
      username: _profile?.username,
      status: MemberStatus.active,
    );
  }

  /// Member id of the current user inside [group], if they belong to it.
  String? myMemberId(SplitGroup group) {
    if (!isCloudSync) return GroupMember.localSelfId;
    return group.memberByUid(_user!.uid)?.id;
  }

  bool isGroupAdmin(SplitGroup group) => !isCloudSync || group.isAdmin(_user!.uid);

  SplitGroup? groupById(String groupId) {
    for (final g in splitGroups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  Future<void> createSplitGroup({
    required String name,
    String icon = '👥',
    List<GroupMember> otherMembers = const [],
  }) async {
    final self = selfMember;
    final group = SplitGroup(
      id: newId(),
      name: name,
      icon: icon,
      members: [self, ...otherMembers],
      createdAt: DateTime.now(),
      createdBy: _user?.uid,
      admins: [if (_user != null) _user!.uid],
    );
    if (isCloudSync) {
      await _cloudWrite(() => _groupsRef.doc(group.id).set(group.toMap()));
      return;
    }
    _splitGroups.insert(0, group);
    notifyListeners();
    await _saveAll();
  }

  Future<void> addGroupMember(String groupId, GroupMember member) async {
    await _updateGroup(groupId, (g) {
      final duplicate = g.members.any((m) =>
          (member.uid != null && m.uid == member.uid) ||
          (member.email != null && m.email?.toLowerCase() == member.email!.toLowerCase()));
      if (duplicate) throw const GroupActionException('This person is already in the group.');
      return g.copyWith(members: [...g.members, member]);
    });
  }

  Future<void> updateGroupMember(String groupId, GroupMember member) async {
    await _updateGroup(groupId, (g) => g.copyWith(
          members: g.members.map((m) => m.id == member.id ? member : m).toList(),
        ));
  }

  Future<void> removeGroupMember(String groupId, String memberId) async {
    final balance = getGroupMemberBalances(groupId)[memberId] ?? 0.0;
    if (balance.abs() >= 0.01) {
      throw const GroupActionException('Settle this member\'s balance before removing them.');
    }
    await _updateGroup(groupId, (g) {
      final removed = g.memberById(memberId);
      return g.copyWith(
        members: g.members.where((m) => m.id != memberId).toList(),
        admins: g.admins.where((a) => a != removed?.uid).toList(),
      );
    });
  }

  Future<void> renameSplitGroup(String groupId, String name) async {
    await _updateGroup(groupId, (g) => g.copyWith(name: name));
  }

  Future<void> _updateGroup(String groupId, SplitGroup Function(SplitGroup g) change) async {
    if (isCloudSync) {
      await _db.runTransaction((tx) async {
        final ref = _groupsRef.doc(groupId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const GroupActionException('This group no longer exists.');
        final updated = change(SplitGroup.fromMap({...snap.data()!, 'id': snap.id}));
        tx.set(ref, updated.toMap());
      });
      return;
    }
    final index = _splitGroups.indexWhere((g) => g.id == groupId);
    if (index == -1) return;
    _splitGroups[index] = change(_splitGroups[index]);
    notifyListeners();
    await _saveAll();
  }

  Future<void> acceptGroupInvite(String groupId) async {
    final user = _user;
    if (user == null) return;
    final email = user.email?.toLowerCase();
    await _updateGroup(groupId, (g) => g.copyWith(
          members: g.members.map((m) {
            final isMe = m.status == MemberStatus.invited &&
                (m.uid == user.uid || (m.uid == null && email != null && m.email?.toLowerCase() == email));
            if (!isMe) return m;
            return m.copyWith(
              uid: user.uid,
              email: email,
              username: _profile?.username,
              status: MemberStatus.active,
            );
          }).toList(),
        ));
  }

  Future<void> declineGroupInvite(String groupId) async {
    final user = _user;
    if (user == null) return;
    final email = user.email?.toLowerCase();
    await _updateGroup(groupId, (g) => g.copyWith(
          members: g.members.map((m) {
            final isMe = m.status == MemberStatus.invited &&
                (m.uid == user.uid || (m.uid == null && email != null && m.email?.toLowerCase() == email));
            // Keep the member (their past expenses still reference them) but unlink the invite
            return isMe ? m.copyWith(status: MemberStatus.placeholder, clearUid: true, clearEmail: true) : m;
          }).toList(),
        ));
  }

  Future<void> deleteSplitGroup(String groupId) async {
    if (isCloudSync) {
      await _cloudWrite(() async {
        final expenses = await _groupsRef.doc(groupId).collection('expenses').get();
        final batch = _db.batch();
        for (final doc in expenses.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(_groupsRef.doc(groupId));
        await batch.commit();
      });
      return;
    }
    _splitGroups.removeWhere((g) => g.id == groupId);
    _groupExpenses.removeWhere((ge) => ge.groupId == groupId);
    notifyListeners();
    await _saveAll();
  }

  Future<void> addGroupExpense(GroupExpense expense) async {
    if (isCloudSync) {
      await _cloudWrite(() => _groupsRef.doc(expense.groupId).collection('expenses').doc(expense.id).set(expense.toMap()));
      return;
    }
    _groupExpenses.insert(0, expense);
    _groupExpenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveAll();
  }

  /// Records that [fromId] paid [toId] back, which moves both balances toward zero.
  Future<void> recordGroupSettlement(String groupId, String fromId, String toId, double amount) async {
    await addGroupExpense(GroupExpense(
      id: newId(),
      groupId: groupId,
      title: 'Settlement',
      amount: amount,
      paidBy: fromId,
      splitAmong: [toId],
      date: DateTime.now(),
      isSettlement: true,
      createdBy: _user?.uid,
    ));
  }

  Future<void> deleteGroupExpense(String groupId, String expenseId) async {
    if (isCloudSync) {
      await _cloudWrite(() => _groupsRef.doc(groupId).collection('expenses').doc(expenseId).delete());
      return;
    }
    _groupExpenses.removeWhere((ge) => ge.id == expenseId);
    notifyListeners();
    await _saveAll();
  }

  List<GroupExpense> getExpensesForGroup(String groupId) {
    if (isCloudSync) return List.unmodifiable(_cloudGroupExpenses[groupId] ?? const []);
    return _groupExpenses.where((ge) => ge.groupId == groupId).toList();
  }

  double getGroupTotalSpent(String groupId) {
    return getExpensesForGroup(groupId)
        .where((ge) => !ge.isSettlement)
        .fold(0.0, (sum, ge) => sum + ge.amount);
  }

  /// Net balance per member id (+ is owed to member, - is owed by member)
  Map<String, double> getGroupMemberBalances(String groupId) {
    final group = groupById(groupId);
    if (group == null) return {};
    final Map<String, double> balances = {
      for (final member in group.members) member.id: 0.0,
    };

    for (final exp in getExpensesForGroup(groupId)) {
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

  /// Minimal list of payments that would bring every balance to zero.
  List<SettlementSuggestion> getSettlementSuggestions(String groupId) {
    final balances = getGroupMemberBalances(groupId);
    final debtors = balances.entries.where((e) => e.value < -0.009).map((e) => MapEntry(e.key, -e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final creditors = balances.entries.where((e) => e.value > 0.009).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final suggestions = <SettlementSuggestion>[];
    var i = 0, j = 0;
    final owed = debtors.map((e) => e.value).toList();
    final due = creditors.map((e) => e.value).toList();
    while (i < debtors.length && j < creditors.length) {
      final amount = owed[i] < due[j] ? owed[i] : due[j];
      suggestions.add(SettlementSuggestion(fromId: debtors[i].key, toId: creditors[j].key, amount: amount));
      owed[i] -= amount;
      due[j] -= amount;
      if (owed[i] < 0.01) i++;
      if (due[j] < 0.01) j++;
    }
    return suggestions;
  }

  // ─── CLOUD SYNC (signed-in users share groups & lending) ──────

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _groupsRef => _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _debtsRef => _db.collection('debts');

  String get _myDisplayName {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return _profile?.displayName ?? _user?.email?.split('@').first ?? 'You';
  }

  String newId() {
    try {
      return _db.collection('_').doc().id;
    } catch (_) {
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
  }

  void _listenToAuth() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    } catch (e) {
      if (kDebugMode) print('ExpenseProvider auth listen error: $e');
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user?.uid == _user?.uid) return;
    _stopCloudSync();
    _user = user;
    if (user == null) {
      notifyListeners();
      return;
    }
    _isCloudLoading = true;
    notifyListeners();

    _profile = await UserDirectoryService().upsertCurrentUser(user);
    await _migrateLocalDataToCloud(user);
    await _claimDebtsSentToMyEmail(user);
    if (_user?.uid != user.uid) return; // Signed out meanwhile
    _startCloudSync(user);
  }

  void _startCloudSync(User user) {
    final uid = user.uid;
    final email = user.email?.toLowerCase();

    _cloudSubs.add(_groupsRef.where('memberUids', arrayContains: uid).snapshots().listen((snap) {
      _cloudGroups = snap.docs.map((d) => SplitGroup.fromMap({...d.data(), 'id': d.id})).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _syncExpenseListeners();
      _isCloudLoading = false;
      notifyListeners();
    }, onError: _onCloudError));

    _cloudSubs.add(_groupsRef.where('invitedUids', arrayContains: uid).snapshots().listen((snap) {
      _invitesByUid = snap.docs.map((d) => SplitGroup.fromMap({...d.data(), 'id': d.id})).toList();
      notifyListeners();
    }, onError: _onCloudError));

    if (email != null) {
      _cloudSubs.add(_groupsRef.where('invitedEmails', arrayContains: email).snapshots().listen((snap) {
        _invitesByEmail = snap.docs.map((d) => SplitGroup.fromMap({...d.data(), 'id': d.id})).toList();
        notifyListeners();
      }, onError: _onCloudError));
    }

    _cloudSubs.add(_debtsRef.where('participants', arrayContains: uid).snapshots().listen((snap) {
      _cloudDebts = snap.docs
          .map((d) => DebtItem.fromMap({...d.data(), 'id': d.id}).forViewer(uid))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: _onCloudError));
  }

  void _syncExpenseListeners() {
    final ids = _cloudGroups.map((g) => g.id).toSet();
    for (final id in _expenseSubs.keys.where((id) => !ids.contains(id)).toList()) {
      _expenseSubs.remove(id)?.cancel();
      _cloudGroupExpenses.remove(id);
    }
    for (final id in ids.where((id) => !_expenseSubs.containsKey(id))) {
      _expenseSubs[id] = _groupsRef.doc(id).collection('expenses').snapshots().listen((snap) {
        _cloudGroupExpenses[id] = snap.docs
            .map((d) => GroupExpense.fromMap({...d.data(), 'id': d.id, 'groupId': id}))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }, onError: _onCloudError);
    }
  }

  void _stopCloudSync() {
    for (final sub in _cloudSubs) {
      sub.cancel();
    }
    _cloudSubs.clear();
    for (final sub in _expenseSubs.values) {
      sub.cancel();
    }
    _expenseSubs.clear();
    _cloudGroups = [];
    _cloudGroupExpenses.clear();
    _invitesByUid = [];
    _invitesByEmail = [];
    _cloudDebts = [];
    _profile = null;
    _isCloudLoading = false;
  }

  void _onCloudError(Object e) {
    _isCloudLoading = false;
    _lastCloudError = e.toString();
    if (kDebugMode) print('ExpenseProvider cloud error: $e');
    notifyListeners();
  }

  Future<void> _cloudWrite(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      _onCloudError(e);
      rethrow;
    }
  }

  /// Uploads groups and lending records created offline so they can be shared.
  Future<void> _migrateLocalDataToCloud(User user) async {
    if (_splitGroups.isEmpty && _debts.isEmpty) return;
    try {
      final batch = _db.batch();
      final self = selfMember;

      for (final group in _splitGroups) {
        String mapId(String id) => id == GroupMember.localSelfId ? self.id : id;
        final migrated = SplitGroup(
          id: group.id,
          name: group.name,
          icon: group.icon,
          members: group.members.map((m) => m.id == GroupMember.localSelfId ? self : m).toList(),
          createdAt: group.createdAt,
          createdBy: user.uid,
          admins: [user.uid],
        );
        batch.set(_groupsRef.doc(group.id), migrated.toMap());
        for (final exp in _groupExpenses.where((e) => e.groupId == group.id)) {
          final moved = GroupExpense(
            id: exp.id,
            groupId: exp.groupId,
            title: exp.title,
            amount: exp.amount,
            paidBy: mapId(exp.paidBy),
            splitAmong: exp.splitAmong.map(mapId).toList(),
            date: exp.date,
            note: exp.note,
            isSettlement: exp.isSettlement,
            createdBy: user.uid,
          );
          batch.set(_groupsRef.doc(group.id).collection('expenses').doc(exp.id), moved.toMap());
        }
      }

      for (final debt in _debts) {
        final moved = DebtItem(
          id: debt.id,
          personName: debt.personName,
          totalAmount: debt.totalAmount,
          paidAmount: debt.paidAmount,
          type: debt.type,
          createdAt: debt.createdAt,
          dueDate: debt.dueDate,
          note: debt.note,
          repayments: debt.repayments,
          isSettled: debt.isSettled,
          ownerUid: user.uid,
          ownerName: _myDisplayName,
        );
        batch.set(_debtsRef.doc(debt.id), moved.toMap());
      }

      await batch.commit();
      _splitGroups = [];
      _groupExpenses = [];
      _debts = [];
      await _saveAll();
    } catch (e) {
      if (kDebugMode) print('ExpenseProvider migration error: $e');
    }
  }

  /// Links lending records that were addressed to this email before signup.
  Future<void> _claimDebtsSentToMyEmail(User user) async {
    final email = user.email?.toLowerCase();
    if (email == null) return;
    try {
      final pending = await _debtsRef
          .where('counterpartyEmail', isEqualTo: email)
          .where('counterpartyUid', isNull: true)
          .get();
      for (final doc in pending.docs) {
        final data = doc.data();
        if (data['counterpartyUid'] != null || data['ownerUid'] == user.uid) continue;
        await doc.reference.update({
          'counterpartyUid': user.uid,
          'participants': FieldValue.arrayUnion([user.uid]),
        });
      }
    } catch (e) {
      if (kDebugMode) print('ExpenseProvider claim debts error: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _stopCloudSync();
    super.dispose();
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
