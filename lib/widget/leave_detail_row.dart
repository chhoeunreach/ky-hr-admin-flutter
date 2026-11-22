import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/cancel_leave_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class LeaveDetailRow extends StatelessWidget {
  final int id;
  final String leaveTypeId;
  final String name;
  final String from;
  final String to;
  final String status;
  final String authorization;
  final String requestedAt;

  LeaveDetailRow(
      {required this.id,
      required this.leaveTypeId,
      required this.name,
      required this.from,
      required this.to,
      required this.status,
      required this.authorization,
      required this.requestedAt});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    void onLeaveCancelledClicked(int id) {
      showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          builder: (context) {
            return CancelLeaveBottomSheet(id, leaveTypeId);
          });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: enterprise.isDark
              ? AppColors.ink900.withValues(alpha: 0.60)
              : AppColors.customFFF1F5F9,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enterprise.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                textBaseline: TextBaseline.alphabetic,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      "$from - $to",
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    authorization == '' ? "N/A" : "By: $authorization",
                    style: TextStyle(
                      color: enterprise.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      requestedAt,
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (status.toLowerCase() == "pending") {
                        onLeaveCancelledClicked(id);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        color: getStatus(),
                        child: Text(
                          status,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Color getStatus() {
    switch (status) {
      case "Approved":
        return AppColors.green;
      case "Rejected":
        return AppColors.redAccent;
      case "Pending":
        return AppColors.orange;
      case "Cancelled":
        return AppColors.red;
      default:
        return AppColors.orange;
    }
  }
}
