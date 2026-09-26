import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/launcher_service.dart';
import '../services/volume_controller_service.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import 'expense_tracker_screen.dart';
import 'habit_tracker_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'volume_controller_screen.dart';

class SuperAppHubScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const SuperAppHubScreen({super.key, required this.themeProvider});

  @override
  State<SuperAppHubScreen> createState() => _SuperAppHubScreenState();
}

class _SuperAppHubScreenState extends State<SuperAppHubScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isOverlayRunning = false;
  bool _isDefaultLauncher = false;
  int _appCount = 0;
  Map<String, dynamic> _systemInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadToolsData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadToolsData();
    }
  }

  Future<void> _loadToolsData() async {
    final overlayRunning = await VolumeControllerService.isVolumeOverlayRunning();
    final defaultLauncher = await LauncherService.isDefaultLauncher();
    final sysInfo = await LauncherService.getSystemInfo();

    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: false,
      );
      if (mounted) {
        setState(() {
          _appCount = apps.length;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isOverlayRunning = overlayRunning;
        _isDefaultLauncher = defaultLauncher;
        _systemInfo = sysInfo;
      });
    }
  }

  Future<void> _toggleVolumeOverlay(bool enable, AppTheme theme) async {
    if (enable) {
      final hasPerm = await VolumeControllerService.isOverlayPermissionGranted();
      if (!hasPerm) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VolumeControllerScreen()),
          ).then((_) => _loadToolsData());
        }
        return;
      }
      final started = await VolumeControllerService.startVolumeOverlay();
      if (mounted) {
        setState(() {
          _isOverlayRunning = started;
        });
      }
    } else {
      final stopped = await VolumeControllerService.stopVolumeOverlay();
      if (mounted) {
        setState(() {
          _isOverlayRunning = !stopped;
        });
      }
    }
  }

  void _openLauncher() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          themeProvider: widget.themeProvider,
          standaloneTool: true,
        ),
      ),
    ).then((_) => _loadToolsData());
  }

  void _openVolumeController() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VolumeControllerScreen()),
    ).then((_) => _loadToolsData());
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(themeProvider: widget.themeProvider),
      ),
    ).then((_) => _loadToolsData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackground,
      body: DigitalGrain(
        opacity: theme.isLight ? 0.015 : 0.04,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // ─── TAB CONTENT (STACK BACKGROUND) ─────────────────
              Column(
                children: [
                  _buildTopHeader(theme),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        // Tab 0: Expense Tracker
                        const ExpenseTrackerScreen(isEmbedded: true),

                        // Tab 1: Habit Tracker
                        const HabitTrackerScreen(isEmbedded: true),

                        // Tab 2: Tools & Launcher (Notes removed as requested)
                        _buildToolsTab(theme),
                      ],
                    ),
                  ),
                ],
              ),

              // ─── FLOATING MINIMAL BOTTOM NAV (STACK FORMAT) ──────
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomPadding > 0 ? bottomPadding + 8 : 18,
                child: _buildFloatingBottomBar(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackground,
        border: Border(
          bottom: BorderSide(color: theme.border.withValues(alpha: 0.6), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.cardSecondary,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/root_icon_load.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) => Icon(
                Icons.terminal,
                color: theme.accent,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'root',
            style: AppFonts.inter(
              color: theme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w200,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              theme.isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: theme.textSecondary,
              size: 20,
            ),
            tooltip: theme.isLight ? 'Switch to Dark Mode' : 'Switch to Light Mode',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              widget.themeProvider.setAppThemeMode(
                theme.isLight ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.tune_outlined, color: theme.textSecondary, size: 20),
            tooltip: 'Appearance & Themes',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showThemeSwitcherSheet(context, theme),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: theme.textSecondary, size: 20),
            tooltip: 'Settings',
            visualDensity: VisualDensity.compact,
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab(AppTheme theme) {
    final themeName = widget.themeProvider.currentTheme.name.toUpperCase();
    final model = _systemInfo['deviceModel'] ?? 'Android Device';
    final androidVer = _systemInfo['androidVersion'] ?? 'OS';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // Screen Title Section (inspired by reference UI "Device settings" & "Scenes")
        Text(
          'tools',
          style: AppFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w200,
            color: theme.textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MINIMAL SYSTEM UTILITIES & CONTROLLERS',
          style: AppFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 20),

        // TOOL 1: LAUNCHER
        _buildToolTile(
          theme: theme,
          icon: Icons.phone_android_rounded,
          iconColor: const Color(0xFF3B82F6),
          title: 'Minimal Launcher',
          subtitle: 'Terminal & Standard ($themeName) • ${_isDefaultLauncher ? "Default Home" : "Tap to open"} • $_appCount apps',
          onTap: _openLauncher,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'OPEN',
              style: AppFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: theme.isLight ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 2: VOLUME CONTROLLER
        _buildToolTile(
          theme: theme,
          icon: Icons.volume_up_rounded,
          iconColor: theme.accentWarm,
          title: 'Floating Volume Controller',
          subtitle: _isOverlayRunning
              ? 'Floating widget active over all apps'
              : 'Turn on floating widget & system audio mixer',
          onTap: _openVolumeController,
          trailing: Switch(
            value: _isOverlayRunning,
            activeThumbColor: Colors.white,
            activeTrackColor: theme.accentWarm,
            inactiveThumbColor: theme.textMuted,
            inactiveTrackColor: theme.cardSecondary,
            onChanged: (val) => _toggleVolumeOverlay(val, theme),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 3: SYSTEM TELEMETRY
        _buildToolTile(
          theme: theme,
          icon: Icons.memory_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'System Telemetry',
          subtitle: '$model • Android $androidVer',
          onTap: _openLauncher,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.cardSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'sys',
              style: AppFonts.jetBrainsMono(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: theme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 4: SETTINGS
        _buildToolTile(
          theme: theme,
          icon: Icons.tune_rounded,
          iconColor: theme.textSecondary,
          title: 'Settings & Appearance',
          subtitle: 'Themes, fonts, appearance, gestures & lock screen',
          onTap: _openSettings,
          trailing: Icon(Icons.arrow_forward_ios_rounded, color: theme.textMuted, size: 14),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showThemeSwitcherSheet(BuildContext context, AppTheme currentTheme) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: currentTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return Padding(
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
                    decoration: BoxDecoration(
                      color: currentTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'appearance',
                      style: AppFonts.inter(
                        color: currentTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: currentTheme.cardSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: currentTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildThemeOptionTile(
                  theme: currentTheme,
                  title: 'Dark Mode',
                  subtitle: 'OLED Pure Black & Matrix Neon Green',
                  icon: Icons.dark_mode_outlined,
                  isSelected: tp.appThemeMode == ThemeMode.dark,
                  onTap: () {
                    tp.setAppThemeMode(ThemeMode.dark);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 8),
                _buildThemeOptionTile(
                  theme: currentTheme,
                  title: 'Light Mode',
                  subtitle: 'Warm minimalist Nordic daylight tone',
                  icon: Icons.light_mode_outlined,
                  isSelected: tp.appThemeMode == ThemeMode.light,
                  onTap: () {
                    tp.setAppThemeMode(ThemeMode.light);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 8),
                _buildThemeOptionTile(
                  theme: currentTheme,
                  title: 'System Mode',
                  subtitle: 'Auto-matches device system settings',
                  icon: Icons.brightness_auto_outlined,
                  isSelected: tp.appThemeMode == ThemeMode.system,
                  onTap: () {
                    tp.setAppThemeMode(ThemeMode.system);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 16),
                Divider(color: currentTheme.border),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Launcher Shell:',
                      style: AppFonts.inter(color: currentTheme.textSecondary, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () => tp.nextTheme(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentTheme.cardSecondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tp.currentTheme.name.toUpperCase(),
                          style: AppFonts.inter(
                            color: currentTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required AppTheme theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
              : theme.cardSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (theme.isLight ? const Color(0xFF18181B) : Colors.white)
                : theme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (theme.isLight ? Colors.white : Colors.black)
                  : theme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.inter(
                      color: isSelected
                          ? (theme.isLight ? Colors.white : Colors.black)
                          : theme.textPrimary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      color: isSelected
                          ? (theme.isLight ? Colors.white70 : Colors.black54)
                          : theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.isLight ? Colors.white : Colors.black,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolTile({
    required AppTheme theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.isLight ? 0.02 : 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: theme.isLight ? 0.1 : 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.inter(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      color: theme.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  // ─── FLOATING MINIMAL BOTTOM NAV (STACK FORMAT - 3 TABS AS REQUESTED) ───
  Widget _buildFloatingBottomBar(AppTheme theme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.navBarBg,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(color: theme.navBarBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: theme.navBarShadow,
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFloatingNavItem(
              index: 0,
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              tooltip: 'Expenses',
              theme: theme,
            ),
            _buildFloatingNavItem(
              index: 1,
              activeIcon: Icons.calendar_month,
              inactiveIcon: Icons.calendar_month_outlined,
              tooltip: 'Habits',
              theme: theme,
            ),
            _buildFloatingNavItem(
              index: 2,
              activeIcon: Icons.person,
              inactiveIcon: Icons.person_outline,
              tooltip: 'Tools',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String tooltip,
    required AppTheme theme,
  }) {
    final isSelected = _currentIndex == index;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? theme.navActiveCircle : Colors.transparent,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.isLight
                          ? Colors.black.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? theme.navActiveIcon : theme.navInactiveIcon,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
