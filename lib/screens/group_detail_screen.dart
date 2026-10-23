import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/split_group.dart';
import '../providers/expense_provider.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/person_picker_field.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final group = provider.groupById(groupId);
        return Scaffold(
          backgroundColor: theme.scaffoldBackground,
          body: SafeArea(
            child: group == null
                ? _buildMissing(context, theme)
                : _GroupDetailBody(group: group, provider: provider),
          ),
        );
      },
    );
  }

  Widget _buildMissing(BuildContext context, AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This group is no longer available.',
              style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                side: BorderSide(color: theme.border),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailBody extends StatelessWidget {
  final SplitGroup group;
  final ExpenseProvider provider;

  const _GroupDetailBody({required this.group, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final myId = provider.myMemberId(group);
    final isAdmin = provider.isGroupAdmin(group);
    final balances = provider.getGroupMemberBalances(group.id);
    final suggestions = provider.getSettlementSuggestions(group.id);
    final expenses = provider.getExpensesForGroup(group.id);
    final myBalance = myId != null ? (balances[myId] ?? 0.0) : 0.0;

    final mySuggestions = suggestions.where((s) => s.fromId == myId || s.toId == myId).toList();
    final otherSuggestions = suggestions.where((s) => s.fromId != myId && s.toId != myId).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildTopBar(context, theme, isAdmin),
            const SizedBox(height: 18),
            _buildSummaryCard(theme, myBalance),
            const SizedBox(height: 22),

            // ─── SETTLE UP ─────────────────────────────────
            _sectionLabel(theme, 'SETTLE UP'),
            const SizedBox(height: 10),
            if (suggestions.isEmpty)
              _infoCard(theme, Icons.check_circle_outline_rounded, 'Everyone is settled up.')
            else ...[
              ...mySuggestions.map((s) => _buildSuggestionTile(context, theme, s, myId, isAdmin)),
              ...otherSuggestions.map((s) => _buildSuggestionTile(context, theme, s, myId, isAdmin)),
            ],
            const SizedBox(height: 22),

            // ─── MEMBERS ───────────────────────────────────
            Row(
              children: [
                Expanded(child: _sectionLabel(theme, 'MEMBERS (${group.members.length})')),
                if (isAdmin)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: theme.textPrimary),
                    onPressed: () => showMemberSheet(context, provider, group),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: Text('Add', style: AppFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                children: group.members
                    .map((m) => _buildMemberTile(context, theme, m, balances[m.id] ?? 0.0, myId, isAdmin))
                    .toList(),
              ),
            ),
            if (!provider.isCloudSync) ...[
              const SizedBox(height: 10),
              _infoCard(
                theme,
                Icons.cloud_off_rounded,
                'Saved on this device only. Sign in with Google to invite members by username or email.',
              ),
            ],
            const SizedBox(height: 22),

            // ─── EXPENSES ──────────────────────────────────
            _sectionLabel(theme, 'ACTIVITY'),
            const SizedBox(height: 10),
            if (expenses.isEmpty)
              _infoCard(theme, Icons.receipt_long_outlined, 'No shared expenses yet.')
            else
              ...expenses.map((e) => _buildExpenseTile(context, theme, e, myId, isAdmin)),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.isLight ? Colors.white : Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              onPressed: () => showAddGroupExpenseSheet(context, provider, group),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Add Expense', style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, AppTheme theme, bool isAdmin) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.cardSecondary, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new, color: theme.textPrimary, size: 14),
          ),
        ),
        const SizedBox(width: 14),
        Text(group.icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            group.name,
            style: AppFonts.inter(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w300),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isAdmin)
          PopupMenuButton<String>(
            color: theme.card,
            icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary),
            onSelected: (value) {
              if (value == 'rename') _showRenameSheet(context, theme);
              if (value == 'delete') _confirmDeleteGroup(context, theme);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'rename',
                child: Text('Rename group', style: AppFonts.inter(color: theme.textPrimary, fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete group', style: AppFonts.inter(color: theme.expenseCoral, fontSize: 13)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryCard(AppTheme theme, double myBalance) {
    final settled = myBalance.abs() < 0.01;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SPENT', style: _labelStyle(theme)),
                const SizedBox(height: 4),
                Text(
                  provider.formatAmount(provider.getGroupTotalSpent(group.id)),
                  style: AppFonts.inter(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
          Container(height: 34, width: 1, color: theme.border),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(settled ? 'YOUR BALANCE' : (myBalance > 0 ? 'YOU ARE OWED' : 'YOU OWE'), style: _labelStyle(theme)),
                const SizedBox(height: 4),
                Text(
                  settled ? 'Settled' : provider.formatAmount(myBalance.abs()),
                  style: AppFonts.inter(
                    color: settled ? theme.textMuted : (myBalance > 0 ? theme.incomeMint : theme.expenseCoral),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(
    BuildContext context,
    AppTheme theme,
    SettlementSuggestion s,
    String? myId,
    bool isAdmin,
  ) {
    final iPay = s.fromId == myId;
    final iReceive = s.toId == myId;
    final from = iPay ? 'You' : group.nameOf(s.fromId);
    final to = iReceive ? 'you' : group.nameOf(s.toId);
    final canSettle = iPay || iReceive || isAdmin;
    final color = iPay ? theme.expenseCoral : (iReceive ? theme.incomeMint : theme.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$from ${iPay ? 'owe' : 'owes'} $to',
                  style: AppFonts.inter(color: theme.textPrimary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  provider.formatAmount(s.amount),
                  style: AppFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (canSettle)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: iPay ? theme.accent : theme.cardSecondary,
                foregroundColor: iPay ? (theme.isLight ? Colors.white : Colors.black) : theme.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showSettleSheet(context, theme, s, from, to),
              child: Text(iPay ? 'Settle' : 'Mark paid', style: AppFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    AppTheme theme,
    GroupMember m,
    double balance,
    String? myId,
    bool isAdmin,
  ) {
    final isMe = m.id == myId;
    final String subtitle;
    switch (m.status) {
      case MemberStatus.active:
        subtitle = m.username != null ? '@${m.username}' : (m.email ?? 'On the app');
      case MemberStatus.invited:
        subtitle = m.uid != null ? 'Invited • waiting to accept' : 'Invited ${m.email ?? ''} • not on the app yet';
      case MemberStatus.placeholder:
        subtitle = 'Name only • not linked to an account';
    }
    final settled = balance.abs() < 0.01;

    return InkWell(
      onTap: isAdmin ? () => showMemberSheet(context, provider, group, member: m) : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: theme.cardSecondary,
              child: Text(
                m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                style: AppFonts.inter(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? '${m.name} (you)' : m.name,
                          style: AppFonts.inter(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (m.uid != null && group.isAdmin(m.uid)) ...[
                        const SizedBox(width: 6),
                        _badge(theme, 'ADMIN'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      color: m.status == MemberStatus.invited ? theme.accentWarm : theme.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              settled ? 'settled' : '${balance > 0 ? '+' : '-'}${provider.formatAmount(balance.abs())}',
              style: AppFonts.inter(
                color: settled ? theme.textMuted : (balance > 0 ? theme.incomeMint : theme.expenseCoral),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: theme.textMuted, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, AppTheme theme, GroupExpense e, String? myId, bool isAdmin) {
    final canDelete = isAdmin || !provider.isCloudSync || e.createdBy == provider.currentUid;
    final payer = e.paidBy == myId ? 'You' : group.nameOf(e.paidBy);
    final String subtitle;
    if (e.isSettlement) {
      final receiver = e.splitAmong.isEmpty ? '' : (e.splitAmong.first == myId ? 'you' : group.nameOf(e.splitAmong.first));
      subtitle = '$payer paid $receiver';
    } else {
      subtitle = '$payer paid • split ${e.splitAmong.length} ways';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (e.isSettlement ? theme.incomeMint : theme.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              e.isSettlement ? Icons.handshake_outlined : Icons.receipt_long_outlined,
              size: 16,
              color: e.isSettlement ? theme.incomeMint : theme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: AppFonts.inter(color: theme.textPrimary, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle • ${DateFormat('MMM d').format(e.date)}',
                  style: AppFonts.inter(color: theme.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            provider.formatAmount(e.amount),
            style: AppFonts.inter(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          if (canDelete)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, color: theme.textMuted, size: 18),
              onPressed: () => _confirm(
                context,
                theme,
                title: 'Delete "${e.title}"?',
                message: 'Balances will be recalculated for everyone in the group.',
                action: 'Delete',
                onConfirm: () => provider.deleteGroupExpense(group.id, e.id),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SHEETS & DIALOGS ──────────────────────────────────────────

  void _showSettleSheet(BuildContext context, AppTheme theme, SettlementSuggestion s, String from, String to) {
    final amountCtrl = TextEditingController(text: s.amount.toStringAsFixed(s.amount % 1 == 0 ? 0 : 2));
    _showSheet(
      context,
      title: 'Record payment',
      builder: (ctx, _) => [
        Text(
          '$from ${from == 'You' ? 'pay' : 'pays'} $to',
          style: AppFonts.inter(color: theme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: amountCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          decoration: sheetInputDecoration(theme, prefixText: '${provider.currencySymbol} '),
        ),
        const SizedBox(height: 20),
        _primaryButton(theme, 'Confirm Settlement', () async {
          final amount = double.tryParse(amountCtrl.text.trim());
          if (amount == null || amount <= 0) return;
          Navigator.of(ctx).pop();
          await _run(context, () => provider.recordGroupSettlement(group.id, s.fromId, s.toId, amount));
        }),
      ],
    );
  }

  void _showRenameSheet(BuildContext context, AppTheme theme) {
    final nameCtrl = TextEditingController(text: group.name);
    _showSheet(
      context,
      title: 'Rename group',
      builder: (ctx, _) => [
        TextField(
          controller: nameCtrl,
          autofocus: true,
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
          decoration: sheetInputDecoration(theme, hint: 'Group name'),
        ),
        const SizedBox(height: 20),
        _primaryButton(theme, 'Save', () async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          Navigator.of(ctx).pop();
          await _run(context, () => provider.renameSplitGroup(group.id, name));
        }),
      ],
    );
  }

  void _confirmDeleteGroup(BuildContext context, AppTheme theme) {
    _confirm(
      context,
      theme,
      title: 'Delete "${group.name}"?',
      message: 'The group and all its expenses will be deleted for every member.',
      action: 'Delete',
      onConfirm: () async {
        Navigator.of(context).maybePop();
        await provider.deleteSplitGroup(group.id);
      },
    );
  }

  // ─── SMALL BUILDING BLOCKS ─────────────────────────────────────

  TextStyle _labelStyle(AppTheme theme) =>
      AppFonts.inter(color: theme.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.6);

  Widget _sectionLabel(AppTheme theme, String text) => Text(
        text,
        style: AppFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      );

  Widget _badge(AppTheme theme, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: theme.cardSecondary, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: AppFonts.inter(color: theme.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );

  Widget _infoCard(AppTheme theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppFonts.inter(color: theme.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// SHARED SHEETS (also opened from the Split Groups tab)
// ═════════════════════════════════════════════════════════════════

Widget _primaryButton(AppTheme theme, String label, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.accent,
        foregroundColor: theme.isLight ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      onPressed: onPressed,
      child: Text(label, style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
    ),
  );
}

/// Runs a provider action and shows its error (if any) as a snackbar.
Future<void> _run(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
  } on GroupActionException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger?.showSnackBar(const SnackBar(content: Text('Could not save. Check your connection and try again.')));
  }
}

void _confirm(
  BuildContext context,
  AppTheme theme, {
  required String title,
  required String message,
  required String action,
  required Future<void> Function() onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.card,
      title: Text(title, style: AppFonts.inter(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      content: Text(message, style: AppFonts.inter(color: theme.textSecondary, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: AppFonts.inter(color: theme.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _run(context, onConfirm);
          },
          child: Text(action, style: AppFonts.inter(color: theme.expenseCoral, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

void _showSheet(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext ctx, StateSetter setSheetState) builder,
}) {
  final theme = AppTheme.of(context);
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                  decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppFonts.inter(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: theme.cardSecondary, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, size: 18, color: theme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...builder(ctx, setSheetState),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Turns a picked person into a group member. App users and emails become
/// invitations they accept inside the app; plain names stay name-only.
GroupMember memberFromPick(ExpenseProvider provider, PersonPick pick, {String? id, String? name}) {
  final memberId = id ?? provider.newId();
  final displayName = (name != null && name.trim().isNotEmpty) ? name.trim() : pick.name;
  if (provider.isCloudSync && pick.user != null) {
    return GroupMember(
      id: memberId,
      name: displayName,
      uid: pick.user!.uid,
      email: pick.user!.email,
      username: pick.user!.username,
      status: MemberStatus.invited,
    );
  }
  if (provider.isCloudSync && pick.email != null) {
    return GroupMember(id: memberId, name: displayName, email: pick.email, status: MemberStatus.invited);
  }
  return GroupMember(id: memberId, name: displayName);
}

/// Add a member (when [member] is null) or edit an existing one.
void showMemberSheet(BuildContext context, ExpenseProvider provider, SplitGroup group, {GroupMember? member}) {
  final theme = AppTheme.of(context);
  final isNew = member == null;
  final nameCtrl = TextEditingController(text: member?.name ?? '');
  PersonPick? pick;
  final canLink = member == null || member.status == MemberStatus.placeholder;
  final isSelf = member?.uid != null && member!.uid == provider.currentUid;

  _showSheet(
    context,
    title: isNew ? 'Add member' : 'Edit member',
    builder: (ctx, setSheetState) => [
      if (!isNew) ...[
        Text('NAME', style: AppFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
          decoration: sheetInputDecoration(theme, hint: 'Display name'),
        ),
        const SizedBox(height: 14),
      ],
      if (canLink) ...[
        Text(
          isNew ? 'FIND BY USERNAME OR EMAIL' : 'LINK TO AN ACCOUNT',
          style: AppFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        PersonPickerField(
          autofocus: isNew,
          searchEnabled: provider.isCloudSync,
          excludeUid: provider.currentUid,
          hint: isNew ? 'Name, @username or email' : '@username or email to invite',
          onChanged: (p) => setSheetState(() => pick = p),
        ),
        if (provider.isCloudSync) ...[
          const SizedBox(height: 8),
          Text(
            'People on the app get an invitation to accept. Others can join after creating an account with the same email.',
            style: AppFonts.inter(color: theme.textMuted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 20),
      ] else if (member.status == MemberStatus.invited) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.cardSecondary, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: theme.accentWarm),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invitation pending${member.email != null ? ' for ${member.email}' : ''}.',
                  style: AppFonts.inter(color: theme.textSecondary, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _run(context, () => provider.updateGroupMember(
                        group.id,
                        member.copyWith(status: MemberStatus.placeholder, clearUid: true, clearEmail: true),
                      ));
                },
                child: Text('Cancel invite', style: AppFonts.inter(color: theme.expenseCoral, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ] else
        const SizedBox(height: 6),
      _primaryButton(theme, isNew ? 'Add to group' : 'Save changes', () async {
        if (isNew) {
          if (pick == null) return;
          Navigator.of(ctx).pop();
          await _run(context, () => provider.addGroupMember(group.id, memberFromPick(provider, pick!)));
          return;
        }
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return;
        final updated = (canLink && pick != null && (pick!.user != null || pick!.email != null))
            ? memberFromPick(provider, pick!, id: member.id, name: name)
            : member.copyWith(name: name);
        Navigator.of(ctx).pop();
        if (updated.uid != null && group.members.any((m) => m.id != member.id && m.uid == updated.uid)) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('This person is already in the group.')),
          );
          return;
        }
        await _run(context, () => provider.updateGroupMember(group.id, updated));
      }),
      if (!isNew && !isSelf) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _run(context, () => provider.removeGroupMember(group.id, member.id));
            },
            child: Text('Remove from group', style: AppFonts.inter(color: theme.expenseCoral, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ],
  );
}

void showAddGroupExpenseSheet(BuildContext context, ExpenseProvider provider, SplitGroup group) {
  final theme = AppTheme.of(context);
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final myId = provider.myMemberId(group);
  String paidBy = (myId != null && group.memberById(myId) != null) ? myId : group.members.first.id;
  final splitAmong = group.members.map((m) => m.id).toSet();
  final selectedBg = theme.isLight ? const Color(0xFF18181B) : Colors.white;
  final selectedFg = theme.isLight ? Colors.white : Colors.black;

  _showSheet(
    context,
    title: 'Add Group Expense',
    builder: (ctx, setSheetState) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final share = splitAmong.isEmpty ? 0.0 : amount / splitAmong.length;
      return [
        TextField(
          controller: titleCtrl,
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
          decoration: sheetInputDecoration(theme, hint: 'Title (e.g. Dinner, Fuel)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setSheetState(() {}),
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: sheetInputDecoration(theme, hint: 'Total Amount', prefixText: '${provider.currencySymbol} '),
        ),
        const SizedBox(height: 14),
        Text('PAID BY', style: AppFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: theme.cardSecondary, borderRadius: BorderRadius.circular(14)),
          child: DropdownButton<String>(
            value: paidBy,
            dropdownColor: theme.card,
            iconEnabledColor: theme.textSecondary,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
            items: group.members
                .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.id == myId ? '${m.name} (you)' : m.name, style: AppFonts.inter(color: theme.textPrimary, fontSize: 14)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setSheetState(() => paidBy = val);
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text('SPLIT EQUALLY AMONG',
                  style: AppFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ),
            if (amount > 0)
              Text('${provider.formatAmount(share)} each', style: AppFonts.inter(color: theme.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: group.members.map((m) {
            final isIncluded = splitAmong.contains(m.id);
            return FilterChip(
              label: Text(
                m.id == myId ? 'You' : m.name,
                style: AppFonts.inter(color: isIncluded ? selectedFg : theme.textSecondary, fontSize: 11.5),
              ),
              selected: isIncluded,
              showCheckmark: true,
              checkmarkColor: selectedFg,
              selectedColor: selectedBg,
              backgroundColor: theme.cardSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide.none,
              onSelected: (val) {
                setSheetState(() {
                  if (val) {
                    splitAmong.add(m.id);
                  } else if (splitAmong.length > 1) {
                    splitAmong.remove(m.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _primaryButton(theme, 'Record Shared Expense', () async {
          final title = titleCtrl.text.trim();
          final amt = double.tryParse(amountCtrl.text.trim());
          if (title.isEmpty || amt == null || amt <= 0 || splitAmong.isEmpty) {
            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
              const SnackBar(content: Text('Enter a title and a valid amount')),
            );
            return;
          }
          Navigator.of(ctx).pop();
          await _run(context, () => provider.addGroupExpense(GroupExpense(
                id: provider.newId(),
                groupId: group.id,
                title: title,
                amount: amt,
                paidBy: paidBy,
                splitAmong: group.members.map((m) => m.id).where(splitAmong.contains).toList(),
                date: DateTime.now(),
                createdBy: provider.currentUid,
              )));
        }),
      ];
    },
  );
}
