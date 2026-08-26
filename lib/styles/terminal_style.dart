import 'dart:async';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_record_service.dart';
import '../services/groq_service.dart';
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
  final AudioRecordService _audioRecordService = AudioRecordService();

  static final List<TerminalOutput> _persistentHistory = [];
  List<AppInfo> _filteredApps = [];
  List<TerminalContact> _contactList = [];
  String _contactFilter = '';
  TerminalMode _mode = TerminalMode.normal;
  bool _processingCommand = false;

  bool _isRecording = false;
  int _recordingDuration = 0;
  bool _isTranscribing = false;

  StreamSubscription<int>? _durationSub;
  StreamSubscription<AudioRecordStatus>? _statusSub;

  late AnimationController _blinkController;
  late AnimationController _pulseController;

  List<TerminalOutput> get _outputHistory => _persistentHistory;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _durationSub = _audioRecordService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    });

    _statusSub = _audioRecordService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isRecording = status == AudioRecordStatus.recording;
        });
      }
    });

    if (_persistentHistory.isEmpty) {
      _loadSystemInfo();
    }
  }

  Future<void> _loadSystemInfo() async {
    try {
      final sysOutput = await _commandService.executeSystemInfo();
      if (mounted) {
        setState(() {
          _persistentHistory.addAll(sysOutput);
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

    // Voice recording commands via typing
    final lower = trimmed.toLowerCase();
    if (lower == 'voice' ||
        lower == 'rec' ||
        lower == 'mic' ||
        lower == 'listen' ||
        lower == 'whisper') {
      _controller.clear();
      _startVoiceRecording();
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
        _persistentHistory.clear();
        _processingCommand = false;
      });
      return;
    }

    final habitProvider = Provider.of<HabitProvider>(context, listen: false);
    final output = await _commandService.execute(
      trimmed,
      themeProvider: widget.themeProvider,
      habitProvider: habitProvider,
    );

    setState(() {
      _persistentHistory.addAll(output);
      _processingCommand = false;
    });
    _scrollToBottom();
  }

  Future<void> _startVoiceRecording() async {
    final hasPerm = await _audioRecordService.hasPermission();
    if (!hasPerm) {
      setState(() {
        _outputHistory.add(TerminalOutput.error(
          '[WHISPER ERROR] Microphone permission not granted. Please allow microphone access.',
        ));
      });
      _scrollToBottom();
      return;
    }

    final started = await _audioRecordService.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _outputHistory.add(TerminalOutput.info(
          '┌─── GROQ WHISPER VOICE INPUT ───────┐',
        ));
        _outputHistory.add(TerminalOutput(
          text: '  ● Listening... Speak your query or command',
          color: const Color(0xFFFF6B6B),
          isBold: true,
        ));
        _outputHistory.add(TerminalOutput.dim(
          '  Tap [TRANSCRIBE] when finished, or [CANCEL] to abort',
        ));
        _outputHistory.add(TerminalOutput.info(
          '└───────────────────────────────────┘',
        ));
      });
      _scrollToBottom();
    } else {
      setState(() {
        _outputHistory.add(TerminalOutput.error(
          '[WHISPER ERROR] Could not initialize audio recorder.',
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _stopAndTranscribeVoice() async {
    final recordedPath = await _audioRecordService.stopRecording();
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    if (recordedPath == null) {
      setState(() {
        _isTranscribing = false;
        _outputHistory.add(TerminalOutput.error('[WHISPER ERROR] Audio file recording failed.'));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _outputHistory.add(TerminalOutput.info(
        '  [Groq Whisper-large-v3] transcribing audio...',
      ));
    });
    _scrollToBottom();

    final transcription = await GroqService.transcribeAudio(
      filePath: recordedPath,
      apiKey: widget.themeProvider.groqApiKey,
      model: widget.themeProvider.groqWhisperModel,
    );

    setState(() {
      _isTranscribing = false;
    });

    if (transcription.startsWith('[WHISPER ERROR]') ||
        transcription == '[WHISPER] No speech detected.') {
      setState(() {
        _outputHistory.add(TerminalOutput.error(transcription));
      });
      _scrollToBottom();
      return;
    }

    // Speech detected successfully! Echo to terminal and execute
    setState(() {
      _outputHistory.add(TerminalOutput(
        text: '🎙 "$transcription"',
        color: const Color(0xFF69FF94),
        isBold: true,
      ));
    });
    _scrollToBottom();

    _onSubmitted(transcription);
  }

  Future<void> _cancelVoiceRecording() async {
    await _audioRecordService.cancelRecording();
    setState(() {
      _isRecording = false;
      _outputHistory.add(TerminalOutput.dim('  [Whisper] voice recording cancelled.'));
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

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _statusSub?.cancel();
    _audioRecordService.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _blinkController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── OUTPUT AREA ───────────────────────────────
            Expanded(
              child: _mode == TerminalMode.contactPicker
                  ? _buildContactPicker()
                  : _buildOutputAndResults(),
            ),

            const SizedBox(height: 8),

            // ─── VOICE HUD / INPUT LINE ───────────────────
            if (_isRecording)
              _buildVoiceRecordingHud()
            else
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

  /// Interactive live recording HUD in the terminal
  Widget _buildVoiceRecordingHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Pulsing REC Dot
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B6B).withValues(
                    alpha: 0.4 + (_pulseController.value * 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(
                        alpha: _pulseController.value * 0.5,
                      ),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),

          // REC Time
          Text(
            'REC ${_formatDuration(_recordingDuration)}',
            style: AppFonts.jetBrainsMono(
              color: const Color(0xFFFF6B6B),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(width: 12),

          // Animated Waveform Bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final factor = ((i % 3) + 1) * 0.3;
                    final height = 4.0 + (12.0 * ((_pulseController.value * factor) % 1.0));
                    return Container(
                      width: 3,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69FF94).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              }),
            ),
          ),

          const SizedBox(width: 12),

          // Transcribe Button
          InkWell(
            onTap: _stopAndTranscribeVoice,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF69FF94).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF69FF94).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                'DONE ›',
                style: AppFonts.jetBrainsMono(
                  color: const Color(0xFF69FF94),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Cancel Button
          InkWell(
            onTap: _cancelVoiceRecording,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '✕',
                style: AppFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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
                  : 'type AI query, command or tap mic...',
              hintStyle: AppFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Transcription progress
        if (_isTranscribing) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF82AAFF)),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Command processing indicator
        if (_processingCommand && !_isTranscribing) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF69FF94)),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Terminal Mic Action Button
        if (!isContactMode)
          GestureDetector(
            onTap: _startVoiceRecording,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF69FF94).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF69FF94).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mic_none_rounded,
                    color: Color(0xFF69FF94),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REC',
                    style: AppFonts.jetBrainsMono(
                      color: const Color(0xFF69FF94),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
