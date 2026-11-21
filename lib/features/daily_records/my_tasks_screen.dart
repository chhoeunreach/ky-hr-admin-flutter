import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'employee_records.dart';
import 'record_detail.dart';
import 'record_widgets.dart';
import 'work_record_editor.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key, required this.api});
  final DailyRecordsApi api;

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final _list = GlobalKey<RecordListState>();
  String _filter = 'assigned';

  static const _filters = {
    'assigned': 'Assigned to me',
    'today': 'Today',
    'upcoming': 'Upcoming',
    'overdue': 'Overdue',
    'completed': 'Completed',
    'returned': 'Returned for correction',
    'history': 'All task history',
  };

  @override
  Widget build(BuildContext context) => RecordScaffold(
        appBar: AppBar(title: const Text('My Tasks')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Show tasks'),
                items: _filters.entries
                    .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child:
                            Text(entry.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() => _filter = value!),
              ),
            ),
            Expanded(
                child: RecordList(
              key: _list,
              query: _filter,
              empty: 'No tasks in this view.',
              load: (page) =>
                  widget.api.get('tasks', {'page': '$page', 'tab': _filter}),
              itemBuilder: (context, task) => ListTile(
                title: Text(task['title'].toString()),
                leading: Icon(recordFlag(task['overdue'])
                    ? Icons.schedule_outlined
                    : Icons.assignment_outlined),
                subtitle: Text([
                  '${recordLabel(task['status'])} · ${recordNumber(task['progress'])}%',
                  if (recordFlag(task['overdue'])) 'Overdue',
                  'Due ${recordDate(task['due_at'])}',
                ].join('\n')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push<void>(recordRoute(
                      builder: (_) => _EmployeeTaskScreen(
                          api: widget.api, id: recordNumber(task['id']))));
                  if (mounted) _list.currentState?.refresh();
                },
              ),
            )),
          ],
        ),
      );
}

class _EmployeeTaskScreen extends StatelessWidget {
  const _EmployeeTaskScreen({required this.api, required this.id});
  final DailyRecordsApi api;
  final int id;

  @override
  Widget build(BuildContext context) => RecordDetail(
        api: api,
        path: 'tasks/$id',
        title: 'Employee task',
        builder: _buildTask,
      );

