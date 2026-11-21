import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'record_widgets.dart';
import 'work_labels.dart';
import 'work_record_editor.dart';

class MonthlyReportProgressScreen extends StatefulWidget {
  const MonthlyReportProgressScreen({
    super.key,
    required this.api,
    required this.editor,
  });

  final DailyRecordsApi api;
  final Widget Function(String date) editor;

  @override
  State<MonthlyReportProgressScreen> createState() =>
      _MonthlyReportProgressScreenState();
}

class _MonthlyReportProgressScreenState
    extends State<MonthlyReportProgressScreen> {
  late Future<MonthlyReportProgress> _progress = _load();

  Future<MonthlyReportProgress> _load() =>
      MonthlyReportProgress.load(widget.api, DateTime.parse(workToday()));

  Future<void> _refresh() async {
    final progress = _load();
    setState(() {
      _progress = progress;
    });
    // FutureBuilder displays any load error and the retry action.
    await progress.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  Future<void> _openDate(DateTime date) async {
    final saved = await Navigator.of(context).push<bool>(recordRoute(
      builder: (_) => widget.editor(_reportDate(date)),
    ));
    if (mounted && saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    return RecordScaffold(
      appBar: AppBar(title: Text(workText(context, 'Monthly report progress'))),
      body: FutureBuilder<MonthlyReportProgress>(
        future: _progress,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return RecordFailure(error: snapshot.error, retry: _refresh);
          }
          final progress = snapshot.requireData;
          final percentage =
              '${dates.formatDecimal((progress.fraction * 100).round())}%';
          final count = workText(context, '{complete} of {total} days complete')
              .replaceFirst(
                  '{complete}', dates.formatDecimal(progress.completed))
              .replaceFirst(
                  '{total}', dates.formatDecimal(progress.through.day));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dates.formatMonthYear(progress.through),
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(percentage, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          semanticsLabel:
                              workText(context, 'Monthly report progress'),
                        ),
                        const SizedBox(height: 8),
                        Text(count),
                        Text(workText(context, 'Calendar days through today')),
                      ],
                    ),
                  ),
                ),
                if (progress.incomplete.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(workText(
                        context, 'All reports through today are complete.')),
                  )
                else ...[
                  RecordHeading(workText(context, 'Incomplete days')),
                  for (final (date, status) in progress.incomplete)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(switch (status) {
                        'draft' => Icons.edit_note,
                        'returned' => Icons.assignment_return_outlined,
                        _ => Icons.event_busy_outlined,
                      }),
                      title: Text(dates.formatFullDate(date)),
                      subtitle: Text(workText(
                          context,
                          status == null
                              ? 'Missing report'
                              : recordLabel(status))),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDate(date),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _reportDate(DateTime date) => date.toIso8601String().substring(0, 10);

class MonthlyReportProgress {
  const MonthlyReportProgress._(this.through, this.incomplete);

  final DateTime through;
  final List<(DateTime, String?)> incomplete;

  int get completed => through.day - incomplete.length;
  double get fraction => completed / through.day;

  static Future<MonthlyReportProgress> load(
      DailyRecordsApi api, DateTime today) async {
    final start = _reportDate(DateTime.utc(today.year, today.month));
    final end = _reportDate(today);
    final statuses = <String, String>{};
    // The employee's summaries are ordered by report date, newest first.
    for (var page = 1;; page++) {
      final result = await api.get('summaries', {'page': '$page'});
      if (result['data'] is! List) {
        throw const DailyRecordsError(
            'The server returned an invalid response.');
      }
      final rows = recordRows(result['data']);
      for (final row in rows) {
        final date = row['report_date'] as String;
        if (date.compareTo(start) >= 0 && date.compareTo(end) <= 0) {
          statuses.putIfAbsent(date, () => row['status'] as String);
        }
      }
      if (result['next_page_url'] == null ||
          rows.isEmpty ||
          (rows.last['report_date'] as String).compareTo(start) < 0) {
        break;
      }
    }
    final incomplete = <(DateTime, String?)>[];
    for (var day = today.day; day >= 1; day--) {
      final date = DateTime.utc(today.year, today.month, day);
      final status = statuses[_reportDate(date)];
      if (!const {'submitted', 'under_review', 'approved'}.contains(status)) {
        incomplete.add((date, status));
      }
    }
    return MonthlyReportProgress._(today, List.unmodifiable(incomplete));
  }
}
