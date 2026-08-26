import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../services/launcher_service.dart';
import '../utils/app_fonts.dart';
import '../widgets/digital_grain.dart';
import '../widgets/theme_tip_sheet.dart';
import 'walkthrough_screen.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeProvider themeProvider;

  const SettingsScreen({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DigitalGrain(
        opacity: 0.08,
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'settings',
                      style: AppFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Theme Selection
                    Text(
                      'INTERFACE THEME',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildThemeOption(
                      context,
                      title: 'terminal / command shell',
                      subtitle: 'type to filter apps, run commands & chat with Groq AI',
                      theme: LauncherThemeType.terminal,
                    ),
                    _buildThemeOption(
                      context,
                      title: 'original / standard phone',
                      subtitle: 'authentic phone home screen with 10-app dock & app drawer',
                      theme: LauncherThemeType.standard,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
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
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'number of columns in the scrollable app drawer.',
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
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
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.15),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$n',
                                      style: AppFonts.inter(
                                        color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildToggleTile(
                      title: 'the intent wall',
                      subtitle: 'mindful 3-second breathing delay before launching apps',
                      value: themeProvider.isIntentWallEnabled,
                      onChanged: (val) => themeProvider.toggleIntentWall(val),
                    ),

                    _buildToggleTile(
                      title: 'app icons',
                      subtitle: 'show colorful app icons in original phone grid',
                      value: themeProvider.isIconsEnabled,
                      onChanged: (val) => themeProvider.toggleIcons(val),
                    ),

                    _buildToggleTile(
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
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'configured for Groq Compound agentic chat & Groq Whisper voice input.',
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Model Selector
                    _buildAiModelSelector(context, themeProvider),

                    const SizedBox(height: 12),

                    // API Key Tile
                    _buildApiKeyTile(context, themeProvider),

                    const SizedBox(height: 48),

                    // Wallpaper
                    Text(
                      'WALLPAPER',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'set a solid black wallpaper on your home and lock screen.',
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'home screen',
                            onTap: () => _setWallpaper(context, which: 1, label: 'home wallpaper'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'lock screen',
                            onTap: () => _setWallpaper(context, which: 2, label: 'lock screen wallpaper'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'both',
                            onTap: () => _setWallpaper(context, which: 3, label: 'wallpapers'),
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
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.power_settings_new,
                                color: Colors.redAccent.withValues(alpha: 0.7),
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'turn off launcher',
                                style: AppFonts.inter(
                                  color: Colors.redAccent.withValues(alpha: 0.7),
                                  fontSize: 14,
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
              style: AppFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.15),
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
            style: AppFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: value
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
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
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.4),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required LauncherThemeType theme,
  }) {
    final isSelected = themeProvider.currentTheme == theme;

    return InkWell(
      onTap: () {
        themeProvider.setTheme(theme);
        if (!themeProvider.hasSeenThemeTip(theme)) {
          themeProvider.markThemeTipSeen(theme);
          showThemeTipSheet(context, theme);
        }
      },
      onLongPress: () => showThemeTipSheet(context, theme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : null,
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
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.w400 : FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModelSelector(
    BuildContext context,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: Color(0xFF69FF94), size: 18),
              const SizedBox(width: 8),
              Text(
                'CHAT COMPLETION MODEL',
                style: AppFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF69FF94),
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
                  color: isSelected ? Colors.white.withValues(alpha: 0.08) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF69FF94).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
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
                              color: isSelected ? const Color(0xFF69FF94) : Colors.white,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['desc']!,
                            style: AppFonts.inter(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check, color: Color(0xFF69FF94), size: 16),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.mic, color: Color(0xFF82AAFF), size: 14),
              const SizedBox(width: 6),
              Text(
                'VOICE STT: Groq Whisper (${themeProvider.groqWhisperModel})',
                style: AppFonts.jetBrainsMono(
                  fontSize: 10,
                  color: const Color(0xFF82AAFF).withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyTile(BuildContext context, ThemeProvider themeProvider) {
    final hasKey = themeProvider.groqApiKey.isNotEmpty;
    final masked = hasKey
        ? '${themeProvider.groqApiKey.substring(0, themeProvider.groqApiKey.length > 8 ? 8 : themeProvider.groqApiKey.length)}••••••••'
        : 'using built-in default key';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                onPressed: () => _showApiKeyDialog(context, themeProvider),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            masked,
            style: AppFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, ThemeProvider themeProvider) {
    final controller = TextEditingController(text: themeProvider.groqApiKey);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: Text(
            'Groq API Key',
            style: AppFonts.inter(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            style: AppFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'gsk_...',
              hintStyle: AppFonts.jetBrainsMono(color: Colors.white30, fontSize: 13),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF69FF94)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('cancel', style: AppFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                themeProvider.setGroqApiKey(controller.text.trim());
                Navigator.of(ctx).pop();
              },
              child: Text(
                'save',
                style: AppFonts.inter(color: const Color(0xFF69FF94), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.inter(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
