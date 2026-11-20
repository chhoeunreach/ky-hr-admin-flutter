import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'employee_records.dart';
import 'record_detail.dart';
import 'record_widgets.dart';
import 'work_labels.dart';
import 'work_record_editor.dart';

const _summaryFields = {
  'summary': 'Completed work summary',
  'challenges': 'Challenges',
  'solutions': 'Solutions',
  'pending_work': 'Pending work',
  'recommendations': 'Recommendations',
};

class DailySummariesScreen extends StatefulWidget {
  const DailySummariesScreen(
      {super.key, required this.api, this.manager = false});

  final DailyRecordsApi api;
  final bool manager;

  @override
  State<DailySummariesScreen> createState() => _DailySummariesScreenState();
}

class _DailySummariesScreenState extends State<DailySummariesScreen> {
  final _list = GlobalKey<RecordListState>();
  late String _status = widget.manager ? 'pending' : '';

  Future<void> _openDate() async {
    final date = await chooseWorkDate(context, workToday());
    if (!mounted || date == null) return;
    await Navigator.of(context).push<bool>(recordRoute(
      builder: (_) => DailySummaryEditor(api: widget.api, date: date),
    ));
    if (mounted) await _list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = {
      if (widget.manager) 'pending': 'Pending reviews',
      '': 'All reports',
      'submitted': 'Submitted',
      'under_review': 'Under review',
      'returned': 'Returned for correction',
      'approved': 'Approved',
      if (!widget.manager) 'draft': 'Draft',
    };
    return Scaffold(
      appBar: AppBar(
          title: Text(workText(context,
              widget.manager ? 'Review Reports' : 'My Submitted Reports'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.manager) ...[
                FilledButton.icon(
                  onPressed: _openDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(workText(context, 'Choose reporting date')),
                ),
                recordSpacing,
              ],
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration:
                    InputDecoration(labelText: workText(context, 'Status')),
                items: [
                  for (final status in statuses.entries)
                    DropdownMenuItem(
                        value: status.key,
                        child: Text(workText(context, status.value),
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _status = value ?? ''),
                isExpanded: true,
              ),
            ],
          ),
        ),
        Expanded(
            child: RecordList(
          key: _list,
          query: _status,
          empty: workText(context, 'No matching records.'),
          load: (page) => widget.api.get(
              widget.manager ? 'summary-inbox' : 'summaries',
              {'page': '$page', if (_status.isNotEmpty) 'status': _status}),
          itemBuilder: (context, row) => ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(widget.manager
                ? row['employee'].toString()
                : row['report_date'].toString()),
            subtitle: Text([
              if (widget.manager) row['report_date'],
              workText(context, recordLabel(row['status'])),
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push<void>(recordRoute(
                  builder: (_) => _SummaryDetail(
                      api: widget.api,
                      id: recordNumber(row['id']),
                      manager: widget.manager)));
              if (mounted) await _list.currentState?.refresh();
            },
          ),
        )),
      ]),
    );
  }
}

class DailySummaryEditor extends StatefulWidget {
  const DailySummaryEditor({super.key, required this.api, required this.date});
  final DailyRecordsApi api;
  final String date;

  @override
  State<DailySummaryEditor> createState() => _DailySummaryEditorState();
}

class _DailySummaryEditorState extends State<DailySummaryEditor> {
  late Future<void> _initial = _load();
  final _form = GlobalKey<FormState>();
  final _content = <String, String>{};
  final _selected = <int>{};
  final _records = <RecordData>[];
  final _tasks = <RecordData>[];
  RecordData _report = {};
  List<PlatformFile> _files = [];
  int _recordPage = 1;
  int _taskPage = 1;
  bool _moreRecords = false;
  bool _moreTasks = false;
  bool _loadingMore = false;
  bool _saving = false;

  Future<RecordData> _preview({int page = 1, int taskPage = 1}) =>
      widget.api.get('summaries/preview',
          {'date': widget.date, 'page': '$page', 'task_page': '$taskPage'});

  Future<void> _load() async {
    final data = await _preview();
    if (!mounted) return;
    _report = recordMap(data['report']);
    final draft = workMap(_report['draft']);
    _content
      ..clear()
      ..addAll({
        for (final key in _summaryFields.keys)
          key: (draft[key] ?? '').toString(),
      });
    _records
      ..clear()
      ..addAll(recordRows(recordMap(data['records'])['data']));
    _tasks
      ..clear()
      ..addAll(recordRows(recordMap(data['tasks'])['data']));
    final eligible = data.containsKey('eligible_ids')
        ? workList(data['eligible_ids']).map(recordNumber)
        : _records.map((row) => recordNumber(row['id']));
    _selected
      ..clear()
      ..addAll(draft.containsKey('record_ids')
          ? workList(draft['record_ids']).map(recordNumber)
          : eligible);
    _recordPage = 1;
    _taskPage = 1;
    _moreRecords = recordMap(data['records'])['next_page_url'] != null;
    _moreTasks = recordMap(data['tasks'])['next_page_url'] != null;
  }

