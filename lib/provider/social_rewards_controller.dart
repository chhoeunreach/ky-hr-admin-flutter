import 'package:cnattendance/model/social_reward.dart';
import 'package:cnattendance/repositories/social_rewards_repository.dart';
import 'package:cnattendance/screen/social_rewards/social_reward_form_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class SocialRewardsController extends GetxController {
  final rewards = <SocialReward>[].obs;
  final isLoading = false.obs;
  final repository = SocialRewardsRepository();

  Future<void> getRewards() async {
    try {
      isLoading.value = true;
      EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black,
      );

      final response = await repository.getRewards();
      rewards.value = response.data;
      EasyLoading.dismiss(animation: true);
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void onCreateClicked() async {
    await Get.to(
      SocialRewardFormScreen(),
      transition: Transition.cupertino,
    );
    getRewards();
  }

  void onRewardClicked(SocialReward reward) async {
    await Get.to(
      SocialRewardFormScreen(reward: reward),
      transition: Transition.cupertino,
    );
    getRewards();
  }

  @override
  void onInit() {
    getRewards();
    super.onInit();
  }
}

class SocialRewardFormController extends GetxController {
  SocialRewardFormController({this.reward});

  final SocialReward? reward;
  final key = GlobalKey<FormState>();
  final repository = SocialRewardsRepository();

  final employeeIdController = TextEditingController();
  final logDateController = TextEditingController();
  final fbPostController = TextEditingController();
  final fbStoryController = TextEditingController();
  final tiktokController = TextEditingController();
  final reasonController = TextEditingController();

  bool get isOverride => reward != null;

  void checkForm() {
    if (key.currentState?.validate() != true) {
      return;
    }
    save();
  }

  Future<void> pickLogDate(BuildContext context) async {
    final initialDate =
        DateTime.tryParse(logDateController.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selected == null) {
      return;
    }

    logDateController.text = '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }

  Future<void> save() async {
    try {
      EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black,
      );

      final response = isOverride
          ? await repository.overrideReward(
              rewardId: reward!.id,
              fbPostUrl: fbPostController.text.trim(),
              fbStoryUrl: fbStoryController.text.trim(),
              tiktokUrl: tiktokController.text.trim(),
              reason: reasonController.text.trim(),
            )
          : await repository.createReward(
              existingEmployeeId: employeeIdController.text.trim(),
              logDate: logDateController.text.trim(),
              fbPostUrl: fbPostController.text.trim(),
              fbStoryUrl: fbStoryController.text.trim(),
              tiktokUrl: tiktokController.text.trim(),
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

  @override
  void onInit() {
    final item = reward;
    if (item != null) {
      employeeIdController.text = item.existingEmployeeId.toString();
      logDateController.text = item.logDate;
      fbPostController.text = item.fbPostUrl;
      fbStoryController.text = item.fbStoryUrl;
      tiktokController.text = item.tiktokUrl;
    }
    super.onInit();
  }

  @override
  void onClose() {
    employeeIdController.dispose();
    logDateController.dispose();
    fbPostController.dispose();
    fbStoryController.dispose();
    tiktokController.dispose();
    reasonController.dispose();
    super.onClose();
  }
}
