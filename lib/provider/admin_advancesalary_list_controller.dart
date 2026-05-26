import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/repositories/admin_advancesalary_repository.dart';
import 'package:cnattendance/screen/advancesalary/advancedetailscreen.dart';
import 'package:cnattendance/screen/advancesalary/admin/admin_create_advancesalary_screen.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AdminAdvanceSalaryController extends GetxController {
  final salaryList = <AdvanceSalary>[].obs;
  final isLoading = false.obs;

  final repository = AdminAdvanceSalaryRepository();

  Future<void> getAdminAdvanceList() async {
    try {
      isLoading.value = true;
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);

      final response = await repository.getAdminAdvanceList();
      EasyLoading.dismiss(animation: true);

      final list = <AdvanceSalary>[];
      for (var advance in response.data) {
        list.add(
          AdvanceSalary(
            advance.id,
            advance.description,
            advance.requested_amount,
            advance.released_amount,
            advance.status,
            advance.is_settled,
            advance.verified_by,
            advance.remark,
            advance.requested_date,
            advance.requested_date,
            advance.released_date,
          ),
        );
      }
      salaryList.value = list;
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      print(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void onAdvanceSalaryClicked(String id) async {
    await Get.to(AdvanceDetailScreen(),
        arguments: {'id': id}, transition: Transition.cupertino);
    getAdminAdvanceList();
  }

  void onAdminAdvanceSalaryCreateClicked() async {
    await Get.to(AdminCreateAdvanceSalaryScreen(),
        transition: Transition.cupertino);
    getAdminAdvanceList();
  }

  @override
  void onInit() {
    getAdminAdvanceList();
    super.onInit();
  }
}

