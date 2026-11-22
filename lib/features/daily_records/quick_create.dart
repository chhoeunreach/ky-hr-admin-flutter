import 'dart:async';
import 'dart:math' as math;

import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/royal_blue_day_theme.dart';
import 'package:flutter/material.dart';

import 'assign_task_screen.dart';
import 'daily_records_api.dart';
import 'record_theme.dart';
import 'employee_records.dart';
import 'my_tasks_screen.dart';
import 'daily_summaries.dart';
import 'work_records_screen.dart';
import 'work_record_editor.dart';
import 'branch_mission_editor.dart';
import 'work_labels.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class CreateRecordButton extends StatefulWidget {
  const CreateRecordButton({super.key, this.api});

  final DailyRecordsApi? api;

  @override
  State<CreateRecordButton> createState() => _CreateRecordButtonState();
}

class _CreateRecordButtonState extends State<CreateRecordButton> {
  bool _sheetOpen = false;

  Future<void> _open() async {
    if (_sheetOpen) return;
    final service = widget.api ?? DailyRecordsApi();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _sheetOpen = true);
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: Colors.transparent,
      elevation: 0,
      sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
      builder: (_) => _QuickCreate(api: service),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (choice == null) return;

    if (choice == 'branch-mission') {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.95,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BranchMissionEditor(api: service, asModal: true),
          ),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workText(context, 'Branch mission record saved.'))),
        );
      }
      return;
    }

    final screen = switch (choice) {
      'tasks' => MyTasksScreen(api: service),
      'records' => MyDailyRecordsScreen(api: service),
      'assign' => AssignEmployeeTaskScreen(api: service),
      'work-records' => WorkRecordsScreen(api: service),
      'branch-mission' => BranchMissionEditor(api: service),
      'activity' => WorkRecordEditor(api: service, kind: 'activity'),
      'work-incident' => WorkRecordEditor(api: service, kind: 'incident'),
      'work-note' => WorkRecordEditor(api: service, kind: 'note'),
      'summary' => DailySummaryEditor(api: service),
      'submissions' => DailySummariesScreen(api: service),
      'review' => DailySummariesScreen(api: service, manager: true),
      _ => NewDailyRecordScreen(api: service, kind: choice),
    };
    final saved = await Navigator.of(context, rootNavigator: true)
        .push<bool>(recordRoute(builder: (_) => screen));
    if (saved == true && mounted) {
      final message = switch (choice) {
        'assign' => 'Task assigned.',
        'report' => 'Daily report submitted.',
        'branch-mission' => 'Branch mission record saved.',
        _ => 'Record saved.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(workText(context, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);
    final button = AnimatedScale(
      scale: _sheetOpen && !reduceMotion ? .94 : 1,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: FloatingActionButton.small(
        heroTag: null,
        tooltip: 'Create Record',
        backgroundColor: theme.primary,
        foregroundColor: theme.isRoyalDay
            ? AppColors.white
            : recordContrastColor(theme.primary, theme.text),
        onPressed: _open,
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          decoration: theme.isRoyalDay
              ? BoxDecoration(
                  gradient: RoyalDayColors.controls,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.accent.withValues(alpha: .85)),
                )
              : null,
          child: AnimatedRotation(
            turns: _sheetOpen ? .125 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (!_sheetOpen && !theme.isRoyalDay)
          Positioned.fill(
            left: -9,
            right: -9,
            top: -9,
            bottom: -9,
            child: IgnorePointer(
              child: reduceMotion
                  ? _SparkleDecoration(
                      animation: const AlwaysStoppedAnimation(0.0),
                      color: theme.accent,
                    )
                  : _QuickCreateSparkles(color: theme.accent),
            ),
          ),
      ],
    );
  }
}

class _QuickCreateSparkles extends StatefulWidget {
  const _QuickCreateSparkles({required this.color});

  final Color color;

  @override
  State<_QuickCreateSparkles> createState() => _QuickCreateSparklesState();
}

