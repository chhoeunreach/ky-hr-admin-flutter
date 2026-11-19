import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';

class ToggleLeaveTime extends StatelessWidget {
  @override
  Widget build(BuildContext context, [bool mounted = true]) {
    final provider = Provider.of<LeaveProvider>(context);
    final enterprise = EnterpriseTheme.of(context);

    void onToggleChanged() async {
      final detailResponse = await provider.getLeaveTypeDetail();

      if (!mounted) return;
      if (detailResponse.statusCode == 200) {
        if (detailResponse.data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              padding: EdgeInsets.all(20), content: Text('No data found')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            padding: const EdgeInsets.all(20),
            content: Text(detailResponse.message)));
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: enterprise.isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9),
        border: Border.all(color: enterprise.cardBorder),
      ),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        margin: EdgeInsets.zero,
        child: ToggleSwitch(
          activeBgColor: [enterprise.accent],
          activeFgColor: Colors.white,
          inactiveFgColor: enterprise.text,
          inactiveBgColor: Colors.transparent,
          minWidth: 88,
          minHeight: 34,
          fontSize: 12.0,
          initialLabelIndex: provider.selectedMonth == 0 ? 1 : 0,
          totalSwitches: 2,
          onToggle: (index) {
            if (index == 0) {
              final DateTime now = DateTime.now();
              provider.setMonth(now.month);
              onToggleChanged();
            } else {
              provider.setMonth(0);
              onToggleChanged();
            }
          },
          labels: [
            translate('leave_screen.this_month'),
            translate('leave_screen.this_year')
          ],
        ),
      ),
    );
  }
}
