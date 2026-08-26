import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/habit_provider.dart';
import '../providers/theme_provider.dart';
import 'groq_service.dart';
import 'launcher_service.dart';

/// Represents a line of output in the terminal history.
class TerminalOutput {
  final String text;
  final Color color;
  final bool isBold;
  final DateTime timestamp;

  TerminalOutput({
    required this.text,
    this.color = Colors.green,
    this.isBold = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TerminalOutput.error(String text)
      : this(text: text, color: const Color(0xFFFF6B6B), isBold: true);

  TerminalOutput.success(String text)
      : this(text: text, color: const Color(0xFF69FF94));

  TerminalOutput.info(String text)
      : this(text: text, color: const Color(0xFF82AAFF));

  TerminalOutput.system(String text)
      : this(text: text, color: Colors.green.withValues(alpha: 0.6));

  TerminalOutput.result(String text)
      : this(text: text, color: const Color(0xFFFFD580), isBold: true);

  TerminalOutput.dim(String text)
      : this(text: text, color: Colors.white.withValues(alpha: 0.35));

  TerminalOutput.ai(String text)
      : this(text: text, color: const Color(0xFF69FF94), isBold: false);

  TerminalOutput.aiHeader(String text)
      : this(text: text, color: const Color(0xFF69FF94), isBold: true);
}

/// A contact entry with name and phone number for display in the terminal.
class TerminalContact {
  final String name;
  final String phone;

  TerminalContact({required this.name, required this.phone});
}

/// The mode the terminal is currently in.
enum TerminalMode {
  normal,         // Regular app search + command mode
  contactPicker,  // Showing contact list for call/msg
}

/// Service that parses and executes terminal power commands & Groq AI queries.
class TerminalCommandService {
  List<TerminalContact> _cachedContacts = [];
  bool _contactsLoaded = false;
  final Battery _battery = Battery();

  /// Check if the input is a recognized command (doesn't just search apps).
  bool isCommand(String input) {
    final trimmed = input.trim().toLowerCase();
    return trimmed.startsWith('call') ||
        trimmed.startsWith('msg ') ||
        trimmed.startsWith('note ') ||
        trimmed.startsWith('search ') ||
        trimmed.startsWith('goog ') ||
        trimmed.startsWith('calc ') ||
        trimmed.startsWith('ai ') ||
        trimmed.startsWith('groq ') ||
        trimmed.startsWith('setkey ') ||
        trimmed.startsWith('model ') ||
        trimmed.startsWith('done ') ||
        trimmed.startsWith('check ') ||
        trimmed.startsWith('undone ') ||
        trimmed.startsWith('uncheck ') ||
        trimmed.startsWith('addhabit ') ||
        trimmed == 'habits' ||
        trimmed == 'habit' ||
        trimmed == 'help' ||
        trimmed == 'notes' ||
        trimmed == 'clear' ||
        trimmed == 'sys' ||
        trimmed == 'ai' ||
        trimmed == 'model' ||
        trimmed == 'models' ||
        trimmed == 'voice' ||
        trimmed == 'rec' ||
        trimmed == 'mic' ||
        trimmed == 'listen' ||
        trimmed == 'whisper';
  }

  /// Parse the command prefix from input.
  String? getCommandPrefix(String input) {
    final trimmed = input.trim().toLowerCase();
    final commands = [
      'call', 'msg', 'note', 'search', 'goog', 'calc', 
      'ai', 'groq', 'setkey', 'model', 'models', 'help', 'notes', 'clear', 'sys',
      'habits', 'habit', 'done', 'check', 'undone', 'uncheck', 'addhabit',
      'voice', 'rec', 'mic', 'listen', 'whisper'
    ];
    for (final cmd in commands) {
      if (trimmed == cmd || trimmed.startsWith('$cmd ')) {
        return cmd;
      }
    }
    return null;
  }

  /// Execute a command or AI query and return terminal output lines.
  Future<List<TerminalOutput>> execute(
    String input, {
    required ThemeProvider themeProvider,
    HabitProvider? habitProvider,
  }) async {
    final trimmed = input.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'help') {
      return _showHelp();
    }

    if (lower == 'clear') {
      return []; // Signal to clear history
    }

    if (lower == 'sys') {
      return await executeSystemInfo();
    }

    // ─── HABIT COMMANDS ──────────────────────────────────
    if (lower == 'habits' || lower == 'habit' || lower == 'habit list') {
      return _executeHabitList(habitProvider);
    }

    if (lower == 'habit stats' || lower == 'habit streak') {
      return _executeHabitStats(habitProvider);
    }

    if (lower.startsWith('done ') || lower.startsWith('check ')) {
      final name = lower.startsWith('done ')
          ? trimmed.substring(5).trim()
          : trimmed.substring(6).trim();
      return _executeHabitDone(name, habitProvider);
    }

    if (lower.startsWith('habit done ')) {
      final name = trimmed.substring(11).trim();
      return _executeHabitDone(name, habitProvider);
    }

    if (lower.startsWith('undone ') || lower.startsWith('uncheck ')) {
      final name = lower.startsWith('undone ')
          ? trimmed.substring(7).trim()
          : trimmed.substring(8).trim();
      return _executeHabitUndone(name, habitProvider);
    }

    if (lower.startsWith('addhabit ')) {
      final name = trimmed.substring(9).trim();
      return _executeHabitAdd(name, habitProvider);
    }

    if (lower.startsWith('habit add ')) {
      final name = trimmed.substring(10).trim();
      return _executeHabitAdd(name, habitProvider);
    }

    if (lower.startsWith('setkey ')) {
      final key = trimmed.substring(7).trim();
      themeProvider.setGroqApiKey(key);
      return [
        TerminalOutput.system('> setkey ${'*' * (key.length > 8 ? 8 : key.length)}'),
        TerminalOutput.success('  ✓ Groq API key updated successfully!'),
      ];
    }

    if (lower.startsWith('calc ')) {
      return _executeCalc(trimmed.substring(5).trim());
    }

    if (lower.startsWith('search ') || lower.startsWith('goog ')) {
      final query = lower.startsWith('search ')
          ? trimmed.substring(7).trim()
          : trimmed.substring(5).trim();
      return _executeSearch(query);
    }

    if (lower.startsWith('note ')) {
      return await _executeNote(trimmed.substring(5).trim());
    }

    if (lower == 'notes') {
      return await _readNotes();
    }

    if (lower == 'call') {
      return [TerminalOutput.info('[SYS] loading contacts...')];
    }

    if (lower.startsWith('call ')) {
      final name = trimmed.substring(5).trim();
      return await _executeCall(name);
    }

    if (lower.startsWith('msg ')) {
      final parts = trimmed.substring(4).trim();
      return await _executeMessage(parts);
    }

    if (lower.startsWith('ai ') || lower.startsWith('groq ')) {
      final prompt = lower.startsWith('ai ')
          ? trimmed.substring(3).trim()
          : trimmed.substring(5).trim();
      return await executeAiQuery(
        prompt,
        themeProvider.groqApiKey,
        model: themeProvider.groqAiModel,
      );
    }

    if (lower == 'ai' || lower == 'groq') {
      return [
        TerminalOutput.info('┌─── GROQ AI CHATBOT (${themeProvider.groqAiModel}) ───┐'),
        TerminalOutput.ai('  Ask any question directly in terminal!'),
        TerminalOutput.dim('  Powered by Groq Compound AI & Whisper STT'),
        TerminalOutput.dim('  Usage: ai <your question> or type directly'),
        TerminalOutput.dim('  Set key: setkey <gsk_...>'),
        TerminalOutput.dim('  Switch model: model <compound|mini|llama>'),
        TerminalOutput.info('└───────────────────────────────────┘'),
      ];
    }

    if (lower == 'model' || lower == 'models') {
      return [
        TerminalOutput.info('┌─── GROQ AI CONFIGURATION ────────┐'),
        TerminalOutput.ai('  Active AI Model:      ${themeProvider.groqAiModel}'),
        TerminalOutput.ai('  Active Whisper Model: ${themeProvider.groqWhisperModel}'),
        TerminalOutput.dim('  Available Models:'),
        TerminalOutput.system('    • groq/compound (default - agentic system)'),
        TerminalOutput.system('    • groq/compound-mini (fast agentic compound)'),
        TerminalOutput.system('    • openai/gpt-oss-120b (GPT-OSS 120B)'),
        TerminalOutput.system('    • openai/gpt-oss-20b (GPT-OSS 20B)'),
        TerminalOutput.system('    • llama-3.3-70b-versatile'),
        TerminalOutput.dim('  Usage: model <compound | mini | gpt120 | gpt20 | llama | custom>'),
        TerminalOutput.info('└───────────────────────────────────┘'),
      ];
    }

    if (lower.startsWith('model ')) {
      final target = trimmed.substring(6).trim();
      final targetLower = target.toLowerCase();
      String selected = target;
      if (targetLower == 'compound' || targetLower == 'groq/compound') {
        selected = 'groq/compound';
      } else if (targetLower == 'mini' ||
          targetLower == 'compound-mini' ||
          targetLower == 'groq/compound-mini') {
        selected = 'groq/compound-mini';
      } else if (targetLower == 'gpt120' ||
          targetLower == 'gpt-120' ||
          targetLower == 'gpt-oss-120b' ||
          targetLower == 'openai/gpt-oss-120b' ||
          targetLower == '120b') {
        selected = 'openai/gpt-oss-120b';
      } else if (targetLower == 'gpt20' ||
          targetLower == 'gpt-20' ||
          targetLower == 'gpt-oss-20b' ||
          targetLower == 'openai/gpt-oss-20b' ||
          targetLower == '20b') {
        selected = 'openai/gpt-oss-20b';
      } else if (targetLower == 'llama' ||
          targetLower == 'llama3.3' ||
          targetLower == 'llama-3.3-70b-versatile') {
        selected = 'llama-3.3-70b-versatile';
      }
      themeProvider.setGroqAiModel(selected);
      return [
        TerminalOutput.system('> model $selected'),
        TerminalOutput.success('  ✓ Groq AI model set to $selected'),
      ];
    }

    // Default Fallback: Route unknown prompt directly to Groq AI!
    return await executeAiQuery(
      trimmed,
      themeProvider.groqApiKey,
      model: themeProvider.groqAiModel,
    );
  }

  /// Query Groq AI and format the response into terminal output lines.
  Future<List<TerminalOutput>> executeAiQuery(
    String prompt,
    String apiKey, {
    String? model,
  }) async {
    if (prompt.isEmpty) {
      return [TerminalOutput.error('usage: ai <your prompt or question>')];
    }

    final activeModel = (model != null && model.isNotEmpty)
        ? model
        : GroqService.defaultModel;

    final String displayName = activeModel == 'groq/compound'
        ? 'Groq Compound'
        : activeModel == 'groq/compound-mini'
            ? 'Groq Compound Mini'
            : activeModel == 'openai/gpt-oss-120b'
                ? 'GPT-OSS 120B'
                : activeModel == 'openai/gpt-oss-20b'
                    ? 'GPT-OSS 20B'
                    : activeModel;

    final output = <TerminalOutput>[
      TerminalOutput.system('> ai $prompt'),
      TerminalOutput.info('  [$displayName] thinking...'),
    ];

    final response = await GroqService.askGroq(
      prompt: prompt,
      apiKey: apiKey,
      model: activeModel,
    );

    // Format response into terminal lines
    output.add(TerminalOutput.aiHeader('┌─── GROQ RESPONSE ($displayName) ─────'));

    final lines = response.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) {
        output.add(TerminalOutput.dim(''));
      } else {
        output.add(TerminalOutput.ai('  $line'));
      }
    }

