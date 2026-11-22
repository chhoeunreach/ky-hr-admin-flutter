import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

//ignore: must_be_immutable
class LeavetypeFilter extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LeavetypeFilterState();
}

class LeavetypeFilterState extends State<LeavetypeFilter> {
  int? selectedLeaveTypeId;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LeaveProvider>(context);
    final enterprise = EnterpriseTheme.of(context);

    void onToggleChanged() async {
      try {
        final detailResponse = await provider.getLeaveTypeDetail();

        if (!mounted) return;
        if (detailResponse.data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              behavior: SnackBarBehavior.floating,
              padding: EdgeInsets.all(20),
              content: Text('No data found')));
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            padding: const EdgeInsets.all(20),
            content: Text(error.toString())));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          translate('leave_screen.filter'),
          style: TextStyle(
            color: enterprise.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton2<int>(
            isExpanded: true,
            hint: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    translate('leave_screen.select_leave_type'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enterprise.mutedText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            items: provider.filterLeaveList
                .map((item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: enterprise.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            value: selectedLeaveTypeId,
            onChanged: (value) {
              setState(() {
                selectedLeaveTypeId = value;
              });
              if (value == null) return;
              provider.setType(value);
              onToggleChanged();
            },
            iconStyleData: IconStyleData(
              icon: const Icon(
                Icons.arrow_forward_ios_outlined,
              ),
              iconSize: 13,
              iconEnabledColor: enterprise.mutedText,
              iconDisabledColor: AppColors.grey,
            ),
            buttonStyleData: ButtonStyleData(
              height: 42,
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enterprise.isDark
                    ? AppColors.ink900
                    : AppColors.customFFF8FAFC,
                border: Border.all(color: enterprise.cardBorder),
              ),
              elevation: 0,
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              padding: null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enterprise.isDark
                    ? AppColors.customFF1E293B
                    : AppColors.white,
                border: Border.all(color: enterprise.cardBorder),
              ),
              elevation: 8,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }
}
