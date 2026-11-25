import 'package:cnattendance/provider/advancedetailcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AdvanceDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AdvanceDetailController());
    final enterprise = EnterpriseTheme.of(context);

    Widget buildInfoCard({required String title, required String value, double fontSize = 16}) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: enterprise.isDark ? AppColors.white12 : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.12 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: enterprise.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: enterprise.text,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: RadialDecoration(),
      child: Obx(
        () => SafeArea(
          child: model.isLoading.value
              ? const SizedBox.shrink()
              : Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    iconTheme: IconThemeData(color: enterprise.text),
                    title: Text(
                      translate('advance_detail_screen.advance_detail'),
                      style: TextStyle(
                        color: enterprise.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  bottomNavigationBar: Obx(
                    () {
                      final isPending =
                          model.advanceSalary.value.status.toLowerCase() ==
                              "pending";
                      final showApprovalActions =
                          isPending && model.canApprove.value;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        height: showApprovalActions ? 110 : 60,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 50,
                              child: Row(
                                children: [
                                  Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    color: isPending
                                        ? AppColors.orange
                                        : model.advanceSalary.value.status
                                                    .toLowerCase() ==
                                                "rejected"
                                            ? AppColors.red
                                            : AppColors.green,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0, vertical: 6.0),
                                      child: Text(
                                          model.advanceSalary.value.status
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          )),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${translate('advance_detail_screen.total')} ",
                                    style: TextStyle(
                                        color: enterprise.mutedText, fontSize: 15),
                                  ),
                                  Text(
                                      "${translate('advance_detail_screen.rs')} ${model.advanceSalary.value.released_amount}",
                                      style: TextStyle(
                                        color: enterprise.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                            ),
                            if (showApprovalActions) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: model.approveAdvanceSalary,
                                      child: const Text("Approve", style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: model.rejectAdvanceSalary,
                                      child: const Text("Reject", style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  body: Obx(
                    () => SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Requested Date",
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          model
                                              .advanceSalary.value.requested_date,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 24,
                                    child: VerticalDivider(
                                      width: 1,
                                      thickness: 1,
                                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Released Date",
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          model.advanceSalary.value.released_date,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            buildInfoCard(
                              title: translate('advance_detail_screen.requested_amount'),
                              value: model.advanceSalary.value.requested_amount,
                              fontSize: 18,
                            ),
                            buildInfoCard(
                              title: translate('advance_detail_screen.released_amount'),
                              value: model.advanceSalary.value.released_amount,
                              fontSize: 18,
                            ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          translate(
                                              'advance_detail_screen.is_settled'),
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          !model.advanceSalary.value.is_settled
                                              ? translate(
                                                  'advance_detail_screen.no')
                                              : translate(
                                                  'advance_detail_screen.yes'),
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 24,
                                    child: VerticalDivider(
                                      width: 1,
                                      thickness: 1,
                                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          translate(
                                              'advance_detail_screen.verified_by'),
                                          style: TextStyle(
                                              color: enterprise.mutedText,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          parse(model.advanceSalary.value
                                                      .verifiedBy ??
                                                  "N/A")
                                              .body!
                                              .text,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            buildInfoCard(
                              title: translate('advance_detail_screen.reason'),
                              value: parse(model.advanceSalary.value.description ?? "").body!.text,
                            ),
                            buildInfoCard(
                              title: translate('advance_detail_screen.remarks'),
                              value: parse(model.advanceSalary.value.remark ?? "N/A").body!.text,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
