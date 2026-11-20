import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'record_widgets.dart';

typedef RecordDetailBuilder = List<Widget> Function(
    BuildContext context, RecordData data, RecordDetailState detail);

class RecordDetail extends StatefulWidget {
  const RecordDetail({
    super.key,
    required this.api,
    required this.path,
    required this.title,
    required this.builder,
    this.query = const {},
  });

  final DailyRecordsApi api;
  final String path;
  final String title;
  final RecordDetailBuilder builder;
  final Map<String, String> query;

  @override
  State<RecordDetail> createState() => RecordDetailState();
}

class RecordDetailState extends State<RecordDetail> {
  RecordData? _data;
  Object? _error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() =>
      _run(() => widget.api.get(widget.path, widget.query));

  Future<bool> action(RecordData fields,
          {List<PlatformFile> files = const []}) =>
      _run(() =>
          widget.api.post('${widget.path}/actions', fields, files: files));

  Future<void> more(String key) {
    final current = recordMap(_data?[key]);
    if (current['next_page_url'] == null) return Future.value();
    final page = recordNumber(current['current_page']) + 1;
    return _run(() async {
      final result = await widget.api.get(widget.path, {
        ...widget.query,
        if (key == 'history') 'history': '$page',
        if (key == 'entries') 'records': '$page',
        if (key == 'tasks') 'task_page': '$page',
        if (key == 'versions') 'versions': '$page',
      });
      final next = recordMap(result[key]);
      return {
        ..._data!,
        key: {
          ...next,
          'data': [...recordRows(current['data']), ...recordRows(next['data'])],
        },
      };
    });
  }

  Future<bool> _run(Future<RecordData> Function() operation) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      final data = await operation();
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
      return true;
    } catch (error) {
      if (mounted) {
        if (_data == null) {
          setState(() => _error = error);
        } else {
          showRecordError(context, error);
        }
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PopScope(
      canPop: !busy || data == null,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              onPressed: busy ? null : refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: data == null
            ? (_error == null || busy
                ? const Center(child: CircularProgressIndicator())
                : RecordFailure(error: _error, retry: refresh))
            : Column(children: [
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: IgnorePointer(
                    ignoring: busy,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: widget.builder(context, data, this),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }
}

Future<void> promptRecordMessage(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  bool allowFiles = true,
  required Future<bool> Function(String message, List<PlatformFile> files) save,
}) =>
    Navigator.of(context).push<void>(recordRoute(
      fullscreenDialog: true,
      builder: (_) => _RecordMessageForm(
        title: title,
        label: label,
        action: action,
        allowFiles: allowFiles,
        save: save,
      ),
    ));

class _RecordMessageForm extends StatefulWidget {
  const _RecordMessageForm({
    required this.title,
    required this.label,
    required this.action,
    required this.save,
    required this.allowFiles,
  });

  final String title;
  final String label;
  final String action;
  final bool allowFiles;
  final Future<bool> Function(String message, List<PlatformFile> files) save;

  @override
  State<_RecordMessageForm> createState() => _RecordMessageFormState();
}

class _RecordMessageFormState extends State<_RecordMessageForm> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  List<PlatformFile> _files = [];
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await widget.save(_message.text.trim(), _files);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _message,
                  decoration: InputDecoration(labelText: widget.label),
                  minLines: 4,
                  maxLines: 9,
                  maxLength: 10000,
                  readOnly: _saving,
                  validator: (text) => text?.trim().isNotEmpty == true
                      ? null
                      : 'Enter a message',
                ),
                if (widget.allowFiles)
                  IgnorePointer(
                    ignoring: _saving,
                    child: RecordFilePicker(
                        files: _files,
                        onChanged: (files) => setState(() => _files = files)),
                  ),
                recordSpacing,
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : widget.action),
                ),
              ],
            ),
          ),
        ),
      );
}
