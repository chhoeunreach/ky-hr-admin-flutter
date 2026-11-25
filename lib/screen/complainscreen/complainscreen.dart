import 'package:cnattendance/screen/complainscreen/complaincontroller.dart';
import 'package:cnattendance/screen/complainscreen/createcomplainscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/profile/complaint_bottom_sheet.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ComplainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(ComplainController());
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            "Complain",
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              Get.to(CreateComplainScreen());
            },
            backgroundColor: enterprise.primary,
            child: const Icon(
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
                            backgroundColor: Colors.transparent,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: enterprise.isDark
                                ? enterprise.cardBorder
                                : AppColors.customFFB8DEFF,
                          ),
                        ),
                        color: complaint.response.isEmpty
                            ? (enterprise.isDark
                                ? AppColors.red.withValues(alpha: .35)
                                : const Color(0xFFFEF2F2))
                            : (enterprise.isDark
                                ? AppColors.white12
                                : AppColors.white),
                        elevation: enterprise.isDark ? 0 : 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      complaint.complaintDate,
                                      style: TextStyle(
                                          color: enterprise.mutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      complaint.subject,
                                      style: TextStyle(
                                          color: enterprise.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                complaint.response.isNotEmpty
                                    ? Icons.reply
                                    : Icons.feedback_rounded,
                                color: complaint.response.isNotEmpty
                                    ? enterprise.primary
                                    : (enterprise.isDark
                                        ? AppColors.white70
                                        : AppColors.red),
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
