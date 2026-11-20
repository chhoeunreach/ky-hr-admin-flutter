import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/community_strings.dart';
import 'package:cnattendance/features/community/mention_directory.dart';
import 'package:flutter/material.dart';

/// Matches an active @mention query directly before the caret, e.g.
/// `"Hi @da|"` exposes `da` as group 1. A single token only, so a mention
/// session ends at the first space (the picker inserts full names atomically).
final RegExp _mentionQueryPattern = RegExp(r'(?:^|\s)@([^\s@]*)$');

/// A [TextField] that shows an @ mention autocomplete: typing `@` lists
/// "Everyone" plus employees from the [MentionDirectory]; picking a row
/// replaces the query with `@Name ` (with a trailing space so the trigger does
/// not re-fire). The suggestion panel is rendered in layout — below the field
/// by default, or above it with [panelAbove] for bottom bars — so it works
/// inside scroll views and bottom docks without an overlay.
class MentionField extends StatefulWidget {
  const MentionField({
    super.key,
    required this.controller,
    this.decoration,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.style,
    this.cursorColor,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.panelAbove = false,
    this.maxPanelHeight = 220,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final TextStyle? style;
  final Color? cursorColor;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Places the suggestion panel above the field (for bottom comment bars).
  final bool panelAbove;
  final double maxPanelHeight;

  @override
  State<MentionField> createState() => _MentionFieldState();
}

class _MentionFieldState extends State<MentionField> {
  bool _active = false;
  int? _queryStart;
  List<MentionSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MentionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      widget.focusNode?.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode?.hasFocus ?? false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active && !(widget.focusNode?.hasFocus ?? false)) {
        _hide();
      }
    });
  }

  void _hide() {
    if (!_active) return;
    setState(() {
      _active = false;
      _queryStart = null;
      _suggestions = const [];
    });
  }

  int _caretIndex() {
    final selection = widget.controller.selection;
    final length = widget.controller.text.length;
    if (!selection.isValid || selection.baseOffset < 0) return length;
    return selection.baseOffset.clamp(0, length);
  }

  void _evaluate() {
    final text = widget.controller.text;
    final cursor = _caretIndex();
    final match = _mentionQueryPattern.firstMatch(text.substring(0, cursor));
    if (match == null) {
      _hide();
      return;
    }
    if (!MentionDirectory.isLoaded) {
      MentionDirectory.ensureLoaded().whenComplete(() {
        if (mounted && _active) _evaluate();
      });
    }
    final query = match.group(1)!;
    final group = match.group(0)!;
    // Offset of the `@` inside the full text.
    final atIndex = match.start + group.length - query.length - 1;
    final rows = MentionDirectory.query(query);
    setState(() {
      _active = true;
      _queryStart = atIndex;
      _suggestions = rows;
    });
  }

  void _pick(MentionSuggestion row) {
    if (!_active || _queryStart == null) return;
    final text = widget.controller.text;
    final cursor = _caretIndex();
    final start = _queryStart!;
    if (start < 0 || start >= text.length || text[start] != '@') {
      _hide();
      return;
    }
    if (start > cursor ||
        _mentionQueryPattern.firstMatch(text.substring(0, cursor)) == null) {
      _hide();
      return;
    }
    final mention = row.isEveryone ? '@everyone ' : '@${row.name} ';
    widget.controller.value = TextEditingValue(
      text: text.replaceRange(start, cursor, mention),
      selection: TextSelection.collapsed(offset: start + mention.length),
    );
    _hide();
    widget.onChanged?.call(widget.controller.text);
  }

  Widget _suggestionRow(MentionSuggestion row) {
    final colors = Theme.of(context).colorScheme;
    final label = row.isEveryone ? communityText('Everyone') : row.name;
    final avatar = row.isEveryone ? '' : row.avatar.trim();
    final image = communityAvatarImage(avatar.isEmpty ? null : avatar);
    return Listener(
      onPointerDown: (_) => _pick(row),
      child: InkWell(
        onTap: () => _pick(row),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundImage: image,
                  child: image == null
                      ? Icon(row.isEveryone ? Icons.public : Icons.person,
                          size: 18, color: colors.onSurfaceVariant)
                      : null),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: colors.onSurface)),
                    if (!row.isEveryone && row.department.isNotEmpty)
                      Text(row.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                  ])),
            ])),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = widget.panelAbove
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : const BorderRadius.vertical(bottom: Radius.circular(16));
    final Widget body;
    if (_suggestions.isEmpty && !MentionDirectory.isLoaded) {
      body = SizedBox(
          height: 36,
          child: Center(
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.primary))));
    } else if (_suggestions.isEmpty) {
      body = Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Text(communityText('No matching people'),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)));
    } else {
      body = ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _suggestions.length,
          itemBuilder: (context, index) => _suggestionRow(_suggestions[index]));
    }
    return Material(
        color: colors.surfaceContainerHigh,
        child: ClipRRect(
            borderRadius: radius,
            child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxPanelHeight),
                child: body)));
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        cursorColor: widget.cursorColor,
        style: widget.style,
        decoration: widget.decoration,
        onTap: () {
          widget.onTap?.call();
          _evaluate();
        },
        onChanged: (value) {
          widget.onChanged?.call(value);
          _evaluate();
        },
        onSubmitted: (value) {
          if (_active && _suggestions.isNotEmpty) {
            _pick(_suggestions.first);
            return;
          }
          widget.onSubmitted?.call(value);
        });
    // The field must always keep the same slot in this tree, otherwise the
    // panel appearing would recreate the EditableText state and drop focus
    // (closing the keyboard) mid-typing.
    final panel = _active ? _panel(context) : const SizedBox.shrink();
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.panelAbove ? [panel, field] : [field, panel]);
  }
}
