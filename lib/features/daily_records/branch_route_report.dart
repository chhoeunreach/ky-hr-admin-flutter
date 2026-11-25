import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'branch_route_model.dart';
import 'branch_route_storage.dart';
import 'daily_records_api.dart';
import 'work_labels.dart';

enum _ReportPeriod { daily, monthly }

class BranchRouteReportScreen extends StatefulWidget {
  const BranchRouteReportScreen({super.key, required this.api});

  final DailyRecordsApi api;

  @override
  State<BranchRouteReportScreen> createState() =>
      _BranchRouteReportScreenState();
}

class _BranchRouteReportScreenState extends State<BranchRouteReportScreen> {
  final _section = GlobalKey<BranchRouteReportSectionState>();

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.backgroundColor,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          workText(context, 'Branch Route Report'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: theme.text,
          ),
        ),
        backgroundColor: theme.colors.cardColor,
        elevation: 1,
        shape: Border(
          bottom: BorderSide(
            color: theme.accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: workText(context, 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _section.currentState?.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _section.currentState?.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: BranchRouteReportSection(key: _section, api: widget.api),
          ),
        ),
      ),
    );
  }
}

/// Daily / monthly Branch Route report list. Rendered both as a standalone
/// screen and embedded inside the Branch Mission editor.
class BranchRouteReportSection extends StatefulWidget {
  const BranchRouteReportSection({
    super.key,
    required this.api,
    this.embedded = false,
    this.heading = false,
  });

  final DailyRecordsApi api;
  final bool embedded;
  final bool heading;

  @override
  BranchRouteReportSectionState createState() =>
      BranchRouteReportSectionState();
}

class BranchRouteReportSectionState extends State<BranchRouteReportSection> {
  late Future<List<_RouteReportItem>> _items = _load();
  _ReportPeriod _period = _ReportPeriod.daily;
  String? _month;

  EdgeInsets get _sectionPadding => widget.embedded
      ? const EdgeInsets.only(top: 6, bottom: 16)
      : const EdgeInsets.fromLTRB(14, 8, 14, 20);

  EdgeInsets get _controlPadding => widget.embedded
      ? const EdgeInsets.only(top: 8)
      : const EdgeInsets.fromLTRB(14, 12, 14, 4);

