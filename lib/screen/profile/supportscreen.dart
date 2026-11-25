import 'package:cnattendance/model/department.dart';
import 'package:cnattendance/provider/supportcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(SupportController());
    final enterprise = EnterpriseTheme.of(context);
    final inputFill = enterprise.isDark ? AppColors.white12 : AppColors.white;
    final inputBorderSide = BorderSide(
      color:
          enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
      width: 1,
    );

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('support_screen.support'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            InkWell(
              onTap: () {
                model.showList();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Icon(Icons.list_alt, color: enterprise.text),
              ),
            )
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Form(
              key: model.form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: enterprise.isDark
                          ? AppColors.white12
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: enterprise.isDark
                            ? enterprise.cardBorder
                            : AppColors.customFFB8DEFF,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(
                              alpha: enterprise.isDark ? 0.12 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.support_agent_rounded,
                            color: enterprise.primary, size: 56),
                        const SizedBox(height: 10),
                        Text(
                          translate('support_screen.help_desk'),
                          style: TextStyle(
                              color: enterprise.text,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          translate('support_screen.contact_us'),
                          style: TextStyle(
                              color: enterprise.mutedText, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          width: double.infinity,
                          child: DropdownButtonHideUnderline(
                            child: Obx(
                              () => DropdownButton2<Department>(
                                isExpanded: true,
                                hint: Text(
                                  translate(
                                      'support_screen.select_department_type'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: enterprise.mutedText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                items: model.departments.map((Department e) {
                                  return DropdownMenuItem<Department>(
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
                                value: model.selected.value.name == ""
                                    ? null
                                    : model.selected.value,
                                onChanged: (value) {
                                  if (value != null) {
                                    model.selected.value = value;
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
                                  padding: const EdgeInsets.only(
                                      left: 14, right: 14),
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
                                  padding: EdgeInsets.only(left: 14, right: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: model.titleController,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.emailAddress,
                          style:
                              TextStyle(color: enterprise.text, fontSize: 14),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return "Field can't be empty";
                            }
                            return null;
                          },
                          cursorColor: enterprise.primary,
                          decoration: InputDecoration(
                            hintText: translate('support_screen.title'),
                            hintStyle: TextStyle(
                                color: enterprise.mutedText, fontSize: 14),
                            labelStyle: TextStyle(color: enterprise.text),
                            fillColor: inputFill,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: inputBorderSide),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: enterprise.primary, width: 1.5)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppColors.red)),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppColors.red)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: model.descriptionController,
                          maxLength: 500,
                          textAlignVertical: TextAlignVertical.top,
                          maxLines: 8,
                          keyboardType: TextInputType.emailAddress,
                          style:
                              TextStyle(color: enterprise.text, fontSize: 14),
                          validator: (value) {
                            if (value!.isEmpty) {
                              return "Field can't be empty";
                            }
                            return null;
                          },
                          cursorColor: enterprise.primary,
                          decoration: InputDecoration(
                            counterStyle:
                                TextStyle(color: enterprise.mutedText),
                            hintText: translate('support_screen.description'),
                            hintStyle: TextStyle(
                                color: enterprise.mutedText, fontSize: 14),
                            labelStyle: TextStyle(color: enterprise.text),
                            fillColor: inputFill,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: inputBorderSide),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: enterprise.primary, width: 1.5)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppColors.red)),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppColors.red)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: enterprise.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                model.onSubmitClicked();
                              },
                              child: Text(
                                translate('support_screen.submit'),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              )),
                        )
                      ],
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
