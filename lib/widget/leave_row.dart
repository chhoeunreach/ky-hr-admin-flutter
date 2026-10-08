import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

class LeaveRow extends StatelessWidget {
  final int id;
  final String name;
  final String allocated;
  final String used;

  LeaveRow(this.id, this.name, this.used, this.allocated);

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return EnterpriseGlass(
      radius: 14,
      padding: EdgeInsets.zero,
      glowOpacity: 0.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              name,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                color: enterprise.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  used.toString() == "null" ? "0" : used.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    color: enterprise.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Visibility(
                  visible: (allocated == "0") ? false : true,
                  child: Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 13,
                      color: enterprise.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Visibility(
                  visible: (allocated == "0") ? false : true,
                  child: Text(
                    allocated.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: enterprise.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
