import 'package:cnattendance/data/source/network/model/complaintresponse/complaintresponse.dart';
import 'package:cnattendance/screen/complainscreen/complaincontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ComplaintBottomSheet extends StatefulWidget {
  final Complaint complaint;

  ComplaintBottomSheet(this.complaint);

  @override
  State<StatefulWidget> createState() => ComplaintBottomSheetState();
}

class ComplaintBottomSheetState extends State<ComplaintBottomSheet> {
  final reason = TextEditingController();

  void dismissLoader() {
    setState(() {
      EasyLoading.dismiss(animation: true);
    });
  }

  void showLoader() {
    setState(() {
      EasyLoading.show(
          status: "Requesting...", maskType: EasyLoadingMaskType.black);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ComplainController model = Get.find();
    final enterprise = EnterpriseTheme.of(context);
    final inputFill = enterprise.isDark ? AppColors.white12 : const Color(0xFFF8FAFC);
    final inputBorderSide = BorderSide(
      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
      width: 1,
    );

    return Container(
      decoration: BoxDecoration(
        color: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: 20,
          right: 20,
          left: 20,
          bottom: (MediaQuery.of(context).viewInsets.bottom) + 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.complaint.subject,
                    style: TextStyle(
                        fontSize: 18,
                        color: enterprise.text,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: enterprise.text, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                widget.complaint.message,
                style: TextStyle(fontSize: 14, color: enterprise.mutedText),
              ),
            ),
            if (widget.complaint.response.isEmpty)
              const SizedBox(height: 10),
            if (widget.complaint.response.isEmpty)
              TextField(
                textAlignVertical: TextAlignVertical.top,
                controller: reason,
                maxLines: 3,
                onTapOutside: (event) {
                  final FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                style: TextStyle(color: enterprise.text, fontSize: 14),
                cursorColor: enterprise.primary,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Write a response...',
                  hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                  fillColor: inputFill,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: inputBorderSide),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: enterprise.primary, width: 1.5)),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red)),
                ),
              ),
            if (widget.complaint.response.isEmpty)
              const SizedBox(height: 12),
            if (widget.complaint.response.isEmpty)
              Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enterprise.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      sendResponse(model);
                    },
                    child: const Text(
                      'Submit Response',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    )),
              ),
            if (widget.complaint.response.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: enterprise.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Response:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: enterprise.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.complaint.response,
                        style: TextStyle(fontSize: 14, color: enterprise.text),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> sendResponse(ComplainController model) async {
    if (reason.text.isEmpty) {
      showToast("Response can't be empty");
      return;
    }
    try {
      showLoader();
      final (status, message) =
          await model.saveResponseComplaint(reason.text, widget.complaint.id);
      dismissLoader();
      model.page = 1;
      model.getCompaints();
      showToast(message);
      Get.back();
    } catch (e) {
      dismissLoader();
    }
  }
}
