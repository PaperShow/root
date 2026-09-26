import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../services/launcher_service.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import '../widgets/theme_tip_sheet.dart';
import 'walkthrough_screen.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeProvider themeProvider;

  const SettingsScreen({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackground,
      body: DigitalGrain(
        opacity: theme.isLight ? 0.02 : 0.08,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: themeProvider,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'settings',
                      style: AppFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        color: theme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Color Mode (Dark / Light / System)
                    Text(
                      'APPEARANCE & COLOR MODE',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildModeButton(
                          context,
                          theme: theme,
                          label: 'Dark',
                          icon: Icons.dark_mode_outlined,
                          isSelected: themeProvider.appThemeMode == ThemeMode.dark,
                          onTap: () => themeProvider.setAppThemeMode(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          context,
                          theme: theme,
                          label: 'Light',
                          icon: Icons.light_mode_outlined,
                          isSelected: themeProvider.appThemeMode == ThemeMode.light,
                          onTap: () => themeProvider.setAppThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _buildModeButton(
                          context,
                          theme: theme,
                          label: 'System',
                          icon: Icons.brightness_auto_outlined,
                          isSelected: themeProvider.appThemeMode == ThemeMode.system,
                          onTap: () => themeProvider.setAppThemeMode(ThemeMode.system),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Theme Selection
                    Text(
                      'INTERFACE THEME',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildThemeOption(
                      context,
                      theme: theme,
                      title: 'terminal / command shell',
                      subtitle: 'type to filter apps, run commands & chat with Groq AI',
                      themeType: LauncherThemeType.terminal,
                    ),
                    _buildThemeOption(
                      context,
                      theme: theme,
                      title: 'original / standard phone',
                      subtitle: 'authentic phone home screen with 10-app dock & app drawer',
                      themeType: LauncherThemeType.standard,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      theme: theme,
                      label: 'how this launcher works',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WalkthroughScreen(
                              themeProvider: themeProvider,
                              onDone: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // STANDARD PHONE GRID SETTINGS
                    if (themeProvider.currentTheme == LauncherThemeType.standard) ...[
                      Text(
                        'APP DRAWER GRID',
                        style: AppFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.textMuted,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'number of columns in the scrollable app drawer.',
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: theme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [3, 4, 5].map((n) {
                          final isSelected = themeProvider.standardGridColumns == n;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => themeProvider.setStandardGridColumns(n),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.accent
                                          : theme.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? theme.accent.withValues(alpha: theme.isLight ? 0.08 : 0.12)
                                        : theme.card,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$n',
                                      style: AppFonts.inter(
                                        color: isSelected ? theme.accent : theme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildToggleTile(
                        theme: theme,
                        title: 'show app labels',
                        subtitle: 'display app names under icons in standard launcher grid',
                        value: themeProvider.showAppLabels,
                        onChanged: (val) => themeProvider.toggleShowAppLabels(val),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Features
                    Text(
                      'FEATURES',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildToggleTile(
                      theme: theme,
                      title: 'the intent wall',
                      subtitle: 'mindful 3-second breathing delay before launching apps',
                      value: themeProvider.isIntentWallEnabled,
                      onChanged: (val) => themeProvider.toggleIntentWall(val),
                    ),

                    _buildToggleTile(
                      theme: theme,
                      title: 'app icons',
                      subtitle: 'show colorful app icons in original phone grid',
                      value: themeProvider.isIconsEnabled,
                      onChanged: (val) => themeProvider.toggleIcons(val),
                    ),

                    _buildToggleTile(
                      theme: theme,
                      title: 'status strip',
                      subtitle: 'battery, network and next event under clock',
                      value: themeProvider.isStatusStripEnabled,
                      onChanged: (val) => themeProvider.toggleStatusStrip(val),
                    ),

                    const SizedBox(height: 48),

                    // Groq AI & Voice
                    Text(
                      'GROQ AI & VOICE INTELLIGENCE',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'configured for Groq Compound agentic chat & Groq Whisper voice input.',
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: theme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Model Selector
                    _buildAiModelSelector(context, theme, themeProvider),

                    const SizedBox(height: 12),

                    // API Key Tile
                    _buildApiKeyTile(context, theme, themeProvider),

                    const SizedBox(height: 48),

                    // Wallpaper
                    Text(
                      'WALLPAPER',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'set a solid minimal wallpaper on your home and lock screen.',
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: theme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            theme: theme,
                            label: 'home screen',
                            onTap: () => _setWallpaper(context, theme: theme, which: 1, label: 'home wallpaper'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            theme: theme,
                            label: 'lock screen',
                            onTap: () => _setWallpaper(context, theme: theme, which: 2, label: 'lock screen wallpaper'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            theme: theme,
                            label: 'both',
                            onTap: () => _setWallpaper(context, theme: theme, which: 3, label: 'wallpapers'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 64),

                    // Turn off Launcher
                    Center(
                      child: InkWell(
                        onTap: () => LauncherService.openLauncherSettings(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: theme.isLight ? 0.06 : 0.1),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.35),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.power_settings_new,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'turn off launcher',
                                style: AppFonts.inter(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _setWallpaper(
    BuildContext context, {
    required AppTheme theme,
    required int which,
    required String label,
    int? color,
  }) async {
    final allowed = await LauncherService.canSetWallpaper();
    if (!allowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'wallpaper changes are not allowed on this device',
              style: AppFonts.inter(color: theme.textPrimary),
            ),
            backgroundColor: theme.card,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final ok = await LauncherService.setBlackWallpaper(which: which, color: color);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '$label set' : 'failed to set $label',
            style: AppFonts.inter(color: theme.textPrimary),
          ),
          backgroundColor: theme.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildToggleTile({
    required AppTheme theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(
          color: value
              ? theme.accent.withValues(alpha: theme.isLight ? 0.35 : 0.4)
              : theme.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    color: theme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
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
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.isLight ? Colors.white : Colors.white,
            activeTrackColor: theme.accent,
            inactiveThumbColor: theme.isLight ? const Color(0xFFD4D4D8) : const Color(0xFF71717A),
            inactiveTrackColor: theme.cardSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required AppTheme theme,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accent.withValues(alpha: theme.isLight ? 0.12 : 0.18)
                : theme.cardSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? theme.accent : theme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? theme.accent : theme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppFonts.jetBrainsMono(
                  color: isSelected ? theme.accent : theme.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required AppTheme theme,
    required String title,
    required String subtitle,
    required LauncherThemeType themeType,
  }) {
    final isSelected = themeProvider.currentTheme == themeType;

    return InkWell(
      onTap: () {
        themeProvider.setTheme(themeType);
        if (!themeProvider.hasSeenThemeTip(themeType)) {
          themeProvider.markThemeTipSeen(themeType);
          showThemeTipSheet(context, themeType);
        }
      },
      onLongPress: () => showThemeTipSheet(context, themeType),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.accent : theme.border,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.accent.withValues(alpha: theme.isLight ? 0.06 : 0.12)
              : theme.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.inter(
                      fontSize: 17,
                      fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                      color: theme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_outline, color: theme.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModelSelector(
    BuildContext context,
    AppTheme theme,
    ThemeProvider themeProvider,
  ) {
    final models = [
      {
        'id': 'groq/compound',
        'name': 'groq / compound (recommended)',
        'desc': 'agentic AI with web search & integrated tools',
      },
      {
        'id': 'groq/compound-mini',
        'name': 'groq / compound-mini',
        'desc': 'ultra low-latency compound AI model',
      },
      {
        'id': 'openai/gpt-oss-120b',
        'name': 'openai / gpt-oss-120b',
        'desc': 'powerful 120B open-weights model on Groq LPU',
      },
      {
        'id': 'openai/gpt-oss-20b',
        'name': 'openai / gpt-oss-20b',
        'desc': 'fast 20B open-weights model on Groq LPU',
      },
      {
        'id': 'llama-3.3-70b-versatile',
        'name': 'llama 3.3 70b versatile',
        'desc': 'standard fast open-weight completion model',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'CHAT COMPLETION MODEL',
                style: AppFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...models.map((m) {
            final isSelected = themeProvider.groqAiModel == m['id'];
            return InkWell(
              onTap: () => themeProvider.setGroqAiModel(m['id']!),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.accent.withValues(alpha: theme.isLight ? 0.08 : 0.12)
                      : theme.cardSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? theme.accent
                        : theme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name']!,
                            style: AppFonts.jetBrainsMono(
                              color: isSelected ? theme.accent : theme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['desc']!,
                            style: AppFonts.inter(
                              color: theme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, color: theme.accent, size: 16),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.mic_outlined, color: Color(0xFF3B82F6), size: 14),
              const SizedBox(width: 6),
              Text(
                'VOICE STT: Groq Whisper (${themeProvider.groqWhisperModel})',
                style: AppFonts.jetBrainsMono(
                  fontSize: 10,
                  color: const Color(0xFF3B82F6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyTile(BuildContext context, AppTheme theme, ThemeProvider themeProvider) {
    final hasKey = themeProvider.groqApiKey.isNotEmpty;
    final masked = hasKey
        ? '${themeProvider.groqApiKey.substring(0, themeProvider.groqApiKey.length > 8 ? 8 : themeProvider.groqApiKey.length)}••••••••'
        : 'using built-in default key';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GROQ API KEY',
                style: AppFonts.inter(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.textSecondary, size: 18),
                onPressed: () => _showApiKeyDialog(context, theme, themeProvider),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            masked,
            style: AppFonts.jetBrainsMono(
              color: theme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, AppTheme theme, ThemeProvider themeProvider) {
    final controller = TextEditingController(text: themeProvider.groqApiKey);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: bottomInset + MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Groq API Key',
                style: AppFonts.inter(
                  color: theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your Groq Cloud API key for on-device voice and AI processing.',
                style: AppFonts.inter(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppFonts.jetBrainsMono(color: theme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: AppFonts.jetBrainsMono(color: theme.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: theme.cardSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel', style: AppFonts.inter(color: theme.textMuted, fontWeight: FontWeight.w300)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: theme.isLight ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        themeProvider.setGroqApiKey(controller.text.trim());
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'Save Key',
                        style: AppFonts.inter(fontWeight: FontWeight.w500),
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
  }

  Widget _buildActionButton({
    required AppTheme theme,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.inter(
              color: theme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