class _QuickCreateSparklesState extends State<_QuickCreateSparkles>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..addStatusListener(_onStatus);
  Timer? _timer;
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active == active) return;
    _active = active;
    _timer?.cancel();
    if (active) {
      _schedule(const Duration(milliseconds: 180));
    } else {
      _animation.reset();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (_active && status == AnimationStatus.completed) {
      _schedule(const Duration(milliseconds: 1600));
    }
  }

  void _schedule(Duration delay) {
    _timer = Timer(delay, () => _animation.forward(from: 0));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SparkleDecoration(animation: _animation, color: widget.color);
}

class _SparkleDecoration extends StatelessWidget {
  const _SparkleDecoration({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('quick-create-sparkles'),
          painter: _QuickCreateSparklePainter(animation, color),
        ),
      );
}

class _QuickCreateSparklePainter extends CustomPainter {
  _QuickCreateSparklePainter(this.animation, this.color)
      : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    const sparks = [
      (Offset(.85, .15), 7.6, 0.0),
      (Offset(.13, .35), 5.6, .13),
      (Offset(.88, .76), 4.8, .26),
    ];
    final highlight = Color.lerp(color, AppColors.white, .55)!;
    final pulse = math.sin(progress * math.pi);
    if (pulse > .01) {
      final center = size.center(Offset.zero);
      final radius = size.shortestSide / 2 - 7 + pulse * 3;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = highlight.withValues(alpha: pulse * .68),
      );
    }
    final paint = Paint();
    for (final (position, radius, delay) in sparks) {
      final time = ((progress - delay) / .67).clamp(0.0, 1.0);
      final intensity = math.sin(time * math.pi);
      final center =
          Offset(size.width * position.dx, size.height * position.dy);
      final length = radius * (.67 + .33 * intensity);
      paint.color = color.withValues(alpha: intensity * .32);
      if (intensity > .01) canvas.drawCircle(center, length * 1.1, paint);
      final sparkle = Path();
      for (var point = 0; point < 8; point++) {
        final angle = point * math.pi / 4;
        final distance = point.isEven ? length : length * .26;
        final vertex =
            center + Offset(math.cos(angle), math.sin(angle)) * distance;
        if (point == 0) {
          sparkle.moveTo(vertex.dx, vertex.dy);
        } else {
          sparkle.lineTo(vertex.dx, vertex.dy);
        }
      }
      sparkle.close();
      canvas.drawPath(
        sparkle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.customFF151725.withValues(alpha: .76),
      );
      paint.color = highlight.withValues(alpha: .82 + .18 * intensity);
      canvas.drawPath(sparkle, paint);
    }
  }

  @override
  bool shouldRepaint(_QuickCreateSparklePainter oldDelegate) =>
      color != oldDelegate.color || animation != oldDelegate.animation;
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
  bool _canSubmit = false;

  Future<RecordData> _capabilities() async {
    final access = await widget.api.get('capabilities');
    if (mounted) {
      setState(() {
        _full = recordFlag(access['work_records']);
        _canSubmit = access['can_submit_report'] == true;
      });
    }
    return access;
  }

  static const _workActions = [
    ('branch-mission', Icons.alt_route_rounded, 'Branch Route'),
    ('activity', Icons.work_outline, 'Daily Activity'),
    ('work-incident', Icons.report_problem_outlined, 'Incident Report'),
    ('todo', Icons.task_alt_outlined, 'To-do / Task'),
    ('work-note', Icons.sticky_note_2_outlined, 'Personal Note'),
  ];

  static const _recordActions = [
    ('branch-mission', Icons.alt_route_rounded, 'Branch Route'),
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
                              if (value != 'report' || _canSubmit)
                                _action(context, theme, value, icon, label,
                                    stacked: twoColumns),
                          ];
                          return Column(
                            children: [
                              if (twoColumns)
                                for (var i = 0; i < actions.length; i += 2) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  if (i + 1 < actions.length)
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
                                    )
                                  else
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: SizedBox(
                                        width: (constraints.maxWidth - 10) / 2,
                                        child: actions[i],
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
                        if (_canSubmit) ...[
                          const SizedBox(height: 8),
                          _action(context, theme, 'summary',
                              Icons.summarize_outlined, 'Daily Summary'),
                        ],
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
