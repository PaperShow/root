import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/launcher_service.dart';
import '../services/volume_controller_service.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import 'expense_tracker_screen.dart';
import 'habit_tracker_screen.dart';
import 'home_screen.dart';
import 'scratchpad_screen.dart';
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
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF202020);

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

  Future<void> _toggleVolumeOverlay(bool enable) async {
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
    return Scaffold(
      backgroundColor: pureBlack,
      body: DigitalGrain(
        opacity: 0.05,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ─── MINIMAL ROOTL HEADER ──────────────────────────
              _buildTopHeader(),

              // ─── TAB CONTENT (INDEXED STACK) ───────────────────
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    // Tab 0: Expense
                    const ExpenseTrackerScreen(isEmbedded: true),

                    // Tab 1: Habit
                    const HabitTrackerScreen(isEmbedded: true),

                    // Tab 2: Notes / Scratchpad
                    const ScratchpadScreen(isEmbedded: true),

                    // Tab 3: Tools
                    _buildToolsTab(),
                  ],
                ),
              ),

              // ─── BOTTOM NAVIGATION BAR ─────────────────────────
              _buildBottomNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: pureBlack,
        border: Border(
          bottom: BorderSide(color: Color(0xFF141414), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/root_icon_load.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const Icon(
              Icons.terminal,
              color: terminalGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'RootL',
            style: AppFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.white70, size: 20),
            tooltip: 'Theme Mode',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showThemeSwitcherSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
            tooltip: 'Settings',
            visualDensity: VisualDensity.compact,
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    final themeName = widget.themeProvider.currentTheme.name.toUpperCase();
    final model = _systemInfo['deviceModel'] ?? 'Android Device';
    final androidVer = _systemInfo['androidVersion'] ?? 'OS';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        // TOOL 1: LAUNCHER
        _buildToolTile(
          icon: Icons.phone_android,
          iconColor: const Color(0xFF54A0FF),
          title: 'Minimal Launcher',
          subtitle: 'Terminal & Standard ($themeName) • ${_isDefaultLauncher ? "Default Home" : "Tap to open"} • $_appCount apps',
          onTap: _openLauncher,
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF54A0FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openLauncher,
            child: Text(
              'OPEN',
              style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 2: VOLUME CONTROLLER
        _buildToolTile(
          icon: Icons.volume_up,
          iconColor: terminalGreen,
          title: 'Floating Volume Controller',
          subtitle: _isOverlayRunning
              ? 'Floating widget is active over all apps'
              : 'Turn on floating widget & system audio mixer',
          onTap: _openVolumeController,
          trailing: Switch(
            value: _isOverlayRunning,
            activeThumbColor: terminalGreen,
            activeTrackColor: terminalGreen.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            onChanged: (val) => _toggleVolumeOverlay(val),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 3: SYSTEM TELEMETRY
        _buildToolTile(
          icon: Icons.memory,
          iconColor: const Color(0xFFA29BFE),
          title: 'System Telemetry',
          subtitle: '$model • Android $androidVer',
          onTap: _openLauncher,
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA29BFE),
              side: BorderSide(color: const Color(0xFFA29BFE).withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _openLauncher,
            child: Text(
              'sys',
              style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // TOOL 4: SETTINGS
        _buildToolTile(
          icon: Icons.tune,
          iconColor: Colors.white70,
          title: 'Settings & Customization',
          subtitle: 'Themes, fonts, appearance, gestures & lock screen',
          onTap: _openSettings,
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showThemeSwitcherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: surfaceBorder),
      ),
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, tp, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '// THEME & APPEARANCE',
                  style: AppFonts.jetBrainsMono(
                    color: terminalGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildThemeOptionTile(
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
                  title: 'Light Mode',
                  subtitle: 'Clean minimalist white and daylight clarity',
                  icon: Icons.light_mode_outlined,
                  isSelected: tp.appThemeMode == ThemeMode.light,
                  onTap: () {
                    tp.setAppThemeMode(ThemeMode.light);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 8),
                _buildThemeOptionTile(
                  title: 'System Mode',
                  subtitle: 'Auto-matches your Android device settings',
                  icon: Icons.brightness_auto_outlined,
                  isSelected: tp.appThemeMode == ThemeMode.system,
                  onTap: () {
                    tp.setAppThemeMode(ThemeMode.system);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: surfaceBorder),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Launcher Style:',
                      style: AppFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () => tp.nextTheme(),
                      child: Text(
                        tp.currentTheme.name.toUpperCase(),
                        style: AppFonts.jetBrainsMono(color: terminalGreen, fontWeight: FontWeight.bold),
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
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? terminalGreen.withValues(alpha: 0.12) : Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? terminalGreen : surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? terminalGreen : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.jetBrainsMono(
                      color: isSelected ? terminalGreen : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: terminalGreen, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: pureBlack,
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'EXPENSE',
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
              ),
              _buildNavItem(
                index: 1,
                label: 'HABIT',
                icon: Icons.check_circle_outline,
                activeIcon: Icons.check_circle,
              ),
              _buildNavItem(
                index: 2,
                label: 'NOTES',
                icon: Icons.edit_note_outlined,
                activeIcon: Icons.edit_note,
              ),
              _buildNavItem(
                index: 3,
                label: 'TOOLS',
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? terminalGreen : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppFonts.jetBrainsMono(
                color: isSelected ? terminalGreen : Colors.white38,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
