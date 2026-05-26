import 'package:cnattendance/model/advancesalary.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/repositories/advancesalaryrepository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AdvanceDetailController extends GetxController {
  var advanceSalary = AdvanceSalary(0, "", "", "", "", false, "", "", "","","").obs;
  var isLoading = false.obs;
  final canApprove = false.obs;
  AdvanceSalaryRepository repository = AdvanceSalaryRepository();
  final remarkController = "".obs;
  final releasedAmountController = "".obs;

  Future<String> getAdvanceSalaryDetail(String id) async {
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);

      final response = await repository.getAdvanceSalaryDetail(id);
      EasyLoading.dismiss(animation: true);

      final data = response.data;

      final salary = AdvanceSalary(
          data.id,
          data.description,
          data.requested_amount,
          data.released_amount,
          data.status,
          data.is_settled,
          data.verified_by,
          data.remark,
          data.released_date,data.requested_date,data.released_date);

      advanceSalary.value = salary;
    } catch (e) {
      print(e.toString());
      EasyLoading.dismiss(animation: true);
      Get.back();
    }
    return "loaded";
  }

  Future<void> loadPermissions() async {
    try {
      final features = await Preferences().getFeatures();
      canApprove.value = features["advance-salary-approve"] == "1";
    } catch (_) {
      canApprove.value = false;
    }
  }

  Future<void> approveAdvanceSalary() async {
    if (!canApprove.value) {
      showToast("You don’t have permission to approve Advance Salary.");
      return;
    }

    final id = advanceSalary.value.id.toString();
    final releasedAmount = (releasedAmountController.value.trim().isEmpty)
        ? advanceSalary.value.released_amount
        : releasedAmountController.value.trim();

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await repository.approveAdvanceSalary(
        id: id,
        releasedAmount: releasedAmount,
        remark: remarkController.value.trim(),
      );
      EasyLoading.dismiss(animation: true);
      showToast(response.message);
      await getAdvanceSalaryDetail(id);
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    }
  }

  Future<void> rejectAdvanceSalary() async {
    if (!canApprove.value) {
      showToast("You don’t have permission to approve Advance Salary.");
      return;
    }

    final id = advanceSalary.value.id.toString();

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await repository.rejectAdvanceSalary(
        id: id,
        remark: remarkController.value.trim(),
      );
      EasyLoading.dismiss(animation: true);
      showToast(response.message);
      await getAdvanceSalaryDetail(id);
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    }
  }

  @override
  void onInit() {
    loadPermissions();
    getAdvanceSalaryDetail(Get.arguments['id']);
    super.onInit();
  }
}
