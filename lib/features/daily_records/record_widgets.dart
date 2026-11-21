import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'daily_records_api.dart';

const recordSpacing = SizedBox(height: 16);

class RecordScaffold extends StatelessWidget {
  const RecordScaffold({super.key, required this.appBar, required this.body});

  final PreferredSizeWidget appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar,
        body: SafeArea(top: false, child: body),
      );
}

void showRecordError(BuildContext context, Object error) {
  final message = error is DailyRecordsError
      ? error.message
      : 'Daily Records is unavailable. Check your connection and try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class RecordFailure extends StatelessWidget {
  const RecordFailure({super.key, required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                error is DailyRecordsError
                    ? error.toString()
                    : 'Unable to load Daily Records.',
                textAlign: TextAlign.center),
            TextButton(onPressed: retry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class RecordList extends StatefulWidget {
  const RecordList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.query,
  });

  final Future<RecordData> Function(int page) load;
  final Widget Function(BuildContext context, RecordData data) itemBuilder;
  final String empty;
  final Object? query;

  @override
  State<RecordList> createState() => RecordListState();
}

class RecordListState extends State<RecordList> {
  final _rows = <RecordData>[];
  Object? _error;
  int _generation = 0;
  int _page = 0;
  bool _more = true;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant RecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) refresh();
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> _load({bool reset = false}) async {
    final generation = ++_generation;
    setState(() {
      if (reset) {
        _rows.clear();
        _page = 0;
        _more = true;
      }
      _busy = true;
      _error = null;
    });
    final page = _page + 1;
    try {
      final result = await widget.load(page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows.addAll(recordRows(result['data']));
        _more = result['next_page_url'] != null;
        _page = page;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty && _error != null) {
      return RecordFailure(error: _error, retry: refresh);
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _rows.length + 1,
        itemBuilder: (context, index) {
          if (index < _rows.length)
            return widget.itemBuilder(context, _rows[index]);
          if (_busy) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_more) {
            return TextButton(
              onPressed: _load,
              child: Text(_error == null ? 'Load more' : 'Retry loading more'),
            );
          }
          if (_rows.isEmpty) {
            return Padding(
                padding: const EdgeInsets.all(24), child: Text(widget.empty));
          }
          return const SizedBox(height: 12);
        },
      ),
    );
  }
}

class RecordDateField extends StatelessWidget {
  const RecordDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;

  Future<void> _choose(BuildContext context) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final current = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 5, 12, 31),
    );
    if (!context.mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null || !context.mounted) return;
    onChanged(
        DateTime.utc(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      validator: (_) =>
          required && value == null ? 'Choose a date and time' : null,
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _choose(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '$label (ICT)',
            prefixIcon: const Icon(Icons.event_outlined),
            errorText: state.errorText,
            suffixIcon: value != null && !required
                ? IconButton(
                    tooltip: 'Clear $label',
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.clear),
                  )
                : null,
          ),
          child: Text(value == null
              ? 'Choose date and time'
              : DateFormat('dd MMM yyyy, HH:mm').format(value!)),
        ),
      ),
    );
  }
}

String recordDateField(DateTime value) =>
    DateFormat("yyyy-MM-dd'T'HH:mm").format(value);

enum RecordAttachmentSource { files, gallery }

