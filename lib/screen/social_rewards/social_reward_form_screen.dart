import 'package:cnattendance/model/social_reward.dart';
import 'package:cnattendance/provider/social_rewards_controller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';

class SocialRewardFormScreen extends StatelessWidget {
  SocialRewardFormScreen({super.key, this.reward});

  final SocialReward? reward;

  @override
  Widget build(BuildContext context) {
    final model = Get.put(
      SocialRewardFormController(reward: reward),
      tag: reward?.id.toString() ?? 'create',
    );

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(model.isOverride
              ? 'Override Social Reward'
              : 'Create Social Reward'),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HexColor('#036eb7'),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
              onPressed: model.checkForm,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text(model.isOverride ? 'Submit Override' : 'Submit'),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: model.key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RewardTextField(
                    controller: model.employeeIdController,
                    hintText: 'Existing employee ID',
                    keyboardType: TextInputType.number,
                    enabled: !model.isOverride,
                  ),
                  const SizedBox(height: 10),
                  _RewardTextField(
                    controller: model.logDateController,
                    hintText: 'Log date',
                    readOnly: true,
                    enabled: !model.isOverride,
                    onTap: model.isOverride
                        ? null
                        : () => model.pickLogDate(context),
                    suffixIcon: Icons.calendar_month,
                  ),
                  const SizedBox(height: 10),
                  const _LockedPointNotice(),
                  const SizedBox(height: 10),
                  _RewardTextField(
                    controller: model.fbPostController,
                    hintText: 'Facebook post URL',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 10),
                  _RewardTextField(
                    controller: model.fbStoryController,
                    hintText: 'Facebook story URL',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 10),
                  _RewardTextField(
                    controller: model.tiktokController,
                    hintText: 'TikTok URL',
                    keyboardType: TextInputType.url,
                  ),
                  if (model.isOverride) ...[
                    const SizedBox(height: 10),
                    _RewardTextField(
                      controller: model.reasonController,
                      hintText: 'Audit reason',
                      maxLines: 4,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedPointNotice extends StatelessWidget {
  const _LockedPointNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.white70, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reward points are locked at 1 point.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTextField extends StatelessWidget {
  const _RewardTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Field is required';
        }
        return null;
      },
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: Colors.white70, size: 20),
        hintStyle: const TextStyle(color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white),
        fillColor: enabled ? Colors.white24 : Colors.white10,
        filled: true,
        disabledBorder: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(),
        focusedErrorBorder: _border(),
        errorBorder: _border(),
      ),
    );
  }

  OutlineInputBorder _border() {
    return const OutlineInputBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    );
  }
}
