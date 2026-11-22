import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/provider/advancesalarylistcontroller.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AdvanceSalaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AdvanceSalaryController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(translate('advance_salary_screen.advance_salary')),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              model.onAdvanceSalaryCreateClicked();
            },
            backgroundColor: AppColors.blue,
            child: Icon(
              Icons.add,
              color: AppColors.white,
            )),
        body: Obx(
          () => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: RefreshIndicator(
                onRefresh: () {
                  return model.getTadaList();
                },
                child: ListView.builder(
                  itemCount: model.salaryList.length,
                  itemBuilder: (context, index) {
                    final AdvanceSalary item = model.salaryList[index];
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
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
                          style: TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          item.submittedDate,
                          style: TextStyle(color: AppColors.grey),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            if (item.status.toLowerCase() == "pending") {
                              model.onAdvanceSalaryEditClicked(
                                  item.id.toString());
                            } else {
                              showToast(
                                  "Accepted/Rejected Advance can't be edited");
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.edit),
                          ),
                        ),
                        leading: Card(
                            color: item.status.toLowerCase() == "pending"
                                ? AppColors.orange
                                : item.status.toLowerCase() == "rejected"
                                    ? AppColors.red
                                    : AppColors.green,
                            shape: CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Text(
                                item.status.toLowerCase() == "pending"
                                    ? "P"
                                    : item.status.toLowerCase() == "rejected"
                                        ? "R"
                                        : "A",
                                style: TextStyle(
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
