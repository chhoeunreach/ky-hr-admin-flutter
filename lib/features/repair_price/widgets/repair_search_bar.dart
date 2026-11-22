import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final String? initialValue;

  const RepairSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.controller,
    this.initialValue,
  });

  @override
  State<RepairSearchBar> createState() => _RepairSearchBarState();
}

class _RepairSearchBarState extends State<RepairSearchBar> {
  late final TextEditingController _controller;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _showClear = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant RepairSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null &&
        widget.initialValue != null &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue!;
      _showClear = _controller.text.isNotEmpty;
    }
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _showClear) {
      setState(() {
        _showClear = hasText;
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:
            AppColors.white.withValues(alpha: enterprise.isDark ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enterprise.glassStroke, width: 0.9),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: enterprise.text,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: enterprise.mutedText.withValues(alpha: 0.6),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: enterprise.mutedText,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          suffixIcon: _showClear
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: enterprise.mutedText),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
