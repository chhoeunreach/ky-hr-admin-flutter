import 'package:cnattendance/features/home_highlights/home_highlight_open_screen.dart';
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/model/notification.dart' as app_notification;
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/screen/profile/notice_detail_screen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:text_sizer_plus/text_sizer_plus.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class NotificationCard extends StatelessWidget {
  final app_notification.Notification notification;

  NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();

    return Card(
      shape: ButtonBorder(),
      elevation: 0,
      color: notification.isRead ? AppColors.white12 : AppColors.white24,
      child: InkWell(
        onTap: () async {
          await controller.markNotificationAsRead(notification);
          final type = notification.type.trim().toLowerCase();
          final noticeId = notification.notificationForId;

          if (type == 'home_highlight' && noticeId > 0) {
            Get.to(() => HomeHighlightOpenScreen(id: noticeId));
            return;
          }

          if (type == 'notice' && noticeId > 0) {
            Get.to(() => NoticeDetailScreen(
                  notice: app_notification.Notification(
                    id: noticeId,
                    title: notification.title,
                    description: notification.description,
                    month: notification.month,
                    day: notification.day,
                    date: notification.date,
                    isRead: notification.isRead,
                    type: notification.type,
                    notificationForId: noticeId,
                  ),
                ));
            return;
          }

          Get.to(GeneralScreen(), arguments: {
            "id": notification.id,
            "notice_id": noticeId,
            "title": notification.title,
            "message": notification.description,
            "date": notification.date.toIso8601String(),
            "type": type,
            ...notification.appUpdate,
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: Card(
                  shape: ButtonBorder(),
                  elevation: 0,
                  color: AppColors.blueAccent,
                  child: Container(
                    width: 60,
                    height: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          notification.day,
                          style:
                              TextStyle(color: AppColors.white, fontSize: 20),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: TextSizerPlus(notification.month,
                              maxLines: 1,
                              style: TextStyle(color: AppColors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        maxLines: 1,
                        softWrap: true,
                        notification.title,
                        style: TextStyle(color: AppColors.white, fontSize: 18),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Text(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        softWrap: true,
                        notification.description,
                        style: TextStyle(color: AppColors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
