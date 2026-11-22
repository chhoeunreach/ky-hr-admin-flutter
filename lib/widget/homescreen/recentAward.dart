import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/awards/awarddetailsscreen.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RecentAward extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final award = context.watch<DashboardProvider>().award;
    final enterprise = EnterpriseTheme.of(context);
    return Visibility(
      visible: award != null ? true : false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  translate('home_screen.recent_award'),
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(AwardsScreen());
                  },
                  child: Text(
                    translate('home_screen.show_all'),
                    style: TextStyle(
                      color: enterprise.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            award != null
                ? GestureDetector(
                    onTap: () {
                      Get.to(AwardDetailScreen(), arguments: {"award": award});
                    },
                    child: Card(
                      shape: ButtonBorder(),
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: enterprise.isDark
                          ? AppColors.customFF1E293B.withValues(alpha: 0.90)
                          : AppColors.white.withValues(alpha: 0.90),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 30,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8),
                          child: Row(
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    award.award_name,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: enterprise.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    award.employee_name,
                                    style: TextStyle(
                                      color: enterprise.mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: enterprise.accent,
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: ClipOval(
                                  child: Image.network(
                                    award.image,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox.shrink()
          ],
        ),
      ),
    );
  }
}
