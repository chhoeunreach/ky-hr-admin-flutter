import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'daily_records_api.dart';
import 'note_description_editor.dart';
import 'record_widgets.dart';
import 'related_task_picker.dart';
import 'work_labels.dart';

class WorkRecordEditor extends StatefulWidget {
  const WorkRecordEditor({
    super.key,
    required this.api,
    required this.kind,
    this.entry,
    this.attachments = const [],
    this.assignmentId,
  });

  final DailyRecordsApi api;
  final String kind;
  final RecordData? entry;
  final List<RecordData> attachments;
  final int? assignmentId;

  @override
  State<WorkRecordEditor> createState() => _WorkRecordEditorState();
}

class _WorkRecordEditorState extends State<WorkRecordEditor> {
  final _form = GlobalKey<FormState>();
  late Future<void> _loading = _load();
  final _data = <String, dynamic>{};
  List<RecordData> _categories = [];
  List<PlatformFile> _files = [];
  final _noteImages = <String, PlatformFile>{};
  Timer? _timer;
  Future<void> _draftWrite = Future.value();
  bool _dirty = false;
  bool _restored = false;
  bool _draftFailed = false;
  bool _saving = false;
  int _formVersion = 0;
  late final _openedRevision = recordNumber(widget.entry?['revision']);

  String get _kind => widget.kind;
  bool get _incident => _kind == 'incident';
  bool get _note => _kind == 'note';
  String get _draftKey => widget.entry != null
      ? 'edit-${widget.entry!['id']}'
      : _kind + (widget.assignmentId == null ? '' : '-${widget.assignmentId}');

  Future<void> _load() async {
    final api = widget.api;
    final results = await Future.wait([
      _note
          ? Future.value(<String, dynamic>{})
          : api.get('catalog', {'kind': _kind}),
      api
          .get('drafts/$_draftKey')
          .catchError((Object _) => <String, dynamic>{}),
    ]);
    if (!mounted) return;
    _categories = recordRows(results.first['categories']);
    final entry = widget.entry ?? {};
    final details = workMap(entry['details']);
    _data
      ..clear()
      ..addAll({
        'kind': _kind,
        'request_id': const Uuid().v4(),
        'revision': _openedRevision,
        if (widget.assignmentId != null) 'assignment_id': widget.assignmentId,
        if (widget.assignmentId == null && entry['assignment_id'] != null)
          'assignment_id': entry['assignment_id'],
        'title': entry['title'],
        'body': entry['body'],
        if (details['note_document'] is List)
          'note_document': jsonEncode(details['note_document']),
        'solution': entry['solution'],
        'private':
            !entry.containsKey('private') || recordFlag(entry['private']),
        'category_id': entry['category_id'],
        'subcategory_id': entry['subcategory_id'],
        'priority': entry['priority'] ?? 'normal',
        'fields': {...recordMap(details['fields'])},
        'tags_text': workList(entry['tags']).join(', '),
        'activity_date':
            _businessStamp(entry['occurred_at'])?.split('T').first ??
                DateFormat('yyyy-MM-dd').format(_businessNow()),
        'occurred_at': _businessStamp(entry['occurred_at']),
        'follow_up_at': _businessStamp(entry['follow_up_at']),
        'start_time': details['start_time'],
        'end_time': _businessStamp(entry['ended_at'])?.split('T').last,
        for (final key in [
          'result',
          'challenges',
          'follow_up',
          'immediate_action',
          'proposed_solution'
        ])
          if (details.containsKey(key)) key: details[key],
      });
    final draft = recordMap(results.last['draft']);
    if (draft.isNotEmpty &&
        draft['kind'] == _kind &&
        recordNumber(draft['revision']) == _openedRevision) {
      _data.addAll(draft);
      _data['fields'] = {...recordMap(_data['fields'])};
      _restored = true;
    }
    _restoreHistoricalClassification(entry);
  }

