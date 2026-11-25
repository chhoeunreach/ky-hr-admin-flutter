import 'package:cnattendance/screen/warningscreen/warningcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/profile/warning_bottom_sheet.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class WarningScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(WarningController());
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
            "Warning",
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Obx(
          () => RefreshIndicator(
            onRefresh: () async {
              model.page = 1;
              await model.getWarnings();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height),
                child: ListView.builder(
                  shrinkWrap: true,
                  primary: true,
                  itemCount: model.warningList.length,
                  itemBuilder: (context, index) {
                    final warning = model.warningList[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: warning.response.isEmpty
                            ? (enterprise.isDark
                                ? AppColors.blue.withValues(alpha: .3)
                                : const Color(0xFFEFF6FF))
                            : (enterprise.isDark
                                ? AppColors.white12
                                : AppColors.white),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          showModalBottomSheet(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20))),
                              builder: (context) {
                                return WarningBottomSheet(warning);
                              });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      warning.warningDate,
                                      style: TextStyle(
                                          color: enterprise.mutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      warning.subject,
                                      style: TextStyle(
                                          color: enterprise.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                warning.response.isNotEmpty
                                    ? Icons.reply
                                    : Icons.warning_amber_rounded,
                                color: warning.response.isNotEmpty
                                    ? enterprise.primary
                                    : AppColors.orange,
                              )
                            ],
                          ),
                        ),
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
