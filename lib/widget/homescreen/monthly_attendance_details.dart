import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

void showMonthlyAttendanceDetails(
    BuildContext context, MonthlyAttendanceSummary? summary) {
  String tr(String key) => translate('home_attendance.$key');
  final lateFormula = tr('late_formula')
      .replaceAll('{total}', '${summary?.totalLateCount ?? '—'}')
      .replaceAll('{excused}', '${summary?.excusedLateCount ?? '—'}')
      .replaceAll('{deductible}', '${summary?.lateCount ?? '—'}');
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = EnterpriseTheme.of(dialogContext);
      return AlertDialog(
        backgroundColor: theme.contentSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
              color: theme.text,
              fontWeight: FontWeight.w800,
            ),
        contentTextStyle:
            Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: theme.mutedText,
                ),
        scrollable: true,
        title: Text(tr('details_title')),
        content: Text(summary == null
            ? tr('unavailable')
            : '${tr('month')}: ${summary.month}\n\n'
                '${tr('total_late')}: ${summary.totalLateCount ?? summary.lateCount}\n'
                '$lateFormula\n${tr('late_formula_explanation')}\n\n'
                '${tr('approved_late')}: ${summary.approvedLateCount ?? '—'}\n'
                '${tr('approved_time_leave')}: ${summary.approvedTimeLeaveCount ?? '—'}\n'
                '${tr('deduction')}: -\$${summary.deduction.toStringAsFixed(2)}\n\n'
                '${tr('bonus')}: \$${summary.bonusTarget.toStringAsFixed(2)} · ${(summary.progress * 100).toStringAsFixed(0)}%\n'
                '${tr('days').replaceAll('{completed}', '${summary.completedDays}').replaceAll('{total}', '${summary.workingDays}')}\n\n'
                '${tr('explanation')}'),
        actions: [
          TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.text),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('close'))),
        ],
      );
    },
  );
}
