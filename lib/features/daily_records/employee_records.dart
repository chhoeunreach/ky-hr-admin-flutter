import 'package:file_picker/file_picker.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'daily_records_api.dart';
import 'note_description_editor.dart';
import 'record_theme.dart';
import 'daily_summaries.dart';
import 'work_record_editor.dart';
import 'work_labels.dart';
import 'record_detail.dart';
import 'record_widgets.dart';

class NewDailyRecordScreen extends StatefulWidget {
  const NewDailyRecordScreen({
    super.key,
    required this.api,
    required this.kind,
    this.assignmentId,
  });

  final DailyRecordsApi api;
  final String kind;
  final int? assignmentId;

  @override
  State<NewDailyRecordScreen> createState() => _NewDailyRecordScreenState();
}

class _NewDailyRecordScreenState extends State<NewDailyRecordScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _solution = TextEditingController();
  final _requestId = const Uuid().v4();
  bool _private = true;
  bool _critical = false;
  bool _saving = false;
  DateTime? _due;
  List<PlatformFile> _files = [];
  String? _reportDate;

  String get kind => widget.kind;
  bool get _bodyRequired =>
      const ['incident', 'report', 'extension'].contains(kind);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _solution.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (kind == 'report' && _reportDate == null) {
        final access = await widget.api.get('capabilities');
        if (access['can_submit_report'] != true ||
            access['reporting_today'] is! String) {
          throw DailyRecordsError(
              workText(context, 'Your role cannot submit daily reports.'));
        }
        _reportDate = access['reporting_today'] as String;
      }
      await widget.api.post(
          'records',
          {
            'request_id': _requestId,
            'kind': kind,
            if (_reportDate != null) 'report_date': _reportDate,
            'title': _title.text.trim(),
            if (_body.text.trim().isNotEmpty) 'body': _body.text.trim(),
            if (widget.assignmentId != null)
              'assignment_id': widget.assignmentId,
            if (kind == 'note') 'private': _private,
            if (kind == 'incident') 'critical': _critical,
            if (kind == 'incident' && _solution.text.trim().isNotEmpty)
              'solution': _solution.text.trim(),
            if (_due != null) 'requested_due_at': recordDateField(_due!),
          },
          files: _files);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showRecordError(context, error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      'note' => 'New note',
      'todo' => 'New to-do',
      'incident' => 'Record incident',
      'extension' => 'Request deadline extension',
      _ => 'Submit daily report',
    };

    return PopScope(
      canPop: !_saving,
      child: RecordScaffold(
        appBar: AppBar(title: Text(title)),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: 180,
                validator: (value) =>
                    value?.trim().isNotEmpty == true ? null : 'Enter a title',
              ),
              recordSpacing,
              TextFormField(
                controller: _body,
                decoration: InputDecoration(
                    labelText: switch (kind) {
                  'incident' => 'What happened?',
                  'extension' => 'Reason for extension',
                  'report' => 'Work completed and outstanding items',
                  _ => 'Details',
                }),
                maxLength: 10000,
                minLines: 3,
                maxLines: 8,
                validator: (value) =>
                    _bodyRequired && value?.trim().isNotEmpty != true
                        ? 'Enter the details'
                        : null,
              ),
              if (kind == 'note')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private note'),
                  subtitle: const Text('Visible only to you'),
                  value: _private,
                  onChanged: (value) => setState(() => _private = value),
                ),
              if (kind == 'incident') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Critical incident'),
                  value: _critical,
                  onChanged: (value) => setState(() => _critical = value),
                ),
                TextFormField(
                  controller: _solution,
                  decoration:
                      const InputDecoration(labelText: 'Solution, if resolved'),
                  minLines: 2,
                  maxLines: 6,
                  maxLength: 10000,
                ),
              ],
              if (kind == 'extension')
                RecordDateField(
                  label: 'Requested deadline',
                  value: _due,
                  required: true,
                  onChanged: (value) => setState(() => _due = value),
                ),
              RecordFilePicker(
                files: _files,
                onChanged: (files) => setState(() => _files = files),
              ),
              recordSpacing,
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving
                    ? 'Saving…'
                    : kind == 'report' || kind == 'extension'
                        ? 'Submit'
                        : 'Save record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyDailyRecordsScreen extends StatefulWidget {
  const MyDailyRecordsScreen({super.key, required this.api});
  final DailyRecordsApi api;

  @override
  State<MyDailyRecordsScreen> createState() => _MyDailyRecordsScreenState();
}

