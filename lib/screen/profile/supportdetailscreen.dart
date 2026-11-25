import 'package:cnattendance/model/support.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class SupportDetailScreen extends StatelessWidget {
  final Support support;

  const SupportDetailScreen(this.support, {super.key});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('support_detail_screen.payslip'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                support.title,
                style: TextStyle(
                  color: enterprise.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Query Date",
                              style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              support.query_date,
                              style: TextStyle(color: enterprise.text, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (support.solved_at != "-")
                          SizedBox(
                            height: 20,
                            child: VerticalDivider(
                              thickness: 1,
                              width: 1,
                              color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                            ),
                          ),
                        if (support.solved_at != "-")
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Solved At",
                                style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                support.solved_at,
                                style: TextStyle(
                                    color: enterprise.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            thickness: 1,
                            width: 1,
                            color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Status",
                              style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              support.status,
                              style: TextStyle(
                                  color: support.status == "Pending"
                                      ? AppColors.deepOrange
                                      : support.status == "In Progress"
                                          ? AppColors.orangeAccent
                                          : AppColors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translate('support_detail_screen.assigned_to'),
                              style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              support.requested_department,
                              style: TextStyle(color: enterprise.text, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            thickness: 1,
                            width: 1,
                            color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              translate('support_detail_screen.solved_by'),
                              style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              support.solved_by,
                              style: TextStyle(
                                  color: enterprise.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('support_detail_screen.description'),
                      style: TextStyle(
                          color: enterprise.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      support.description,
                      style: TextStyle(color: enterprise.text, fontSize: 14),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
