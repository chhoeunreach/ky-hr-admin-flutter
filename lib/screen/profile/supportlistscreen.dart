import 'package:cnattendance/provider/supportlistcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class SupportListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(SupportListController());
    final enterprise = EnterpriseTheme.of(context);

    Widget filterChip(String key, String label) {
      final isSelected = model.selected.value == key;
      return GestureDetector(
        onTap: () {
          model.selected.value = key;
          model.filterList();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? enterprise.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : enterprise.mutedText,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('support_list_screen.my_tickets'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Obx(
          () => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: enterprise.isDark ? AppColors.white12 : AppColors.white,
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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          filterChip("All", translate('support_list_screen.all')),
                          const SizedBox(width: 4),
                          filterChip("Pending", translate('support_list_screen.pending')),
                          const SizedBox(width: 4),
                          filterChip("In Progress", translate('support_list_screen.in_progress')),
                          const SizedBox(width: 4),
                          filterChip("Solved", translate('support_list_screen.solved')),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: model.filteredList.length,
                      itemBuilder: (context, index) {
                        final support = model.filteredList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: enterprise.isDark ? AppColors.white12 : AppColors.white,
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
                              model.onSupportClicked(support);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: enterprise.primary.withValues(alpha: enterprise.isDark ? 0.25 : 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: enterprise.primary.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          support.day,
                                          style: TextStyle(
                                              color: enterprise.primary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          support.month,
                                          style: TextStyle(
                                              color: enterprise.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          support.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: enterprise.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    translate('support_list_screen.issue_to'),
                                                    style: TextStyle(
                                                        color: enterprise.mutedText,
                                                        fontSize: 11),
                                                  ),
                                                  Text(
                                                    support.requested_department,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color: enterprise.text,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              height: 20,
                                              child: VerticalDivider(
                                                thickness: 1,
                                                width: 16,
                                                color: enterprise.isDark
                                                    ? enterprise.cardBorder
                                                    : AppColors.customFFB8DEFF,
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "Status",
                                                    style: TextStyle(
                                                        color: enterprise.mutedText,
                                                        fontSize: 11),
                                                  ),
                                                  Text(
                                                    support.status,
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: support.status == "Pending"
                                                            ? AppColors.deepOrange
                                                            : support.status == "In Progress"
                                                                ? AppColors.orangeAccent
                                                                : AppColors.green,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