class _MyDailyRecordsScreenState extends State<MyDailyRecordsScreen> {
  final _list = GlobalKey<RecordListState>();
  String _kind = '';
  static const _kinds = {
    '': 'All records',
    'note': 'Notes',
    'todo': 'To-dos',
    'incident': 'Incidents',
    'report': 'Reports',
    'extension': 'Extensions',
  };

  @override
  Widget build(BuildContext context) => RecordScaffold(
        appBar: AppBar(title: const Text('My Daily Records')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Record type'),
                items: _kinds.entries
                    .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child:
                            Text(entry.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() => _kind = value ?? ''),
              ),
            ),
            Expanded(
                child: RecordList(
              key: _list,
              query: _kind,
              empty: 'No records in this view.',
              load: (page) => widget.api.get('records',
                  {'page': '$page', if (_kind.isNotEmpty) 'kind': _kind}),
              itemBuilder: (context, record) => DailyRecordTile(
                api: widget.api,
                record: record,
                onReturn: () => _list.currentState?.refresh(),
              ),
            )),
          ],
        ),
      );
}

class DailyRecordTile extends StatelessWidget {
  const DailyRecordTile(
      {super.key, required this.api, required this.record, this.onReturn});
  final DailyRecordsApi api;
  final RecordData record;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(record['title'].toString()),
        subtitle: Text([
          recordLabel(record['kind']),
          if (recordFlag(record['private'])) 'Private',
          if (record['status'] != null) recordLabel(record['status']),
          recordDate(record['updated_at']),
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push<void>(
              context,
              recordRoute(
                  builder: (_) => DailyRecordScreen(
                      api: api, id: recordNumber(record['id']))));
          if (context.mounted) onReturn?.call();
        },
      );
}

class DailyRecordScreen extends StatelessWidget {
  const DailyRecordScreen({
    super.key,
    required this.api,
    required this.id,
    this.workRecords = false,
    this.assigned = false,
  });
  final DailyRecordsApi api;
  final int id;
  final bool workRecords;
  final bool assigned;

  String get _path => assigned ? 'assigned-incidents/$id' : 'records/$id';

