import 'package:cnattendance/model/month.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class AttendanceToggle extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AttendanceToggleState();
}

class AttendanceToggleState extends State<AttendanceToggle> {
  var initial = true;

  @override
  Widget build(BuildContext context) {
    final provider =
        Provider.of<AttendanceReportProvider>(context, listen: true);
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            translate('attendance_screen.attendance_history'),
            style: TextStyle(
              color: enterprise.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Consumer(
            builder: (context, value, child) {
              return provider.month.isEmpty
                  ? SizedBox.shrink()
                  : DropdownButtonHideUnderline(
                      child: DropdownButton2(
                        isExpanded: true,
                        items: (provider.month)
                            .map((item) => DropdownMenuItem<Month>(
                                  value: item,
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: enterprise.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        value: provider.month[provider.selectedMonth],
                        onChanged: (value) {
                          print((value as Month).index);
                          setState(() {
                            provider.selectedMonth = (value).index;
                            provider.getAttendanceReport();
                          });
                        },
                        iconStyleData: IconStyleData(
                          icon: Icon(
                            Icons.arrow_forward_ios_outlined,
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
                            borderRadius: BorderRadius.circular(18),
                            color: enterprise.surface.withValues(
                              alpha: enterprise.isDark ? 0.78 : 0.94,
                            ),
                            border: Border.all(
                              color: enterprise.primary.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: enterprise.primary.withValues(
                                  alpha: enterprise.isDark ? 0.08 : 0.12,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          elevation: 0,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 200,
                          padding: null,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: enterprise.surface,
                          ),
                          elevation: 8,
                        ),
                        menuItemStyleData: MenuItemStyleData(
                          height: 40,
                          padding: const EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    );
            },
          ),
        ],
      ),
    );
  }
}
