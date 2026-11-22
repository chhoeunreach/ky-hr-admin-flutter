import 'package:cnattendance/model/notification.dart' as app_notification;
import 'package:cnattendance/screen/profile/notice_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cnattendance/core/theme/app_colors.dart';

class NoticeCard extends StatelessWidget {
  final app_notification.Notification notice;

  const NoticeCard({Key? key, required this.notice}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final previewText =
        html_parser.parseFragment(notice.description).text?.trim() ??
            notice.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Get.to(() => NoticeDetailScreen(notice: notice));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AppColors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.blueAccent.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        notice.day,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notice.month,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notice.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.white.withValues(alpha: 0.72),
                          ),
                        ],
                      ),
                      if (previewText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          previewText,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
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