  @override
  Widget build(BuildContext context) => RecordDetail(
        api: api,
        path: _path,
        title: 'Daily record',
        builder: (context, data, detail) {
          final entry = recordMap(data['entry']);
          final kind = entry['kind'];
          final status = entry['status'];
          final closed = entry['archived_at'] != null;
          final canEdit = workRecords &&
              !assigned &&
              !closed &&
              (kind == 'note' ||
                  kind == 'activity' ||
                  kind == 'incident' && status == 'reported');
          final classification = workMap(entry['classification']);
          final details = workMap(entry['details']);
          final fields = recordMap(details['fields']);
          final note =
              kind == 'note' ? noteOperations(details['note_document']) : null;
          final files = recordRows(data['files']);
          final inlineImages = noteImageNames(note);
          return [
            Text(entry['title'].toString(),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text([
              recordLabel(kind),
              if (status != null) recordLabel(status),
              if (recordFlag(entry['private'])) 'Private',
              if (recordFlag(entry['sensitive']))
                workText(context, 'Confidential'),
            ].join(' · ')),
            if (entry['occurred_at'] != null)
              Text(recordDate(entry['occurred_at'])),
            if (classification.isNotEmpty)
              Text([
                classificationName(
                    context, recordMap(classification['category'])),
                classificationName(
                    context, recordMap(classification['subcategory'])),
              ].where((name) => name.isNotEmpty).join(' · ')),
            if (workList(entry['tags']).isNotEmpty)
              Wrap(spacing: 6, children: [
                for (final tag in workList(entry['tags']))
                  Chip(label: Text(tag.toString()))
              ]),
            if (note != null) ...[
              recordSpacing,
              NoteDescriptionEditor(
                key: ValueKey((id, entry['revision'])),
                api: api,
                entryId: id,
                plainText: (entry['body'] ?? '').toString(),
                operations: note,
                attachments: files,
              ),
            ] else if (entry['body'] != null) ...[
              recordSpacing,
              Text(entry['body'].toString())
            ],
            if (fields['from_branch'] != null ||
                fields['to_branch'] != null) ...[
              recordSpacing,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alt_route_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${fields['from_branch'] ?? ''} ➔ ${fields['to_branch'] ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        if (recordFlag(fields['gps_verified']))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_outlined,
                                    size: 13, color: AppColors.green),
                                SizedBox(width: 4),
                                Text('GPS Verified',
                                    style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (fields['departure_time'] != null ||
                        fields['arrival_time'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${fields['departure_time'] != null ? '${workText(context, 'Departure Time')}: ${fields['departure_time']}' : ''}'
                        '${fields['departure_time'] != null && fields['arrival_time'] != null ? '  |  ' : ''}'
                        '${fields['arrival_time'] != null ? '${workText(context, 'Arrival Time')}: ${fields['arrival_time']}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (fields['shoot_types'] != null ||
                        fields['media_types'] != null ||
                        fields['shoot_count'] != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if ((fields['shoot_types'] ?? fields['media_types']) is List)
                            for (final t in ((fields['shoot_types'] ?? fields['media_types']) as List))
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(t.toString(),
                                    style: const TextStyle(fontSize: 11)),
                              )
                          else if ((fields['shoot_types'] ?? fields['media_types']) != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text((fields['shoot_types'] ?? fields['media_types']).toString(),
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          if (fields['shoot_count'] != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.photo_camera, size: 14),
                              label: Text(
                                  '${fields['shoot_count']} shots/items',
                                  style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (entry['solution'] != null) ...[
              const RecordHeading('Solution'),
              Text(entry['solution'].toString())
            ],
            for (final label in const {
              'result': 'Work result',
              'challenges': 'Challenges',
              'immediate_action': 'Immediate action',
              'proposed_solution': 'Proposed solution'
            }.entries)
              if (details[label.key]?.toString().isNotEmpty == true) ...[
                RecordHeading(workText(context, label.value)),
                Text(details[label.key].toString()),
              ],
            for (final field in recordRows(classification['fields']))
              if (fields[field['key']] != null) ...[
                RecordHeading((field[
                            Localizations.localeOf(context).languageCode == 'km'
                                ? 'label_km'
                                : 'label_en'] ??
                        field['key'])
                    .toString()),
                Text(fields[field['key']] is List
                    ? workList(fields[field['key']]).join(', ')
                    : fields[field['key']].toString()),
              ],
            if (entry['follow_up_at'] != null) ...[
              RecordHeading(workText(context, 'Follow-up date and time')),
              Text(recordDate(entry['follow_up_at'])),
            ],
            if (entry['requested_due_at'] != null) ...[
              const RecordHeading('Requested deadline'),
              Text(recordDate(entry['requested_due_at'])),
            ],
            recordSpacing,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canEdit)
                  FilledButton(
                      onPressed: () => _edit(context, detail, entry, files),
                      child: Text(workText(context, 'Edit record'))),
                if (workRecords && !assigned && kind == 'note') ...[
                  if (!closed)
                    OutlinedButton(
                        onPressed: () => _noteAction(context, detail,
                            recordFlag(entry['pinned']) ? 'unpin' : 'pin'),
                        child: Text(workText(context,
                            recordFlag(entry['pinned']) ? 'Unpin' : 'Pin'))),
                  OutlinedButton(
                      onPressed: () => _noteAction(
                          context, detail, closed ? 'restore' : 'archive'),
                      child: Text(
                          workText(context, closed ? 'Restore' : 'Archive'))),
                ],
                if (recordFlag(entry['consolidated']) &&
                    entry['occurred_at'] != null)
                  FilledButton(
                      onPressed: () async {
                        final date = recordDateField(
                                recordBusinessTime(entry['occurred_at'])!)
                            .split('T')
                            .first;
                        await Navigator.of(context).push<bool>(recordRoute(
                            builder: (_) =>
                                DailySummaryEditor(api: api, date: date)));
                        if (context.mounted) await detail.refresh();
                      },
                      child: Text(workText(context, 'Daily Summary'))),
                if (!assigned && kind == 'todo')
                  FilledButton(
                    onPressed: () => detail.action(
                        {'action': status == 'open' ? 'complete' : 'reopen'}),
                    child: Text(
                        status == 'open' ? 'Complete to-do' : 'Reopen to-do'),
                  ),
                if (!assigned &&
                    kind == 'incident' &&
                    status == 'open' &&
                    entry['category_id'] == null)
                  FilledButton(
                      onPressed: () => _message(context, detail, 'resolve',
                          'Record solution', 'How was it resolved?'),
                      child: const Text('Record solution')),
                if (kind == 'report' &&
                    status == 'returned' &&
                    entry['assignment_id'] == null &&
                    data['can_submit_report'] == true &&
                    recordBusinessTime(entry['created_at'])
                            ?.toIso8601String()
                            .split('T')
                            .first ==
                        data['reporting_today'] &&
                    !recordFlag(entry['consolidated']))
                  FilledButton(
                      onPressed: () => _message(context, detail, 'resubmit',
                          'Resubmit report', 'Corrected daily report'),
                      child: const Text('Resubmit report')),
                if (!closed &&
                    (!assigned || !['closed', 'cancelled'].contains(status)))
                  OutlinedButton(
                    onPressed: () => _message(
                        context,
                        detail,
                        'comment',
                        assigned ? 'Respond to incident' : 'Add comment',
                        assigned ? 'Incident response' : 'Comment'),
                    child: Text(workText(context,
                        assigned ? 'Respond to incident' : 'Add comment')),
                  ),
              ],
            ),
            RecordAttachments(
                api: api,
                path: _path,
                files: files
                    .where((file) => !inlineImages.contains(file['name']))
                    .toList()),
            RecordHistory(
                page: recordMap(data['history']),
                onMore: () => detail.more('history')),
          ];
        },
      );

  Future<void> _edit(BuildContext context, RecordDetailState detail,
      RecordData entry, List<RecordData> files) async {
    final saved = await Navigator.of(context).push<bool>(recordRoute(
      builder: (_) => WorkRecordEditor(
          api: api,
          kind: entry['kind'].toString(),
          entry: entry,
          attachments: files),
    ));
    if (saved == true && context.mounted) await detail.refresh();
  }

  Future<void> _noteAction(
      BuildContext context, RecordDetailState detail, String action) async {
    if (detail.busy) return;
    try {
      await api.post('work-records/$id/note', {'action': action});
      if (context.mounted) await detail.refresh();
    } catch (error) {
      if (context.mounted) showRecordError(context, error);
    }
  }

  Future<void> _message(BuildContext context, RecordDetailState detail,
          String action, String title, String label) =>
      promptRecordMessage(
        context,
        title: workText(context, title),
        label: workText(context, label),
        action: workText(context, title),
        save: (message, files) => detail.action(
          {'action': action, 'message': message},
          files: files,
        ),
      );
}
