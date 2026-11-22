import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:text_sizer_plus/text_sizer_plus.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class Holidaycard extends StatelessWidget {
  final int id;
  final String name;
  final String month;
  final String day;
  final String desc;
  final bool isPublicHoliday;

  Holidaycard({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    required this.desc,
    required this.isPublicHoliday,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Card(
      shape: ButtonBorder(),
      elevation: 0,
      color: enterprise.isDark
          ? AppColors.customFF1E293B.withValues(alpha: 0.90)
          : AppColors.white.withValues(alpha: 0.90),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Card(
                shape: ButtonBorder(),
                elevation: 0,
                color: isPublicHoliday
                    ? AppColors.dangerToken
                    : enterprise.primary,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: TextSizerPlus(
                          month,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      softWrap: true,
                      name,
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      overflow: TextOverflow.fade,
                      softWrap: true,
                      parse(desc).body?.text ?? '',
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
