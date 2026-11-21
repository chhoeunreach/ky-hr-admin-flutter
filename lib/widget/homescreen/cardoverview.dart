import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

/// Compact icon tile for the home quick-actions grid (screenshot style):
/// colored squircle chip + centered label, no counts.
class CardOverView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final base = enterprise.isKhmerHeritage || enterprise.layout.accent != null
        ? enterprise.primary
        : chipColor ?? enterprise.primary;
    final iconColor = enterprise.isKhmerHeritage
        ? enterprise.accent
        : ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : const Color(0xFF0F172A);

    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: callback,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
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
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: base.withValues(alpha: 0.38),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: icon is String
                      ? Image.asset(icon,
                          width: 20, height: 20, color: iconColor)
                      : Icon(icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                type,
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
    );
  }
}