Future<RecordAttachmentSource?> showRecordAttachmentSourcePicker(
  BuildContext context, {
  String title = 'Add attachment',
  String description = 'Choose where to select your attachment.',
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<RecordAttachmentSource>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      )),
              const SizedBox(height: 16),
              _AttachmentSourceTile(
                icon: Icons.folder_open_rounded,
                title: 'Files',
                subtitle: 'Browse documents and files on your device',
                onTap: () =>
                    Navigator.pop(context, RecordAttachmentSource.files),
              ),
              const SizedBox(height: 8),
              _AttachmentSourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                subtitle: 'Choose photos from your gallery',
                onTap: () =>
                    Navigator.pop(context, RecordAttachmentSource.gallery),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AttachmentSourceTile extends StatelessWidget {
  const _AttachmentSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class RecordFilePicker extends StatelessWidget {
  const RecordFilePicker(
      {super.key, required this.files, required this.onChanged});
  final List<PlatformFile> files;
  final ValueChanged<List<PlatformFile>> onChanged;

  Future<void> _pick(BuildContext context) async {
    try {
      final source = await showRecordAttachmentSourcePicker(context);
      if (!context.mounted || source == null) return;

      List<PlatformFile> selected;
      if (source == RecordAttachmentSource.files) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'txt',
            'csv',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx'
          ],
          allowMultiple: true,
          withData: kIsWeb,
        );
        if (result == null) return;
        selected = result.files;
      } else {
        final images = await ImagePicker().pickMultiImage(
          requestFullMetadata: false,
          imageQuality: 95,
          maxWidth: 4096,
          maxHeight: 4096,
        );
        if (images.isEmpty || !context.mounted) return;
        selected = [];
        for (final image in images) {
          final extension = image.name.split('.').last.toLowerCase();
          if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
            throw const DailyRecordsError(
                'Gallery images must be JPG, PNG, or WebP.');
          }
          selected.add(PlatformFile(
            name: image.name,
            size: await image.length(),
            path: kIsWeb ? null : image.path,
            bytes: kIsWeb ? await image.readAsBytes() : null,
          ));
        }
      }

      if (!context.mounted || selected.isEmpty) return;
      final next = [...files, ...selected];
      if (next.length > 4 || next.any((file) => file.size > 10 * 1024 * 1024)) {
        throw const DailyRecordsError('Choose up to four files of 10 MB each.');
      }
      onChanged(next);
    } catch (error) {
      if (context.mounted) showRecordError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: files.length < 4 ? () => _pick(context) : null,
          icon: const Icon(Icons.attach_file),
          label: const Text('Attach files'),
        ),
        for (final (index, file) in files.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(file.name),
            trailing: IconButton(
              tooltip: 'Remove attachment',
              onPressed: () => onChanged([...files]..removeAt(index)),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }
}

class RecordAttachments extends StatelessWidget {
  const RecordAttachments(
      {super.key, required this.api, required this.path, required this.files});

  final DailyRecordsApi api;
  final String path;
  final List<RecordData> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RecordHeading('Attachments'),
        for (final file in files)
          Builder(
              builder: (context) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text((file['name'] ?? 'Attachment').toString()),
                    trailing: const Icon(Icons.download_outlined),
                    onTap: () => _download(context, file),
                  )),
      ],
    );
  }

  Future<void> _download(BuildContext context, RecordData file) async {
    try {
      final data = await api.attachment('$path/files/${file['id']}');
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final filename = (file['name'] ?? 'Attachment')
          .toString()
          .split(RegExp(r'[/\\]'))
          .last;
      await Share.shareXFiles(
        [XFile.fromData(data, mimeType: 'application/octet-stream')],
        fileNameOverrides: [filename],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      if (context.mounted) showRecordError(context, error);
    }
  }
}

class RecordHeading extends StatelessWidget {
  const RecordHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class RecordHistory extends StatelessWidget {
  const RecordHistory({super.key, required this.page, required this.onMore});
  final RecordData page;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final events = recordRows(page['data']);
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RecordHeading('Activity history'),
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(recordLabel(event['action'])),
            subtitle: Text(_description(event)),
          ),
        if (page['next_page_url'] != null)
          TextButton(
              onPressed: onMore, child: const Text('Load earlier activity')),
      ],
    );
  }

  String _description(RecordData event) {
    final details = recordMap(jsonDecode(event['details']?.toString() ?? '{}'));
    return [
      recordDate(event['created_at']),
      if (details['message'] != null) details['message'].toString(),
      if (details['progress'] != null) '${details['progress']}%',
      if (details['due_at'] != null)
        'Deadline ${recordDate(details['due_at'])}',
    ].join('\n');
  }
}
