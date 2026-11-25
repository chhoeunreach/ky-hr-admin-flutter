import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/provider/advancesalarylistcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
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
            translate('advance_salary_screen.advance_salary'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              model.onAdvanceSalaryCreateClicked();
            },
            backgroundColor: enterprise.primary,
            child: const Icon(
              Icons.add,
              color: AppColors.white,
            )),
        body: Obx(
          () => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
              child: RefreshIndicator(
                onRefresh: () {
                  return model.getTadaList();
                },
                child: ListView.builder(
                  itemCount: model.salaryList.length,
                  itemBuilder: (context, index) {
                    final AdvanceSalary item = model.salaryList[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: enterprise.isDark
                              ? enterprise.cardBorder
                              : AppColors.customFFB8DEFF,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(
                                alpha: enterprise.isDark ? 0.12 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        onTap: () {
                          model.onAdvanceSalaryClicked(item.id.toString());
                        },
                        title: Text(
                          item.requested_amount,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: enterprise.text,
                          ),
                        ),
                        subtitle: Text(
                          item.submittedDate,
                          style: TextStyle(
                            color: enterprise.mutedText,
                            fontSize: 12,
                          ),
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
                            child: Icon(
                              Icons.edit,
                              color: item.status.toLowerCase() == "pending"
                                  ? enterprise.primary
                                  : enterprise.mutedText,
                            ),
                          ),
                        ),
                        leading: Card(
                            color: item.status.toLowerCase() == "pending"
                                ? AppColors.orange
                                : item.status.toLowerCase() == "rejected"
                                    ? AppColors.red
                                    : AppColors.green,
                            shape: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                item.status.toLowerCase() == "pending"
                                    ? "P"
                                    : item.status.toLowerCase() == "rejected"
                                        ? "R"
                                        : "A",
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
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
