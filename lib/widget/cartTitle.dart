import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

class CardTitle extends StatelessWidget {
  const CardTitle(this.title, this.value, {super.key});

  final String value;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final label =
        Text(title, style: TextStyle(color: theme.mutedText, fontSize: 15));
    final content = Text(value,
        style: TextStyle(
            color: theme.text, fontSize: 15, fontWeight: FontWeight.bold));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 3),
                content,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: label),
          const SizedBox(width: 12),
          Expanded(
              flex: 3,
              child: Align(
                  alignment: AlignmentDirectional.centerEnd, child: content)),
        ]);
      }),
    );
  }
}
