import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../providers/theme_provider.dart';
import '../services/terminal_command_service.dart';
import '../utils/app_fonts.dart';
import '../utils/app_launcher.dart';

class TerminalStyle extends StatefulWidget {
  final List<AppInfo> apps;
  final ThemeProvider themeProvider;
  final VoidCallback? onSwipeLeft;

  const TerminalStyle({
    super.key,
    required this.apps,
    required this.themeProvider,
    this.onSwipeLeft,
  });

  @override
  State<TerminalStyle> createState() => _TerminalStyleState();
}

class _TerminalStyleState extends State<TerminalStyle> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TerminalCommandService _commandService = TerminalCommandService();

  List<AppInfo> _filteredApps = [];
  List<TerminalOutput> _outputHistory = [];
  List<TerminalContact> _contactList = [];
  String _contactFilter = '';
  TerminalMode _mode = TerminalMode.normal;
  bool _processingCommand = false;

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _outputHistory = [];
    _loadSystemInfo();
  }

  Future<void> _loadSystemInfo() async {
    try {
      final sysOutput = await _commandService.executeSystemInfo();
      if (mounted) {
        setState(() {
          _outputHistory.addAll(sysOutput);
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _onInputChanged(String query) {
    if (_mode == TerminalMode.contactPicker) {
      _filterContacts(query);
      return;
    }

    final cmdPrefix = _commandService.getCommandPrefix(query);

    if (cmdPrefix != null) {
      setState(() {
        _filteredApps = [];
      });
      return;
    }

    _filterApps(query);
  }

  void _filterApps(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredApps = [];
      });
      return;
    }

    setState(() {
      _filteredApps = widget.apps
          .where((app) => app.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
    _scrollToBottom();
  }

  void _filterContacts(String query) {
    setState(() {
      _contactFilter = query;
    });
  }

  List<TerminalContact> get _filteredContacts {
    if (_contactFilter.isEmpty) return _contactList;
    return _contactList
        .where((c) => c.name.toLowerCase().contains(_contactFilter.toLowerCase()))
        .toList();
  }

  void _onSubmitted(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    if (_mode == TerminalMode.contactPicker) {
      final index = int.tryParse(trimmed);
      if (index != null && index >= 1 && index <= _filteredContacts.length) {
        final contact = _filteredContacts[index - 1];
        _controller.clear();
        setState(() {
          _mode = TerminalMode.normal;
          _contactList = [];
          _contactFilter = '';
        });
        final output = await _commandService.callDirect(contact);
        setState(() {
          _outputHistory.addAll(output);
        });
        _scrollToBottom();
        return;
      }

      final matches = _filteredContacts
          .where((c) => c.name.toLowerCase().contains(trimmed.toLowerCase()))
          .toList();
      if (matches.length == 1) {
        _controller.clear();
        setState(() {
          _mode = TerminalMode.normal;
          _contactList = [];
          _contactFilter = '';
        });
        final output = await _commandService.callDirect(matches.first);
        setState(() {
          _outputHistory.addAll(output);
        });
        _scrollToBottom();
        return;
      }
      return;
    }

    // Check if exact app match exists and input is single app name
    final exactAppMatches = widget.apps
        .where((app) => app.name.toLowerCase() == trimmed.toLowerCase())
        .toList();

    if (exactAppMatches.isNotEmpty && !_commandService.isCommand(trimmed)) {
      _launchApp(exactAppMatches.first);
      return;
    }

    // Process command or route query to Groq AI
    _controller.clear();
    setState(() {
      _filteredApps = [];
      _processingCommand = true;
    });

    if (trimmed.toLowerCase() == 'call') {
      setState(() {
        _outputHistory.add(TerminalOutput.info('[SYS] loading contacts...'));
      });

      final contacts = await _commandService.getContacts();

      if (contacts.isEmpty) {
        setState(() {
          _outputHistory.add(TerminalOutput.error('  no contacts found or permission denied'));
          _processingCommand = false;
        });
        _scrollToBottom();
        return;
      }

      setState(() {
        _contactList = contacts;
        _contactFilter = '';
        _mode = TerminalMode.contactPicker;
        _outputHistory.add(TerminalOutput.success('  ${contacts.length} contacts loaded'));
        _outputHistory.add(TerminalOutput.info('  type name to filter, or # to select'));
        _processingCommand = false;
      });
      _scrollToBottom();
      return;
    }

    if (trimmed.toLowerCase() == 'clear') {
      setState(() {
        _outputHistory = [];
        _processingCommand = false;
      });
      return;
    }

    final output = await _commandService.execute(
      trimmed,
      themeProvider: widget.themeProvider,
    );

    setState(() {
      _outputHistory.addAll(output);
      _processingCommand = false;
    });
    _scrollToBottom();
  }

  void _launchApp(AppInfo app) {
    AppLauncher.launch(context, app, widget.themeProvider);
    _controller.clear();
    _filterApps('');
    _focusNode.unfocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _exitContactPicker() {
    setState(() {
      _mode = TerminalMode.normal;
      _contactList = [];
      _contactFilter = '';
    });
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HABIT TRACKER SWIPE HINT ──────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '// TERMINAL_AI_SHELL',
                    style: AppFonts.jetBrainsMono(
                      color: const Color(0xFF69FF94).withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSwipeLeft,
                    child: Text(
                      'HABITS →',
                      style: AppFonts.jetBrainsMono(
                        color: const Color(0xFF69FF94),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── OUTPUT AREA ───────────────────────────────
            Expanded(
              child: _mode == TerminalMode.contactPicker
                  ? _buildContactPicker()
                  : _buildOutputAndResults(),
            ),

            const SizedBox(height: 8),

            // ─── INPUT LINE ────────────────────────────────
            _buildInputLine(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputAndResults() {
    final hasFilteredApps = _filteredApps.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: hasFilteredApps ? 0 : 1,
          child: hasFilteredApps
              ? const SizedBox.shrink()
              : ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  children: _outputHistory.map(_buildOutputLine).toList(),
                ),
        ),

        if (hasFilteredApps)
          Expanded(
            child: ListView.builder(
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredApps.length,
              itemBuilder: (context, index) {
                final app = _filteredApps[_filteredApps.length - 1 - index];
                return _buildAppResult(app);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOutputLine(TerminalOutput output) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SelectableText(
        output.text,
        style: AppFonts.jetBrainsMono(
          color: output.color,
          fontSize: 13,
          fontWeight: output.isBold ? FontWeight.bold : FontWeight.normal,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAppResult(AppInfo app) {
    return InkWell(
      onTap: () => _launchApp(app),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Text(
              '› ',
              style: AppFonts.jetBrainsMono(
                color: const Color(0xFF69FF94),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                app.name.toLowerCase(),
                style: AppFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'launch →',
              style: AppFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPicker() {
    final contacts = _filteredContacts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '─── CONTACTS ',
              style: AppFonts.jetBrainsMono(
                color: const Color(0xFF82AAFF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                '─' * 40,
                style: AppFonts.jetBrainsMono(
                  color: const Color(0xFF82AAFF).withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
            ),
            GestureDetector(
              onTap: _exitContactPicker,
              child: Text(
                ' [ESC] ',
                style: AppFonts.jetBrainsMono(
                  color: const Color(0xFFFF6B6B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Expanded(
          child: contacts.isEmpty
              ? Center(
                  child: Text(
                    'no contacts match',
                    style: AppFonts.jetBrainsMono(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return InkWell(
                      onTap: () async {
                        _controller.clear();
                        setState(() {
                          _mode = TerminalMode.normal;
                          _contactList = [];
                          _contactFilter = '';
                        });
                        final output = await _commandService.callDirect(contact);
                        setState(() {
                          _outputHistory.addAll(output);
                        });
                        _scrollToBottom();
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${index + 1}.',
                                style: AppFonts.jetBrainsMono(
                                  color: const Color(0xFF69FF94).withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                contact.name.toLowerCase(),
                                style: AppFonts.jetBrainsMono(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              contact.phone,
                              style: AppFonts.jetBrainsMono(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInputLine() {
    final isContactMode = _mode == TerminalMode.contactPicker;
    final promptColor = isContactMode ? const Color(0xFF82AAFF) : const Color(0xFF69FF94);
    final promptText = isContactMode ? 'call> ' : '\$ ';

    return Row(
      children: [
        AnimatedBuilder(
          animation: _blinkController,
          builder: (context, child) {
            return Text(
              promptText,
              style: AppFonts.jetBrainsMono(
                color: promptColor.withValues(
                  alpha: 0.6 + (_blinkController.value * 0.4),
                ),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _onInputChanged,
            onSubmitted: _onSubmitted,
            style: AppFonts.jetBrainsMono(
              color: promptColor,
              fontSize: 16,
            ),
            cursorColor: promptColor,
            cursorWidth: 8,
            cursorHeight: 18,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: isContactMode
                  ? 'search or tap to call...'
                  : 'type AI question or command...',
              hintStyle: AppFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (_processingCommand)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF69FF94)),
            ),
          ),
      ],
    );
  }
}
