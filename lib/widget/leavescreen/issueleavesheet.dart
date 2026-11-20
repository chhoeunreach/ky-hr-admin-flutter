import 'package:cnattendance/model/leave.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart' as picker;
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:provider/provider.dart';

class IssueLeaveSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => IssueLeaveSheetState();
}

class IssueLeaveSheetState extends State<IssueLeaveSheet> {
  Leave? selectedValue;

  bool isLoading = false;

  TextEditingController endDate = TextEditingController();
  TextEditingController reason = TextEditingController();
  TextEditingController startDate = TextEditingController();

  DateTime startNepaliDate = DateTime.now();
  DateTime endNepaliDate = DateTime.now();

  void issueLeave() async {
    if (endDate.text.isNotEmpty &&
        startDate.text.isNotEmpty &&
        reason.text.isNotEmpty &&
        selectedValue != null) {
      try {
        final isAd =
            await Provider.of<LeaveProvider>(context, listen: false).isAd();
        showLoader();
        isLoading = true;
        final response =
            await Provider.of<LeaveProvider>(context, listen: false).issueLeave(
                isAd
                    ? startDate.text
                    : DateFormat('yyyy-MM-dd hh:mm:ss').format(startNepaliDate),
                isAd
                    ? startDate.text
                    : DateFormat('yyyy-MM-dd hh:mm:ss').format(startNepaliDate),
                isAd
                    ? endDate.text
                    : DateFormat('yyyy-MM-dd hh:mm:ss').format(endNepaliDate),
                reason.text,
                selectedValue!.id,
                0);

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
      NavigationService()
          .showSnackBar("Leave Status", "Field must not be empty");
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
          status: "Requesting...", maskType: EasyLoadingMaskType.black);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LeaveProvider>(context);
    final enterprise = EnterpriseTheme.of(context);
    return PopScope(
      canPop: !isLoading,
      child: Container(
        decoration: BoxDecoration(
          color: enterprise.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: enterprise.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apply Leave',
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
              Container(
                  width: MediaQuery.of(context).size.width,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton2(
                      isExpanded: true,
                      hint: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select Leave Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: enterprise.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      items: provider.leaveList
                          .where((element) => element.status)
                          .map((item) => DropdownMenuItem<Leave>(
                                value: item,
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: enterprise.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      value: selectedValue,
                      onChanged: (value) {
                        selectedValue = value;
                        if (selectedValue != null) {
                          setState(() {});
                        }
                      },
                      iconStyleData: IconStyleData(
                        icon: Icon(
                          Icons.arrow_forward_ios_outlined,
                          color: enterprise.mutedText,
                        ),
                        iconSize: 14,
                        iconEnabledColor: enterprise.mutedText,
                        iconDisabledColor: Colors.grey,
                      ),
                      buttonStyleData: ButtonStyleData(
                        height: 50,
                        width: 160,
                        padding: const EdgeInsets.only(left: 14, right: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: enterprise.isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          border: Border.all(color: enterprise.cardBorder),
                        ),
                        elevation: 0,
                      ),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 200,
                        padding: null,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: enterprise.cardBackground,
                          border: Border.all(color: enterprise.cardBorder),
                        ),
                        elevation: 8,
                      ),
                      menuItemStyleData: const MenuItemStyleData(
                        height: 40,
                        padding: EdgeInsets.only(left: 14, right: 14),
                      ),
                    ),
                  )),
              gaps(10),
              TextField(
                controller: startDate,
                style: TextStyle(color: enterprise.text),
                cursorColor: enterprise.accent,
                decoration: InputDecoration(
                  hintText: 'Select Start Date',
                  hintStyle: TextStyle(color: enterprise.mutedText),
                  prefixIcon:
                      Icon(Icons.calendar_month, color: enterprise.accent),
                  labelStyle: TextStyle(color: enterprise.text),
                  fillColor: enterprise.isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.accent)),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
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
                      String formattedDate =
                          NepaliDateFormat('yyyy-MM-dd hh:mm:ss')
                              .format((pickedDate as NepaliDateTime));
                      startNepaliDate = (pickedDate).toDateTime();
                      startDate.text = formattedDate;
                    } else {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd hh:mm:ss').format(pickedDate);
                      setState(() {
                        startDate.text =
                            formattedDate; //set output date to TextField value.
                      });
                    }

                    if (endDate.text.isNotEmpty && startDate.text.isNotEmpty) {
                      setState(() {});
                    }
                  } else {}
                },
              ),
              gaps(10),
              TextField(
                controller: endDate,
                style: TextStyle(color: enterprise.text),
                cursorColor: enterprise.accent,
                decoration: InputDecoration(
                  hintText: 'Select End Date',
                  hintStyle: TextStyle(color: enterprise.mutedText),
                  prefixIcon:
                      Icon(Icons.calendar_month, color: enterprise.accent),
                  labelStyle: TextStyle(color: enterprise.text),
                  fillColor: enterprise.isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.accent)),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
                ),
                readOnly: true,
                //set it true, so that user will not able to edit text
                onTap: () async {
                  final pickedDate = await provider.isAd()
                      ? await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateFormat("yyyy-MM-dd hh:mm:ss")
                                  .tryParse(startDate.text) ??
                              DateTime(1950),
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
                      String formattedDate =
                          NepaliDateFormat('yyyy-MM-dd hh:mm:ss')
                              .format((pickedDate as NepaliDateTime));
                      endNepaliDate = (pickedDate).toDateTime();
                      endDate.text = formattedDate;
                    } else {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd hh:mm:ss').format(pickedDate);
                      setState(() {
                        endDate.text =
                            formattedDate; //set output date to TextField value.
                      });
                    }

                    if (endDate.text.isNotEmpty && startDate.text.isNotEmpty) {
                      setState(() {});
                    }
                  } else {}
                },
              ),
              if (endDate.text.isNotEmpty && startDate.text.isNotEmpty)
                gaps(10),
              if (endDate.text.isNotEmpty && startDate.text.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Leave Days: ",
                        style: TextStyle(color: enterprise.text),
                      ),
                      Text(
                        (DateFormat("yyyy-MM-dd hh:mm:ss")
                                    .parse(endDate.text)
                                    .difference(
                                        DateFormat("yyyy-MM-dd hh:mm:ss")
                                            .parse(startDate.text))
                                    .inDays +
                                1)
                            .toString(),
                        style: TextStyle(
                            color: enterprise.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              gaps(10),
              TextField(
                textAlignVertical: TextAlignVertical.top,
                controller: reason,
                maxLines: 3,
                onTapOutside: (event) {
                  FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                style: TextStyle(color: enterprise.text),
                cursorColor: enterprise.accent,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Reason',
                  hintStyle: TextStyle(color: enterprise.mutedText),
                  prefixIcon: Icon(Icons.edit_note, color: enterprise.accent),
                  labelStyle: TextStyle(color: enterprise.text),
                  fillColor: enterprise.isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: enterprise.accent)),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red)),
                ),
              ),
              gaps(20),
              Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.only(left: 5),
                child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: enterprise.primary,
                      padding: EdgeInsets.zero,
                      shape: ButtonBorder(),
                    ),
                    onPressed: () {
                      issueLeave();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'Request Leave',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
