import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/widget/notification/notificationcard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final NotificationController model = Get.find();
    return Obx(
      () {
        if (model.isInitialLoading.value && model.notificationList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (model.errorMessage.value.isNotEmpty &&
            model.notificationList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                model.errorMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (model.notificationList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No notifications found',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ListView.builder(
              primary: false,
              controller: model.controller,
              itemCount: model.notificationList.length +
                  (model.isLoadingMore.value ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index >= model.notificationList.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return NotificationCard(
                  notification: model.notificationList[index],
                );
              }),
        );
      },
    );
  }
}