  Future<void> _more({bool tasks = false}) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = tasks ? _taskPage + 1 : _recordPage + 1;
      final data =
          await _preview(page: tasks ? 1 : next, taskPage: tasks ? next : 1);
      if (!mounted) return;
      final result = recordMap(data[tasks ? 'tasks' : 'records']);
      final rows = recordRows(result['data']);
      setState(() {
        if (tasks) {
          _tasks.addAll(rows);
          _taskPage = next;
          _moreTasks = result['next_page_url'] != null;
        } else {
          _records.addAll(rows);
          _recordPage = next;
          _moreRecords = result['next_page_url'] != null;
        }
      });
    } catch (error) {
      if (mounted) showRecordError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _save(bool submit) async {
    if (_saving || !_form.currentState!.validate()) return;
    if (submit && _content['summary']?.trim().isNotEmpty != true) {
      showRecordError(
          context,
          DailyRecordsError(
              workText(context, 'Enter the completed work summary.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.postWork(
          'summaries',
          {
            'report_date': widget.date,
            'revision': recordNumber(_report['revision']),
            'action': submit ? 'submit' : 'save',
            'record_ids': _selected.toList(),
            ..._content,
          },
          files: _files);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRecordError(context, error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: Text(workText(context, 'Daily Summary'))),
          body: FutureBuilder<void>(
            future: _initial,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return RecordFailure(
                    error: snapshot.error,
                    retry: () => setState(() {
                          _initial = _load();
                        }));
              final editable = _report.isEmpty ||
                  ['draft', 'returned'].contains(_report['status']);
              if (!editable) {
                return Center(
                    child: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(recordRoute(
                    builder: (_) => _SummaryDetail(
                        api: widget.api,
                        id: recordNumber(_report['id']),
                        manager: false),
                  )),
                  child: Text(workText(context, 'Open submitted report')),
                ));
              }
              return Form(
                key: _form,
                child: IgnorePointer(
                  ignoring: _saving,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('${widget.date} ICT',
                          style: Theme.of(context).textTheme.titleLarge),
                      RecordHeading(
                          "${workText(context, 'Records to include')} (${_selected.length})"),
                      if (_records.isEmpty)
                        Text(workText(
                            context, 'No eligible records for this date.')),
                      for (final record in _records)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(record['title'].toString()),
                          subtitle: Text(
                              workText(context, recordLabel(record['kind']))),
                          value: _selected.contains(recordNumber(record['id'])),
                          onChanged: (value) => setState(() {
                            final id = recordNumber(record['id']);
                            if (value == true && _selected.length < 250) {
                              _selected.add(id);
                            } else if (value == false) {
                              _selected.remove(id);
                            }
                          }),
                        ),
                      if (_moreRecords)
                        TextButton(
                            onPressed: _loadingMore ? null : () => _more(),
                            child:
                                Text(workText(context, 'Load more records'))),
                      if (_tasks.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(workText(context, 'My Tasks')),
                          children: [
                            for (final task in _tasks)
                              ListTile(
                                  title: Text(task['title'].toString()),
                                  subtitle: Text(workText(
                                      context, recordLabel(task['status'])))),
                            if (_moreTasks)
                              TextButton(
                                  onPressed: _loadingMore
                                      ? null
                                      : () => _more(tasks: true),
                                  child: Text(workText(context, 'Load more'))),
                          ],
                        ),
                      for (final field in _summaryFields.entries) ...[
                        recordSpacing,
                        TextFormField(
                          initialValue: _content[field.key],
                          decoration: InputDecoration(
                              labelText: workText(context, field.value)),
                          minLines: 2,
                          maxLines: 5,
                          maxLength: field.key == 'summary' ? 10000 : 5000,
                          onChanged: (value) => _content[field.key] = value,
                        ),
                      ],
                      RecordFilePicker(
                          files: _files,
                          onChanged: (files) => setState(() => _files = files)),
                      recordSpacing,
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(
                            onPressed: _saving ? null : () => _save(false),
                            child: Text(workText(context, 'Save draft'))),
                        FilledButton(
                            onPressed: _saving ? null : () => _save(true),
                            child: Text(workText(
                                context,
                                _report['status'] == 'returned'
                                    ? 'Submit correction'
                                    : 'Submit report'))),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _SummaryDetail extends StatelessWidget {
  const _SummaryDetail(
      {required this.api,
      required this.id,
      required this.manager,
      this.version});
  final DailyRecordsApi api;
  final int id;
  final bool manager;
  final int? version;

  @override
  Widget build(BuildContext context) {
    final path = manager ? 'summary-inbox/$id' : 'summaries/$id';
    return RecordDetail(
      api: api,
      path: path,
      query: {if (version != null) 'version': '$version'},
      title: workText(context, manager ? 'Review Reports' : 'Daily Summary'),
      builder: (context, data, detail) {
        final report = recordMap(data['report']);
        final fields = recordMap(data['content'] ?? data['draft']);
        final current = data['selected_version'] == report['version'];
        final pending =
            ['submitted', 'under_review'].contains(report['status']);
        final date = report['report_date'].toString();
        final tasks = recordMap(data['tasks']);
        final versions = recordMap(data['versions']);
        return [
          Text('$date ICT', style: Theme.of(context).textTheme.headlineSmall),
          Text([
            report['employee'],
            workText(context, recordLabel(report['status']))
          ].whereType<String>().join(' · ')),
          if (data['selected_version'] != null)
            Text("${workText(context, 'Version')} ${data['selected_version']}"),
          for (final field in _summaryFields.entries)
            if (fields[field.key]?.toString().isNotEmpty == true) ...[
              RecordHeading(workText(context, field.value)),
              Text(fields[field.key].toString()),
            ],
          if (recordRows(data['records']).isNotEmpty) ...[
            RecordHeading(workText(context, 'Records to include')),
            for (final record in recordRows(data['records']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(record['title'].toString()),
                subtitle: Text([
                  workText(context, recordLabel(record['kind'])),
                  record['body']
                ].whereType<String>().join('\n')),
                onTap: manager
                    ? null
                    : () => Navigator.of(context).push<void>(recordRoute(
                          builder: (_) => DailyRecordScreen(
                              api: api,
                              id: recordNumber(record['id']),
                              workRecords: true),
                        )),
              ),
          ],
          if (recordRows(tasks['data']).isNotEmpty)
            ExpansionTile(
              title: Text(workText(context, 'My Tasks')),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final task in recordRows(tasks['data']))
                  ListTile(
                      title: Text(task['title'].toString()),
                      subtitle:
                          Text(workText(context, recordLabel(task['status'])))),
                if (tasks['next_page_url'] != null)
                  TextButton(
                      onPressed: () => detail.more('tasks'),
                      child: Text(workText(context, 'Load more'))),
              ],
            ),
          recordSpacing,
          if (!manager && ['draft', 'returned'].contains(report['status']))
            FilledButton(
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                      recordRoute(
                          builder: (_) =>
                              DailySummaryEditor(api: api, date: date)));
                  if (saved == true && context.mounted) await detail.refresh();
                },
                child: Text(workText(context, 'Edit record'))),
          if (manager && current)
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (pending) ...[
                if (report['status'] == 'submitted')
                  OutlinedButton(
                      onPressed: () => detail.action(
                          {'action': 'start', 'version': report['version']}),
                      child: Text(workText(context, 'Start review'))),
                FilledButton(
                    onPressed: () => detail.action(
                        {'action': 'approve', 'version': report['version']}),
                    child: Text(workText(context, 'Approve'))),
                OutlinedButton(
                    onPressed: () => _feedback(context, detail, report,
                        'return', 'Return for correction'),
                    child: Text(workText(context, 'Return for correction'))),
              ],
              OutlinedButton(
                  onPressed: () => _feedback(
                      context, detail, report, 'comment', 'Add review comment'),
                  child: Text(workText(context, 'Add review comment'))),
            ]),
          RecordAttachments(
              api: api,
              path: manager ? path : 'records/$id',
              files: recordRows(data['files'])),
          RecordHistory(
              page: recordMap(data['history']),
              onMore: () => detail.more('history')),
          if (recordRows(versions['data']).isNotEmpty)
            ExpansionTile(
              title: Text(workText(context, 'Version')),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final item in recordRows(versions['data']))
                  ListTile(
                    title: Text(
                        "${workText(context, 'Version')} ${item['version']}"),
                    subtitle: Text(recordDate(item['submitted_at'])),
                    onTap: item['version'] == data['selected_version']
                        ? null
                        : () => Navigator.of(context).push<void>(recordRoute(
                            builder: (_) => _SummaryDetail(
                                api: api,
                                id: id,
                                manager: manager,
                                version: recordNumber(item['version'])))),
                  ),
                if (versions['next_page_url'] != null)
                  TextButton(
                      onPressed: () => detail.more('versions'),
                      child: Text(workText(context, 'Load more'))),
              ],
            ),
        ];
      },
    );
  }

  Future<void> _feedback(BuildContext context, RecordDetailState detail,
          RecordData report, String action, String label) =>
      promptRecordMessage(context,
          title: workText(context, label),
          label: workText(context, 'Review notes'),
          action: workText(context, label),
          allowFiles: false,
          save: (message, _) => detail.action({
                'action': action,
                'version': report['version'],
                'message': message
              }));
}