  void _restoreHistoricalClassification(RecordData entry) {
    final categoryId = entry['category_id'];
    if (categoryId == null) return;
    final snapshot = workMap(entry['classification']);
    final category = _find(_categories, categoryId);
    final childId = entry['subcategory_id'];
    if (category != null &&
        (childId == null ||
            _find(recordRows(category['children']), childId) != null)) {
      return;
    }
    final children = [...recordRows(category?['children'])];
    if (childId != null) {
      children.add({
        ...recordMap(snapshot['subcategory']),
        'id': childId,
        'fields': snapshot['fields'],
      });
    }
    _categories = [
      for (final node in _categories)
        if (node['id'] != categoryId) node,
      {
        ...?category,
        ...recordMap(snapshot['category']),
        'id': categoryId,
        'fields': snapshot['fields'],
        'children': children,
      },
    ];
  }

  void _change(String key, Object? value, {bool rebuild = false}) {
    if (_saving) return;
    _data[key] = value;
    _dirty = true;
    if (rebuild) setState(() {});
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 850), _queueDraft);
  }

  void _queueDraft() {
    if (!_dirty) return;
    final draft = {..._data};
    final ops = noteOperations(draft['note_document']);
    if (_noteImages.isNotEmpty && ops != null) {
      draft['note_document'] = jsonEncode([
        for (final op in ops)
          if (!noteImageNames([op]).any(_noteImages.containsKey)) op,
      ]);
    }
    final serialized = jsonEncode(draft);
    _draftWrite = _draftWrite.then((_) async {
      try {
        await widget.api.post('drafts/$_draftKey', {'payload': serialized});
        if (mounted && _draftFailed) setState(() => _draftFailed = false);
      } catch (_) {
        if (mounted && !_saving) setState(() => _draftFailed = true);
      }
    });
    _dirty = false;
  }

  Future<void> _discard() async {
    _timer?.cancel();
    _dirty = false;
    await _draftWrite;
    try {
      await widget.api.post('drafts/$_draftKey', {});
      if (!mounted) return;
      setState(() {
        _restored = false;
        _draftFailed = false;
        _files = [];
        _noteImages.clear();
        _formVersion++;
        _loading = _load();
      });
    } catch (error) {
      if (mounted) showRecordError(context, error);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _queueDraft();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    _timer?.cancel();
    final payload = <String, dynamic>{
      for (final field in _data.entries)
        if (field.value != null &&
            field.value != '' &&
            !['tags_text', 'related_title', 'tags_text_reset']
                .contains(field.key))
          field.key: field.value,
      if (_data.containsKey('assignment_id') && _data['assignment_id'] == null)
        'assignment_id': null,
      'tags': (_data['tags_text']?.toString() ?? '')
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
    };
    final path = widget.entry == null
        ? 'work-records'
        : 'work-records/${widget.entry!['id']}';
    final images = noteImageNames(noteOperations(payload['note_document']));
    final uploads = [
      ..._files,
      for (final name in images)
        if (_noteImages[name] case final PlatformFile file) file,
    ];
    try {
      if (uploads.length > 4) {
        throw const DailyRecordsError(
            'A note can upload up to four files at a time.');
      }
      await _draftWrite;
      await widget.api.postWork(path, payload, files: uploads);
      _dirty = false;
      try {
        await widget.api.post('drafts/$_draftKey', {});
      } catch (_) {
        // The record is already committed. The draft's request ID prevents duplicate creation.
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRecordError(context, error);
        setState(() => _saving = false);
        _queueDraft();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.entry != null
        ? 'Edit record'
        : _note
            ? 'Personal Note'
            : _incident
                ? 'Incident Report'
                : 'Daily Activity';
    return PopScope(
      canPop: !_saving,
      child: RecordScaffold(
        appBar: AppBar(title: Text(workText(context, label))),
        body: FutureBuilder<void>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return RecordFailure(
                  error: snapshot.error,
                  retry: () => setState(() {
                        _loading = _load();
                      }));
            }
            return Form(
              key: _form,
              child: IgnorePointer(
                ignoring: _saving,
                child: ListView(
                  key: ValueKey(_formVersion),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_restored || _draftFailed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.drafts_outlined),
                        title: Text(workText(
                            context,
                            _draftFailed
                                ? 'Draft could not be saved'
                                : 'Draft recovered')),
                        trailing: TextButton(
                            onPressed: _discard,
                            child: Text(workText(context, 'Discard draft'))),
                      ),
                    _text('title', 'Title', limit: 180, required: true),
                    if (!_note) ..._classification(),
                    if (_incident)
                      _dateTime('occurred_at', 'Occurrence date and time',
                          required: true),
                    if (!_note && !_incident) ...[
                      _date('activity_date', 'Activity date', required: true),
                      _time('start_time', 'Start time'),
                      _time('end_time', 'End time'),
                      _relatedTask(),
                    ],
                    if (_note)
                      NoteDescriptionEditor(
                        key: ValueKey(_formVersion),
                        api: widget.api,
                        plainText: (_data['body'] ?? '').toString(),
                        operations: noteOperations(_data['note_document']),
                        entryId: widget.entry == null
                            ? null
                            : recordNumber(widget.entry!['id']),
                        attachments: widget.attachments,
                        pendingImages: _noteImages,
                        freeUploadSlots: 4 - _files.length,
                        onImage: (file) {
                          if (_noteImages.length >= 4) {
                            final used = noteImageNames(
                                noteOperations(_data['note_document']));
                            _noteImages
                                .removeWhere((name, _) => !used.contains(name));
                          }
                          _noteImages[file.name] = file;
                        },
                        onChanged: (document, plain) {
                          _data['body'] = plain;
                          _change('note_document', document);
                        },
                      )
                    else
                      _text(
                          'body', _incident ? 'Description' : 'Work performed',
                          limit: 10000, required: true, lines: 4),
                    if (_incident) ...[
                      _choice(
                          'priority',
                          'Severity',
                          {
                            for (final value in [
                              'low',
                              'normal',
                              'high',
                              'urgent'
                            ])
                              value: recordLabel(value),
                          },
                          required: true),
                      _text('immediate_action', 'Immediate action',
                          lines: 2, limit: 3000),
                      _text('proposed_solution', 'Proposed solution',
                          lines: 2, limit: 3000),
                      _text('solution', 'Actual solution',
                          lines: 2, limit: 10000),
                      _dateTime('follow_up_at', 'Follow-up date and time'),
                    ] else if (_note)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(workText(
                            context, 'Share with authorized managers')),
                        value: !recordFlag(_data['private']),
                        onChanged: (value) =>
                            _change('private', !value, rebuild: true),
                      )
                    else ...[
                      _text('result', 'Work result', lines: 2, limit: 3000),
                      _text('challenges', 'Challenges', lines: 2, limit: 3000),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(workText(context, 'Follow-up required')),
                        value: recordFlag(_data['follow_up']),
                        onChanged: (value) =>
                            _change('follow_up', value, rebuild: true),
                      ),
                      if (recordFlag(_data['follow_up']))
                        _dateTime('follow_up_at', 'Follow-up date and time'),
                    ],
                    _text('tags_text', 'Tags', limit: 400),
                    RecordFilePicker(
                        files: _files,
                        onChanged: (files) => setState(() => _files = files)),
                    recordSpacing,
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(workText(context, 'Save record'))),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _classification() {
    final category = _find(_categories, _data['category_id']);
    final children = recordRows(category?['children']);
    final child = _find(children, _data['subcategory_id']);
    final locked = _incident && widget.entry?['category_id'] != null;
    final entry = widget.entry;
    final historical = entry != null &&
        recordNumber(entry['category_id']) ==
            recordNumber(_data['category_id']) &&
        recordNumber(entry['subcategory_id']) ==
            recordNumber(_data['subcategory_id']);
    final definitions = historical
        ? recordRows(workMap(entry['classification'])['fields'])
        : [
            ...recordRows(category?['fields']),
            ...recordRows(child?['fields']),
          ];
    final fields = <String, RecordData>{
      for (final field in definitions) field['key'].toString(): field,
    };
    final suggested = {
      ...workList(category?['tags']).map((tag) => tag.toString()),
      ...workList(child?['tags']).map((tag) => tag.toString()),
    };
    final selectedTags = (_data['tags_text']?.toString() ?? '')
        .split(',')
        .map((tag) => tag.trim())
        .toSet();
    return [
      _categorySelector('category_id', 'Category', _categories,
          locked: locked, required: true),
      if (children.isNotEmpty)
        _categorySelector('subcategory_id', 'Subcategory', children,
            locked: locked, required: _incident),
      if (recordFlag(category?['sensitive']) || recordFlag(child?['sensitive']))
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(workText(context, 'Confidential')),
          contentPadding: EdgeInsets.zero,
        ),
      for (final field in fields.values)
        KeyedSubtree(
          key: ValueKey('${category?['id']}-${child?['id']}-${field['key']}'),
          child: _dynamicField(field),
        ),
      if (suggested.isNotEmpty)
        Wrap(spacing: 6, children: [
          for (final tag in suggested)
            FilterChip(
                label: Text(tag),
                selected: selectedTags.contains(tag),
                onSelected: (value) {
                  _data['tags_text_reset'] =
                      (_data['tags_text_reset'] as int? ?? 0) + 1;
                  if (value) {
                    selectedTags.add(tag);
                  } else {
                    selectedTags.remove(tag);
                  }
                  _change('tags_text',
                      selectedTags.where((item) => item.isNotEmpty).join(', '),
                      rebuild: true);
                }),
        ]),
    ];
  }

  Widget _relatedTask() => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.assignment_outlined),
        title: Text(workText(context, 'Related task')),
        subtitle: Text((_data['related_title'] ??
                _data['assignment_id'] ??
                workText(context, 'Choose'))
            .toString()),
        trailing: _data['assignment_id'] == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _data.remove('related_title');
                  _change('assignment_id', null, rebuild: true);
                },
              ),
        onTap: () async {
          final task = await pickRelatedTask(context, widget.api);
          if (!mounted || task == null) return;
          _data['related_title'] = task['title'];
          _change('assignment_id', task['id'], rebuild: true);
        },
      );

  Widget _categorySelector(
    String key,
    String label,
    List<RecordData> values, {
    required bool locked,
    required bool required,
  }) {
    final selected = _find(values, _data[key])?['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$key-${_data['category_id']}-$selected'),
        initialValue: selected == null ? null : recordNumber(selected),
        isExpanded: true,
        decoration: InputDecoration(labelText: workText(context, label)),
        items: [
          if (!required)
            DropdownMenuItem(
                value: 0, child: Text(workText(context, 'Choose'))),
          for (final value in values)
            DropdownMenuItem(
                value: recordNumber(value['id']),
                child: Text(classificationName(context, value),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: locked
            ? null
            : (value) {
                if (key == 'category_id') _data['subcategory_id'] = null;
                _data['fields'] = <String, dynamic>{};
                _change(key, value == 0 ? null : value, rebuild: true);
              },
        validator: (value) =>
            required && value == null ? workText(context, 'Required') : null,
      ),
    );
  }

  Widget _dynamicField(RecordData field) {
    final key = field['key'].toString();
    final label = (field[Localizations.localeOf(context).languageCode == 'km'
                ? 'label_km'
                : 'label_en'] ??
            key)
        .toString();
    final values = _data['fields'] as RecordData;
    final required = recordFlag(field['required']);
    final options =
        workList(field['options']).map((item) => item.toString()).toList();
    void change(Object? value) {
      final next = {...values};
      if (value == null || value == '') {
        next.remove(key);
      } else {
        next[key] = value;
      }
      _change('fields', next, rebuild: true);
    }

    final taken = recordMap(_data['fields'])[key];
    if (field['type'] == 'select') {
      return _choice(key, label, {for (final option in options) option: option},
          required: required, current: taken?.toString(), onChanged: change);
    }
    if (field['type'] == 'multi') {
      return FormField<List<String>>(
        validator: (_) =>
            required && workList(recordMap(_data['fields'])[key]).isEmpty
                ? workText(context, 'Required')
                : null,
        builder: (state) => InputDecorator(
          decoration:
              InputDecoration(labelText: label, errorText: state.errorText),
          child: Wrap(spacing: 6, children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: workList(taken).contains(option),
                onSelected: (selected) => change([
                  ...workList(taken).where((value) => value != option),
                  if (selected) option,
                ]),
              ),
          ]),
        ),
      );
    }
    if (field['type'] == 'date' || field['type'] == 'datetime') {
      return field['type'] == 'date'
          ? _date(key, label,
              required: required, current: taken?.toString(), onChanged: change)
          : _dateTime(key, label,
              required: required,
              current: taken?.toString(),
              onChanged: change);
    }
    return _text(key, label,
        required: required,
        lines: field['type'] == 'multiline' ? 3 : 1,
        limit: field['type'] == 'multiline' ? 3000 : 240,
        numeric: field['type'] == 'number',
        initial: taken?.toString(),
        onChanged: change);
  }

  Widget _text(String key, String label,
      {int lines = 1,
      int limit = 240,
      bool required = false,
      bool numeric = false,
      String? initial,
      ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key == 'tags_text' ? ValueKey(_data['tags_text_reset']) : null,
        initialValue: onChanged == null ? _data[key]?.toString() : initial,
        decoration: InputDecoration(labelText: workText(context, label)),
        minLines: lines,
        maxLines: lines > 1 ? lines + 3 : 1,
        maxLength: limit,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(signed: true, decimal: true)
            : null,
        validator: (value) {
          if (required && value?.trim().isNotEmpty != true)
            return workText(context, 'Required');
          if (numeric &&
              value?.trim().isNotEmpty == true &&
              num.tryParse(value!.trim()) == null)
            return workText(context, 'Enter a number');
          return null;
        },
        onChanged: onChanged ?? (value) => _change(key, value),
      ),
    );
  }

  Widget _choice(String key, String label, Map<String, String> options,
      {bool required = false,
      String? current,
      ValueChanged<String?>? onChanged}) {
    final value = onChanged == null ? _data[key]?.toString() : current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: workText(context, label)),
        items: [
          if (!required)
            DropdownMenuItem(
                value: '', child: Text(workText(context, 'Choose'))),
          for (final option in options.entries)
            DropdownMenuItem(
                value: option.key,
                child: Text(workText(context, option.value),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged ?? (value) => _change(key, value),
        validator: (value) =>
            required && value == null ? workText(context, 'Required') : null,
      ),
    );
  }

  Widget _dateTime(String key, String label,
      {bool required = false,
      String? current,
      ValueChanged<String?>? onChanged}) {
    final stored = onChanged == null ? _data[key]?.toString() : current;
    final change = onChanged ?? (value) => _change(key, value, rebuild: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RecordDateField(
        label: workText(context, label),
        required: required,
        value: stored == null ? null : DateTime.tryParse(stored),
        onChanged: (value) =>
            change(value == null ? null : recordDateField(value)),
      ),
    );
  }

  Widget _date(String key, String label,
      {bool required = false,
      String? current,
      ValueChanged<String?>? onChanged}) {
    final stored = onChanged == null ? _data[key]?.toString() : current;
    final change = onChanged ?? (value) => _change(key, value, rebuild: true);
    return FormField<String>(
      validator: (_) =>
          required && stored == null ? workText(context, 'Required') : null,
      builder: (state) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(workText(context, label)),
        subtitle:
            Text(state.errorText ?? stored ?? workText(context, 'Choose')),
        onTap: () async {
          final date = await chooseWorkDate(context, stored);
          if (date != null && mounted) change(date);
        },
      ),
    );
  }

  Widget _time(String key, String label) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_outlined),
        title: Text(workText(context, label)),
        subtitle: Text(_data[key]?.toString() ?? workText(context, 'Choose')),
        onTap: () async {
          final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_businessNow()));
          if (picked != null && mounted) {
            _change(key,
                "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}",
                rebuild: true);
          }
        },
      );

  RecordData? _find(List<RecordData> values, Object? id) => values
      .where((value) => value['id']?.toString() == id?.toString())
      .firstOrNull;
}

DateTime _businessNow() => DateTime.now().toUtc().add(const Duration(hours: 7));

String workToday() => DateFormat('yyyy-MM-dd').format(_businessNow());

Future<String?> chooseWorkDate(BuildContext context, String? selected) async {
  final current = DateTime.tryParse(selected ?? '') ?? _businessNow();
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(current.year, current.month, current.day),
    firstDate: DateTime(current.year - 10),
    lastDate: DateTime(current.year + 5, 12, 31),
  );
  return date == null ? null : DateFormat('yyyy-MM-dd').format(date);
}

String? _businessStamp(Object? value) {
  final date = recordBusinessTime(value);
  return date == null ? null : recordDateField(date);
}

Object? _decoded(Object? data) {
  if (data is! String) return data;
  try {
    return jsonDecode(data);
  } on FormatException {
    return null;
  }
}

RecordData workMap(Object? data) => recordMap(_decoded(data));
List<dynamic> workList(Object? data) =>
    _decoded(data) is List ? _decoded(data) as List : const [];
