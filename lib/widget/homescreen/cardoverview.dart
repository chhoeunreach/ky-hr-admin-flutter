import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

class CardOverView extends StatelessWidget {
  final String type;
  final String value;
  final String? subtitle;
  final dynamic icon;
  final VoidCallback callback;

  CardOverView(
      {required this.type,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.callback});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final parsedValue = int.tryParse(value);
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: callback,
        child: EnterpriseGlass(
          radius: 20,
          padding: EdgeInsets.zero,
          glowColor: enterprise.accent,
          glowOpacity: 0.10,
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white
                      .withValues(alpha: enterprise.isDark ? 0.08 : 0.28),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        enterprise.primary.withValues(alpha: 0.98),
                        enterprise.accent.withValues(alpha: 0.88),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: enterprise.accent.withValues(alpha: 0.34),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: icon is String
                        ? Image.asset(icon,
                            width: 22, height: 22, color: Colors.white)
                        : Icon(icon, size: 22, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: parsedValue?.toDouble() ?? 0,
                        ),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedValue, _) {
                          return Text(
                            parsedValue == null
                                ? value
                                : animatedValue.round().toString(),
                            style: TextStyle(
                              color: enterprise.accent,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          );
                        },
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 11,
                              color: enterprise.text.withValues(alpha: 0.65),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      enterprise.text.withValues(alpha: 0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white
                        .withValues(alpha: enterprise.isDark ? 0.08 : 0.50),
                    border: Border.all(color: enterprise.glassStroke),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: enterprise.text.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
