import 'package:cnattendance/model/project.dart';
import 'package:cnattendance/model/task.dart';
import 'package:cnattendance/provider/projectdashboardcontroller.dart';
import 'package:cnattendance/screen/projectscreen/projectdetailscreen/projectdetailscreen.dart';
import 'package:cnattendance/screen/projectscreen/projectlistscreen/projectlistscreen.dart';
import 'package:cnattendance/screen/projectscreen/taskdetailscreen/taskdetailscreen.dart';
import 'package:cnattendance/screen/projectscreen/tasklistscreen/tasklistscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_stack/image_stack.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class ProjectScreen extends StatelessWidget {
  final model = Get.put(ProjectDashboardController());

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            translate('project_screen.project_management'),
            style: TextStyle(
              color: enterprise.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: enterprise.text),
        ),
        body: FocusDetector(
          onFocusGained: () {
            model.getProjectOverview();
          },
          child: RefreshIndicator(
            triggerMode: RefreshIndicatorTriggerMode.onEdge,
            color: enterprise.accent,
            backgroundColor: enterprise.cardBackground,
            edgeOffset: 50,
            onRefresh: () {
              return model.getProjectOverview();
            },
            child: SafeArea(
                child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                width: double.infinity,
                child: Column(
                  children: [
                    projectOverview(enterprise),
                    recentProject(enterprise),
                    recentTasks(enterprise)
                  ],
                ),
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget projectOverview(EnterpriseTheme enterprise) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
          side: BorderSide(color: enterprise.cardBorder)),
      color: enterprise.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Obx(
              () => CircularPercentIndicator(
                radius: 60.0,
                animation: true,
                animationDuration: 1200,
                lineWidth: 15.0,
                percent: (model.overview['progress']! / 100),
                center: Obx(
                  () => Text(
                    model.overview['progress'].toString() + "%",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: enterprise.text),
                  ),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: enterprise.isDark
                    ? Colors.white12
                    : const Color(0xFFE2E8F0),
                progressColor: (model.overview['progress']! / 100) <= .25
                    ? HexColor("#C1E1C1")
                    : (model.overview['progress']! / 100) <= .50
                        ? HexColor("#C9CC3F")
                        : (model.overview['progress']! / 100) <= .75
                            ? HexColor("#93C572")
                            : HexColor("#3cb116"),
              ),
            ),
            SizedBox(
              width: 20,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate('project_screen.progress_current_task'),
                      style: TextStyle(
                          color: enterprise.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  Divider(
                    color: enterprise.cardBorder,
                    endIndent: 0,
                    indent: 0,
                  ),
                  Obx(
                    () => Text(
                        model.overview['project_completed'].toString() +
                            " / " +
                            model.overview['total_project'].toString() +
                            " ${translate('project_screen.task_completed')}",
                        style: TextStyle(
                            color: enterprise.mutedText,
                            fontWeight: FontWeight.normal,
                            fontSize: 12)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget recentProject(EnterpriseTheme enterprise) {
    return Obx(
      () => Visibility(
        visible: model.projectList.isEmpty ? false : true,
        child: Container(
          height: 215,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translate('project_screen.recent_projects'),
                    style: TextStyle(
                        color: enterprise.text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Get.to(ProjectListScreen());
                    },
                    child: Text(
                      translate('project_screen.view_all'),
                      style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: enterprise.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.normal),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Expanded(
                  child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: model.projectList.length,
                itemBuilder: (context, index) {
                  Project item = model.projectList[index];
                  var memberImages = [];

                  for (var member in item.members) {
                    memberImages.add(member.image);
                  }

                  return GestureDetector(
                    onTap: () {
                      Get.to(ProjectDetailScreen(), arguments: {"id": item.id});
                    },
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10)),
                          side: BorderSide(color: enterprise.cardBorder)),
                      color: enterprise.cardBackground,
                      child: Container(
                        width: MediaQuery.sizeOf(context).width - 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 0),
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
                                      color: enterprise.accent,
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Expanded(
                                      child: Text(item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              height: 1,
                                              color: enterprise.text,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18)),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Date",
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        Text(
                                          item.date,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Status",
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        Text(
                                          item.status,
                                          style: TextStyle(
                                              color: enterprise.accent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Priority",
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        Text(
                                          item.priority,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                LinearPercentIndicator(
                                  padding: EdgeInsets.zero,
                                  percent: item.progress / 100,
                                  lineHeight: 5,
                                  barRadius: Radius.circular(20),
                                  backgroundColor: enterprise.isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0),
                                  progressColor: item.progress <= 25
                                      ? HexColor("#C1E1C1")
                                      : item.progress <= 50
                                          ? HexColor("#C9CC3F")
                                          : item.progress <= 75
                                              ? HexColor("#93C572")
                                              : HexColor("#3cb116"),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                ImageStack(
                                  imageList: List<String>.from(memberImages),
                                  totalCount: memberImages.length,
                                  imageRadius: 25,
                                  imageCount: 4,
                                  imageBorderColor:
                                      enterprise.cardBackground,
                                  imageBorderWidth: 1,
                                ),
                                Spacer(),
                                Icon(
                                  Icons.flag,
                                  size: 15,
                                  color: enterprise.mutedText,
                                ),
                                SizedBox(
                                  width: 5,
                                ),
                                Text(item.noOfTask.toString(),
                                    style: TextStyle(
                                        color: enterprise.mutedText,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget recentTasks(EnterpriseTheme enterprise) {
    return Obx(
      () => Visibility(
        visible: model.taskList.isEmpty ? false : true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translate('project_screen.recent_tasks'),
                    style: TextStyle(
                        color: enterprise.text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Get.to(TaskListScreen(),
                          transition: Transition.cupertino);
                    },
                    child: Text(
                      translate('project_screen.view_all'),
                      style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: enterprise.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.normal),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Obx(
                () => ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: model.taskList.length,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    Task item = model.taskList[index];

                    List<String> members = [];
                    for (var member in item.members) {
                      members.add(member.image);
                      print(member.image);
                    }

                    return InkWell(
                      onTap: () {
                        Get.to(TaskDetailScreen(), arguments: {"id": item.id});
                      },
                      child: Card(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10)),
                            side: BorderSide(color: enterprise.cardBorder)),
                        color: enterprise.cardBackground,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name ?? "",
                                      maxLines: 2,
                                      style: TextStyle(
                                          height: 1.5,
                                          color: enterprise.text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20)),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.work,
                                        size: 10,
                                        color: enterprise.mutedText,
                                      ),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      Expanded(
                                        child: Text(item.projectName ?? "",
                                            maxLines: 2,
                                            style: TextStyle(
                                                height: 1.5,
                                                color: enterprise.mutedText,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Start Date",
                                            style: TextStyle(
                                                color: enterprise.mutedText,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            item.date ?? "",
                                            style: TextStyle(
                                                color: enterprise.text,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "End Date",
                                            style: TextStyle(
                                                color: enterprise.mutedText,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            item.endDate ?? "",
                                            style: TextStyle(
                                                color: enterprise.text,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Priority",
                                            style: TextStyle(
                                                color: enterprise.mutedText,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            item.priority ?? "",
                                            style: TextStyle(
                                                color: enterprise.text,
                                                fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  if (item.progress != 0 &&
                                      item.hasProgress == true)
                                    LinearPercentIndicator(
                                      padding: EdgeInsets.zero,
                                      percent: item.progress! / 100,
                                      lineHeight: 5,
                                      barRadius: Radius.circular(20),
                                      backgroundColor: enterprise.isDark
                                          ? Colors.white12
                                          : const Color(0xFFE2E8F0),
                                      progressColor: item.progress! <= 25
                                          ? HexColor("#C1E1C1")
                                          : item.progress! <= 50
                                              ? HexColor("#C9CC3F")
                                              : item.progress! <= 75
                                                  ? HexColor("#93C572")
                                                  : HexColor("#3cb116"),
                                    ),
                                  if (item.progress == 0 &&
                                      item.hasProgress == false)
                                    Divider(
                                      color: enterprise.cardBorder,
                                    ),
                                  SizedBox(
                                    height: 5,
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
                                    imageBorderColor:
                                        enterprise.cardBackground,
                                    imageBorderWidth: 1,
                                  ),
                                  Spacer(),
                                  Text(
                                    item.status,
                                    style: TextStyle(
                                        color: enterprise.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
