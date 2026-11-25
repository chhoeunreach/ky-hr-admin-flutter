import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/meetingcontroller.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class MeetingDetailScreen extends StatelessWidget {
  static const routeName = '/meetingdetailscreen';

  @override
  Widget build(BuildContext context) {
    final model = Get.put(MeetingController());
    final enterprise = EnterpriseTheme.of(context);
    final args = Get.arguments["id"] as int;
    final item = model.meetingList.where((item) => item.id == args).first;

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('meeting_detail_screen.meeting_detail'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.image != "") ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: item.image,
                      height: 200,
                      fit: BoxFit.cover,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  item.title,
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translate('meeting_list_screen.venue'),
                              style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.venue,
                              style: TextStyle(
                                  color: enterprise.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 26,
                        child: VerticalDivider(
                          width: 16,
                          color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Date",
                              style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.meetingDate,
                              style: TextStyle(
                                  color: enterprise.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 26,
                        child: VerticalDivider(
                          width: 16,
                          color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Time",
                              style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.meetingStartTime,
                              style: TextStyle(
                                  color: enterprise.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.createdBy.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Host',
                          style: TextStyle(
                              color: enterprise.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          item.createdBy,
                          style: TextStyle(
                              color: enterprise.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Description",
                        style: TextStyle(
                            color: enterprise.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.agenda,
                        style: TextStyle(color: enterprise.mutedText, fontSize: 14),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: enterprise.isDark ? AppColors.white12 : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('meeting_detail_screen.participants'),
                        style: TextStyle(
                            color: enterprise.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                          primary: false,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return InkWell(
                              onTap: () {
                                Get.to(EmployeeDetailScreen(), arguments: {
                                  "employeeId": item.participator[index].id
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Text(
                                      "${index + 1}.",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: enterprise.mutedText,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.participator[index].name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: enterprise.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.participator[index].post,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: enterprise.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return Divider(
                              height: 1,
                              color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                            );
                          },
                          itemCount: item.participator.length)
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
