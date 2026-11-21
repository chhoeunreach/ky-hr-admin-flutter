import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/royal_blue_day_theme.dart';
import 'package:cnattendance/widget/enterprise/khmer_luxury_frame.dart';
import 'package:flutter/material.dart';

/// Compact icon tile for the home quick-actions grid (screenshot style):
/// colored squircle chip + centered label, no counts.
class CardOverView extends StatefulWidget {
  final String type;
  final String value;
  final String? subtitle;
  final dynamic icon;
  final VoidCallback callback;
  final Color? chipColor;

  CardOverView({
    required this.type,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.callback,
    this.chipColor,
  });

  @override
  State<CardOverView> createState() => _CardOverViewState();
}

class _CardOverViewState extends State<CardOverView> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final luxuryDay = enterprise.isRoyalLuxuryDay;
    final brightOriginal = enterprise.mode == AppThemeMode.light;
    final base = enterprise.isKhmerHeritage || enterprise.layout.accent != null
        ? enterprise.primary
        : widget.chipColor ?? enterprise.primary;
    final iconColor = enterprise.isKhmerHeritage
        ? enterprise.accent
        : ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : const Color(0xFF0F172A);

    final tile = InkWell(
      borderRadius: BorderRadius.circular(14),
      onHighlightChanged: (pressed) {
        if (_pressed != pressed) setState(() => _pressed = pressed);
      },
      onTap: widget.callback,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: DecoratedBox(
            decoration: luxuryDay
                ? BoxDecoration(
                    gradient: KhmerLuxuryColors.frosted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: KhmerLuxuryColors.metallicGold
                            .withValues(alpha: .7)),
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: luxuryDay ? const EdgeInsets.all(4) : EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: brightOriginal
                            ? [
                                Color.lerp(base, Colors.white, 0.24)!,
                                Color.lerp(base, enterprise.primary, 0.10)!,
                              ]
                            : [
                                base.withValues(alpha: 0.95),
                                Color.lerp(
                                    base,
                                    enterprise.isKhmerHeritage
                                        ? enterprise.secondary
                                        : const Color(0xFF0A1F44),
                                    0.35)!,
                              ],
                      ),
                      border: enterprise.isKhmerHeritage
                          ? Border.all(color: enterprise.cardBorder)
                          : brightOriginal
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  width: 1,
                                )
                              : null,
                      boxShadow: [
                        BoxShadow(
                          color: base.withValues(
                              alpha: brightOriginal
                                  ? (_pressed ? 0.42 : 0.28)
                                  : 0.38),
                          blurRadius: brightOriginal
                              ? (_pressed ? 24 : 18)
                              : 14,
                          spreadRadius: brightOriginal
                              ? (_pressed ? 2 : 1)
                              : 0.5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.icon is String
                          ? Image.asset(widget.icon,
                              width: 20, height: 20, color: iconColor)
                          : Icon(widget.icon, size: 20, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final framedTile = luxuryDay
        ? KhmerLuxuryFrame(
            style: KhmerFrameStyle.gold,
            radius: 14,
            cornerSize: 12,
            child: tile,
          )
        : tile;
    return RepaintBoundary(child: framedTile);
  }
}
