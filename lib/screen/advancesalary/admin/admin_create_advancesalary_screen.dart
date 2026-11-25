import 'package:cnattendance/provider/admin_create_advancesalary_controller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AdminCreateAdvanceSalaryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AdminCreateAdvanceSalaryController());
    final enterprise = EnterpriseTheme.of(context);
    final inputFill = enterprise.isDark ? AppColors.white12 : AppColors.white;
    final inputBorderSide = BorderSide(
      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
      width: 1,
    );

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('more_screen.create_admin_advance_salary'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  model.checkForm();
                },
                child: const Text(
                  "Submit",
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                )),
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
                  TextFormField(
                    controller: model.expensesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: enterprise.text, fontSize: 14),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Field is required";
                      }
                      return null;
                    },
                    cursorColor: enterprise.primary,
                    decoration: InputDecoration(
                      hintText: "Expected amount",
                      hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                      labelStyle: TextStyle(color: enterprise.text),
                      fillColor: inputFill,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: inputBorderSide),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: enterprise.primary, width: 1.5)),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.red)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.red)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: model.descriptionController,
                    maxLines: 5,
                    keyboardType: TextInputType.name,
                    style: TextStyle(color: enterprise.text, fontSize: 14),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Field is required";
                      }
                      return null;
                    },
                    cursorColor: enterprise.primary,
                    decoration: InputDecoration(
                      hintText: "Reason",
                      hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                      labelStyle: TextStyle(color: enterprise.text),
                      fillColor: inputFill,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: inputBorderSide),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: enterprise.primary, width: 1.5)),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.red)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.red)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
