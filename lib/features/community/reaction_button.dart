import 'dart:math' as math;

import 'package:cnattendance/theme/enterprise_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'community_strings.dart';

const communityReactions = {
  'like': '👍',
  'love': '❤️',
  'haha': '😆',
  'wow': '😮',
  'sad': '😢',
  'angry': '😡',
};

String _label(String reaction) =>
    communityText('${reaction[0].toUpperCase()}${reaction.substring(1)}');

Color _color(String? reaction, Color fallback) => switch (reaction) {
      'like' => const Color(0xff1877f2),
      'love' => const Color(0xfff33e58),
      'haha' || 'wow' || 'sad' => const Color(0xffb77900),
      'angry' => const Color(0xffe15a2b),
      _ => fallback,
    };

/// Tap Like, or hold to choose a reaction in the anchored floating tray.
class CommunityReactionButton extends StatelessWidget {
  const CommunityReactionButton(
      {super.key, this.reaction, required this.onChanged, this.enabled = true});
  final String? reaction;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  Future<void> _choose(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    HapticFeedback.selectionClick();
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
              scale: Tween(begin: .92, end: 1.0).animate(animation),
              child: child)),
      pageBuilder: (context, _, __) =>
          LayoutBuilder(builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = math.min(360.0, constraints.maxWidth - 16);
        final left = anchor.left
            .clamp(8.0, math.max(8.0, constraints.maxWidth - width - 8));
        const height = 82.0;
        final top = (anchor.top >= padding.top + height + 8
                ? anchor.top - height - 8
                : anchor.bottom + 8)
            .clamp(
                padding.top + 8,
                math.max(padding.top + 8,
                    constraints.maxHeight - padding.bottom - height - 8));
        return Stack(children: [
          Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              width: width,
              child: Material(
                elevation: 12,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(40),
                color: EnterpriseTheme.of(context).contentSurface,
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                    child: Row(children: [
                      for (final entry in communityReactions.entries)
                        Expanded(
                            child: Semantics(
                                selected: entry.key == reaction,
                                child: InkWell(
                                  key: ValueKey('reaction-choice-${entry.key}'),
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () =>
                                      Navigator.pop(context, entry.key),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                          color: entry.key == reaction
                                              ? _color(entry.key, Colors.blue)
                                                  .withValues(alpha: .12)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(28)),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(entry.value,
                                                style: const TextStyle(
                                                    fontSize: 27)),
                                            Text(_label(entry.key),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface)),
                                          ])),
                                )))
                    ])),
              ))
        ]);
      }),
    );
    if (!context.mounted || selected == null) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = communityReactions.containsKey(reaction);
    final color =
        _color(reaction, Theme.of(context).colorScheme.onSurfaceVariant);
    return Builder(
        builder: (buttonContext) => TextButton.icon(
              onPressed:
                  enabled ? () => onChanged(selected ? null : 'like') : null,
              onLongPress: enabled ? () => _choose(buttonContext) : null,
              style: TextButton.styleFrom(foregroundColor: color),
              icon: selected
                  ? Text(communityReactions[reaction]!,
                      style: const TextStyle(fontSize: 19))
                  : const Icon(Icons.thumb_up_alt_outlined, size: 19),
              label: Text(selected ? _label(reaction!) : communityText('Like'),
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600)),
            ));
  }
}
