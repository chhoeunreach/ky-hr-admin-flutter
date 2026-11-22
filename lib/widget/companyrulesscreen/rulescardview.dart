import 'package:cnattendance/widget/buttonborder.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RulesCardView extends StatelessWidget {
  final String title;
  final String description;

  RulesCardView(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: ButtonBorder(),
      elevation: 0,
      color: AppColors.white12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        child: ExpandableTheme(
          data: const ExpandableThemeData(
            iconPadding: EdgeInsets.all(0),
            iconColor: AppColors.white,
            tapHeaderToExpand: true,
            animationDuration: Duration(milliseconds: 500),
          ),
          child: ExpandablePanel(
              header: Text(
                title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white),
              ),
              collapsed: Html(
                shrinkWrap: true,
                style: {
                  "body": Style(
                      color: AppColors.white,
                      fontSize: FontSize.medium,
                      maxLines: 1)
                },
                data: description,
              ),
              expanded: Html(
                shrinkWrap: true,
                style: {
                  "body":
                      Style(color: AppColors.white, fontSize: FontSize.medium)
                },
                data: description,
              )),
        ),
      ),
    );
  }
}
