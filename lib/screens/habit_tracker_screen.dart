import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../utils/app_fonts.dart';

class HabitTrackerScreen extends StatefulWidget {
  final VoidCallback? onSwipeRight;

  const HabitTrackerScreen({super.key, this.onSwipeRight});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF222222);

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
            int totalCompletionsToday = habitProvider.totalCompletionsOn(now);
            int totalHabits = habitProvider.habits.length;
            int completionPercent = totalHabits > 0
                ? ((totalCompletionsToday / totalHabits) * 100).round()
                : 0;

            return Column(
              children: [
                // ─── TOP BAR ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: widget.onSwipeRight,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '// HABIT_TRACKER',
                            style: AppFonts.jetBrainsMono(
                              color: terminalGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMM d').format(now).toLowerCase(),
                            style: AppFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showCreateHabitSheet(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: terminalGreen,
                            borderRadius: BorderRadius.circular(12),
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
                              const Icon(Icons.add, size: 16, color: Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                'NEW',
                                style: AppFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 1,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          completionPercent,
                        ),

                        const SizedBox(height: 28),

                        // ─── PER HABIT SECTION HEADER ─────────────
                        Row(
                          children: [
                            Text(
                              '// PER_HABIT',
                              style: AppFonts.jetBrainsMono(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${habitProvider.habits.length}',
                                style: AppFonts.jetBrainsMono(
                                  color: terminalGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'LAST 7 DAYS',
                              style: AppFonts.jetBrainsMono(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ─── HABIT CARDS LIST ──────────────────────
                        if (habitProvider.habits.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: habitProvider.habits.length,
                            itemBuilder: (context, index) {
                              final habit = habitProvider.habits[index];
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
    int completionPercent,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: terminalGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: terminalGreen.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '// COMMIT_BOARD',
                    style: AppFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Text(
                monthYearStr,
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                        final totalHabits = provider.habits.length;

                        Color blockColor;
                        if (completions == 0 || totalHabits == 0) {
                          blockColor = Colors.white.withValues(alpha: 0.05);
                        } else {
                          final ratio = completions / totalHabits;
                          if (ratio >= 0.75) {
                            blockColor = terminalGreen;
                          } else if (ratio >= 0.5) {
                            blockColor = const Color(0xFF4EFA8B);
                          } else if (ratio >= 0.25) {
                            blockColor = const Color(0xFF2E8B57);
                          } else {
                            blockColor = const Color(0xFF1B4D2E);
                          }
                        }

                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: blockColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),

          const SizedBox(height: 16),

          // Bottom Bar with Stats and Intensity Scale
          Row(
            children: [
              Text(
                'TODAY: ',
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completionPercent%',
                style: AppFonts.jetBrainsMono(
                  color: terminalGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'INTENSITY: ',
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 3),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF1B4D2E), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 3),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF2E8B57), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 3),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF4EFA8B), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 3),
              Container(width: 9, height: 9, decoration: BoxDecoration(color: terminalGreen, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(
                'NONE',
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'FULL',
                style: AppFonts.jetBrainsMono(
                  color: terminalGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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

    // Calculate completion streak in last 7 days
    int completedCount = 0;
    for (final d in last7Days) {
      if (habit.isCompletedOn(d)) completedCount++;
    }

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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        habit.name.toUpperCase().replaceAll(' ', '_'),
                        style: AppFonts.jetBrainsMono(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: terminalGreen.withValues(alpha: 0.1),
                        border: Border.all(color: terminalGreen.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        habit.category,
                        style: AppFonts.jetBrainsMono(
                          color: terminalGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completedCount/7d',
                style: AppFonts.jetBrainsMono(
                  color: completedCount >= 5 ? terminalGreen : Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => provider.deleteHabit(habit.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 17,
                  ),
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
                      style: AppFonts.jetBrainsMono(
                        color: isToday
                            ? terminalGreen
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone ? terminalGreen : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? terminalGreen
                              : isToday
                                  ? terminalGreen.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.12),
                          width: isToday ? 1.5 : 1,
                        ),
                        boxShadow: isDone
                            ? [
                                BoxShadow(
                                  color: terminalGreen.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.black)
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
              color: terminalGreen.withValues(alpha: 0.6),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'NO_HABITS_YET',
              style: AppFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'tap "+ NEW" to build your daily commitments.',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                color: Colors.white.withValues(alpha: 0.4),
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
    String selectedCategory = 'FITNESS';
    String selectedDuration = '30 MIN';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 20,
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '// CREATE_HABIT',
                          style: AppFonts.jetBrainsMono(
                            color: terminalGreen,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 1. HABIT_NAME
                    Text(
                      'HABIT_NAME',
                      style: AppFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: terminalGreen, width: 1.5),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. MORNING_RUN',
                          hintStyle: AppFonts.jetBrainsMono(
                            color: Colors.white.withValues(alpha: 0.25),
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
                      style: AppFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
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

                    // 3. REMINDER_TIME
                    Text(
                      'REMINDER_TIME',
                      style: AppFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
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
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedTime,
                              style: AppFonts.jetBrainsMono(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.schedule,
                              color: terminalGreen.withValues(alpha: 0.8),
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
                      style: AppFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['FITNESS', 'MIND', 'HEALTH', 'WORK'].map((cat) {
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
                                  color: isSel ? terminalGreen : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? terminalGreen : surfaceBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '[$cat]',
                                    style: AppFonts.jetBrainsMono(
                                      color: isSel ? Colors.black : Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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

                    // 5. TARGET_DURATION
                    Text(
                      'TARGET_DURATION',
                      style: AppFonts.jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['15 MIN', '30 MIN', '60 MIN'].map((dur) {
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
                                  color: isSel ? terminalGreen : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? terminalGreen : surfaceBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    dur,
                                    style: AppFonts.jetBrainsMono(
                                      color: isSel ? Colors.black : Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'CREATE HABIT',
                          style: AppFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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
          color: isSelected ? terminalGreen : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? terminalGreen : surfaceBorder,
          ),
        ),
        child: Center(
          child: Text(
            letter,
            style: AppFonts.jetBrainsMono(
              color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
