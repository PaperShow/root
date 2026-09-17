import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/expense.dart';
import '../models/split_group.dart';
import '../providers/expense_provider.dart';
import '../utils/app_fonts.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  final bool isEmbedded;
  const ExpenseTrackerScreen({super.key, this.isEmbedded = false});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF202020);
  static const Color expenseCoral = Color(0xFFFF6B6B);
  static const Color incomeMint = Color(0xFF1DD1A1);

  // Sub-navigation tabs: 0 = SPENDING, 1 = SPLIT GROUPS, 2 = LENDING
  int _mainTab = 0;
  String _filterType = 'ALL'; // ALL, EXPENSE, INCOME
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: pureBlack,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ─── TOP BAR ───────────────────────────────────
                _buildTopBar(provider),

                // ─── SEGMENTED SUB-TABS ────────────────────────
                _buildSegmentedTabRow(),

                // ─── MAIN BODY ─────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _mainTab,
                    children: [
                      // Tab 0: Personal Spending
                      _buildSpendingTab(provider),

                      // Tab 1: Splitwise Groups
                      _buildSplitGroupsTab(provider),

                      // Tab 2: Lending & Borrowing (IOU)
                      _buildLendingTab(provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── TOP BAR & HEADER ──────────────────────────────────────────

  Widget _buildTopBar(ExpenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          if (!widget.isEmbedded) ...[
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: surfaceBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Text(
            'EXPENSES',
            style: AppFonts.jetBrainsMono(
              color: terminalGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (_mainTab == 0) ...[
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white60, size: 18),
              tooltip: 'Set Budget',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showSetBudgetDialog(context, provider),
            ),
            _buildPrimaryActionButton(
              label: 'NEW',
              onTap: () => _showAddExpenseSheet(context, provider),
            ),
          ] else if (_mainTab == 1) ...[
            _buildPrimaryActionButton(
              label: 'NEW GROUP',
              onTap: () => _showCreateGroupDialog(context, provider),
            ),
          ] else if (_mainTab == 2) ...[
            _buildPrimaryActionButton(
              label: 'NEW DEBT',
              onTap: () => _showAddDebtDialog(context, provider),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: terminalGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: Colors.black),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      child: Row(
        children: [
          _buildSegmentTabItem(0, 'SPENDING'),
          _buildSegmentTabItem(1, 'SPLIT GROUPS'),
          _buildSegmentTabItem(2, 'LENDING (IOU)'),
        ],
      ),
    );
  }

  Widget _buildSegmentTabItem(int index, String label) {
    final isSelected = _mainTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _mainTab = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? pureBlack : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: terminalGreen.withValues(alpha: 0.6)) : null,
          ),
          child: Text(
            label,
            style: AppFonts.jetBrainsMono(
              color: isSelected ? terminalGreen : Colors.white54,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 0: SPENDING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSpendingTab(ExpenseProvider provider) {
    final totalExpense = provider.totalExpenseThisMonth;
    final totalIncome = provider.totalIncomeThisMonth;
    final netBalance = provider.netBalanceThisMonth;
    final budget = provider.monthlyBudget;
    final budgetRatio = provider.budgetProgressRatio;

    final filteredItems = provider.items.where((item) {
      if (_filterType == 'EXPENSE') return item.type == ExpenseType.expense;
      if (_filterType == 'INCOME') return item.type == ExpenseType.income;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildBalanceCard(netBalance, totalIncome, totalExpense),
        const SizedBox(height: 12),
        _buildBudgetCard(provider, totalExpense, budget, budgetRatio),
        const SizedBox(height: 16),
        if (provider.categoryBreakdownThisMonth.isNotEmpty) ...[
          _buildCategoryBreakdown(provider),
          const SizedBox(height: 16),
        ],
        _buildTransactionsHeader(filteredItems.length),
        const SizedBox(height: 10),
        if (filteredItems.isEmpty)
          _buildEmptyState('NO TRANSACTIONS', 'Tap "+ NEW" to add an expense or income.')
        else
          ..._buildGroupedTransactionList(filteredItems, provider),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBalanceCard(double netBalance, double totalIncome, double totalExpense) {
    final isPositive = netBalance >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY NET SAVINGS',
            style: AppFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(netBalance),
            style: AppFonts.jetBrainsMono(
              color: isPositive ? terminalGreen : expenseCoral,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: incomeMint.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, color: incomeMint, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INCOME', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                            Text(
                              _currencyFormat.format(totalIncome),
                              style: AppFonts.jetBrainsMono(color: incomeMint, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: expenseCoral.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: expenseCoral, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXPENSES', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                            Text(
                              _currencyFormat.format(totalExpense),
                              style: AppFonts.jetBrainsMono(color: expenseCoral, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(ExpenseProvider provider, double totalExpense, double budget, double ratio) {
    final percent = (ratio * 100).round();
    final remaining = budget - totalExpense;
    final isNearLimit = ratio > 0.85;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUDGET: ${_currencyFormat.format(budget)}',
                style: AppFonts.jetBrainsMono(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                '$percent% USED',
                style: AppFonts.jetBrainsMono(
                  color: isNearLimit ? expenseCoral : terminalGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? expenseCoral : (ratio > 0.6 ? Colors.amber : terminalGreen),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${_currencyFormat.format(totalExpense)}',
                style: AppFonts.inter(color: Colors.white54, fontSize: 10),
              ),
              Text(
                remaining >= 0
                    ? '${_currencyFormat.format(remaining)} left'
                    : '${_currencyFormat.format(remaining.abs())} over',
                style: AppFonts.jetBrainsMono(
                  color: remaining >= 0 ? Colors.white70 : expenseCoral,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(ExpenseProvider provider) {
    final breakdown = provider.categoryBreakdownThisMonth;
    final totalExpense = provider.totalExpenseThisMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY BREAKDOWN',
          style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: breakdown.entries.map((entry) {
              final cat = ExpenseCategory.findById(entry.key);
              final amount = entry.value;
              final percent = totalExpense > 0 ? ((amount / totalExpense) * 100).round() : 0;

              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cat.color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(cat.icon, color: cat.color, size: 16),
                        Text('$percent%', style: AppFonts.jetBrainsMono(color: cat.color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name, style: AppFonts.inter(color: Colors.white70, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_currencyFormat.format(amount), style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('HISTORY ($count)', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        Row(
          children: [
            _buildFilterChip('ALL'),
            const SizedBox(width: 4),
            _buildFilterChip('EXPENSE'),
            const SizedBox(width: 4),
            _buildFilterChip('INCOME'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String type) {
    final isSelected = _filterType == type;
    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? terminalGreen : cardDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? terminalGreen : surfaceBorder),
        ),
        child: Text(
          type,
          style: AppFonts.jetBrainsMono(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTransactionList(List<ExpenseItem> items, ExpenseProvider provider) {
    final List<Widget> widgets = [];
    DateTime? lastDate;

    for (final item in items) {
      final isNewDay = lastDate == null ||
          item.date.year != lastDate.year ||
          item.date.month != lastDate.month ||
          item.date.day != lastDate.day;

      if (isNewDay) {
        lastDate = item.date;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              _formatDateHeader(item.date).toUpperCase(),
              style: AppFonts.jetBrainsMono(color: Colors.white30, fontSize: 9, letterSpacing: 1),
            ),
          ),
        );
      }

      widgets.add(_buildTransactionTile(item, provider));
      widgets.add(const SizedBox(height: 5));
    }

    return widgets;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(date);
  }

  Widget _buildTransactionTile(ExpenseItem item, ExpenseProvider provider) {
    final isExpense = item.type == ExpenseType.expense;
    final cat = item.category;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: expenseCoral, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      onDismissed: (_) {
        provider.deleteExpense(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            content: Text('Deleted "${item.title}"', style: AppFonts.inter(color: Colors.white)),
            action: SnackBarAction(label: 'UNDO', textColor: terminalGreen, onPressed: () => provider.addExpense(item)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(cat.icon, color: cat.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(cat.name, style: AppFonts.inter(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${_currencyFormat.format(item.amount)}',
              style: AppFonts.jetBrainsMono(
                color: isExpense ? expenseCoral : incomeMint,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: SPLITWISE GROUPS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSplitGroupsTab(ExpenseProvider provider) {
    final groups = provider.splitGroups;
    if (groups.isEmpty) {
      return _buildEmptyState('NO SPLIT GROUPS', 'Create a group to split trip, dinner or flat expenses.');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      children: [
        ...groups.map((g) => _buildGroupCard(g, provider)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildGroupCard(SplitGroup group, ExpenseProvider provider) {
    final totalSpent = provider.getGroupTotalSpent(group.id);
    final balances = provider.getGroupMemberBalances(group.id);
    final myBalance = balances['You'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${group.members.length} members: ${group.members.join(", ")}',
                      style: AppFonts.inter(color: Colors.white54, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                onPressed: () => provider.deleteSplitGroup(group.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL SPENT', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                    Text(_currencyFormat.format(totalSpent), style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('YOUR BALANCE', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                    Text(
                      myBalance >= 0 ? '+${_currencyFormat.format(myBalance)} (lent)' : '-${_currencyFormat.format(myBalance.abs())} (owe)',
                      style: AppFonts.jetBrainsMono(
                        color: myBalance >= 0 ? terminalGreen : expenseCoral,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: terminalGreen,
                    side: const BorderSide(color: surfaceBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _showAddGroupExpenseDialog(context, provider, group),
                  child: Text('+ ADD SPLIT EXPENSE', style: AppFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: surfaceBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                ),
                onPressed: () => _showGroupDetailsSheet(context, provider, group),
                child: Text('DETAILS', style: AppFonts.jetBrainsMono(fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: LENDING & BORROWING (IOU WITH BREAKS / PARTIAL REPAYMENT)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLendingTab(ExpenseProvider provider) {
    final debts = provider.debts;
    final toReceive = provider.totalToReceive;
    final toPay = provider.totalToPay;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        // SUMMARY HERO TILES
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: incomeMint.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I LENT (TO RECEIVE)', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(toReceive),
                      style: AppFonts.jetBrainsMono(color: incomeMint, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: expenseCoral.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I BORROWED (TO PAY)', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(toPay),
                      style: AppFonts.jetBrainsMono(color: expenseCoral, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (debts.isEmpty)
          _buildEmptyState('NO ACTIVE DEBTS', 'Record money you gave to friends or borrowed with partial return tracking.')
        else ...[
          Text('ACTIVE & PENDING', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...debts.where((d) => !d.isSettled).map((d) => _buildDebtTile(d, provider)),
          if (debts.any((d) => d.isSettled)) ...[
            const SizedBox(height: 16),
            Text('SETTLED RECORDS', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...debts.where((d) => d.isSettled).map((d) => _buildDebtTile(d, provider)),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDebtTile(DebtItem debt, ExpenseProvider provider) {
    final isLent = debt.type == DebtType.lent;
    final accent = isLent ? incomeMint : expenseCoral;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: debt.isSettled ? surfaceBorder : accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLent ? 'LENT TO' : 'BORROWED FROM',
                  style: AppFonts.jetBrainsMono(color: accent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  debt.personName,
                  style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              if (debt.isSettled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: terminalGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('SETTLED', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => provider.deleteDebt(debt.id),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Numbers row: Total, Repaid in breaks, Left
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                  Text(_currencyFormat.format(debt.totalAmount), style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('REPAID', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                  Text(_currencyFormat.format(debt.paidAmount), style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('LEFT / DUE', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 9)),
                  Text(_currencyFormat.format(debt.remainingAmount), style: AppFonts.jetBrainsMono(color: accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: debt.progressRatio,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(debt.isSettled ? terminalGreen : accent),
            ),
          ),
          const SizedBox(height: 6),

          if (debt.note != null && debt.note!.isNotEmpty) ...[
            Text('Note: ${debt.note}', style: AppFonts.inter(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 8),
          ],

          // Repayment installment records
          if (debt.repayments.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PAYMENT BREAKS (${debt.repayments.length}):', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 8)),
                  ...debt.repayments.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('+${_currencyFormat.format(r.amount)} (${r.note ?? "Installment"})', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 10)),
                          Text(DateFormat('MMM d').format(r.date), style: AppFonts.jetBrainsMono(color: Colors.white30, fontSize: 9)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action buttons: Record Partial Payment / Settle
          if (!debt.isSettled)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: terminalGreen,
                      side: const BorderSide(color: surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showRecordRepaymentDialog(context, provider, debt),
                    child: Text('+ PAY IN BREAKS', style: AppFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: terminalGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => provider.settleDebt(debt.id),
                  child: Text('SETTLE ALL', style: AppFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white24, size: 40),
          const SizedBox(height: 10),
          Text(title, style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: AppFonts.inter(color: Colors.white24, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS & BOTTOM SHEETS
  // ═══════════════════════════════════════════════════════════════

  void _showAddExpenseSheet(BuildContext context, ExpenseProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: surfaceBorder),
      ),
      builder: (ctx) => _AddExpenseSheetContent(provider: provider),
    );
  }

  void _showSetBudgetDialog(BuildContext context, ExpenseProvider provider) {
    final controller = TextEditingController(text: provider.monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        title: Text('SET MONTHLY BUDGET', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: AppFonts.jetBrainsMono(color: terminalGreen),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) provider.setMonthlyBudget(val);
              Navigator.of(ctx).pop();
            },
            child: Text('SAVE', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddDebtDialog(BuildContext context, ExpenseProvider provider) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DebtType type = DebtType.lent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: cardDark,
          title: Text('RECORD LENDING / DEBT', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 13, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDlgState(() => type = DebtType.lent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: type == DebtType.lent ? incomeMint.withValues(alpha: 0.2) : Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: type == DebtType.lent ? incomeMint : surfaceBorder),
                          ),
                          child: Text('I LENT MONEY', style: AppFonts.jetBrainsMono(color: type == DebtType.lent ? incomeMint : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDlgState(() => type = DebtType.borrowed),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: type == DebtType.borrowed ? expenseCoral.withValues(alpha: 0.2) : Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: type == DebtType.borrowed ? expenseCoral : surfaceBorder),
                          ),
                          child: Text('I BORROWED', style: AppFonts.jetBrainsMono(color: type == DebtType.borrowed ? expenseCoral : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: AppFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Person's name (e.g. Alex)",
                    hintStyle: AppFonts.inter(color: Colors.white30, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: 'Amount',
                    hintStyle: AppFonts.jetBrainsMono(color: Colors.white30),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: AppFonts.inter(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Note (e.g. Dinner share, tickets)',
                    hintStyle: AppFonts.inter(color: Colors.white30, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text.trim());
                if (name.isNotEmpty && amt != null && amt > 0) {
                  provider.addDebt(
                    DebtItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      personName: name,
                      totalAmount: amt,
                      type: type,
                      createdAt: DateTime.now(),
                      note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: Text('SAVE', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordRepaymentDialog(BuildContext context, ExpenseProvider provider, DebtItem debt) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Installment');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        title: Text('RECORD REPAYMENT', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remaining: ${_currencyFormat.format(debt.remainingAmount)}', style: AppFonts.jetBrainsMono(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: 'Amount paid in this break',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: AppFonts.inter(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
            onPressed: () {
              final val = double.tryParse(amountCtrl.text.trim());
              if (val != null && val > 0) {
                provider.recordDebtRepayment(debt.id, val, noteCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: Text('CONFIRM', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, ExpenseProvider provider) {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController(text: 'You, ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        title: Text('NEW SPLIT GROUP', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 13, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: AppFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Group Name (e.g. Goa Trip, Flatmates)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersCtrl,
              style: AppFonts.inter(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Members separated by comma (e.g. You, Alex, Sam)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final memList = membersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (name.isNotEmpty && memList.isNotEmpty) {
                provider.createSplitGroup(
                  SplitGroup(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    members: memList,
                    createdAt: DateTime.now(),
                  ),
                );
              }
              Navigator.of(ctx).pop();
            },
            child: Text('CREATE', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddGroupExpenseDialog(BuildContext context, ExpenseProvider provider, SplitGroup group) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paidBy = group.members.first;
    List<String> splitAmong = List<String>.from(group.members);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: cardDark,
          title: Text('ADD GROUP EXPENSE', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 13, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: AppFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(hintText: 'Title (e.g. Dinner, Fuel)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(prefixText: '\$ ', hintText: 'Total Amount', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 12),
                Text('PAID BY:', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 10)),
                DropdownButton<String>(
                  value: paidBy,
                  dropdownColor: cardDark,
                  isExpanded: true,
                  items: group.members.map((m) => DropdownMenuItem(value: m, child: Text(m, style: AppFonts.inter(color: Colors.white)))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => paidBy = val);
                  },
                ),
                const SizedBox(height: 10),
                Text('SPLIT EQUALLY AMONG:', style: AppFonts.jetBrainsMono(color: Colors.white54, fontSize: 10)),
                Wrap(
                  spacing: 6,
                  children: group.members.map((m) {
                    final isIncluded = splitAmong.contains(m);
                    return FilterChip(
                      label: Text(m, style: TextStyle(color: isIncluded ? Colors.black : Colors.white70, fontSize: 10)),
                      selected: isIncluded,
                      selectedColor: terminalGreen,
                      backgroundColor: Colors.black,
                      onSelected: (val) {
                        setDlgState(() {
                          if (val) {
                            splitAmong.add(m);
                          } else if (splitAmong.length > 1) {
                            splitAmong.remove(m);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim());
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty && amt != null && amt > 0 && splitAmong.isNotEmpty) {
                  provider.addGroupExpense(
                    GroupExpense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      groupId: group.id,
                      title: title,
                      amount: amt,
                      paidBy: paidBy,
                      splitAmong: splitAmong,
                      date: DateTime.now(),
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: Text('ADD', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetailsSheet(BuildContext context, ExpenseProvider provider, SplitGroup group) {
    final expenses = provider.getExpensesForGroup(group.id);
    final balances = provider.getGroupMemberBalances(group.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('// ${group.name.toUpperCase()} BALANCES', style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: balances.entries.map((e) {
                  final isOwed = e.value >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: AppFonts.inter(color: Colors.white, fontSize: 12)),
                        Text(
                          isOwed ? '+${_currencyFormat.format(e.value)}' : '-${_currencyFormat.format(e.value.abs())}',
                          style: AppFonts.jetBrainsMono(color: isOwed ? terminalGreen : expenseCoral, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text('EXPENSES LOG (${expenses.length})', style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: expenses.isEmpty
                  ? Center(child: Text('No group expenses yet', style: AppFonts.inter(color: Colors.white30)))
                  : ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (_, i) {
                        final ge = expenses[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ge.title, style: AppFonts.inter(color: Colors.white, fontSize: 12)),
                                  Text('Paid by ${ge.paidBy}', style: AppFonts.inter(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                              Text(_currencyFormat.format(ge.amount), style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExpenseSheetContent extends StatefulWidget {
  final ExpenseProvider provider;
  const _AddExpenseSheetContent({required this.provider});

  @override
  State<_AddExpenseSheetContent> createState() => _AddExpenseSheetContentState();
}

class _AddExpenseSheetContentState extends State<_AddExpenseSheetContent> {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color expenseCoral = Color(0xFFFF6B6B);
  static const Color incomeMint = Color(0xFF1DD1A1);
  static const Color surfaceBorder = Color(0xFF202020);

  ExpenseType _type = ExpenseType.expense;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategoryId = 'food';
  final DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();

    if (amount == null || amount <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount and title')),
      );
      return;
    }

    final item = ExpenseItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      categoryId: _selectedCategoryId,
      type: _type,
      date: _selectedDate,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    widget.provider.addExpense(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '// NEW TRANSACTION',
                  style: AppFonts.jetBrainsMono(
                    color: terminalGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      _buildTypeToggle('EXPENSE', ExpenseType.expense, expenseCoral),
                      _buildTypeToggle('INCOME', ExpenseType.income, incomeMint),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppFonts.jetBrainsMono(
                color: _type == ExpenseType.expense ? expenseCoral : incomeMint,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: surfaceBorder)),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [10, 50, 100, 500].map((val) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () {
                        final current = double.tryParse(_amountController.text) ?? 0.0;
                        _amountController.text = (current + val).toStringAsFixed(0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                        child: Text('+$val', style: AppFonts.jetBrainsMono(color: Colors.white70, fontSize: 10)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              style: AppFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Title (e.g. Lunch, Grocery, Fuel)',
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ExpenseCategory.defaultCategories.map((cat) {
                final isSelected = cat.id == _selectedCategoryId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = cat.id;
                      if (_selectedCategoryId == 'salary' && _type == ExpenseType.expense) {
                        _type = ExpenseType.income;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? cat.color.withValues(alpha: 0.2) : Colors.black,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? cat.color : surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, color: isSelected ? cat.color : Colors.white54, size: 12),
                        const SizedBox(width: 4),
                        Text(cat.name, style: AppFonts.inter(color: isSelected ? Colors.white : Colors.white60, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: terminalGreen, foregroundColor: Colors.black),
                onPressed: _submit,
                child: Text('ADD TRANSACTION', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String label, ExpenseType type, Color color) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: AppFonts.jetBrainsMono(color: isSelected ? color : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
