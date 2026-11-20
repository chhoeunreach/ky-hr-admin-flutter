import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

import 'assign_task_screen.dart';
import 'daily_records_api.dart';
import 'record_theme.dart';
import 'employee_records.dart';
import 'my_tasks_screen.dart';
import 'daily_summaries.dart';
import 'work_records_screen.dart';
import 'work_record_editor.dart';
import 'work_labels.dart';

class CreateRecordButton extends StatelessWidget {
  const CreateRecordButton({super.key, this.api});

  final DailyRecordsApi? api;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: 'Create Record',
      backgroundColor: theme.primary,
      foregroundColor: recordContrastColor(theme.primary, theme.text),
      onPressed: () async {
        final service = api ?? DailyRecordsApi();
        final choice = await showModalBottomSheet<String>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 560),
          backgroundColor: Colors.transparent,
          elevation: 0,
          builder: (_) => _QuickCreate(api: service),
        );
        if (choice == null || !context.mounted) return;
        final screen = switch (choice) {
          'tasks' => MyTasksScreen(api: service),
          'records' => MyDailyRecordsScreen(api: service),
          'assign' => AssignEmployeeTaskScreen(api: service),
          'work-records' => WorkRecordsScreen(api: service),
          'activity' => WorkRecordEditor(api: service, kind: 'activity'),
          'work-incident' => WorkRecordEditor(api: service, kind: 'incident'),
          'work-note' => WorkRecordEditor(api: service, kind: 'note'),
          'summary' => DailySummaryEditor(api: service, date: workToday()),
          'submissions' => DailySummariesScreen(api: service),
          'review' => DailySummariesScreen(api: service, manager: true),
          _ => NewDailyRecordScreen(api: service, kind: choice),
        };
        final saved = await Navigator.of(context, rootNavigator: true)
            .push<bool>(recordRoute(builder: (_) => screen));
        if (saved == true && context.mounted) {
          final message = switch (choice) {
            'assign' => 'Task assigned.',
            'report' => 'Daily report submitted.',
            _ => 'Record saved.',
          };
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(workText(context, message))));
        }
      },
      child: const Icon(Icons.add),
    );
  }
}

/// Positions the button over More even when the active theme reorders tabs.
class AboveMoreLocation extends FloatingActionButtonLocation {
  const AboveMoreLocation({required this.slot, required this.slots});

  final int slot;
  final int slots;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final padding = geometry.minViewPadding;
    final available =
        geometry.scaffoldSize.width - padding.left - padding.right - 20;
    final center = padding.left + 10 + available * (slot + .5) / slots;
    final x = geometry.textDirection == TextDirection.rtl
        ? padding.left + geometry.scaffoldSize.width - padding.right - center
        : center;
    return Offset(x - geometry.floatingActionButtonSize.width / 2,
        geometry.contentBottom - geometry.floatingActionButtonSize.height - 8);
  }
}

class _QuickCreate extends StatefulWidget {
  const _QuickCreate({required this.api});

  final DailyRecordsApi api;

  @override
  State<_QuickCreate> createState() => _QuickCreateState();
}

class _QuickCreateState extends State<_QuickCreate> {
  late Future<RecordData> _access = _capabilities();
  bool _full = false;

  Future<RecordData> _capabilities() async {
    final access = await widget.api.get('capabilities');
    if (mounted) setState(() => _full = recordFlag(access['work_records']));
    return access;
  }

  static const _workActions = [
    ('activity', Icons.work_outline, 'Daily Activity'),
    ('work-incident', Icons.report_problem_outlined, 'Incident Report'),
    ('todo', Icons.task_alt_outlined, 'To-do / Task'),
    ('work-note', Icons.sticky_note_2_outlined, 'Personal Note'),
  ];

