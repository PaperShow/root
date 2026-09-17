import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/theme_provider.dart';
import '../services/launcher_service.dart';
import '../styles/standard_style.dart';
import '../styles/terminal_style.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import '../widgets/minimal_clock.dart';
import '../widgets/status_strip.dart';
import 'habit_tracker_screen.dart';
import 'settings_screen.dart';
import 'super_app_hub_screen.dart';
import 'walkthrough_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final bool standaloneTool;

  const HomeScreen({
    super.key,
    required this.themeProvider,
    this.standaloneTool = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final HabitProvider _habitProvider = HabitProvider();

  List<AppInfo> _apps = [];
  bool _loading = true;
  bool _isDefaultLauncher = false;
  bool _checkingLauncher = true;
  bool _userSkippedSetup = false;
  bool? _iconsEnabledSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.themeProvider.addListener(_handleThemeProviderChange);
    _iconsEnabledSnapshot = widget.themeProvider.isIconsEnabled;
    _habitProvider.init();
    _checkLauncherStatus();
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.themeProvider.removeListener(_handleThemeProviderChange);
    _pageController.dispose();
    _habitProvider.dispose();
    super.dispose();
  }

  void _handleThemeProviderChange() {
    final iconsEnabled = widget.themeProvider.isIconsEnabled;
    if (_iconsEnabledSnapshot != iconsEnabled) {
      _iconsEnabledSnapshot = iconsEnabled;
      _loadApps();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLauncherStatus(initial: false);
    }
  }

  Future<void> _checkLauncherStatus({bool initial = true}) async {
    if (initial) {
      setState(() {
        _checkingLauncher = true;
      });
    }
    final isDefault = await LauncherService.isDefaultLauncher();
    if (mounted) {
      setState(() {
        _isDefaultLauncher = isDefault;
        _checkingLauncher = false;
      });
    }
  }

  Future<void> _loadApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: widget.themeProvider.isIconsEnabled,
      );
      apps.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _apps = apps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateToHabitTracker() {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToMainLauncher() {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLauncher) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    }

    final canPop = Navigator.of(context).canPop();
    if (!_isDefaultLauncher && !_userSkippedSetup && !widget.standaloneTool && !canPop) {
      return _buildSetupScreen();
    }

    if (!widget.themeProvider.hasSeenWalkthrough) {
      return WalkthroughScreen(
        themeProvider: widget.themeProvider,
        onDone: () => setState(() {}),
      );
    }

    return ChangeNotifierProvider<HabitProvider>.value(
      value: _habitProvider,
      child: PopScope(
        canPop: canPop,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              // Page 0: Main Launcher Surface (Terminal or Standard)
              _buildMainLauncherPage(),

              // Page 1: Habit Tracker Screen (Swipe Left from Terminal)
              HabitTrackerScreen(
                onSwipeRight: _navigateToMainLauncher,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainLauncherPage() {
    return DigitalGrain(
      opacity: 0.08,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.themeProvider,
          builder: (context, _) {
            return GestureDetector(
              onDoubleTap: () => LauncherService.lockScreen(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── TOP HEADER ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 20, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onLongPress: () => widget.themeProvider.nextTheme(),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MinimalClock(
                                  isTerminal: widget.themeProvider.currentTheme ==
                                      LauncherThemeType.terminal,
                                ),
                                Consumer<HabitProvider>(
                                  builder: (context, habitProvider, _) {
                                    final progress = habitProvider.getTodayProgress();
                                    final completed = progress['completed'] ?? 0;
                                    final total = progress['total'] ?? 0;
                                    if (total == 0) return const SizedBox.shrink();

                                    final maxBlocks = 5;
                                    final filledBlocks = total > 0 ? ((completed / total) * maxBlocks).round() : 0;
                                    final blockStr = '${'■' * filledBlocks}${'□' * (maxBlocks - filledBlocks)}';

                                    return GestureDetector(
                                      onTap: _navigateToHabitTracker,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF101010),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF69FF94).withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'HABITS ',
                                              style: AppFonts.jetBrainsMono(
                                                color: const Color(0xFF69FF94),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            Text(
                                              blockStr,
                                              style: const TextStyle(
                                                color: Color(0xFF69FF94),
                                                fontSize: 10,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$completed/$total',
                                              style: AppFonts.jetBrainsMono(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Color(0xFF69FF94),
                                              size: 11,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (widget.themeProvider.isStatusStripEnabled &&
                                    widget.themeProvider.currentTheme !=
                                        LauncherThemeType.terminal) ...[
                                  const SizedBox(height: 8),
                                  const StatusStrip(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                color: Color(0xFF69FF94),
                              ),
                              tooltip: 'Super App Hub',
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SuperAppHubScreen(
                                          themeProvider: widget.themeProvider),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.format_list_bulleted,
                                color: const Color(0xFF69FF94).withValues(alpha: 0.9),
                              ),
                              tooltip: 'Habit Tracker',
                              onPressed: _navigateToHabitTracker,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              tooltip: 'Settings',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SettingsScreen(
                                        themeProvider: widget.themeProvider),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── MAIN CONTENT SURFACE ──────────────────
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white54),
                          )
                        : _buildCurrentStyle(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DigitalGrain(
        opacity: 0.08,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_android, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'enable\nminimalist\nphone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w200,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'to transform your ui into a distraction-free experience, you need to set this app as your default launcher.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                InkWell(
                  onTap: () {
                    LauncherService.openLauncherSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'turn on launcher',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _userSkippedSetup = true;
                    });
                  },
                  child: Text(
                    'skip for now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => SuperAppHubScreen(themeProvider: widget.themeProvider),
                        ),
                      );
                    }
                  },
                  child: Text(
                    '← back to super app hub',
                    style: TextStyle(
                      color: const Color(0xFF69FF94).withValues(alpha: 0.85),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStyle() {
    if (_loading) return const SizedBox.shrink();

    switch (widget.themeProvider.currentTheme) {
      case LauncherThemeType.standard:
        return StandardStyle(
          apps: _apps,
          themeProvider: widget.themeProvider,
        );
      case LauncherThemeType.terminal:
        return TerminalStyle(
          apps: _apps,
          themeProvider: widget.themeProvider,
          onSwipeLeft: _navigateToHabitTracker,
        );
    }
  }
}
