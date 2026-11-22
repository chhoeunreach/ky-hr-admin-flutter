import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String? actionLabel;

  CustomAlertDialog(this.title, {this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final message = title.toString().toLowerCase().contains("null")
        ? "សូមបើកបិទរ៉ោតទ័រឡើងវិញ ហើយព្យាយាមម្តងទៀត។"
        : title;
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/icons/dialog_icon.png",
            width: 80,
            height: 80,
          ),
          SizedBox(
            height: 20,
          ),
          Text(
            textAlign: TextAlign.center,
            message,
            style: TextStyle(fontSize: 15, color: AppColors.black),
          ),
          SizedBox(
            height: 10,
          ),
          if (actionLabel != null) ...[
            Container(
              width: double.infinity,
              child: ElevatedButton(
                  style: TextButton.styleFrom(
                      backgroundColor: AppColors.customFF036EB7,
                      shape: ButtonBorder()),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Text(actionLabel!,
                        style: TextStyle(color: AppColors.white)),
                  )),
            ),
            SizedBox(
              height: 10,
            ),
          ],
          Container(
            width: double.infinity,
            child: ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: AppColors.customFF036EB7,
                    shape: ButtonBorder()),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(translate('common.close'),
                      style: TextStyle(color: AppColors.white)),
                )),
          )
        ],
      ),
    );
  }
}