  Future<void> refresh() async {
    final future = _load();
    setState(() => _items = future);
    await future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  String _dayTitle(String title, DateTime start) =>
      '$title|${DateFormat('yyyy-MM-dd').format(start)}';

  Future<List<_RouteReportItem>> _load() async {
    final items = <String, _RouteReportItem>{};
    final seenDays = <String>{};
    for (final route in await BranchRouteStorage.getRouteHistory()) {
      if (route.isProcessing) continue;
      final item = _RouteReportItem.fromRoute(route);
      items[item.key] = item;
      seenDays.add(_dayTitle(item.title, item.start));
    }
    try {
      for (var page = 1; page <= 20; page++) {
        final result = await widget.api.get('work-records', {
          'page': '$page',
          'tag': '#branch-route',
        });
        final rows = recordRows(result['data']);
        for (final row in rows) {
          final item = _RouteReportItem.fromServer(row);
          final dayKey = _dayTitle(item.title, item.start);
          if (items.containsKey(item.key) || seenDays.contains(dayKey)) {
            continue;
          }
          items[item.key] = item;
          seenDays.add(dayKey);
        }
        if (result['next_page_url'] == null || rows.isEmpty) break;
      }
    } catch (_) {
      // Locally stored missions stay available when the server list fails.
    }
    final list = items.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 នាទី';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0 ? '$hours ម៉ោង $rest នាទី' : '$rest នាទី';
  }

  String _statusText(String status) => switch (status) {
        'completed' => 'Completed',
        'processing' => 'In progress',
        'cancelled' => 'Cancelled',
        _ => recordLabel(status),
      };

  Map<DateTime, List<_RouteReportItem>> _groupByDay(
      List<_RouteReportItem> items) {
    final groups = <DateTime, List<_RouteReportItem>>{};
    for (final item in items) {
      final day = DateTime(item.start.year, item.start.month, item.start.day);
      (groups[day] ??= []).add(item);
    }
    return groups;
  }

  List<Widget> _daySections(
    EnterpriseTheme theme,
    Map<DateTime, List<_RouteReportItem>> groups,
  ) {
    final dates = MaterialLocalizations.of(context);
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dates.formatFullDate(day),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                  ),
                ),
              ),
              Text(
                '${groups[day]!.length} ${workText(context, 'Missions')}',
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colors.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              for (final (index, item) in groups[day]!.indexed) ...[
                if (index > 0)
                  Divider(
                      height: 1, color: theme.accent.withValues(alpha: 0.1)),
                _RouteTile(
                  item: item,
                  statusLabel: workText(context, _statusText(item.status)),
                  checkpointsLabel: workText(context, 'Checkpoints'),
                  durationLabel: _formatMinutes(item.totalMinutes),
                  onTap: () => _showDetails(theme, item),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildDaily(EnterpriseTheme theme, List<_RouteReportItem> items) {
    return Padding(
      padding: _sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _daySections(theme, _groupByDay(items)),
      ),
    );
  }

  Widget _buildMonthly(EnterpriseTheme theme, List<_RouteReportItem> items) {
    final dates = MaterialLocalizations.of(context);
    final months = <String, DateTime>{};
    for (final item in items) {
      months.putIfAbsent(
        _monthKey(item.start),
        () => DateTime(item.start.year, item.start.month),
      );
    }
    final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    final selected =
        (_month != null && keys.contains(_month)) ? _month! : keys.first;
    final monthItems =
        items.where((item) => _monthKey(item.start) == selected).toList();
    final minutes =
        monthItems.fold<int>(0, (sum, item) => sum + item.totalMinutes);
    final branches = <String>{};
    for (final item in monthItems) {
      if (item.origin.isNotEmpty) branches.add(item.origin);
      branches.addAll(item.targets);
      for (final checkpoint in item.checkpoints) {
        if (checkpoint.branchName.isNotEmpty) {
          branches.add(checkpoint.branchName);
        }
      }
    }

    return Padding(
      padding: _sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(labelText: workText(context, 'Month')),
            items: [
              for (final key in keys)
                DropdownMenuItem(
                  value: key,
                  child: Text(dates.formatMonthYear(months[key]!),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _month = value),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                _SummaryCell(
                  value: '${monthItems.length}',
                  label: workText(context, 'Missions'),
                  theme: theme,
                ),
                _SummaryCell(
                  value: _formatMinutes(minutes),
                  label: workText(context, 'Total duration'),
                  theme: theme,
                ),
                _SummaryCell(
                  value: '${branches.length}',
                  label: workText(context, 'Branches'),
                  theme: theme,
                ),
              ],
            ),
          ),
          ..._daySections(theme, _groupByDay(monthItems)),
        ],
      ),
    );
  }

  Widget _empty(EnterpriseTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.alt_route_rounded, size: 40, color: theme.mutedText),
          const SizedBox(height: 10),
          Text(
            workText(context, 'No branch route records yet.'),
            style: TextStyle(color: theme.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _failure(EnterpriseTheme theme, Object error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: theme.mutedText),
          const SizedBox(height: 10),
          Text(
            error is DailyRecordsError
                ? error.message
                : workText(context, 'Unable to load branch route report.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: refresh,
            child: Text(workText(context, 'Retry')),
          ),
        ],
      ),
    );
  }

  void _showDetails(EnterpriseTheme theme, _RouteReportItem item) {
    final dates = MaterialLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.text.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.displayTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.text,
              ),
            ),
            if (item.purpose.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.purpose,
                style: TextStyle(fontSize: 13, color: theme.mutedText),
              ),
            ],
            const SizedBox(height: 12),
            _DetailRow(
              theme: theme,
              icon: Icons.schedule,
              label: workText(context, 'Departure Time'),
              value:
                  '${dates.formatShortMonthDay(item.start)}, ${DateFormat('HH:mm').format(item.start)}',
            ),
            if (item.end != null)
              _DetailRow(
                theme: theme,
                icon: Icons.flag_outlined,
                label: workText(context, 'Arrival Time'),
                value: DateFormat('HH:mm').format(item.end!),
              ),
            _DetailRow(
              theme: theme,
              icon: Icons.timelapse,
              label: workText(context, 'Total duration'),
              value: _formatMinutes(item.totalMinutes),
            ),
            _DetailRow(
              theme: theme,
              icon: Icons.alt_route_rounded,
              label: workText(context, 'Mission Type'),
              value: item.missionMode == 'round_trip'
                  ? workText(context, 'Round trip')
                  : item.missionMode == 'multi_branch'
                      ? workText(context, 'Multi-branch')
                      : workText(context, _statusText(item.status)),
            ),
            _DetailRow(
              theme: theme,
              icon: item.synced
                  ? Icons.cloud_done_outlined
                  : Icons.smartphone_rounded,
              label: item.synced
                  ? workText(context, 'Synced to server')
                  : workText(context, 'Saved on this device'),
              value: '',
            ),
            if (item.checkpoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                workText(context, 'Checkpoints'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              for (final checkpoint in item.checkpoints)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    checkpoint.isDeparture
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    size: 18,
                    color: theme.primary,
                  ),
                  title: Text(
                    checkpoint.branchName,
                    style: TextStyle(fontSize: 13.5, color: theme.text),
                  ),
                  subtitle: Text(
                    [
                      DateFormat('HH:mm').format(checkpoint.arrivedAt),
                      if (checkpoint.notes.isNotEmpty) checkpoint.notes,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
                ),
            ],
            if (item.finalSummary?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                workText(context, 'Final summary'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.finalSummary!,
                style: TextStyle(fontSize: 13, color: theme.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return FutureBuilder<List<_RouteReportItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _failure(theme, snapshot.error!);
        }
        final items = snapshot.requireData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.heading)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 17, color: theme.primary),
                    const SizedBox(width: 7),
                    Text(
                      workText(context, 'Branch Route Report'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: _controlPadding,
              child: SegmentedButton<_ReportPeriod>(
                segments: [
                  ButtonSegment(
                    value: _ReportPeriod.daily,
                    icon: const Icon(Icons.today_outlined, size: 18),
                    label: Text(workText(context, 'Daily')),
                  ),
                  ButtonSegment(
                    value: _ReportPeriod.monthly,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(workText(context, 'Monthly')),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (selection) =>
                    setState(() => _period = selection.first),
              ),
            ),
            items.isEmpty
                ? _empty(theme)
                : (_period == _ReportPeriod.daily
                    ? _buildDaily(theme, items)
                    : _buildMonthly(theme, items)),
          ],
        );
      },
    );
  }
}

