import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../providers/theme_provider.dart';
import '../utils/app_fonts.dart';
import '../utils/app_launcher.dart';

class StandardStyle extends StatefulWidget {
  final List<AppInfo> apps;
  final ThemeProvider themeProvider;
  final double contentTopPadding;

  const StandardStyle({
    super.key,
    required this.apps,
    required this.themeProvider,
    required this.contentTopPadding,
  });

  @override
  State<StandardStyle> createState() => _StandardStyleState();
}

class _StandardStyleState extends State<StandardStyle> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.apps;
    return widget.apps
        .where((app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _scrollToAllApps() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.themeProvider.standardGridColumns;
    final showLabels = widget.themeProvider.showAppLabels;
    final showIcons = widget.themeProvider.isIconsEnabled;
    final pinnedPackages = widget.themeProvider.pinnedApps;

    // Up to 10 pinned apps
    final pinnedAppInfos = widget.apps
        .where((app) => pinnedPackages.contains(app.packageName))
        .take(ThemeProvider.maxDockApps)
        .toList();

    return Padding(
      padding: EdgeInsets.only(top: widget.contentTopPadding),
      child: Column(
        children: [
          // ─── SEARCH BAR ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: const Color(0xFF69FF94).withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      style: AppFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'search apps...',
                        hintStyle: AppFonts.inter(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── CONTENT AREA ────────────────────────────────
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(columns, showLabels, showIcons)
                : _buildHomeAndDrawer(pinnedAppInfos, columns, showLabels, showIcons),
          ),
        ],
      ),
    );
  }

  /// When searching, show direct matches immediately
  Widget _buildSearchResults(int columns, bool showLabels, bool showIcons) {
    if (_filteredApps.isEmpty) {
      return Center(
        child: Text(
          'no matching apps found',
          style: AppFonts.inter(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: showLabels ? 0.82 : 1.0,
      ),
      itemCount: _filteredApps.length,
      itemBuilder: (context, index) {
        final app = _filteredApps[index];
        return _buildAppItem(app, showLabels, showIcons);
      },
    );
  }

  /// Two-stage view: Front screen with 10-app Dock + Scroll down for All Apps
  Widget _buildHomeAndDrawer(
    List<AppInfo> pinnedAppInfos,
    int columns,
    bool showLabels,
    bool showIcons,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ══════════════════════════════════════════════
              // SECTION 1: FRONT SCREEN (DOCK MAX 10)
              // ══════════════════════════════════════════════
              SizedBox(
                height: screenHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      const Spacer(),

                      // Quick tip / info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              color: const Color(0xFF69FF94).withValues(alpha: 0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'scroll down for all apps • long press to pin',
                              style: AppFonts.inter(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // FRONT DOCK (MAX 10 APPS)
                      _buildFrontDock(pinnedAppInfos, showLabels, showIcons),

                      const SizedBox(height: 16),

                      // SCROLL DOWN BUTTON INDICATOR
                      InkWell(
                        onTap: _scrollToAllApps,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ALL APPS',
                                style: AppFonts.jetBrainsMono(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: const Color(0xFF69FF94).withValues(alpha: 0.8),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ══════════════════════════════════════════════
              // SECTION 2: ALL APPS GRID (SCROLL DOWN)
              // ══════════════════════════════════════════════
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Drawer Header
                    Row(
                      children: [
                        Text(
                          '// ALL_APPS (${widget.apps.length})',
                          style: AppFonts.jetBrainsMono(
                            color: const Color(0xFF69FF94),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _scrollToTop,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'TOP',
                                  style: AppFonts.jetBrainsMono(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_upward, color: Colors.white.withValues(alpha: 0.6), size: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Grid of all apps
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: showLabels ? 0.82 : 1.0,
                      ),
                      itemCount: widget.apps.length,
                      itemBuilder: (context, index) {
                        final app = widget.apps[index];
                        return _buildAppItem(app, showLabels, showIcons);
                      },
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Front Dock supporting up to 10 apps
  Widget _buildFrontDock(
    List<AppInfo> pinnedAppInfos,
    bool showLabels,
    bool showIcons,
  ) {
    if (pinnedAppInfos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_to_home_screen,
                color: const Color(0xFF69FF94).withValues(alpha: 0.6),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                'DOCK IS EMPTY (MAX 10 APPS)',
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'scroll down & long-press any app to pin it here',
                style: AppFonts.inter(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Text(
                  '// DOCK (${pinnedAppInfos.length}/${ThemeProvider.maxDockApps})',
                  style: AppFonts.jetBrainsMono(
                    color: const Color(0xFF69FF94),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: showLabels ? 0.78 : 1.0,
            ),
            itemCount: pinnedAppInfos.length,
            itemBuilder: (context, index) {
              final app = pinnedAppInfos[index];
              return InkWell(
                onTap: () => AppLauncher.launch(context, app, widget.themeProvider),
                onLongPress: () {
                  widget.themeProvider.togglePinned(app.packageName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unpinned ${app.name} from Dock',
                        style: AppFonts.inter(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF69FF94).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Center(
                        child: (showIcons && app.icon != null)
                            ? Image.memory(
                                app.icon!,
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFallbackIcon(app.name, size: 16),
                              )
                            : _buildFallbackIcon(app.name, size: 16),
                      ),
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: 4),
                      Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(AppInfo app, bool showLabels, bool showIcons) {
    final isPinned = widget.themeProvider.isPinned(app.packageName);

    return InkWell(
      onTap: () => AppLauncher.launch(context, app, widget.themeProvider),
      onLongPress: () {
        final pinnedCount = widget.themeProvider.pinnedApps.length;
        if (!isPinned && pinnedCount >= ThemeProvider.maxDockApps) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dock is full (max ${ThemeProvider.maxDockApps} apps)',
                style: AppFonts.inter(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.7),
            ),
          );
          return;
        }

        final newlyPinned = widget.themeProvider.togglePinned(app.packageName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newlyPinned
                  ? 'Pinned ${app.name} to Dock'
                  : 'Unpinned ${app.name} from Dock',
              style: AppFonts.inter(color: Colors.white),
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPinned
                    ? const Color(0xFF69FF94).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
                width: isPinned ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: (showIcons && app.icon != null)
                  ? Image.memory(
                      app.icon!,
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackIcon(app.name),
                    )
                  : _buildFallbackIcon(app.name),
            ),
          ),
          if (showLabels) ...[
            const SizedBox(height: 6),
            Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(String name, {double size = 18}) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      letter,
      style: AppFonts.outfit(
        color: const Color(0xFF69FF94),
        fontSize: size,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
