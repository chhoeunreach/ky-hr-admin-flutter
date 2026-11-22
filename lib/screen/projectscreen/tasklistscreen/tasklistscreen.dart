import 'package:cnattendance/model/task.dart';
import 'package:cnattendance/screen/projectscreen/taskdetailscreen/taskdetailscreen.dart';
import 'package:cnattendance/screen/projectscreen/tasklistscreen/tasklistscontroller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:image_stack/image_stack.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class TaskListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(TaskListController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(translate('task_list_screen.tasks')),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () {
              return model.getTaskList();
            },
            child: Container(
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10))),
                    color: AppColors.white12,
                    elevation: 0,
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Obx(
                        () => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "All";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "All"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate('task_list_screen.all'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "In Progress";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "In Progress"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate(
                                            'task_list_screen.in_progress'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "Completed";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "Completed"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate('task_list_screen.completed'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "On Hold";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "On Hold"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate('task_list_screen.on_hold'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "Cancelled";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "Cancelled"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate('task_list_screen.cancelled'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    model.selected.value = "Not Started";
                                    model.filterList();
                                  },
                                  child: Card(
                                    elevation: 0,
                                    color: model.selected.value == "Not Started"
                                        ? AppColors.white24
                                        : Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 15),
                                      child: Text(
                                        translate(
                                            'task_list_screen.not_started'),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Expanded(
                    child: Obx(
                      () => model.filteredList.isEmpty
                          ? SingleChildScrollView(
                              physics: AlwaysScrollableScrollPhysics(),
                              child: Container(),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                primary: false,
                                itemCount: model.filteredList.length,
                                itemBuilder: (context, index) {
                                  final Task item = model.filteredList[index];

                                  final List<String> members = [];
                                  for (var member in item.members) {
                                    members.add(member.image);
                                  }

                                  return InkWell(
                                    onTap: () {
                                      Get.to(TaskDetailScreen(),
                                          arguments: {"id": item.id});
                                    },
                                    child: Card(
                                      margin:
                                          EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(10),
                                              bottomRight:
                                                  Radius.circular(10))),
                                      color: AppColors.white12,
                                      elevation: 0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 15, vertical: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name ?? "",
                                                    maxLines: 2,
                                                    style: TextStyle(
                                                        height: 1.5,
                                                        color: AppColors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20)),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.work,
                                                      size: 10,
                                                      color: AppColors.white54,
                                                    ),
                                                    SizedBox(
                                                      width: 5,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                          item.projectName ??
                                                              "",
                                                          maxLines: 2,
                                                          style: TextStyle(
                                                              height: 1.5,
                                                              color:
                                                                  Colors
                                                                      .white54,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12)),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: 5,
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Start Date",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12),
                                                        ),
                                                        Text(
                                                          item.date ?? "",
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .white,
                                                              fontSize: 15),
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "End Date",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12),
                                                        ),
                                                        Text(
                                                          item.endDate ?? "",
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .white,
                                                              fontSize: 15),
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Priority",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12),
                                                        ),
                                                        Text(
                                                          item.priority ?? "",
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .white,
                                                              fontSize: 15),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: 10,
                                                ),
                                                if (item.hasProgress == true)
                                                  LinearPercentIndicator(
                                                    padding: EdgeInsets.zero,
                                                    percent:
                                                        item.progress! / 100,
                                                    lineHeight: 5,
                                                    barRadius:
                                                        Radius.circular(20),
                                                    backgroundColor:
                                                        AppColors.white12,
                                                    progressColor: item
                                                                .progress! <=
                                                            25
                                                        ? AppColors
                                                            .customFFC1E1C1
                                                        : item.progress! <= 50
                                                            ? AppColors
                                                                .customFFC9CC3F
                                                            : item.progress! <=
                                                                    75
                                                                ? AppColors
                                                                    .customFF93C572
                                                                : AppColors
                                                                    .customFF3CB116,
                                                  ),
                                                if (item.progress == 0 &&
                                                    item.hasProgress == false)
                                                  Divider(
                                                    color: AppColors.white24,
                                                  ),
                                                SizedBox(
                                                  height: 10,
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                ImageStack(
                                                  imageList: List<String>.from(
                                                      members),
                                                  totalCount: members.length,
                                                  imageRadius: 25,
                                                  imageCount: 4,
                                                  imageBorderColor:
                                                      AppColors.white,
                                                  imageBorderWidth: 1,
                                                ),
                                                Spacer(),
                                                Text(
                                                  item.status,
                                                  style: TextStyle(
                                                      color: AppColors.white,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