  static const _recordActions = [
    ('note', Icons.sticky_note_2_outlined, 'New note'),
    ('todo', Icons.task_alt_outlined, 'New to-do'),
    ('incident', Icons.report_problem_outlined, 'Record incident'),
    ('report', Icons.description_outlined, 'Submit daily report'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final surface = theme.contentSurface;
    final foreground = recordContrastColor(surface, theme.text);
    final muted =
        recordContrastColor(surface, Color.lerp(foreground, surface, .28)!);
    final text = Theme.of(context).textTheme;
    final outline = foreground.withValues(alpha: .14);
    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: .32),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(workText(context, 'Quick Create'),
                          style: text.headlineSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    color: muted,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Divider(color: outline, height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          final twoColumns =
                              constraints.maxWidth >= 272 * scale;
                          final actions = [
                            for (final (value, icon, label)
                                in (_full ? _workActions : _recordActions))
                              _action(context, theme, value, icon, label,
                                  stacked: twoColumns),
                          ];
                          return Column(
                            children: [
                              if (twoColumns)
                                for (var i = 0; i < actions.length; i += 2) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: actions[i]),
                                        const SizedBox(width: 10),
                                        Expanded(child: actions[i + 1]),
                                      ],
                                    ),
                                  ),
                                ]
                              else
                                for (final (i, action) in actions.indexed) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  action,
                                ],
                            ],
                          );
                        },
                      ),
                      FutureBuilder<RecordData>(
                        future: _access,
                        builder: (context, snapshot) {
                          final permissions = snapshot.data ?? const {};
                          if (recordFlag(permissions['assign_tasks']) ||
                              recordFlag(permissions['review_reports'])) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(children: [
                                if (recordFlag(permissions['assign_tasks']))
                                  _action(
                                      context,
                                      theme,
                                      'assign',
                                      Icons.assignment_ind_outlined,
                                      'Assign Employee Task',
                                      emphasis: true),
                                if (recordFlag(
                                    permissions['review_reports'])) ...[
                                  const SizedBox(height: 8),
                                  _action(
                                      context,
                                      theme,
                                      'review',
                                      Icons.fact_check_outlined,
                                      'Review Reports',
                                      emphasis: true),
                                ],
                              ]),
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color:
                                    recordContrastColor(surface, theme.accent),
                                backgroundColor: outline,
                                semanticsLabel: workText(
                                    context, 'Checking assignment access'),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                      workText(context,
                                          'Could not check assignment access'),
                                      style: text.bodyMedium
                                          ?.copyWith(color: foreground)),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: recordContrastColor(
                                            surface, theme.primary)),
                                    onPressed: () {
                                      final access = _capabilities();
                                      setState(() {
                                        _access = access;
                                      });
                                    },
                                    child: Text(workText(context, 'Retry')),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 8),
                        child: Semantics(
                          header: true,
                          child: Text(workText(context, 'Your work'),
                              style: text.titleSmall?.copyWith(
                                  color: muted, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      _action(context, theme, 'tasks',
                          Icons.assignment_outlined, 'My Tasks'),
                      const SizedBox(height: 8),
                      _action(
                          context,
                          theme,
                          _full ? 'work-records' : 'records',
                          Icons.folder_open_outlined,
                          _full ? 'My Records' : 'My Daily Records'),
                      if (_full) ...[
                        const SizedBox(height: 8),
                        _action(context, theme, 'summary',
                            Icons.summarize_outlined, 'Daily Summary'),
                        const SizedBox(height: 8),
                        _action(context, theme, 'submissions',
                            Icons.history_outlined, 'My Submitted Reports'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, EnterpriseTheme theme, String value,
      IconData icon, String label,
      {bool stacked = false, bool emphasis = false}) {
    final surface = theme.contentSurface;
    final fill = Color.lerp(surface, theme.accent, emphasis ? .17 : .05)!;
    final iconFill = Color.lerp(fill, theme.accent, .16)!;
    final foreground = recordContrastColor(fill, theme.text);
    final accent = theme.isDark ? theme.accent : theme.primary;
    final text = Text(workText(context, label),
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700));
    final marker = DecoratedBox(
      decoration: BoxDecoration(
        color: iconFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child:
            Icon(icon, size: 20, color: recordContrastColor(iconFill, accent)),
      ),
    );
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: emphasis
              ? Color.lerp(fill, accent, .55)!
              : foreground.withValues(alpha: .16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => Navigator.pop(context, value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [marker, const SizedBox(height: 8), text],
                  )
                : Row(children: [
                    marker,
                    const SizedBox(width: 12),
                    Expanded(child: text),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: foreground),
                  ]),
          ),
        ),
      ),
    );
  }
}
