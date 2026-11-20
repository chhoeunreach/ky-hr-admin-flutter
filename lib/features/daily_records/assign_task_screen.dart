import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'record_widgets.dart';

class AssignEmployeeTaskScreen extends StatefulWidget {
  const AssignEmployeeTaskScreen({super.key, required this.api});
  final DailyRecordsApi api;

  @override
  State<AssignEmployeeTaskScreen> createState() =>
      _AssignEmployeeTaskScreenState();
}

class _AssignEmployeeTaskScreenState extends State<AssignEmployeeTaskScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _checklist = TextEditingController();
  final _requestId = const Uuid().v4();
  late Future<RecordData> _groups = widget.api.get('groups');
  Map<int, String> _employees = {};
  int _department = 0;
  int _location = 0;
  String _priority = 'normal';
  String _frequency = '';
  DateTime? _due;
  DateTime? _reminder;
  List<PlatformFile> _files = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _checklist.dispose();
    super.dispose();
  }

  Future<void> _chooseEmployees() async {
    final selected =
        await Navigator.of(context).push<Map<int, String>>(recordRoute(
      builder: (_) => _EmployeePicker(api: widget.api, selected: _employees),
    ));
    if (mounted && selected != null) setState(() => _employees = selected);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_employees.isEmpty && _department == 0 && _location == 0) {
      showRecordError(
          context,
          const DailyRecordsError(
              'Select employees, a department, or a location.'));
      return;
    }
    final checklist = _checklist.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (checklist.length > 40 || checklist.any((item) => item.length > 240)) {
      showRecordError(
          context,
          const DailyRecordsError(
              'Use up to 40 checklist items, 240 characters each.'));
      return;
    }
    if (_reminder != null && !_reminder!.isBefore(_due!)) {
      showRecordError(context,
          const DailyRecordsError('The reminder must be before the deadline.'));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.post(
          'assign',
          {
            'request_id': _requestId,
            'title': _title.text.trim(),
            'instructions': _instructions.text.trim(),
            'priority': _priority,
            'due_at': recordDateField(_due!),
            if (_reminder != null) 'remind_at': recordDateField(_reminder!),
            if (_frequency.isNotEmpty) 'frequency': _frequency,
            'checklist': checklist,
            if (_employees.isNotEmpty) 'employee_ids': _employees.keys.toList(),
            if (_department != 0) 'department_id': _department,
            if (_location != 0) 'branch_id': _location,
          },
          files: _files);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop(true);
      }
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
          appBar: AppBar(title: const Text('Assign Employee Task')),
          body: FutureBuilder<RecordData>(
            future: _groups,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return RecordFailure(
                  error: snapshot.error,
                  retry: () =>
                      setState(() => _groups = widget.api.get('groups')),
                );
              final groups = snapshot.data!;
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _title,
                      maxLength: 180,
                      decoration:
                          const InputDecoration(labelText: 'Task title'),
                      validator: (text) => text?.trim().isNotEmpty == true
                          ? null
                          : 'Enter a task title',
                    ),
                    const RecordHeading('Assign to'),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _chooseEmployees,
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('Choose employees'),
                    ),
                    if (_employees.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final employee in _employees.entries)
                            InputChip(
                              label: Text(employee.value),
                              onDeleted: _saving
                                  ? null
                                  : () => setState(
                                      () => _employees.remove(employee.key)),
                            ),
                        ],
                      ),
                    recordSpacing,
                    _group('Department', _department, groups['departments'],
                        (value) => setState(() => _department = value)),
                    recordSpacing,
                    _group('Location', _location, groups['locations'],
                        (value) => setState(() => _location = value)),
                    const SizedBox(height: 8),
                    const Text(
                        'Choose a department or location to assign to everyone you manage in that group.'),
                    recordSpacing,
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: ['low', 'normal', 'high', 'urgent']
                          .map((priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(recordLabel(priority))))
                          .toList(),
                      onChanged: (value) => setState(() => _priority = value!),
                    ),
                    recordSpacing,
                    RecordDateField(
                        label: 'Deadline',
                        value: _due,
                        required: true,
                        onChanged: (value) => setState(() => _due = value)),
                    recordSpacing,
                    RecordDateField(
                        label: 'Reminder',
                        value: _reminder,
                        onChanged: (value) =>
                            setState(() => _reminder = value)),
                    recordSpacing,
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Repeat'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Once')),
                        for (final frequency in ['daily', 'weekly', 'monthly'])
                          DropdownMenuItem(
                              value: frequency,
                              child: Text(recordLabel(frequency))),
                      ],
                      onChanged: (value) => setState(() => _frequency = value!),
                    ),
                    recordSpacing,
                    TextFormField(
                      controller: _instructions,
                      decoration:
                          const InputDecoration(labelText: 'Instructions'),
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 10000,
                    ),
                    recordSpacing,
                    TextFormField(
                      controller: _checklist,
                      decoration: const InputDecoration(
                          labelText: 'Checklist',
                          helperText: 'Enter one item per line'),
                      minLines: 3,
                      maxLines: 7,
                    ),
                    recordSpacing,
                    RecordFilePicker(
                        files: _files,
                        onChanged: (files) => setState(() => _files = files)),
                    recordSpacing,
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Assigning…' : 'Assign task'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

  Widget _group(
          String label, int value, Object? data, ValueChanged<int> changed) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: 0, child: Text('Any ${label.toLowerCase()}')),
          for (final group in recordRows(data))
            DropdownMenuItem(
                value: recordNumber(group['id']),
                child: Text(group['name'].toString(),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (value) => changed(value!),
      );
}

class _EmployeePicker extends StatefulWidget {
  const _EmployeePicker({required this.api, required this.selected});
  final DailyRecordsApi api;
  final Map<int, String> selected;

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  final _search = TextEditingController();
  late final _selected = {...widget.selected};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch() {
    setState(() => _query = _search.text.trim());
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Choose employees'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text('Done (${_selected.length})')),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  labelText: 'Employee name',
                  suffixIcon: IconButton(
                      onPressed: _submitSearch,
                      tooltip: 'Search',
                      icon: const Icon(Icons.search)),
                ),
              ),
            ),
            Expanded(
                child: RecordList(
              query: _query,
              empty: 'No authorized employees found.',
              load: (page) => widget.api
                  .get('employees', {'search': _query, 'page': '$page'}),
              itemBuilder: (context, employee) {
                final id = recordNumber(employee['id']);
                final name = employee['name'].toString();
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: Text([employee['department'], employee['location']]
                      .whereType<String>()
                      .join(' · ')),
                  value: _selected.containsKey(id),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _selected[id] = name;
                    } else {
                      _selected.remove(id);
                    }
                  }),
                );
              },
            )),
          ],
        ),
      );
}
