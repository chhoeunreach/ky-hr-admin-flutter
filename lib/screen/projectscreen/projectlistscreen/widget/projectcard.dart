import 'package:cnattendance/model/project.dart';
import 'package:cnattendance/screen/projectscreen/projectlistscreen/projectlistscrreencontroller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_stack/image_stack.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ProjectCard extends StatelessWidget {
  final Project item;

  ProjectCard(this.item);

  @override
  Widget build(BuildContext context) {
    final ProjectListScreenController model = Get.find();

    final List<String> members = [];
    for (var member in item.members) {
      members.add(member.image);
    }

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
      elevation: 0,
      color: AppColors.white10,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
        onTap: () {
          model.onProjectClicked(item);
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.work,
                        size: 20,
                        color: AppColors.white,
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Expanded(
                        child: Text(item.name,
                            maxLines: 2,
                            style: TextStyle(
                                height: 1.5,
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Date",
                            style: TextStyle(
                                color: AppColors.white70, fontSize: 12),
                          ),
                          Text(
                            item.date,
                            style:
                                TextStyle(color: AppColors.white, fontSize: 15),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Status",
                            style: TextStyle(
                                color: AppColors.white70, fontSize: 12),
                          ),
                          Text(
                            item.status,
                            style:
                                TextStyle(color: AppColors.white, fontSize: 15),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Priority",
                            style: TextStyle(
                                color: AppColors.white70, fontSize: 12),
                          ),
                          Text(
                            item.priority,
                            style:
                                TextStyle(color: AppColors.white, fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    percent: item.progress / 100,
                    lineHeight: 5,
                    barRadius: Radius.circular(20),
                    backgroundColor: AppColors.white12,
                    progressColor: item.progress <= 25
                        ? AppColors.customFFC1E1C1
                        : item.progress <= 50
                            ? AppColors.customFFC9CC3F
                            : item.progress <= 75
                                ? AppColors.customFF93C572
                                : AppColors.customFF3CB116,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                ],
              ),
              Row(
                children: [
                  ImageStack(
                    imageList: List<String>.from(members),
                    totalCount: members.length,
                    imageRadius: 25,
                    imageCount: 4,
                    imageBorderColor: AppColors.white,
                    imageBorderWidth: 1,
                  ),
                  Spacer(),
                  Icon(
                    Icons.flag,
                    size: 15,
                    color: AppColors.white,
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(item.noOfTask.toString(),
                      style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
