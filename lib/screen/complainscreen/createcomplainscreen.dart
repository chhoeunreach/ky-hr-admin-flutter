import 'package:cnattendance/data/source/network/model/complaintresponse/departmentresponse.dart';
import 'package:cnattendance/screen/complainscreen/complaincontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class CreateComplainScreen extends StatelessWidget {
  final subject = TextEditingController();
  final message = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final ComplainController model = Get.find();
    model.getDepartments();

    Future<void> onComplainSubmitted() async {
      if (!_formKey.currentState!.validate()) {
        return;
      }

      if (model.selectedEmployees.isEmpty) {
        showToast("Please select an employee");
        return;
      }

      try {
        EasyLoading.show(
            status: translate('loader.loading'),
            maskType: EasyLoadingMaskType.black);
        final (status, body) =
            await model.applyComplaint(subject.text, message.text);
        EasyLoading.dismiss(animation: true);
        if (status) {
          model.clearAll();
          Get.back();
        }
        showToast(body);
      } catch (e) {
        EasyLoading.dismiss(animation: true);
        showToast(e.toString());
      }
    }

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
              "Create Complaint",
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
                    onComplainSubmitted();
                  },
                  child: Text(
                    translate('create_salary_screen.submit'),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  )),
            ),
          ),
          body: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Department",
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      width: double.infinity,
                      child: DropdownButtonHideUnderline(
                        child: Obx(
                          () => DropdownButton2(
                            isExpanded: true,
                            hint: Text(
                              translate('support_screen.select_department_type'),
                              style: TextStyle(
                                fontSize: 14,
                                color: enterprise.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: model.departments.map((DepartmentApi e) {
                              return DropdownMenuItem(
                                value: e.name,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    e.name,
                                    style: TextStyle(
                                        color: enterprise.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }).toList(),
                            value: null,
                            onChanged: (value) {
                              final result = model.departments
                                  .where((dep) => dep.name == value)
                                  .toList();

                              if (result.isNotEmpty) {
                                model.addDepatment(result[0]);
                              }
                            },
                            iconStyleData: IconStyleData(
                              icon: const Icon(
                                Icons.arrow_forward_ios_outlined,
                              ),
                              iconSize: 14,
                              iconEnabledColor: enterprise.primary,
                              iconDisabledColor: enterprise.mutedText,
                            ),
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              width: 160,
                              padding:
                                  const EdgeInsets.only(left: 14, right: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: inputFill,
                                border: Border.all(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              elevation: 0,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 200,
                              padding: null,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: enterprise.isDark
                                    ? const Color(0xFF1E293B)
                                    : AppColors.white,
                                border: Border.all(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              elevation: 8,
                            ),
                            menuItemStyleData: const MenuItemStyleData(
                              height: 40,
                              padding:
                                  EdgeInsets.only(left: 14, right: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Obx(
                      () => model.selectedDepartments.isNotEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Selected Department",
                                style: TextStyle(
                                  color: enterprise.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Obx(
                      () => Wrap(
                        spacing: 10,
                        children: model.selectedDepartments.map(
                          (element) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              color: inputFill,
                              child: GestureDetector(
                                onTap: () {
                                  model.removeDepartment(element);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        element.name,
                                        style:
                                            TextStyle(color: enterprise.text, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: enterprise.primary,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Employee",
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      width: double.infinity,
                      child: DropdownButtonHideUnderline(
                        child: Obx(
                          () => DropdownButton2(
                            isExpanded: true,
                            hint: Text(
                              "Select Employee",
                              style: TextStyle(
                                fontSize: 14,
                                color: enterprise.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: model.getEmployees().map((Employee e) {
                              return DropdownMenuItem(
                                value: e,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                    e.name,
                                    style: TextStyle(
                                        color: enterprise.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }).toList(),
                            value: null,
                            onChanged: (value) {
                              if (value != null) model.addEmployee(value);
                            },
                            iconStyleData: IconStyleData(
                              icon: const Icon(
                                Icons.arrow_forward_ios_outlined,
                              ),
                              iconSize: 14,
                              iconEnabledColor: enterprise.primary,
                              iconDisabledColor: enterprise.mutedText,
                            ),
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              width: 160,
                              padding:
                                  const EdgeInsets.only(left: 14, right: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: inputFill,
                                border: Border.all(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              elevation: 0,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 200,
                              padding: null,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: enterprise.isDark
                                    ? const Color(0xFF1E293B)
                                    : AppColors.white,
                                border: Border.all(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              elevation: 8,
                            ),
                            menuItemStyleData: const MenuItemStyleData(
                              height: 40,
                              padding:
                                  EdgeInsets.only(left: 14, right: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Obx(
                      () => model.selectedEmployees.isNotEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "Selected Employee",
                                style: TextStyle(
                                  color: enterprise.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Obx(
                      () => Wrap(
                        spacing: 10,
                        children: model.selectedEmployees.map(
                          (element) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: enterprise.isDark
                                      ? enterprise.cardBorder
                                      : AppColors.customFFB8DEFF,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              color: inputFill,
                              child: GestureDetector(
                                onTap: () {
                                  model.removeEmployee(element);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        element.name,
                                        style:
                                            TextStyle(color: enterprise.text, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: enterprise.primary,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Subject",
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: subject,
                      textAlignVertical: TextAlignVertical.top,
                      validator: (value) {
                        if (value!.trim().isEmpty) {
                          return "Subject can't be empty";
                        }

                        return null;
                      },
                      maxLines: 1,
                      onTapOutside: (event) {
                        final FocusScopeNode currentFocus =
                            FocusScope.of(context);
                        if (!currentFocus.hasPrimaryFocus &&
                            currentFocus.focusedChild != null) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      },
                      style: TextStyle(color: enterprise.text, fontSize: 14),
                      cursorColor: enterprise.primary,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Subject',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Message",
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: message,
                      textAlignVertical: TextAlignVertical.top,
                      maxLines: 5,
                      validator: (value) {
                        if (value!.trim().isEmpty) {
                          return "Message can't be empty";
                        }

                        return null;
                      },
                      onTapOutside: (event) {
                        final FocusScopeNode currentFocus =
                            FocusScope.of(context);
                        if (!currentFocus.hasPrimaryFocus &&
                            currentFocus.focusedChild != null) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      },
                      style: TextStyle(color: enterprise.text, fontSize: 14),
                      cursorColor: enterprise.primary,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message',
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
          )),
    );
  }
}