class _RouteReportItem {
  const _RouteReportItem({
    required this.key,
    required this.title,
    required this.purpose,
    required this.origin,
    required this.targets,
    required this.status,
    required this.start,
    required this.end,
    required this.totalMinutes,
    required this.checkpointsCount,
    required this.synced,
    required this.missionMode,
    required this.finalSummary,
    required this.checkpoints,
  });

  final String key;
  final String title;
  final String purpose;
  final String origin;
  final List<String> targets;
  final String status;
  final DateTime start;
  final DateTime? end;
  final int totalMinutes;
  final int checkpointsCount;
  final bool synced;
  final String missionMode;
  final String? finalSummary;
  final List<RouteCheckpoint> checkpoints;

  String get displayTitle {
    if (origin.isEmpty) return title;
    return targets.isEmpty ? origin : '$origin → ${targets.join(', ')}';
  }

  static String _routeTitle(String origin, List<String> targets) =>
      'បេសកកម្មពី $origin${targets.isNotEmpty ? ' ទៅ ${targets.join(', ')}' : ''}';

  factory _RouteReportItem.fromRoute(BranchRoute route) {
    return _RouteReportItem(
      key: route.id,
      title: _routeTitle(route.originBranch, route.targetBranches),
      purpose: route.purpose,
      origin: route.originBranch,
      targets: route.targetBranches,
      status: route.status,
      start: route.startTime,
      end: route.endTime,
      totalMinutes: route.endTime != null
          ? route.currentDuration.inMinutes
          : route.totalMinutes,
      checkpointsCount: route.checkpoints.length,
      synced: route.isSynced,
      missionMode: route.missionMode,
      finalSummary: route.finalSummary,
      checkpoints: route.checkpoints,
    );
  }

  factory _RouteReportItem.fromServer(RecordData row) {
    final fields = recordMap(row['fields']);
    final origin = (fields['origin_branch'] ?? '').toString();
    final targets = (fields['target_branches'] as List?)
            ?.map((value) => '$value')
            .toList() ??
        const <String>[];
    final start = recordBusinessTime(row['occurred_at'] ?? row['created_at']) ??
        DateTime.now();
    final title = (row['title'] ?? _routeTitle(origin, targets)).toString();
    final routeId = (fields['route_id'] ?? '').toString();
    return _RouteReportItem(
      key: routeId.isNotEmpty ? routeId : 'server:${row['id']}',
      title: title,
      purpose: (fields['purpose'] ?? '').toString(),
      origin: origin,
      targets: targets,
      status: (fields['status'] ?? 'completed').toString(),
      start: start,
      end: _parseClock(fields['arrival_time'], start),
      totalMinutes: int.tryParse('${fields['total_minutes'] ?? ''}') ?? 0,
      checkpointsCount:
          int.tryParse('${fields['checkpoints_count'] ?? ''}') ?? 0,
      synced: true,
      missionMode: (fields['mission_mode'] ?? '').toString(),
      finalSummary: fields['final_summary']?.toString(),
      checkpoints: const [],
    );
  }

  static DateTime? _parseClock(Object? value, DateTime start) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch('${value ?? ''}'.trim());
    if (match == null) return null;
    final end = DateTime(
      start.year,
      start.month,
      start.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
    return end.isAfter(start) ? end : null;
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.item,
    required this.statusLabel,
    required this.checkpointsLabel,
    required this.durationLabel,
    required this.onTap,
  });

  final _RouteReportItem item;
  final String statusLabel;
  final String checkpointsLabel;
  final String durationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final times = item.end != null
        ? '${DateFormat('HH:mm').format(item.start)} – ${DateFormat('HH:mm').format(item.end!)}'
        : DateFormat('HH:mm').format(item.start);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.alt_route_rounded,
                  size: 18, color: theme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      times,
                      durationLabel,
                      if (item.checkpointsCount > 0)
                        '${item.checkpointsCount} $checkpointsLabel',
                      statusLabel,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              item.synced
                  ? Icons.cloud_done_outlined
                  : Icons.smartphone_rounded,
              size: 16,
              color: item.synced ? theme.accent : theme.mutedText,
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: theme.mutedText),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.value,
    required this.label,
    required this.theme,
  });

  final String value;
  final String label;
  final EnterpriseTheme theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: theme.mutedText),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final EnterpriseTheme theme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: theme.mutedText)),
          ),
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
