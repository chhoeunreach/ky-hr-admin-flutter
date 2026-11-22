import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/provider/admin_advancesalary_list_controller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AdminAdvanceSalaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AdminAdvanceSalaryController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(translate('more_screen.admin_advance_salary')),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              model.onAdminAdvanceSalaryCreateClicked();
            },
            backgroundColor: AppColors.blue,
            child: const Icon(
              Icons.add,
              color: AppColors.white,
            )),
        body: Obx(
          () => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: RefreshIndicator(
                onRefresh: () async {
                  await model.getAdminAdvanceList();
                },
                child: ListView.builder(
                  itemCount: model.salaryList.length,
                  itemBuilder: (context, index) {
                    final AdvanceSalary item = model.salaryList[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(0),
                                bottomLeft: Radius.circular(0),
                                bottomRight: Radius.circular(10))),
                        tileColor: AppColors.white12,
                        onTap: () {
                          model.onAdvanceSalaryClicked(item.id.toString());
                        },
                        textColor: AppColors.white,
                        iconColor: AppColors.white,
                        title: Text(
                          item.requested_amount,
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          item.submittedDate,
                          style: const TextStyle(color: AppColors.grey),
                        ),
                        leading: Card(
                            color: item.status.toLowerCase() == "pending"
                                ? AppColors.orange
                                : item.status.toLowerCase() == "rejected"
                                    ? AppColors.red
                                    : AppColors.green,
                            shape: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Text(
                                item.status.toLowerCase() == "pending"
                                    ? "P"
                                    : item.status.toLowerCase() == "rejected"
                                        ? "R"
                                        : "A",
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                            )),
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