    output.add(TerminalOutput.aiHeader('└──────────────────────────────────────'));
    return output;
  }

  // ─── SYSTEM INFO (neofetch) ────────────────────────────

  Future<List<TerminalOutput>> executeSystemInfo() async {
    final output = <TerminalOutput>[];

    int batteryLevel = 0;
    String batteryState = 'unknown';
    try {
      batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      switch (state) {
        case BatteryState.charging:
          batteryState = 'charging';
          break;
        case BatteryState.discharging:
          batteryState = 'discharging';
          break;
        case BatteryState.full:
          batteryState = 'full';
          break;
        case BatteryState.connectedNotCharging:
          batteryState = 'connected';
          break;
        default:
          batteryState = 'unknown';
      }
    } catch (_) {}

    Map<String, dynamic> sysInfo = {};
    try {
      sysInfo = await LauncherService.getSystemInfo();
    } catch (_) {}

    final networkType = sysInfo['networkType'] as String? ?? 'unknown';
    final wifiSsid = sysInfo['wifiSsid'] as String?;
    final screenTimeMinutes = sysInfo['screenTimeMinutes'] as int? ?? -1;
    final nextEventTitle = sysInfo['nextEventTitle'] as String?;
    final nextEventTime = sysInfo['nextEventTime'] as String?;
    final deviceModel = sysInfo['deviceModel'] as String? ?? 'unknown';
    final androidVersion = sysInfo['androidVersion'] as String? ?? '?';

    final filledBlocks = (batteryLevel / 10).round();
    final emptyBlocks = 10 - filledBlocks;
    final batteryBar = '${'█' * filledBlocks}${'░' * emptyBlocks}';
    final batteryColor = batteryLevel > 50
        ? const Color(0xFF69FF94)
        : batteryLevel > 20
            ? const Color(0xFFFFD580)
            : const Color(0xFFFF6B6B);

    String networkDisplay;
    if (networkType == 'wifi') {
      networkDisplay = wifiSsid != null ? 'wifi ($wifiSsid)' : 'wifi';
    } else if (networkType == 'cellular') {
      networkDisplay = 'cellular';
    } else if (networkType == 'offline') {
      networkDisplay = 'offline';
    } else {
      networkDisplay = networkType;
    }

    String screenTimeDisplay;
    if (screenTimeMinutes < 0) {
      screenTimeDisplay = 'n/a (enable in settings)';
    } else {
      final hours = screenTimeMinutes ~/ 60;
      final mins = screenTimeMinutes % 60;
      if (hours > 0) {
        screenTimeDisplay = '${hours}h ${mins}m today';
      } else {
        screenTimeDisplay = '${mins}m today';
      }
    }

    String calendarDisplay;
    if (nextEventTitle != null && nextEventTime != null) {
      final title = nextEventTitle.length > 20
          ? '${nextEventTitle.substring(0, 20)}...'
          : nextEventTitle;
      calendarDisplay = '${title.toLowerCase()} @ $nextEventTime';
    } else {
      calendarDisplay = 'no upcoming events';
    }

    final host = deviceModel.toLowerCase().replaceAll(' ', '_');

    output.add(TerminalOutput.dim(''));
    output.add(TerminalOutput(
      text: '  root@$host',
      color: const Color(0xFF69FF94),
      isBold: true,
    ));
    output.add(TerminalOutput.dim('  ${'─' * (7 + host.length)}'));

    output.add(TerminalOutput(
      text: '  os      android $androidVersion',
      color: const Color(0xFFE0E0E0),
    ));

    output.add(TerminalOutput(
      text: '  bat     $batteryLevel% [$batteryState] $batteryBar',
      color: batteryColor,
    ));

    output.add(TerminalOutput(
      text: '  net     $networkDisplay',
      color: networkType == 'offline'
          ? const Color(0xFFFF6B6B)
          : const Color(0xFFE0E0E0),
    ));

    output.add(TerminalOutput(
      text: '  screen  $screenTimeDisplay',
      color: screenTimeMinutes < 0
          ? Colors.white.withValues(alpha: 0.35)
          : const Color(0xFFE0E0E0),
    ));

    output.add(TerminalOutput(
      text: '  cal     $calendarDisplay',
      color: nextEventTitle != null
          ? const Color(0xFFFFD580)
          : Colors.white.withValues(alpha: 0.35),
    ));

    output.add(TerminalOutput.dim(''));

    return output;
  }

  // ─── HELP ──────────────────────────────────────────────

  List<TerminalOutput> _showHelp() {
    return [
      TerminalOutput.info('┌──────────────────────────────────────────────┐'),
      TerminalOutput.info('│            TERMINAL QUICK ACTIONS            │'),
      TerminalOutput.info('├──────────────────────────────────────────────┤'),
      TerminalOutput(text: '│ ai [query]        ask Groq AI                │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ voice / mic       record audio (Groq Whisper)│', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ model [name]      switch Groq AI model       │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ habits            list daily habits          │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ done [habit]      mark habit done            │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ undone [habit]    uncheck habit              │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ addhabit [name]   create habit               │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ habit stats       habit telemetry            │', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '│ call              list contacts              │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ call [name]       direct dial                │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ msg [name] [text] send sms                   │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ note [text]       save a note                │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ notes             view all notes             │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ search [query]    google search              │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ calc [expr]       evaluate math              │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ sys               system info                │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ clear             clear terminal             │', color: const Color(0xFFFFD580)),
      TerminalOutput(text: '│ help              show this help             │', color: const Color(0xFFFFD580)),
      TerminalOutput.info('└──────────────────────────────────────────────┘'),
      TerminalOutput.aiHeader('  ★ Tap the mic icon or type a query directly to talk to Groq!'),
    ];
  }

  // ─── CALC ──────────────────────────────────────────────

  List<TerminalOutput> _executeCalc(String expression) {
    if (expression.isEmpty) {
      return [TerminalOutput.error('usage: calc <expression>')];
    }

    try {
      String sanitized = expression
          .replaceAll('x', '*')
          .replaceAll('×', '*')
          .replaceAll('÷', '/');

      GrammarParser p = GrammarParser();
      Expression exp = p.parse(sanitized);
      ContextModel cm = ContextModel();
      double result = exp.evaluate(EvaluationType.REAL, cm);

      String formatted = result == result.truncateToDouble()
          ? result.toInt().toString()
          : result.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

      return [
        TerminalOutput.system('> calc $expression'),
        TerminalOutput.result('  = $formatted'),
      ];
    } catch (e) {
      return [
        TerminalOutput.system('> calc $expression'),
        TerminalOutput.error('  error: invalid expression'),
      ];
    }
  }

  // ─── SEARCH ────────────────────────────────────────────

  List<TerminalOutput> _executeSearch(String query) {
    if (query.isEmpty) {
      return [TerminalOutput.error('usage: search <query>')];
    }

    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    launchUrl(url, mode: LaunchMode.externalApplication);

    return [
      TerminalOutput.system('> search $query'),
      TerminalOutput.success('  opening browser...'),
    ];
  }

  // ─── NOTE ──────────────────────────────────────────────

  Future<File> _getNotesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notes.txt');
  }

  Future<List<TerminalOutput>> _executeNote(String text) async {
    if (text.isEmpty) {
      return [TerminalOutput.error('usage: note <text>')];
    }

    try {
      final file = await _getNotesFile();
      final timestamp = DateTime.now().toString().substring(0, 16);
      await file.writeAsString('[$timestamp] $text\n', mode: FileMode.append);

      return [
        TerminalOutput.system('> note $text'),
        TerminalOutput.success('  ✓ note saved'),
      ];
    } catch (e) {
      return [
        TerminalOutput.error('  error saving note: $e'),
      ];
    }
  }

  Future<List<TerminalOutput>> _readNotes() async {
    try {
      final file = await _getNotesFile();
      if (!await file.exists()) {
        return [TerminalOutput.info('  no notes yet. use: note <text>')];
      }

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        return [TerminalOutput.info('  no notes yet. use: note <text>')];
      }

      final output = <TerminalOutput>[
        TerminalOutput.info('┌─── NOTES ─────────────────────────┐'),
      ];

      final recent = lines.length > 10 ? lines.sublist(lines.length - 10) : lines;
      for (final line in recent) {
        output.add(TerminalOutput(text: '  $line', color: const Color(0xFFE0E0E0)));
      }

      if (lines.length > 10) {
        output.add(TerminalOutput.system('  ... and ${lines.length - 10} more'));
      }

      output.add(TerminalOutput.info('└───────────────────────────────────┘'));
      return output;
    } catch (e) {
      return [TerminalOutput.error('  error reading notes: $e')];
    }
  }

  // ─── CONTACTS ──────────────────────────────────────────

  Future<bool> _ensureContactsPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;

    final result = await Permission.contacts.request();
    return result.isGranted;
  }

  Future<List<TerminalContact>> getContacts({String filter = ''}) async {
    if (!await _ensureContactsPermission()) {
      return [];
    }

    if (!_contactsLoaded) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      _cachedContacts = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => TerminalContact(
                name: c.displayName,
                phone: c.phones.first.number,
              ))
          .toList();
      _cachedContacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _contactsLoaded = true;
    }

    if (filter.isEmpty) return _cachedContacts;

    return _cachedContacts
        .where((c) => c.name.toLowerCase().contains(filter.toLowerCase()))
        .toList();
  }

  void invalidateContacts() {
    _contactsLoaded = false;
    _cachedContacts = [];
  }

  // ─── CALL ──────────────────────────────────────────────

  Future<List<TerminalOutput>> _executeCall(String name) async {
    if (!await _ensureContactsPermission()) {
      return [TerminalOutput.error('  contacts permission denied')];
    }

    final matches = await getContacts(filter: name);

    if (matches.isEmpty) {
      return [
        TerminalOutput.system('> call $name'),
        TerminalOutput.error('  no contacts found matching "$name"'),
      ];
    }

    if (matches.length == 1) {
      final contact = matches.first;
      final phoneUrl = Uri.parse('tel:${contact.phone}');
      await launchUrl(phoneUrl);
      return [
        TerminalOutput.system('> call ${contact.name.toLowerCase()}'),
        TerminalOutput.success('  calling ${contact.phone}...'),
      ];
    }

    final output = <TerminalOutput>[
      TerminalOutput.system('> call $name'),
      TerminalOutput.info('  ${matches.length} contacts found:'),
    ];

    for (int i = 0; i < matches.length && i < 10; i++) {
      output.add(TerminalOutput(
        text: '  ${i + 1}. ${matches[i].name.toLowerCase()} — ${matches[i].phone}',
        color: const Color(0xFFE0E0E0),
      ));
    }

    if (matches.length > 10) {
      output.add(TerminalOutput.system('  ... and ${matches.length - 10} more'));
    }

    return output;
  }

  Future<List<TerminalOutput>> callDirect(TerminalContact contact) async {
    final phoneUrl = Uri.parse('tel:${contact.phone}');
    await launchUrl(phoneUrl);
    return [
      TerminalOutput.success('  calling ${contact.name.toLowerCase()} (${contact.phone})...'),
    ];
  }

  // ─── MESSAGE ───────────────────────────────────────────

  Future<List<TerminalOutput>> _executeMessage(String input) async {
    if (input.isEmpty) {
      return [TerminalOutput.error('usage: msg <name> <message>')];
    }

    if (!await _ensureContactsPermission()) {
      return [TerminalOutput.error('  contacts permission denied')];
    }

    final words = input.split(' ');
    
    TerminalContact? bestMatch;
    String message = '';

    for (int i = 1; i <= words.length; i++) {
      final nameCandidate = words.sublist(0, i).join(' ');
      final matches = await getContacts(filter: nameCandidate);

      if (matches.length == 1) {
        bestMatch = matches.first;
        message = words.sublist(i).join(' ');
        break;
      }
    }

    if (bestMatch == null) {
      final nameCandidate = words.first;
      final matches = await getContacts(filter: nameCandidate);
      if (matches.isNotEmpty) {
        bestMatch = matches.first;
        message = words.sublist(1).join(' ');
      }
    }

    if (bestMatch == null) {
      return [
        TerminalOutput.system('> msg $input'),
        TerminalOutput.error('  no contact found'),
      ];
    }

    if (message.isEmpty) {
      return [
        TerminalOutput.system('> msg $input'),
        TerminalOutput.error('  no message body provided'),
        TerminalOutput.info('  usage: msg <name> <message>'),
      ];
    }

    final smsUrl = Uri.parse('sms:${bestMatch.phone}?body=${Uri.encodeComponent(message)}');
    await launchUrl(smsUrl);

    return [
      TerminalOutput.system('> msg ${bestMatch.name.toLowerCase()}'),
      TerminalOutput.success('  opening sms to ${bestMatch.phone}...'),
    ];
  }

  // ─── HABIT COMMANDS ─────────────────────────────────────

  List<TerminalOutput> _executeHabitList(HabitProvider? provider) {
    if (provider == null) {
      return [TerminalOutput.error('  habit tracker service unavailable')];
    }

    final habits = provider.habits;
    if (habits.isEmpty) {
      return [
        TerminalOutput.info('┌─── HABIT TRACKER ───────────────────┐'),
        TerminalOutput.dim('│ No habits configured yet.           │'),
        TerminalOutput.ai('│ Type "addhabit <name>" to create!   │'),
        TerminalOutput.info('└─────────────────────────────────────┘'),
      ];
    }

    final now = DateTime.now();
    final progress = provider.getTodayProgress();
    final comp = progress['completed'] ?? 0;
    final total = progress['total'] ?? 0;

    final output = <TerminalOutput>[
      TerminalOutput.aiHeader('┌─── HABITS ($comp/$total DONE TODAY) ─────────'),
    ];

    for (final h in habits) {
      final isDone = h.isCompletedOn(now);
      final streak = provider.getStreak(h);
      final check = isDone ? '[✓]' : '[ ]';
      final nameStr = h.name.padRight(16);
      final nameDisplay = nameStr.length > 16 ? '${nameStr.substring(0, 14)}..' : nameStr;

      output.add(TerminalOutput(
        text: '  $check $nameDisplay 🔥 ${streak}d streak  [${h.category}]',
        color: isDone ? const Color(0xFF69FF94) : Colors.white.withValues(alpha: 0.6),
        isBold: isDone,
      ));
    }

    output.add(TerminalOutput.aiHeader('├──────────────────────────────────────'));
    output.add(TerminalOutput.dim('  Commands: done <name> | undone <name> | addhabit <name>'));
    output.add(TerminalOutput.aiHeader('└──────────────────────────────────────'));
    return output;
  }

  List<TerminalOutput> _executeHabitDone(String query, HabitProvider? provider) {
    if (provider == null) return [TerminalOutput.error('  habit tracker unavailable')];
    if (query.isEmpty) return [TerminalOutput.error('usage: done <habit_name>')];

    final updated = provider.markHabitDoneByName(query);
    if (updated == null) {
      return [
        TerminalOutput.system('> done $query'),
        TerminalOutput.error('  no matching habit found for "$query"'),
        TerminalOutput.info('  type "habits" to list your tracked habits'),
      ];
    }

    final streak = provider.getStreak(updated);
    final prog = provider.getTodayProgress();

    return [
      TerminalOutput.system('> done ${updated.name}'),
      TerminalOutput.success('  ✓ Marked ${updated.name} completed for today! (🔥 ${streak}d streak)'),
      TerminalOutput.info('  [HABITS: ${prog['completed']}/${prog['total']} DONE]'),
    ];
  }

  List<TerminalOutput> _executeHabitUndone(String query, HabitProvider? provider) {
    if (provider == null) return [TerminalOutput.error('  habit tracker unavailable')];
    if (query.isEmpty) return [TerminalOutput.error('usage: undone <habit_name>')];

    final updated = provider.markHabitUndoneByName(query);
    if (updated == null) {
      return [
        TerminalOutput.system('> undone $query'),
        TerminalOutput.error('  no matching habit found for "$query"'),
      ];
    }

    final prog = provider.getTodayProgress();
    return [
      TerminalOutput.system('> undone ${updated.name}'),
      TerminalOutput(
        text: '  ↩ Unchecked ${updated.name} for today',
        color: Colors.white.withValues(alpha: 0.7),
      ),
      TerminalOutput.info('  [HABITS: ${prog['completed']}/${prog['total']} DONE]'),
    ];
  }

  List<TerminalOutput> _executeHabitAdd(String query, HabitProvider? provider) {
    if (provider == null) return [TerminalOutput.error('  habit tracker unavailable')];
    if (query.isEmpty) return [TerminalOutput.error('usage: addhabit <habit_name>')];

    final newHabit = provider.addHabitFromCli(query);
    return [
      TerminalOutput.system('> addhabit ${newHabit.name}'),
      TerminalOutput.success('  ✓ Created new habit: ${newHabit.name} [DAILY]'),
      TerminalOutput.info('  Swipe left from terminal to customize time or category!'),
    ];
  }

  List<TerminalOutput> _executeHabitStats(HabitProvider? provider) {
    if (provider == null) return [TerminalOutput.error('  habit tracker unavailable')];

    final habits = provider.habits;
    final prog = provider.getTodayProgress();
    final comp = prog['completed'] ?? 0;
    final total = prog['total'] ?? 0;
    final percent = total > 0 ? ((comp / total) * 100).round() : 0;

    int totalLifetimeCommits = 0;
    int highestStreak = 0;
    for (final h in habits) {
      totalLifetimeCommits += h.completedDates.length;
      final bStreak = provider.getBestStreak(h);
      if (bStreak > highestStreak) highestStreak = bStreak;
    }

    return [
      TerminalOutput.aiHeader('┌─── HABIT TELEMETRY ─────────────────'),
      TerminalOutput(text: '  Today\'s Progress:  $percent% ($comp/$total completed)', color: const Color(0xFF69FF94)),
      TerminalOutput(text: '  Active Habits:     $total tracked', color: Colors.white),
      TerminalOutput(text: '  Total Commits:     $totalLifetimeCommits completions', color: Colors.white),
      TerminalOutput(text: '  Best Streak:       🔥 $highestStreak days', color: const Color(0xFFFFD580)),
      TerminalOutput.aiHeader('└─────────────────────────────────────'),
    ];
  }
}
