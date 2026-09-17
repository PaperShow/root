import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_fonts.dart';

class ScratchpadScreen extends StatefulWidget {
  final bool isEmbedded;
  const ScratchpadScreen({super.key, this.isEmbedded = false});

  @override
  State<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends State<ScratchpadScreen> {
  static const Color terminalGreen = Color(0xFF69FF94);
  static const Color pureBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF101010);
  static const Color surfaceBorder = Color(0xFF222222);

  static const String _storageKey = 'root_super_app_scratchpad';
  final TextEditingController _controller = TextEditingController();
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    final note = prefs.getString(_storageKey) ?? '';
    if (mounted) {
      setState(() {
        _controller.text = note;
        _saved = true;
      });
    }
  }

  void _onTextChanged() {
    if (_saved) {
      setState(() {
        _saved = false;
      });
    }
    _autoSave();
  }

  Future<void> _autoSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _controller.text);
    if (mounted) {
      setState(() {
        _saved = true;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardDark,
        content: Text('Copied to clipboard', style: AppFonts.inter(color: Colors.white)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearNote() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: surfaceBorder),
        ),
        title: Text(
          'CLEAR SCRATCHPAD?',
          style: AppFonts.jetBrainsMono(color: terminalGreen, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'All text will be permanently erased.',
          style: AppFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: AppFonts.jetBrainsMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              _controller.clear();
              _autoSave();
              Navigator.of(ctx).pop();
            },
            child: Text('CLEAR', style: AppFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final charCount = text.length;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      backgroundColor: pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (!widget.isEmbedded) ...[
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
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '// SCRATCHPAD',
                        style: AppFonts.jetBrainsMono(
                          color: terminalGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _saved ? terminalGreen : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _saved ? 'saved locally' : 'saving...',
                            style: AppFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, color: Colors.white70, size: 20),
                    tooltip: 'Copy all',
                    onPressed: _copyToClipboard,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                    tooltip: 'Clear',
                    onPressed: _clearNote,
                  ),
                ],
              ),
            ),

            // EDITOR
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: surfaceBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    style: AppFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    cursorColor: terminalGreen,
                    decoration: InputDecoration(
                      hintText: '# Write quick thoughts, todos, links, code snippets...\nAuto-saves as you type.',
                      hintStyle: AppFonts.jetBrainsMono(
                        color: Colors.white24,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // FOOTER STATS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$wordCount words • $charCount chars',
                    style: AppFonts.jetBrainsMono(color: Colors.white38, fontSize: 11),
                  ),
                  Text(
                    'PERSISTENT STORAGE',
                    style: AppFonts.jetBrainsMono(color: terminalGreen.withValues(alpha: 0.7), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
