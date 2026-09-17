import 'package:flutter/material.dart';

import '../services/volume_controller_service.dart';
import '../utils/app_fonts.dart';

class VolumeControllerScreen extends StatefulWidget {
  const VolumeControllerScreen({super.key});

  @override
  State<VolumeControllerScreen> createState() => _VolumeControllerScreenState();
}

class _VolumeControllerScreenState extends State<VolumeControllerScreen>
    with WidgetsBindingObserver {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF222222);

  bool _isOverlayRunning = false;
  bool _hasOverlayPermission = true;
  VolumeLevels? _volumeLevels;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final hasPerm = await VolumeControllerService.isOverlayPermissionGranted();
    final isRunning = await VolumeControllerService.isVolumeOverlayRunning();
    final levels = await VolumeControllerService.getVolumeLevels();

    if (mounted) {
      setState(() {
        _hasOverlayPermission = hasPerm;
        _isOverlayRunning = isRunning;
        _volumeLevels = levels;
        _loading = false;
      });
    }
  }

  Future<void> _toggleOverlay(bool enable) async {
    if (enable) {
      if (!_hasOverlayPermission) {
        await _promptOverlayPermission();
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

  Future<void> _promptOverlayPermission() async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder),
        ),
        title: Text(
          'OVERLAY PERMISSION',
          style: AppFonts.jetBrainsMono(
            color: terminalGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Android requires "Display over other apps" permission so the floating volume widget can stay accessible over all applications.',
          style: AppFonts.inter(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: AppFonts.jetBrainsMono(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: terminalGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'OPEN SETTINGS',
              style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await VolumeControllerService.requestOverlayPermission();
    }
  }

  Future<void> _setVolume(String stream, int value) async {
    await VolumeControllerService.setVolumeLevel(stream, value);
    final levels = await VolumeControllerService.getVolumeLevels();
    if (mounted && levels != null) {
      setState(() {
        _volumeLevels = levels;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP BAR ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '// VOLUME_CONTROLLER',
                        style: AppFonts.jetBrainsMono(
                          color: terminalGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'floating overlay & system mixer',
                        style: AppFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                    onPressed: _refreshState,
                    tooltip: 'Refresh Volumes',
                  ),
                ],
              ),
            ),

            // ─── MAIN CONTENT ──────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: terminalGreen),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // MASTER FLOATING WIDGET CARD
                        _buildFloatingOverlayCard(),
                        const SizedBox(height: 18),

                        // QUICK ACTION SHORTCUTS
                        _buildQuickActionsRow(),
                        const SizedBox(height: 20),

                        // SYSTEM VOLUME SLIDERS
                        Text(
                          'HARDWARE AUDIO STREAMS',
                          style: AppFonts.jetBrainsMono(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_volumeLevels != null) ...[
                          _buildStreamSliderCard(
                            title: 'Media Audio',
                            subtitle: 'Music, videos, games, browser',
                            icon: Icons.music_note,
                            streamKey: 'media',
                            info: _volumeLevels!.media,
                          ),
                          const SizedBox(height: 10),
                          _buildStreamSliderCard(
                            title: 'Ringtone',
                            subtitle: 'Incoming phone calls',
                            icon: Icons.notifications_active_outlined,
                            streamKey: 'ring',
                            info: _volumeLevels!.ring,
                          ),
                          const SizedBox(height: 10),
                          _buildStreamSliderCard(
                            title: 'Notifications',
                            subtitle: 'Messages, app alerts & ping sounds',
                            icon: Icons.chat_bubble_outline,
                            streamKey: 'notification',
                            info: _volumeLevels!.notification,
                          ),
                          const SizedBox(height: 10),
                          _buildStreamSliderCard(
                            title: 'Alarms',
                            subtitle: 'Wake up clock & timer alerts',
                            icon: Icons.alarm,
                            streamKey: 'alarm',
                            info: _volumeLevels!.alarm,
                          ),
                          const SizedBox(height: 10),
                          _buildStreamSliderCard(
                            title: 'In-Call Voice',
                            subtitle: 'Phone call ear speaker',
                            icon: Icons.phone_in_talk,
                            streamKey: 'call',
                            info: _volumeLevels!.call,
                          ),
                        ],

                        const SizedBox(height: 24),
                        _buildWidgetFeaturesInfo(),
                        const SizedBox(height: 30),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingOverlayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOverlayRunning ? terminalGreen.withValues(alpha: 0.4) : surfaceBorder,
          width: 1.2,
        ),
        boxShadow: _isOverlayRunning
            ? [
                BoxShadow(
                  color: terminalGreen.withValues(alpha: 0.1),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isOverlayRunning
                      ? terminalGreen.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isOverlayRunning ? terminalGreen : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isOverlayRunning ? Icons.volume_up : Icons.volume_mute,
                  color: _isOverlayRunning ? terminalGreen : Colors.white54,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'FLOATING WIDGET',
                          style: AppFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isOverlayRunning
                                ? terminalGreen.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isOverlayRunning ? 'ACTIVE' : 'OFF',
                            style: AppFonts.jetBrainsMono(
                              color: _isOverlayRunning ? terminalGreen : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shows a draggable floating volume widget over all apps and home screen.',
                      style: AppFonts.inter(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOverlayRunning,
                activeThumbColor: terminalGreen,
                activeTrackColor: terminalGreen.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
                onChanged: (val) => _toggleOverlay(val),
              ),
            ],
          ),
          if (!_hasOverlayPermission) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Overlay permission required to draw over other apps.',
                      style: AppFonts.inter(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: _promptOverlayPermission,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'ENABLE',
                      style: AppFonts.jetBrainsMono(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'MUTE MEDIA',
            icon: Icons.volume_off,
            onTap: () => _setVolume('media', 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            label: '50% VOLUME',
            icon: Icons.volume_down,
            onTap: () {
              final max = _volumeLevels?.media.max ?? 15;
              _setVolume('media', (max / 2).round());
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            label: 'MAX MEDIA',
            icon: Icons.volume_up,
            onTap: () {
              final max = _volumeLevels?.media.max ?? 15;
              _setVolume('media', max);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: terminalGreen, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamSliderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String streamKey,
    required VolumeStreamInfo info,
  }) {
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
          Row(
            children: [
              Icon(icon, color: terminalGreen, size: 18),
              const SizedBox(width: 10),
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
                    Text(
                      subtitle,
                      style: AppFonts.inter(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Text(
                  '${info.percent}%',
                  style: AppFonts.jetBrainsMono(
                    color: terminalGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: terminalGreen,
              inactiveTrackColor: surfaceBorder,
              thumbColor: terminalGreen,
              overlayColor: terminalGreen.withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: info.current.toDouble(),
              min: 0,
              max: info.max.toDouble(),
              divisions: info.max > 0 ? info.max : 1,
              onChanged: (val) {
                _setVolume(streamKey, val.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetFeaturesInfo() {
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
            '// FLOATING WIDGET HIGHLIGHTS',
            style: AppFonts.jetBrainsMono(
              color: terminalGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _buildFeatureBullet('Drag Anywhere', 'Freely reposition the widget anywhere on your screen.'),
          _buildFeatureBullet('Instant Tap HUD', 'Tap the pill to expand an interactive volume controller panel.'),
          _buildFeatureBullet('Hardware Sync', 'Auto-syncs in real time when you press device volume buttons.'),
          _buildFeatureBullet('Auto-Collapse', 'Collapses back to a sleek mini pill after 8 seconds of idle time.'),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppFonts.jetBrainsMono(color: terminalGreen)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppFonts.inter(color: Colors.white70, fontSize: 12),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
