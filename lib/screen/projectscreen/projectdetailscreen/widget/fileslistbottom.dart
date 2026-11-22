import 'package:cnattendance/screen/projectscreen/projectdetailscreen/projectdetailcontroller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../model/attachment.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class FilesListBottom extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ProjectDetailController model = Get.find();
    final attachments = <Attachment>[];

    for (var attachment in model.project.value.attachment) {
      if (attachment.type == "file") {
        attachments.add(attachment);
      }
    }
    return Container(
        padding: EdgeInsets.all(5),
        child: ListView.builder(
          itemCount: attachments.length,
          primary: false,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            return Card(
                elevation: 0,
                color: AppColors.white12,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          attachment.url,
                          style: TextStyle(color: AppColors.white),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          model.launchUrls(attachment.url);
                        },
                        child: Icon(
                          Icons.download,
                          color: AppColors.white,
                        ),
                      )
                    ],
                  ),
                ));
          },
        ));
  }
}
