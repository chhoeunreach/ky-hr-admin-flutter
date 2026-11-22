import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/leavescreen/earlyleavesheet.dart';
import 'package:cnattendance/widget/leavescreen/issueleavesheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class LeaveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final enterprise = EnterpriseTheme.of(context);
    return Row(
      children: [
        if (provider.features['mobile.function.Leave.saveLeaveRequestDetail'] ==
            '1')
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
                onPressed: () {
                  showModalBottomSheet(
                      elevation: 0,
                      context: context,
                      useRootNavigator: true,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20))),
                      builder: (context) {
                        return Padding(
                          padding: MediaQuery.of(context).viewInsets,
                          child: IssueLeaveSheet(),
                        );
                      });
                },
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    translate('leave_screen.issue_leave'),
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w800),
                  ),
                )),
          )),
        if (provider.features['mobile.function.Leave.saveLeaveRequestDetail'] ==
                '1' &&
            provider.features['mobile.function.Leave.saveTimeLeaveRequest'] ==
                '1')
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: enterprise.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
                onPressed: () {
                  if (provider.attendanceList['check-in'] != '-' &&
                      provider.attendanceList['check-out'] == '-') {
                    showModalBottomSheet(
                        elevation: 0,
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20))),
                        builder: (context) {
                          return Padding(
                            padding: MediaQuery.of(context).viewInsets,
                            child: EarlyLeaveSheet(true),
                          );
                        });
                  } else {
                    showModalBottomSheet(
                        elevation: 0,
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20))),
                        builder: (context) {
                          return Padding(
                            padding: MediaQuery.of(context).viewInsets,
                            child: EarlyLeaveSheet(false),
                          );
                        });
                  }
                },
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    translate('leave_screen.time_leave'),
                    style: TextStyle(color: AppColors.white),
                  ),
                )),
          )),
      ],
    );
  }
}
