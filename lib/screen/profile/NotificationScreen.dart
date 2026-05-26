import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/widget/notification/notificationlist.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class NotificationScreen extends StatefulWidget {
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationController model;

  @override
  void initState() {
    super.initState();
    model = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController(), permanent: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await model.ensureLoaded();
      await model.syncAppIconBadge();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            backgroundColor: Colors.transparent,
            title: Text(translate('notification_screen.notifications'),
                style: TextStyle(color: Colors.white)),
          ),
          body: RefreshIndicator(
              onRefresh: () {
                return model.refreshNotifications();
              },
              child: NotificationList())),
    );
  }
}
