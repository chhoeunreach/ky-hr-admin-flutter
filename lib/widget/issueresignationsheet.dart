import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart' as picker;
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class IssueResignationSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => IssueResignationSheetState();
}

class IssueResignationSheetState extends State<IssueResignationSheet> {
  bool isLoading = false;

  bool canApply = true;
  String status = "";
  String adminRemark = "";

  TextEditingController reason = TextEditingController();
  TextEditingController startDate = TextEditingController();

  DateTime startNepaliDate = DateTime.now();
  DateTime endNepaliDate = DateTime.now();

  void issueResignation() async {
    if (startDate.text.isNotEmpty && reason.text.isNotEmpty) {
      try {
        final isAd =
            await Provider.of<LeaveProvider>(context, listen: false).isAd();

        final date = isAd
            ? startDate.text
            : DateFormat('yyyy-MM-dd').format(startNepaliDate);

        showLoader();
        isLoading = true;
        final response =
            await Provider.of<LeaveProvider>(context, listen: false)
                .issueResignation(date, reason.text.toString());

        if (!mounted) {
          return;
        }
        dismissLoader();
        Navigator.pop(context);
        isLoading = false;
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(response.message),
            );
          },
        );
      } catch (e) {
        dismissLoader();
        isLoading = false;
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(e.toString()),
            );
          },
        );
      }
    } else {
      NavigationService().showSnackBar(
        translate('resignation.status_title'),
        translate('resignation.field_required'),
      );
    }
  }

  void dismissLoader() {
    setState(() {
      EasyLoading.dismiss(animation: true);
    });
  }

  void showLoader() {
    setState(() {
      EasyLoading.show(
          status: translate('resignation.requesting'),
          maskType: EasyLoadingMaskType.black);
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) async {
        final response =
            await Provider.of<LeaveProvider>(context, listen: false)
                .getResignation();

        if (response.data == null) {
          canApply = true;
          status = "";
          setState(() {});
        } else {
          if (response.data!.status == "rejected") {
            canApply = true;
          } else {
            canApply = false;
          }
          status = response.data!.status;
          adminRemark = response.data?.remark ?? "";
          setState(() {});
        }
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LeaveProvider>(context);
    final enterprise = EnterpriseTheme.of(context);
    final inputFill = enterprise.isDark ? AppColors.white12 : const Color(0xFFF8FAFC);
    final inputBorderSide = BorderSide(
      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
      width: 1,
    );

    return PopScope(
      canPop: !isLoading,
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == "approved" || status == "onReview")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Spacer(),
                    IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: enterprise.text,
                        )),
                  ],
                ),
              if (status != "approved" && status != "onReview")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      translate('resignation.apply'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: enterprise.text,
                      ),
                    ),
                    IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: enterprise.text,
                        )),
                  ],
                ),
              if (status == "rejected" || status.isEmpty)
                TextField(
                  controller: startDate,
                  style: TextStyle(color: enterprise.text, fontSize: 14),
                  cursorColor: enterprise.primary,
                  decoration: InputDecoration(
                    hintText: translate('resignation.select_start_date'),
                    hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.calendar_month, color: enterprise.primary),
                    labelStyle: TextStyle(color: enterprise.text),
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
                  readOnly: true,
                  //set it true, so that user will not able to edit text
                  onTap: () async {
                    final pickedDate = await provider.isAd()
                        ? await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1950),
                            //DateTime.now() - not to allow to choose before today.
                            lastDate: DateTime(2100))
                        : await picker.showMaterialDatePicker(
                            context: context,
                            initialDate: NepaliDateTime.now(),
                            firstDate: NepaliDateTime(2000),
                            lastDate: NepaliDateTime(2090),
                            initialDatePickerMode: DatePickerMode.day,
                          );

                    if (pickedDate != null) {
                      if (!(await provider.isAd())) {
                        final formattedDate = NepaliDateFormat('yyyy-MM-dd')
                            .format((pickedDate as NepaliDateTime));
                        startNepaliDate = (pickedDate).toDateTime();
                        startDate.text = formattedDate;
                      } else {
                        final formattedDate =
                            DateFormat('yyyy-MM-dd').format(pickedDate);
                        setState(() {
                          startDate.text =
                              formattedDate; //set output date to TextField value.
                        });
                      }
                    } else {}
                  },
                ),
              if (status == "rejected" || status.isEmpty) gaps(10),
              if (status == "rejected" || status.isEmpty)
                TextField(
                  textAlignVertical: TextAlignVertical.top,
                  controller: reason,
                  maxLines: 3,
                  onTapOutside: (event) {
                    final currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus &&
                        currentFocus.focusedChild != null) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                  style: TextStyle(color: enterprise.text, fontSize: 14),
                  cursorColor: enterprise.primary,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: translate('resignation.reason'),
                    hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                    prefixIcon: Icon(Icons.edit_note, color: enterprise.primary),
                    labelStyle: TextStyle(color: enterprise.text),
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
              if (status.isNotEmpty && (!canApply || adminRemark.isNotEmpty))
                gaps(10),
              if (status.isNotEmpty && (!canApply || adminRemark.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text(
                    translate('resignation.request_status').replaceAll(
                      '{status}',
                      status.toUpperCase(),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enterprise.text,
                    ),
                  ),
                ),
              if (adminRemark.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 5.0, right: 5, bottom: 10),
                  child: Text(
                    translate('resignation.remark_value')
                        .replaceAll('{remark}', adminRemark),
                    style: TextStyle(
                      fontSize: 14,
                      color: enterprise.mutedText,
                    ),
                  ),
                ),
              gaps(10),
              if (status == "rejected" || status.isEmpty)
                Container(
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.only(left: 5),
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canApply
                            ? enterprise.primary
                            : enterprise.primary.withValues(alpha: .3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: canApply
                          ? () {
                              issueResignation();
                            }
                          : null,
                      child: Text(
                        translate('resignation.request'),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget gaps(double value) {
    return SizedBox(
      height: value,
    );
  }
}
