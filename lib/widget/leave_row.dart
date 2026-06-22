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
      radius: 20,
      padding: EdgeInsets.zero,
      glowOpacity: 0.08,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              name,
              style: TextStyle(
                fontSize: 15,
                color: enterprise.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  used.toString() == "null" ? "0" : used.toString(),
                  style: TextStyle(
                    fontSize: 35,
                    color: enterprise.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Visibility(
                  visible: (allocated == "0") ? false : true,
                  child: Text(
                    '/',
                    style: TextStyle(fontSize: 20, color: enterprise.mutedText),
                  ),
                ),
                Visibility(
                  visible: (allocated == "0") ? false : true,
                  child: Text(
                    allocated.toString(),
                    style: TextStyle(fontSize: 20, color: enterprise.mutedText),
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
