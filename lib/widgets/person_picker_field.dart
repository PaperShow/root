import 'dart:async';

import 'package:flutter/material.dart';

import '../services/user_directory_service.dart';
import '../styles/app_theme.dart';
import '../utils/app_fonts.dart';

/// Who the user picked: an app account, an email of someone not on the app
/// yet, or just a name kept on this device.
class PersonPick {
  final String name;
  final AppUserProfile? user;
  final String? email;

  const PersonPick({required this.name, this.user, this.email});

  bool get isAppUser => user != null;
  bool get isPendingEmail => user == null && email != null;
}

/// Shared input styling for the expense sheets, readable in light and dark mode.
InputDecoration sheetInputDecoration(AppTheme theme, {String? hint, String? prefixText, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppFonts.inter(color: theme.textMuted, fontSize: 13),
    prefixText: prefixText,
    prefixStyle: AppFonts.inter(color: theme.textMuted, fontSize: 16),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: theme.cardSecondary,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.textMuted.withValues(alpha: 0.6)),
    ),
  );
}

/// Text field that searches app users by username, name or email as you type.
/// Falls back to an email invite or a plain name when nobody matches.
class PersonPickerField extends StatefulWidget {
  final ValueChanged<PersonPick?> onChanged;
  final bool searchEnabled;
  final String hint;
  final String? excludeUid;
  final String? initialText;
  final bool autofocus;

  const PersonPickerField({
    super.key,
    required this.onChanged,
    this.searchEnabled = true,
    this.hint = 'Name, @username or email',
    this.excludeUid,
    this.initialText,
    this.autofocus = false,
  });

  @override
  State<PersonPickerField> createState() => _PersonPickerFieldState();
}

class _PersonPickerFieldState extends State<PersonPickerField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  Timer? _debounce;
  List<AppUserProfile> _results = [];
  AppUserProfile? _selected;
  bool _searching = false;
  int _searchSeq = 0;

  AppTheme get theme => AppTheme.of(context);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _emit();
    _debounce?.cancel();
    if (!widget.searchEnabled || text.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      final found = await UserDirectoryService().search(text, excludeUid: widget.excludeUid);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    });
  }

  void _emit() {
    if (_selected != null) {
      widget.onChanged(PersonPick(name: _selected!.displayName, user: _selected, email: _selected!.email));
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onChanged(null);
    } else if (UserDirectoryService.looksLikeEmail(text)) {
      widget.onChanged(PersonPick(name: text.split('@').first, email: text.toLowerCase()));
    } else {
      widget.onChanged(PersonPick(name: text.replaceFirst(RegExp(r'^@'), '')));
    }
  }

  void _select(AppUserProfile user) {
    setState(() {
      _selected = user;
      _results = [];
    });
    FocusScope.of(context).unfocus();
    _emit();
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _controller.clear();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _buildSelected(_selected!);

    final text = _controller.text.trim();
    final isEmail = UserDirectoryService.looksLikeEmail(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          onChanged: _onTextChanged,
          keyboardType: TextInputType.emailAddress,
          style: AppFonts.inter(color: theme.textPrimary, fontSize: 14),
          decoration: sheetInputDecoration(
            theme,
            hint: widget.searchEnabled ? widget.hint : "Person's name",
            suffixIcon: _searching
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.textMuted),
                    ),
                  )
                : (widget.searchEnabled ? Icon(Icons.search_rounded, color: theme.textMuted, size: 20) : null),
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: theme.cardSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              children: _results.map(_buildResultTile).toList(),
            ),
          ),
        ] else if (widget.searchEnabled && !_searching && text.length >= 2) ...[
          const SizedBox(height: 8),
          _buildHint(
            isEmail
                ? Icons.mark_email_unread_outlined
                : Icons.info_outline_rounded,
            isEmail
                ? 'Not on the app yet. They will see this after signing up with $text.'
                : 'No account found. This will be saved as a name only — use their email to share it with them.',
          ),
        ],
      ],
    );
  }

  Widget _buildResultTile(AppUserProfile user) {
    return InkWell(
      onTap: () => _select(user),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _Avatar(name: user.displayName, photoUrl: user.photoUrl, theme: theme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppFonts.inter(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${user.username}${user.email != null ? ' • ${user.email}' : ''}',
                    style: AppFonts.inter(color: theme.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: theme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSelected(AppUserProfile user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Avatar(name: user.displayName, photoUrl: user.photoUrl, theme: theme),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: AppFonts.inter(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '@${user.username} • on the app',
                  style: AppFonts.inter(color: theme.incomeMint, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearSelection,
            icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: theme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppFonts.inter(color: theme.textMuted, fontSize: 11)),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final AppTheme theme;

  const _Avatar({required this.name, required this.photoUrl, required this.theme});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: theme.card,
      foregroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppFonts.inter(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
