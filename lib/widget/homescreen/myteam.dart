import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:cnattendance/screen/profile/teamsheetscreen.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class MyTeam extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final employee =
        Provider.of<DashboardProvider>(context, listen: true).employeeList;
    return Visibility(
      visible: employee.isNotEmpty,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  translate('home_screen.my_team'),
                  style: TextStyle(
                      color: enterprise.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(TeamSheetScreen(), arguments: {
                      "department":
                          context.read<DashboardProvider>().department,
                      "branch": context.read<DashboardProvider>().branch
                    });
                  },
                  child: Text(
                    translate('home_screen.view_all'),
                    style: TextStyle(
                        color: enterprise.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            Container(
              height: 78,
              child: ListView.builder(
                physics: PageScrollPhysics(),
                primary: false,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: employee.length,
                itemBuilder: (context, index) {
                  return teamCard(employee[index], enterprise);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

Widget teamCard(Employee teamList, EnterpriseTheme enterprise) {
  return InkWell(
    onTap: () {
      Get.to(EmployeeDetailScreen(),
          arguments: {"employeeId": teamList.id.toString()});
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: EdgeInsets.zero,
              shape: CircleBorder(),
              elevation: 0,
              color: teamList.onlineStatus == "1"
                  ? AppColors.green
                  : Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(2.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: AppColors.white,
                    child: CachedNetworkImage(
                      imageUrl: teamList.avatar,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 5,
            ),
            Text(
              teamList.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: enterprise.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            )
          ],
        ),
      ),
    ),
  );
}
