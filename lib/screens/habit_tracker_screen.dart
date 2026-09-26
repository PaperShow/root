import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/habit_reminder_service.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';

class HabitTrackerScreen extends StatefulWidget {
  final VoidCallback? onSwipeRight;
  final bool isEmbedded;

  const HabitTrackerScreen({
    super.key,
    this.onSwipeRight,
    this.isEmbedded = false,
  });

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  AppTheme get theme => AppTheme.of(context);
  Color get terminalGreen => theme.accent;
  Color get pureBlack => theme.scaffoldBackground;
  Color get cardDark => theme.card;
  Color get surfaceBorder => theme.border;
  Color get textPrimary => theme.textPrimary;
  Color get textSecondary => theme.textSecondary;
  Color get textMuted => theme.textMuted;

  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habitProvider = Provider.of<HabitProvider>(context, listen: false);
      if (!habitProvider.isInitialized) {
        habitProvider.init();
      }
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'FITNESS':
        return Icons.fitness_center_rounded;
      case 'MIND':
        return Icons.self_improvement_rounded;
      case 'HEALTH':
        return Icons.favorite_border_rounded;
      case 'WORK':
        return Icons.laptop_mac_rounded;
      case 'CREATIVE':
        return Icons.brush_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureBlack,
      body: SafeArea(
        child: Consumer<HabitProvider>(
          builder: (context, habitProvider, _) {
            final now = DateTime.now();
            final monthYearStr = DateFormat('MMM yyyy').format(now).toUpperCase();

            // Calculate overall stats
            final totalCompletionsToday = habitProvider.totalCompletionsOn(now);
            final totalHabits = habitProvider.habits.length;
            final completionPercent = totalHabits > 0
                ? ((totalCompletionsToday / totalHabits) * 100).round()
                : 0;

            final topStreak = habitProvider.habits.fold<int>(
              0,
              (prev, h) => prev > habitProvider.getStreak(h) ? prev : habitProvider.getStreak(h),
            );

            // Filtered habits
            final filteredHabits = _selectedCategoryFilter == 'All'
                ? habitProvider.habits
                : habitProvider.habits
                    .where((h) => h.category.toUpperCase() == _selectedCategoryFilter.toUpperCase())
                    .toList();

            return Column(
              children: [
                // ─── TOP BAR ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      if (!widget.isEmbedded) ...[
                        InkWell(
                          onTap: widget.onSwipeRight ?? () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: surfaceBorder),
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
                            'habits',
                            style: AppFonts.inter(
                              color: textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('EEEE, MMM d').format(now).toUpperCase()} • $totalCompletionsToday OF $totalHabits COMPLETED',
                            style: AppFonts.inter(
                              color: textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showCreateHabitSheet(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: terminalGreen,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: terminalGreen.withValues(alpha: 0.25),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Add',
                                style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── MAIN CONTENT ─────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 0, 20, widget.isEmbedded ? 100 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),

                        // ─── COMMIT BOARD HEATMAP ─────────────────
                        _buildCommitBoard(
                          habitProvider,
                          monthYearStr,
                          now,
                          totalCompletionsToday,
                          totalHabits,
                          topStreak,
                          completionPercent,
                        ),

                        const SizedBox(height: 20),

                        // ─── CATEGORY FILTER PILLS ────────────────
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: ['All', 'Fitness', 'Mind', 'Health', 'Work', 'Creative']
                                .map((cat) {
                              final isSel = _selectedCategoryFilter == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryFilter = cat;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? textPrimary : cardDark,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSel ? textPrimary : surfaceBorder,
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: AppFonts.inter(
                                        color: isSel ? pureBlack : textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: isSel ? FontWeight.w400 : FontWeight.w300,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── HABIT SECTION HEADER ─────────────────
                        Row(
                          children: [
                            Text(
                              'ROUTINES',
                              style: AppFonts.inter(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: textPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filteredHabits.length}',
                                style: AppFonts.inter(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'LAST 7 DAYS',
                              style: AppFonts.inter(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ─── HABIT CARDS LIST ──────────────────────
                        if (filteredHabits.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredHabits.length,
                            itemBuilder: (context, index) {
                              final habit = filteredHabits[index];
                              return _buildHabitCard(habit, habitProvider, now);
                            },
                          ),

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── COMMIT BOARD HEATMAP WIDGET ────────────────────────────
  Widget _buildCommitBoard(
    HabitProvider provider,
    String monthYearStr,
    DateTime now,
    int completionsToday,
    int totalHabits,
    int topStreak,
    int completionPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-Column Metric Row (like Reference Image 1)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPLETED',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completionsToday / $totalHabits',
                      style: AppFonts.inter(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: surfaceBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOP STREAK',
                        style: AppFonts.inter(
                          color: textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topStreak}d',
                        style: AppFonts.inter(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Consecutive',
                        style: AppFonts.inter(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 44, color: surfaceBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROGRESS',
                        style: AppFonts.inter(
                          color: textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completionPercent%',
                        style: AppFonts.inter(
                          color: terminalGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Success rate',
                        style: AppFonts.inter(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Horizontal Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalHabits > 0 ? (completionsToday / totalHabits).clamp(0.0, 1.0) : 0.0,
              backgroundColor: textPrimary.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(terminalGreen),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 20),

          // Heatmap Matrix Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMMIT ACTIVITY',
                style: AppFonts.inter(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              Text(
                monthYearStr,
                style: AppFonts.inter(
                  color: textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Matrix grid representing recent days (7 rows x 18 cols)
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 18;
              const rows = 7;
              const totalDays = cols * rows;

              return Column(
                children: List.generate(rows, (r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(cols, (c) {
                        final daysAgo = totalDays - 1 - (c * rows + r);
                        final targetDate = now.subtract(Duration(days: daysAgo));
                        final completions = provider.totalCompletionsOn(targetDate);
                        final habitsCount = provider.habits.length;

                        Color blockColor;
                        if (completions == 0 || habitsCount == 0) {
                          blockColor = textPrimary.withValues(alpha: 0.05);
                        } else {
                          final ratio = completions / habitsCount;
                          if (ratio >= 0.75) {
                            blockColor = terminalGreen;
                          } else if (ratio >= 0.5) {
                            blockColor = terminalGreen.withValues(alpha: 0.75);
                          } else if (ratio >= 0.25) {
                            blockColor = terminalGreen.withValues(alpha: 0.45);
                          } else {
                            blockColor = terminalGreen.withValues(alpha: 0.22);
                          }
                        }

                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: blockColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── HABIT CARD WIDGET ──────────────────────────────────────
  Widget _buildHabitCard(
    Habit habit,
    HabitProvider provider,
    DateTime now,
  ) {
    // Generate last 7 days
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final streak = provider.getStreak(habit);
    final isDoneToday = habit.isCompletedOn(now);

    return InkWell(
      onTap: () => _showHabitDetailSheet(context, habit, provider, now),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(habit.category),
                    color: textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Habit Title and Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: AppFonts.inter(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${habit.category} • ${habit.targetDuration}',
                        style: AppFonts.inter(
                          color: textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak pill
                if (streak > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: terminalGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔥 ${streak}d',
                      style: AppFonts.inter(
                        color: terminalGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Today toggle button
                InkWell(
                  onTap: () => provider.toggleHabitCompletion(habit.id, now),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDoneToday ? terminalGreen : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDoneToday ? terminalGreen : surfaceBorder,
                        width: 1.5,
                      ),
                    ),
                    child: isDoneToday
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 7 Days Completion Status Blocks
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.map((date) {
                final isDone = habit.isCompletedOn(date);
                final isToday = date.day == now.day &&
                    date.month == now.month &&
                    date.year == now.year;
                final dayLetter = DateFormat('E').format(date)[0];

                return InkWell(
                  onTap: () => provider.toggleHabitCompletion(habit.id, date),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    children: [
                      Text(
                        dayLetter,
                        style: AppFonts.inter(
                          color: isToday ? terminalGreen : textMuted,
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone ? terminalGreen : textPrimary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone
                                ? terminalGreen
                                : isToday
                                    ? terminalGreen.withValues(alpha: 0.5)
                                    : surfaceBorder,
                            width: isToday ? 1.5 : 1,
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HABIT DETAIL MODAL SHEET ───────────────────────────────
  void _showHabitDetailSheet(
    BuildContext context,
    Habit habit,
    HabitProvider provider,
    DateTime now,
  ) {
    final streak = provider.getStreak(habit);
    final bestStreak = provider.getBestStreak(habit);
    final totalCommits = habit.completedDates.length;
    final isDoneToday = habit.isCompletedOn(now);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDetailState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_getCategoryIcon(habit.category), color: textPrimary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.name,
                              style: AppFonts.inter(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${habit.category} • ${habit.targetDuration} • ${habit.reminderTime}',
                              style: AppFonts.inter(
                                color: textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: textPrimary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: textSecondary, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Telemetry Stats Row
                  Row(
                    children: [
                      _buildStatBox('CURRENT STREAK', '🔥 ${streak}d', terminalGreen),
                      const SizedBox(width: 8),
                      _buildStatBox('BEST STREAK', '🏆 ${bestStreak}d', const Color(0xFFD9532F)),
                      const SizedBox(width: 8),
                      _buildStatBox('LIFETIME', '$totalCommits commits', textPrimary),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Individual 60-Day Contribution Heatmap
                  Text(
                    'RECENT 60 DAYS',
                    style: AppFonts.inter(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pureBlack,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const cols = 12;
                        const rows = 5;
                        const totalDays = cols * rows;

                        return Column(
                          children: List.generate(rows, (r) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(cols, (c) {
                                  final daysAgo = totalDays - 1 - (c * rows + r);
                                  final targetDate = now.subtract(Duration(days: daysAgo));
                                  final isCompleted = habit.isCompletedOn(targetDate);

                                  return Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? terminalGreen
                                          : textPrimary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reminder Alert Action
                  InkWell(
                    onTap: () {
                      HabitReminderService.showInAppReminder(context, habit);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: pureBlack,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: terminalGreen, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Reminder: ${habit.reminderTime}',
                            style: AppFonts.inter(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'TEST',
                            style: AppFonts.inter(
                              color: terminalGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      // Delete Habit Button
                      InkWell(
                        onTap: () {
                          provider.deleteHabit(habit.id);
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Toggle Today Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              provider.toggleHabitCompletion(habit.id, now);
                              setDetailState(() {});
                              Navigator.of(ctx).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDoneToday
                                  ? textPrimary.withValues(alpha: 0.08)
                                  : terminalGreen,
                              foregroundColor: isDoneToday ? textPrimary : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isDoneToday ? 'Mark Incomplete' : 'Mark Complete For Today',
                              style: AppFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: pureBlack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: surfaceBorder),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppFonts.inter(
                color: textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppFonts.inter(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── EMPTY STATE WIDGET ─────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.track_changes_outlined,
              color: textMuted,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'No habits in this category',
              style: AppFonts.inter(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+ Add" to build your daily commitments.',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                color: textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CREATE HABIT SHEET ─────────────────────────────────────
  void _showCreateHabitSheet(BuildContext context) {
    final nameController = TextEditingController();
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7];
    String selectedTime = '06:00 AM';
    String selectedCategory = 'Fitness';
    String selectedDuration = '30 Min';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
                top: 16,
                left: 20,
                right: 20,
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
                        decoration: BoxDecoration(
                          color: textPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'New Habit',
                          style: AppFonts.inter(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: textPrimary.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: textSecondary, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. HABIT NAME
                    Text(
                      'HABIT NAME',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: pureBlack,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: TextField(
                        controller: nameController,
                        autofocus: true,
                        style: AppFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Morning Run, Read 20 pages',
                          hintStyle: AppFonts.inter(
                            color: textMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. SCHEDULE
                    Text(
                      'SCHEDULE',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDayPill('M', 1, selectedDays, setModalState),
                        _buildDayPill('T', 2, selectedDays, setModalState),
                        _buildDayPill('W', 3, selectedDays, setModalState),
                        _buildDayPill('T', 4, selectedDays, setModalState),
                        _buildDayPill('F', 5, selectedDays, setModalState),
                        _buildDayPill('S', 6, selectedDays, setModalState),
                        _buildDayPill('S', 7, selectedDays, setModalState),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 3. REMINDER TIME
                    Text(
                      'REMINDER TIME',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: const TimeOfDay(hour: 6, minute: 0),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked.format(ctx);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: pureBlack,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedTime,
                              style: AppFonts.inter(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.schedule,
                              color: terminalGreen,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. CATEGORY
                    Text(
                      'CATEGORY',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Fitness', 'Mind', 'Health', 'Work'].map((cat) {
                        final isSel = selectedCategory == cat;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedCategory = cat;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? textPrimary : pureBlack,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? textPrimary : surfaceBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: AppFonts.inter(
                                      color: isSel ? pureBlack : textSecondary,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // 5. TARGET DURATION
                    Text(
                      'TARGET DURATION',
                      style: AppFonts.inter(
                        color: textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['15 Min', '30 Min', '60 Min'].map((dur) {
                        final isSel = selectedDuration == dur;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedDuration = dur;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? textPrimary : pureBlack,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? textPrimary : surfaceBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    dur,
                                    style: AppFonts.inter(
                                      color: isSel ? pureBlack : textSecondary,
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // CREATE HABIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final newHabit = Habit(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: name,
                            scheduleDays: selectedDays,
                            reminderTime: selectedTime,
                            category: selectedCategory,
                            targetDuration: selectedDuration,
                            completedDates: {},
                          );

                          Provider.of<HabitProvider>(context, listen: false).addHabit(newHabit);
                          Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: terminalGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Create Habit',
                          style: AppFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayPill(
    String letter,
    int dayVal,
    List<int> selectedDays,
    StateSetter setModalState,
  ) {
    final isSelected = selectedDays.contains(dayVal);
    return GestureDetector(
      onTap: () {
        setModalState(() {
          if (isSelected) {
            if (selectedDays.length > 1) selectedDays.remove(dayVal);
          } else {
            selectedDays.add(dayVal);
          }
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? textPrimary : pureBlack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? textPrimary : surfaceBorder,
          ),
        ),
        child: Center(
          child: Text(
            letter,
            style: AppFonts.inter(
              color: isSelected ? pureBlack : textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
