import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/provider/admin_advancesalary_list_controller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
          title: const Text("Admin Advance Salary"),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: () {
              model.onAdminAdvanceSalaryCreateClicked();
            },
            child: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            backgroundColor: Colors.blue),
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
                    AdvanceSalary item = model.salaryList[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(0),
                                bottomLeft: Radius.circular(0),
                                bottomRight: Radius.circular(10))),
                        tileColor: Colors.white12,
                        onTap: () {
                          model.onAdvanceSalaryClicked(item.id.toString());
                        },
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        title: Text(
                          item.requested_amount,
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          item.submittedDate,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        leading: Card(
                            color: item.status.toLowerCase() == "pending"
                                ? Colors.orange
                                : item.status.toLowerCase() == "rejected"
                                    ? Colors.red
                                    : Colors.green,
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
                                    color: Colors.white,
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

