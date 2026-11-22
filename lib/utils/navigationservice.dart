import 'package:flutter/material.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void showSnackBar(String title, String desc, {VoidCallback? onTap}) {
    try {
      InAppNotification.show(
        child: Card(
          margin: const EdgeInsets.all(15),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: onTap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              leading: Container(
                  height: double.infinity, child: Icon(Icons.notifications)),
              iconColor: AppColors.customFF011754,
              textColor: AppColors.customFF011754,
              minVerticalPadding: 10,
              minLeadingWidth: 0,
              tileColor: AppColors.white,
              title: Text(title),
              subtitle: Text(
                desc,
                style: TextStyle(color: AppColors.grey),
              ),
            ),
          ),
        ),
        context: NavigationService.navigatorKey.currentState!.context,
      );
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
    }
  }
}
