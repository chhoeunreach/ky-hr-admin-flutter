import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/awards/awarddetailsscreen.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class RecentAward extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final award = context.watch<DashboardProvider>().award;
    return Visibility(
      visible: award != null ? true : false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  translate('home_screen.recent_award'),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(AwardsScreen());
                  },
                  child: Text(
                    translate('home_screen.show_all'),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            award != null
                ? GestureDetector(
                    onTap: () {
                      Get.to(AwardDetailScreen(), arguments: {"award": award});
                    },
                    child: Card(
                      shape: ButtonBorder(),
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: Colors.white12,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 30,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8),
                          child: Row(
                            children: [
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    award.award_name,
                                    maxLines: 2,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    award.employee_name,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                              Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white,
                                      width:
                                          1.5), // Change color and width as needed
                                ),
                                padding: EdgeInsets.all(
                                    3), // Adjust padding if needed
                                child: ClipOval(
                                  child: Image.network(
                                    award.image,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox.shrink()
          ],
        ),
      ),
    );
  }
}
