import 'package:cnattendance/data/source/network/model/meeting/Participator.dart';
import 'package:cnattendance/screen/profile/meetingdetailscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class MeetingCard extends StatelessWidget {
  final int id;
  final String title;
  final String venue;
  final String date;
  final String time;
  final List<Participator> participator;

  const MeetingCard(
      this.id, this.title, this.venue, this.date, this.participator, this.time,
      {super.key});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: enterprise.isDark ? AppColors.white12 : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(
                alpha: enterprise.isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Get.to(MeetingDetailScreen(), arguments: {"id": id});
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    color: enterprise.text,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('meeting_list_screen.venue'),
                          style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          venue,
                          style: TextStyle(
                              color: enterprise.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: VerticalDivider(
                      width: 16,
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Date",
                          style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: TextStyle(
                              color: enterprise.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: VerticalDivider(
                      width: 16,
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Time",
                          style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time,
                          style: TextStyle(
                              color: enterprise.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
