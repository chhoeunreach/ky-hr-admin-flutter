import 'package:cnattendance/repositories/admin_advancesalary_repository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AdminCreateAdvanceSalaryController extends GetxController {
  final key = GlobalKey<FormState>();

  final expensesController = TextEditingController();
  final descriptionController = TextEditingController();

  final repository = AdminAdvanceSalaryRepository();

  void checkForm() {
    if (key.currentState?.validate() != true) {
      return;
    }
    create();
  }

  Future<void> create() async {
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);

      final response = await repository.createAdminAdvanceSalary(
        reqAmt: expensesController.text.trim(),
        desc: descriptionController.text.trim(),
      );

      EasyLoading.dismiss(animation: true);
      showToast(response.message);
      if (response.status) {
        Get.back();
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    }
  }
}

