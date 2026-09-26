import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/expense.dart';
import '../models/split_group.dart';
import '../providers/expense_provider.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  final bool isEmbedded;
  const ExpenseTrackerScreen({super.key, this.isEmbedded = false});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  AppTheme get theme => AppTheme.of(context);
  Color get terminalGreen => theme.accent;
  Color get pureBlack => theme.scaffoldBackground;
  Color get cardDark => theme.card;
  Color get surfaceBorder => theme.border;
  Color get expenseCoral => theme.expenseCoral;
  Color get incomeMint => theme.incomeMint;
  Color get textPrimary => theme.textPrimary;
  Color get textSecondary => theme.textSecondary;
  Color get textMuted => theme.textMuted;

  // Sub-navigation tabs: 0 = SPENDING, 1 = SPLIT GROUPS, 2 = LENDING
  int _mainTab = 0;
  String _filterType = 'ALL'; // ALL, EXPENSE, INCOME
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackground,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // ─── TOP BAR (MINIMAL HEADER, NO CLUTTERED TOP BUTTON) ────
                    _buildTopBar(provider),

                    // ─── SEGMENTED SUB-TABS (MINIMAL PILL SELECTOR) ───────────
                    _buildSegmentedTabRow(),

                    // ─── MAIN BODY ─────────────────────────────────────────────
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

                // ─── FLOATING ACTION BUTTON (ABOVE BOTTOM NAV, NO COLLISION) ──
                Positioned(
                  right: 20,
                  bottom: widget.isEmbedded ? 94 : 28,
                  child: _buildFloatingAddButton(provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── FLOATING ACTION BUTTON (Transferred from top bar) ──────────
  Widget _buildFloatingAddButton(ExpenseProvider provider) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.16 : 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: theme.isLight ? const Color(0xFF18181B) : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (_mainTab == 0) {
              _showAddExpenseSheet(context, provider);
            } else if (_mainTab == 1) {
              _showCreateGroupSheet(context, provider);
            } else {
              _showAddDebtSheet(context, provider);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: theme.isLight ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR & HEADER (CLEAN & SPACIOUS, LIKE REFERENCE UI) ────
  Widget _buildTopBar(ExpenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isEmbedded) ...[
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: textPrimary,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'expenses',
                style: AppFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  color: textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'MONTHLY BUDGET • ${_currencyFormat.format(provider.monthlyBudget)}',
                style: AppFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Quick tune budget button
          InkWell(
            onTap: () => _showSetBudgetSheet(context, provider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.tune_rounded, color: textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEGMENTED SUB-TABS (MINIMAL PILL ROW LIKE REFERENCE UI) ──
  Widget _buildSegmentedTabRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.cardSecondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _buildSegmentTabItem(0, 'Personal'),
            _buildSegmentTabItem(1, 'Split Groups'),
            _buildSegmentTabItem(2, 'Lending (IOU)'),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTabItem(int index, String label) {
    final isSelected = _mainTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mainTab = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: theme.isLight ? 0.08 : 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppFonts.inter(
              color: isSelected
                  ? (theme.isLight ? Colors.white : Colors.black)
                  : textMuted,
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
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
    final totalIncome = provider.totalIncomeThisMonth;
    final totalExpense = provider.totalExpenseThisMonth;
    final netBalance = totalIncome - totalExpense;
    final budget = provider.monthlyBudget;
    final budgetRatio = budget > 0 ? (totalExpense / budget) : 0.0;

    final filteredItems = provider.items.where((item) {
      if (_filterType == 'EXPENSE') return item.type == ExpenseType.expense;
      if (_filterType == 'INCOME') return item.type == ExpenseType.income;
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, widget.isEmbedded ? 104 : 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // ─── 3-COLUMN METRIC CARD (REFERENCE UI KITCHEN/BEDROOM STYLE) ──
        _buildHeroOverviewCard(provider, netBalance, totalIncome, totalExpense, budget, budgetRatio),
        const SizedBox(height: 16),

        if (provider.categoryBreakdownThisMonth.isNotEmpty) ...[
          _buildCategoryBreakdown(provider),
          const SizedBox(height: 16),
        ],

        // ─── TRANSACTIONS LIST & FILTER ROW ─────────────────────────
        _buildTransactionsHeader(filteredItems.length),
        const SizedBox(height: 10),

        if (filteredItems.isEmpty)
          _buildEmptyState('NO TRANSACTIONS', 'Tap the + button below to log your first expense or income.')
        else
          ..._buildGroupedTransactionList(filteredItems, provider),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── 3-COLUMN HERO METRIC CARD (REFERENCE IMAGE 1 STYLE) ────────
  Widget _buildHeroOverviewCard(
    ExpenseProvider provider,
    double netBalance,
    double totalIncome,
    double totalExpense,
    double budget,
    double ratio,
  ) {
    final remaining = budget - totalExpense;
    final percent = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.02 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH',
                style: AppFonts.inter(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              InkWell(
                onTap: () => _showSetBudgetSheet(context, provider),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Budget: \$${budget.toInt()}',
                        style: AppFonts.inter(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-Column Metrics (Image 1 style)
          Row(
            children: [
              Expanded(
                child: _buildMetricColumn(
                  'SPENT',
                  _currencyFormat.format(totalExpense),
                  '$percent% used',
                  totalExpense > budget ? expenseCoral : textPrimary,
                ),
              ),
              Container(height: 38, width: 1, color: surfaceBorder),
              Expanded(
                child: _buildMetricColumn(
                  'INCOME',
                  _currencyFormat.format(totalIncome),
                  'received',
                  incomeMint,
                ),
              ),
              Container(height: 38, width: 1, color: surfaceBorder),
              Expanded(
                child: _buildMetricColumn(
                  'LEFT',
                  _currencyFormat.format(remaining),
                  remaining >= 0 ? 'Surplus' : 'Deficit',
                  remaining >= 0 ? textPrimary : expenseCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Progress Bar (Image 1 schedule/brightness slider style)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: theme.cardSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio > 1.0 ? expenseCoral : (theme.isLight ? const Color(0xFF18181B) : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, String subtext, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.inter(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppFonts.inter(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: AppFonts.inter(
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w300,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── CATEGORY BREAKDOWN ─────────────────────────────────────────
  Widget _buildCategoryBreakdown(ExpenseProvider provider) {
    final breakdown = provider.categoryBreakdownThisMonth;
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'TOP CATEGORIES',
            style: AppFonts.inter(
              color: textMuted,
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final entry = sorted[i];
              final cat = ExpenseCategory.findById(entry.key);
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(cat.icon, size: 16, color: cat.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: AppFonts.inter(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _currencyFormat.format(entry.value),
                      style: AppFonts.inter(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── TRANSACTIONS HEADER & FILTER ROW ───────────────────────────
  Widget _buildTransactionsHeader(int count) {
    return Row(
      children: [
        Text(
          'History ($count)',
          style: AppFonts.inter(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        // Filter pills (All, Expense, Income)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: theme.cardSecondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildMiniFilterTab('ALL', 'All'),
              _buildMiniFilterTab('EXPENSE', 'Expenses'),
              _buildMiniFilterTab('INCOME', 'Income'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFilterTab(String type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            color: isSelected
                ? (theme.isLight ? Colors.white : Colors.black)
                : textMuted,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              _formatDateHeader(item.date).toUpperCase(),
              style: AppFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
          ),
        );
      }

      widgets.add(_buildTransactionTile(item, provider));
      widgets.add(const SizedBox(height: 6));
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
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: expenseCoral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: expenseCoral, size: 20),
      ),
      onDismissed: (_) {
        provider.deleteExpense(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark,
            content: Text('Deleted "${item.title}"', style: AppFonts.inter(color: textPrimary)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.cardSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(cat.icon, size: 20, color: cat.color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppFonts.inter(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.name,
                    style: AppFonts.inter(
                      color: textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${_currencyFormat.format(item.amount)}',
              style: AppFonts.inter(
                color: isExpense ? textPrimary : incomeMint,
                fontSize: 15,
                fontWeight: FontWeight.w300,
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
      return _buildEmptyState('NO SPLIT GROUPS', 'Tap the + button below to create a group for shared trips or flat expenses.');
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, widget.isEmbedded ? 104 : 20),
      physics: const BouncingScrollPhysics(),
      children: [
        ...groups.map((g) => _buildGroupCard(g, provider)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildGroupCard(SplitGroup group, ExpenseProvider provider) {
    final expenses = provider.getExpensesForGroup(group.id);
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final userBalance = provider.getGroupMemberBalances(group.id)['You'] ?? 0.0;
    final isPositive = userBalance >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.02 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: AppFonts.inter(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      '${group.members.length} members • ${expenses.length} shared bills',
                      style: AppFonts.inter(color: textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: textMuted, size: 18),
                onPressed: () => provider.deleteSplitGroup(group.id),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Group Hero Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL SPENT', style: AppFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2)),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(totalSpent),
                        style: AppFonts.inter(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                Container(height: 28, width: 1, color: surfaceBorder),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR BALANCE', style: AppFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2)),
                        const SizedBox(height: 2),
                        Text(
                          isPositive ? '+${_currencyFormat.format(userBalance)}' : '-${_currencyFormat.format(userBalance.abs())}',
                          style: AppFonts.inter(
                            color: userBalance == 0 ? textMuted : (isPositive ? incomeMint : expenseCoral),
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: surfaceBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _showAddGroupExpenseSheet(context, provider, group),
                  child: Text('+ Add Expense', style: AppFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSecondary,
                  side: BorderSide(color: surfaceBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                onPressed: () => _showGroupDetailsSheet(context, provider, group),
                child: Text('Balances', style: AppFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: LENDING & BORROWING (IOU)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLendingTab(ExpenseProvider provider) {
    final debts = provider.debts;
    final toReceive = provider.totalToReceive;
    final toPay = provider.totalToPay;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, widget.isEmbedded ? 104 : 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // SUMMARY TILES
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I LENT (RECEIVE)', style: AppFonts.inter(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(
                      _currencyFormat.format(toReceive),
                      style: AppFonts.inter(color: incomeMint, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I BORROWED (PAY)', style: AppFonts.inter(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(
                      _currencyFormat.format(toPay),
                      style: AppFonts.inter(color: expenseCoral, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (debts.isEmpty)
          _buildEmptyState('NO LENDING RECORDS', 'Tap the + button below to log who owes you or who you owe money to.')
        else ...[
          Text('ACTIVE RECORDS', style: AppFonts.inter(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...debts.where((d) => !d.isSettled).map((d) => _buildDebtCard(d, provider)),
          if (debts.any((d) => d.isSettled)) ...[
            const SizedBox(height: 16),
            Text('SETTLED', style: AppFonts.inter(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            ...debts.where((d) => d.isSettled).map((d) => _buildDebtCard(d, provider)),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDebtCard(DebtItem debt, ExpenseProvider provider) {
    final isLent = debt.type == DebtType.lent;
    final progress = debt.totalAmount > 0 ? (debt.paidAmount / debt.totalAmount) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isLent ? incomeMint : expenseCoral).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLent ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                  color: isLent ? incomeMint : expenseCoral,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.personName,
                      style: AppFonts.inter(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      isLent ? 'Owes you money' : 'You owe this person',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: textMuted, size: 16),
                onPressed: () => provider.deleteDebt(debt.id),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total & Due stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ${_currencyFormat.format(debt.totalAmount)}', style: AppFonts.inter(color: textSecondary, fontSize: 11.5)),
              Text('Left: ${_currencyFormat.format(debt.remainingAmount)}', style: AppFonts.inter(color: isLent ? incomeMint : expenseCoral, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),

          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: theme.cardSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(isLent ? incomeMint : expenseCoral),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),

          if (!debt.isSettled)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: surfaceBorder),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showRecordRepaymentSheet(context, provider, debt),
                    child: Text('+ Record Payment', style: AppFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.isLight ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => provider.settleDebt(debt.id),
                  child: Text('Settle', style: AppFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE WIDGET ─────────────────────────────────────────
  Widget _buildEmptyState(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: textMuted.withValues(alpha: 0.5), size: 36),
            const SizedBox(height: 12),
            Text(title, style: AppFonts.inter(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(desc, style: AppFonts.inter(color: textMuted, fontSize: 11.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ALL POPUPS CONVERTED TO ROOT BOTTOM SHEETS (NO COLLISION!)
  // ═══════════════════════════════════════════════════════════════

  // 1. ADD EXPENSE BOTTOM SHEET
  void _showAddExpenseSheet(BuildContext context, ExpenseProvider provider) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _AddExpenseSheetContent(provider: provider),
    );
  }

  // 2. SET BUDGET BOTTOM SHEET (converted from showDialog)
  void _showSetBudgetSheet(BuildContext context, ExpenseProvider provider) {
    final controller = TextEditingController(text: provider.monthlyBudget.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Budget', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: AppFonts.inter(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: AppFonts.inter(color: textMuted, fontSize: 18),
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isLight ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  if (val != null && val > 0) provider.setMonthlyBudget(val);
                  Navigator.of(ctx).pop();
                },
                child: Text('Save Budget', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. ADD DEBT BOTTOM SHEET (converted from showDialog)
  void _showAddDebtSheet(BuildContext context, ExpenseProvider provider) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DebtType type = DebtType.lent;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Record Lending / Debt', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Type selector
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => type = DebtType.lent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: type == DebtType.lent
                                ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                                : theme.cardSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'I LENT MONEY',
                            style: AppFonts.inter(
                              color: type == DebtType.lent
                                  ? (theme.isLight ? Colors.white : Colors.black)
                                  : textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => type = DebtType.borrowed),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: type == DebtType.borrowed
                                ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                                : theme.cardSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'I BORROWED',
                            style: AppFonts.inter(
                              color: type == DebtType.borrowed
                                  ? (theme.isLight ? Colors.white : Colors.black)
                                  : textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameCtrl,
                  style: AppFonts.inter(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Person's name (e.g. Alex)",
                    filled: true,
                    fillColor: theme.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppFonts.inter(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: 'Amount',
                    filled: true,
                    fillColor: theme.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: AppFonts.inter(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Note (optional)',
                    filled: true,
                    fillColor: theme.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.isLight ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
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
                    child: Text('Save Record', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 4. RECORD REPAYMENT BOTTOM SHEET (converted from showDialog)
  void _showRecordRepaymentSheet(BuildContext context, ExpenseProvider provider, DebtItem debt) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Installment');

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Record Payment', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining Due: ${_currencyFormat.format(debt.remainingAmount)}',
              style: AppFonts.inter(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: AppFonts.inter(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: 'Amount paid',
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              style: AppFonts.inter(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isLight ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: () {
                  final val = double.tryParse(amountCtrl.text.trim());
                  if (val != null && val > 0) {
                    provider.recordDebtRepayment(debt.id, val, noteCtrl.text.trim());
                  }
                  Navigator.of(ctx).pop();
                },
                child: Text('Confirm Payment', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. CREATE SPLIT GROUP BOTTOM SHEET (converted from showDialog)
  void _showCreateGroupSheet(BuildContext context, ExpenseProvider provider) {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController(text: 'You, ');

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Split Group', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameCtrl,
              style: AppFonts.inter(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Group Name (e.g. Goa Trip, Flatmates)',
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersCtrl,
              style: AppFonts.inter(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Members separated by comma (e.g. You, Alex, Sam)',
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isLight ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
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
                child: Text('Create Group', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. ADD GROUP EXPENSE BOTTOM SHEET (converted from showDialog)
  void _showAddGroupExpenseSheet(BuildContext context, ExpenseProvider provider, SplitGroup group) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paidBy = group.members.first;
    List<String> splitAmong = List<String>.from(group.members);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add Group Expense', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: titleCtrl,
                  style: AppFonts.inter(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Title (e.g. Dinner, Fuel)',
                    filled: true,
                    fillColor: theme.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppFonts.inter(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: 'Total Amount',
                    filled: true,
                    fillColor: theme.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                Text('PAID BY', style: AppFonts.inter(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.cardSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: paidBy,
                    dropdownColor: cardDark,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: group.members.map((m) => DropdownMenuItem(value: m, child: Text(m, style: AppFonts.inter(color: textPrimary)))).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => paidBy = val);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text('SPLIT EQUALLY AMONG', style: AppFonts.inter(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: group.members.map((m) {
                    final isIncluded = splitAmong.contains(m);
                    return FilterChip(
                      label: Text(m, style: TextStyle(color: isIncluded ? (theme.isLight ? Colors.white : Colors.black) : textSecondary, fontSize: 11)),
                      selected: isIncluded,
                      selectedColor: theme.isLight ? const Color(0xFF18181B) : Colors.white,
                      backgroundColor: theme.cardSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide.none,
                      onSelected: (val) {
                        setSheetState(() {
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.isLight ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      final amt = double.tryParse(amountCtrl.text.trim());
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
                    child: Text('Record Shared Expense', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 7. GROUP BALANCES BOTTOM SHEET
  void _showGroupDetailsSheet(BuildContext context, ExpenseProvider provider, SplitGroup group) {
    final balances = provider.getGroupMemberBalances(group.id);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${group.name} Balances', style: AppFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: theme.cardSecondary, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: balances.entries.map((e) {
                  final isOwed = e.value >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: AppFonts.inter(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(
                          isOwed ? '+${_currencyFormat.format(e.value)}' : '-${_currencyFormat.format(e.value.abs())}',
                          style: AppFonts.inter(color: isOwed ? incomeMint : expenseCoral, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// ADD EXPENSE SHEET CONTENT (Image 2 & 4 style bottom sheet)
// ═════════════════════════════════════════════════════════════════

class _AddExpenseSheetContent extends StatefulWidget {
  final ExpenseProvider provider;
  const _AddExpenseSheetContent({required this.provider});

  @override
  State<_AddExpenseSheetContent> createState() => _AddExpenseSheetContentState();
}

class _AddExpenseSheetContentState extends State<_AddExpenseSheetContent> {
  AppTheme get theme => AppTheme.of(context);
  Color get terminalGreen => theme.accent;
  Color get expenseCoral => theme.expenseCoral;
  Color get incomeMint => theme.incomeMint;
  Color get surfaceBorder => theme.border;

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
    final categories = ExpenseCategory.defaultCategories;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: surfaceBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _type == ExpenseType.expense ? 'New Expense' : 'New Income',
                  style: AppFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: theme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Toggle (Expense vs Income pill)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.cardSecondary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = ExpenseType.expense),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _type == ExpenseType.expense
                              ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Expense',
                          style: AppFonts.inter(
                            color: _type == ExpenseType.expense
                                ? (theme.isLight ? Colors.white : Colors.black)
                                : theme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = ExpenseType.income),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _type == ExpenseType.income
                              ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Income',
                          style: AppFonts.inter(
                            color: _type == ExpenseType.income
                                ? (theme.isLight ? Colors.white : Colors.black)
                                : theme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppFonts.inter(
                color: theme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: AppFonts.inter(color: theme.textMuted, fontSize: 28),
                hintText: '0.00',
                hintStyle: AppFonts.inter(color: theme.textMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Title Field
            TextField(
              controller: _titleController,
              style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Title (e.g. Grocery, Lunch, Salary)',
                hintStyle: AppFonts.inter(color: theme.textMuted),
                filled: true,
                fillColor: theme.cardSecondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Categories Selector (Image 4 icon selector style)
            Text(
              'CATEGORY',
              style: AppFonts.inter(
                color: theme.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategoryId == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = cat.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                          : theme.cardSecondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          size: 14,
                          color: isSelected
                              ? (theme.isLight ? Colors.white : Colors.black)
                              : cat.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: AppFonts.inter(
                            color: isSelected
                                ? (theme.isLight ? Colors.white : Colors.black)
                                : theme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Submit Button (Image 2/4 full-width pill button)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isLight ? Colors.white : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  _type == ExpenseType.expense ? 'Add Expense' : 'Add Income',
                  style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
