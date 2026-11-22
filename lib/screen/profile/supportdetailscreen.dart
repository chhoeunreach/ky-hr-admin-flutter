import 'package:cnattendance/model/support.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class SupportDetailScreen extends StatelessWidget {
  final Support support;

  SupportDetailScreen(this.support);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(translate('support_detail_screen.payslip')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                support.title,
                style: TextStyle(color: AppColors.white, fontSize: 18),
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Query Date",
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      Text(
                        support.query_date,
                        style: TextStyle(color: AppColors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  if (support.solved_at != "-")
                    SizedBox(
                      height: 20,
                      child: VerticalDivider(
                        thickness: 1,
                        width: 1,
                      ),
                    ),
                  if (support.solved_at != "-")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Solved At",
                          style: TextStyle(color: AppColors.grey, fontSize: 14),
                        ),
                        Text(
                          support.solved_at,
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      thickness: 1,
                      width: 1,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Status",
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      Text(
                        support.status,
                        style: TextStyle(
                            color: support.status == "Pending"
                                ? AppColors.deepOrange
                                : support.status == "In Progress"
                                    ? AppColors.orangeAccent
                                    : AppColors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('support_detail_screen.assigned_to'),
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      Text(
                        support.requested_department,
                        style: TextStyle(color: AppColors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      thickness: 1,
                      width: 1,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        translate('support_detail_screen.solved_by'),
                        style: TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      Text(
                        support.solved_by,
                        style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.normal,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: 15,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: AppColors.white24,
                    shape: ButtonBorder(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translate('support_detail_screen.description'),
                            style: TextStyle(
                                color: AppColors.white70, fontSize: 14),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text(
                            support.description,
                            style:
                                TextStyle(color: AppColors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
