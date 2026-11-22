import 'package:cnattendance/screen/complainscreen/complaincontroller.dart';
import 'package:cnattendance/screen/complainscreen/createcomplainscreen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/profile/complaint_bottom_sheet.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ComplainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(ComplainController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text("Complain"),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              Get.to(CreateComplainScreen());
            },
            backgroundColor: AppColors.blue,
            child: Icon(
              Icons.add,
              color: AppColors.white,
            )),
        body: Obx(
          () => RefreshIndicator(
            onRefresh: () async {
              model.page = 1;
              await model.getCompaints();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height),
                child: ListView.builder(
                  shrinkWrap: true,
                  primary: true,
                  itemCount: model.complaintList.length,
                  itemBuilder: (context, index) {
                    final complaint = model.complaintList[index];
                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                            elevation: 0,
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20))),
                            builder: (context) {
                              return ComplaintBottomSheet(complaint);
                            });
                      },
                      child: Card(
                        shape: ButtonBorder(),
                        color: complaint.response.isEmpty
                            ? AppColors.red.withValues(alpha: .5)
                            : AppColors.white24,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      complaint.complaintDate,
                                      style: TextStyle(
                                          color: AppColors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal),
                                    ),
                                    Text(
                                      complaint.subject,
                                      style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                complaint.response.isNotEmpty
                                    ? Icons.reply
                                    : Icons.feedback_rounded,
                                color: AppColors.white,
                              )
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
        ),
      ),
    );
  }
}