  List<Widget> _buildTask(
      BuildContext context, RecordData data, RecordDetailState detail) {
    final task = recordMap(data['task']);
    final status = task['status'];
    final checklist = (task['checklist'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();
    final checked =
        (task['checked'] as List? ?? const []).map(recordNumber).toSet();
    final active = task['archived_at'] == null &&
        task['superseded_at'] == null &&
        status != 'cancelled';
    final incomplete = active &&
        const ['assigned', 'acknowledged', 'in_progress', 'returned', 'on_hold']
            .contains(status);
    final records = recordMap(data['entries']);
    final feedback = recordRows(recordMap(data['history'])['data'])
        .where((event) => event['action'] == 'return')
        .firstOrNull;
    return [
      Text(task['title'].toString(),
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text([
        recordLabel(status),
        if (recordFlag(task['overdue'])) 'Overdue',
        '${recordLabel(task['priority'])} priority',
      ].join(' · ')),
      Text('Due ${recordDate(task['due_at'])}'),
      if (task['completed_at'] != null)
        Text('Completed ${recordDate(task['completed_at'])}'),
      if (task['submitted_at'] != null)
        Text('Submitted ${recordDate(task['submitted_at'])}'),
      if (task['approved_at'] != null)
        Text('Approved ${recordDate(task['approved_at'])}'),
      const RecordHeading('Instructions'),
      Text((task['instructions']?.toString().isNotEmpty ?? false)
          ? task['instructions'].toString()
          : 'No instructions were added.'),
      if (active && status == 'in_progress')
        _TaskProgress(
          key: ValueKey('${task['status']}-${task['progress']}-$checked'),
          checklist: checklist,
          selected: checked,
          initial: recordNumber(task['progress']),
          save: (progress, checked) => detail.action({
            'action': 'progress',
            'progress': progress,
            'checked': checked.toList()..sort()
          }),
        )
      else ...[
        const RecordHeading('Progress'),
        LinearProgressIndicator(value: recordNumber(task['progress']) / 100),
        const SizedBox(height: 4),
        Text('${recordNumber(task['progress'])}%'),
        if (checklist.isNotEmpty) const RecordHeading('Checklist'),
        for (final (index, label) in checklist.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(checked.contains(index)
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank),
            title: Text(label),
          ),
      ],
      if (status == 'returned' && feedback != null)
        const Text('See the return instructions in Activity history.'),
      if (active) ...[
        recordSpacing,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (status == 'assigned')
              FilledButton(
                  onPressed: () => detail.action({'action': 'acknowledge'}),
                  child: const Text('Acknowledge')),
            if (status == 'acknowledged' || status == 'returned')
              FilledButton(
                  onPressed: () => detail.action({'action': 'start'}),
                  child: Text(status == 'returned'
                      ? 'Start correction'
                      : 'Start work')),
            if (status == 'in_progress')
              FilledButton(
                onPressed: checklist.length == checked.length
                    ? () => _message(context, detail, 'submit',
                        'Submit work report', 'Work completed and evidence')
                    : null,
                child: const Text('Submit work report'),
              ),
            OutlinedButton(
              onPressed: () => _message(context, detail, 'comment',
                  'Add note or evidence', 'Note or response to feedback'),
              child: const Text('Add note or evidence'),
            ),
            if (incomplete) ...[
              OutlinedButton(
                  onPressed: () => _record(context, detail, 'incident',
                      classified: recordFlag(data['work_records'])),
                  child: const Text('Record incident')),
              OutlinedButton(
                  onPressed: () => _record(context, detail, 'extension'),
                  child: const Text('Request extension')),
            ],
          ],
        ),
      ],
      RecordAttachments(
          api: api, path: 'tasks/$id', files: recordRows(data['files'])),
      if (recordRows(records['data']).isNotEmpty) ...[
        const RecordHeading('Related records'),
        for (final record in recordRows(records['data']))
          DailyRecordTile(api: api, record: record, onReturn: detail.refresh),
        if (records['next_page_url'] != null)
          TextButton(
              onPressed: () => detail.more('entries'),
              child: const Text('Load earlier records')),
      ],
      RecordHistory(
          page: recordMap(data['history']),
          onMore: () => detail.more('history')),
    ];
  }

  Future<void> _message(BuildContext context, RecordDetailState detail,
          String action, String title, String label) =>
      promptRecordMessage(
        context,
        title: title,
        label: label,
        action: title,
        save: (message, files) => detail.action(
          {'action': action, 'message': message},
          files: files,
        ),
      );

  Future<void> _record(
      BuildContext context, RecordDetailState detail, String kind,
      {bool classified = false}) async {
    final saved = await Navigator.of(context).push<bool>(recordRoute(
        builder: (_) => classified
            ? WorkRecordEditor(api: api, kind: kind, assignmentId: id)
            : NewDailyRecordScreen(api: api, kind: kind, assignmentId: id)));
    if (saved == true && context.mounted) await detail.refresh();
  }
}

class _TaskProgress extends StatefulWidget {
  const _TaskProgress({
    super.key,
    required this.checklist,
    required this.selected,
    required this.initial,
    required this.save,
  });

  final List<String> checklist;
  final Set<int> selected;
  final int initial;
  final Future<void> Function(int progress, Set<int> checked) save;

  @override
  State<_TaskProgress> createState() => _TaskProgressState();
}

class _TaskProgressState extends State<_TaskProgress> {
  late int _progress = widget.initial;
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecordHeading('Progress · $_progress%'),
          Slider(
            value: _progress.toDouble(),
            max: 100,
            divisions: 100,
            label: '$_progress%',
            onChanged: (value) => setState(() => _progress = value.round()),
          ),
          if (widget.checklist.isNotEmpty) const RecordHeading('Checklist'),
          for (final (index, item) in widget.checklist.indexed)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(index),
              title: Text(item),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _selected.add(index);
                } else {
                  _selected.remove(index);
                }
              }),
            ),
          OutlinedButton(
            onPressed: () => widget.save(_progress, _selected),
            child: const Text('Save progress and checklist'),
          ),
        ],
      );
}
