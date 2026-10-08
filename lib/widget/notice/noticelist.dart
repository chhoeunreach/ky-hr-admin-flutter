import 'package:cnattendance/provider/noticecontroller.dart';
import 'package:cnattendance/widget/notice/noticecard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NoticeList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => NoticeListState();
}

class NoticeListState extends State<NoticeList> {
  @override
  Widget build(BuildContext context) {
    final NoticeController model = Get.find();
    return Obx(
      () {
        if (model.notificationList.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
            children: [
              Icon(
                Icons.campaign_outlined,
                color: Colors.white.withValues(alpha: 0.36),
                size: 58,
              ),
              const SizedBox(height: 14),
              Text(
                'No notices available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: model.controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: model.notificationList.length,
          itemBuilder: (ctx, index) {
            return NoticeCard(notice: model.notificationList[index]);
          },
        );
      },
    );
  }
}
