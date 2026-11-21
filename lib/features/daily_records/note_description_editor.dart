import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'daily_records_api.dart';
import 'record_widgets.dart';
import 'work_labels.dart';

List<dynamic>? noteOperations(Object? value) {
  try {
    final decoded = value is String ? jsonDecode(value) : value;
    return decoded is List && decoded.isNotEmpty ? decoded : null;
  } on FormatException {
    return null;
  }
}

Set<String> noteImageNames(List<dynamic>? operations) => {
      for (final operation in operations ?? const [])
        if (operation is Map && operation['insert'] is Map)
          if ((operation['insert'] as Map)['image'] case final String name)
            name,
    };

class NoteDescriptionEditor extends StatefulWidget {
  const NoteDescriptionEditor({
    super.key,
    required this.api,
    required this.plainText,
    this.operations,
    this.entryId,
    this.attachments = const [],
    this.pendingImages = const {},
    this.freeUploadSlots = 4,
    this.onImage,
    this.onChanged,
  });

  final DailyRecordsApi api;
  final String plainText;
  final List<dynamic>? operations;
  final int? entryId;
  final List<RecordData> attachments;
  final Map<String, PlatformFile> pendingImages;
  final int freeUploadSlots;
  final void Function(PlatformFile file)? onImage;
  final void Function(String document, String plainText)? onChanged;

  bool get readOnly => onChanged == null;

  @override
  State<NoteDescriptionEditor> createState() => _NoteDescriptionEditorState();
}

class _NoteDescriptionEditorState extends State<NoteDescriptionEditor> {
  static const _maxImageBytes = 10 * 1024 * 1024;
  late final quill.QuillController _controller = quill.QuillController(
    document: _document(),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: widget.readOnly,
    config: const quill.QuillControllerConfig(
      // Accept clipboard text without importing external HTML or image URLs.
      // ignore: experimental_member_use
      clipboardConfig: quill.QuillClipboardConfig(
        // ignore: experimental_member_use
        enableExternalRichPaste: false,
      ),
    ),
  );
  final _focus = FocusNode();
  late String _lastDocument;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _lastDocument = jsonEncode(_controller.document.toDelta().toJson());
    _controller.addListener(_changed);
  }

  quill.Document _document() {
    final operations = widget.operations;
    if (operations != null) {
      try {
        return quill.Document.fromJson(operations);
      } catch (_) {
        // Older or incomplete documents can still open using the plain-text copy.
      }
    }
    final text = widget.plainText;
    return quill.Document.fromJson([
      {'insert': text.endsWith('\n') ? text : '$text\n'},
    ]);
  }

  void _changed() {
    if (widget.readOnly) return;
    final operations = _controller.document.toDelta().toJson();
    final document = jsonEncode(operations);
    if (document == _lastDocument) return;
    _lastDocument = document;
    final plain = [
      for (final operation in operations)
        if (operation['insert'] is String)
          operation['insert'] as String
        else
          '\n',
    ].join().trim();
    widget.onChanged?.call(document, plain);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _insertImage() async {
    if (_picking) return;
    final referenced = noteImageNames(_controller.document.toDelta().toJson());
    if (referenced.where(widget.pendingImages.containsKey).length >=
        widget.freeUploadSlots) {
      showRecordError(
          context,
          const DailyRecordsError(
              'A note can upload up to four files at a time.'));
      return;
    }
    setState(() => _picking = true);
    try {
      final source = await showRecordAttachmentSourcePicker(
        context,
        title: 'Insert image',
        description: 'Choose an image from Files or your Gallery.',
      );
      if (!mounted || source == null) return;

      PlatformFile image;
      Uint8List? galleryBytes;
      if (source == RecordAttachmentSource.gallery) {
        final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
          imageQuality: 95,
          maxWidth: 4096,
          maxHeight: 4096,
        );
        if (selected == null || !mounted) return;
        final size = await selected.length();
        if (size > _maxImageBytes) {
          throw const DailyRecordsError('Choose an image under 10 MB.');
        }
        galleryBytes = await selected.readAsBytes();
        image = PlatformFile(
          name: selected.name,
          size: size,
          bytes: galleryBytes,
        );
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withReadStream: true,
        );
        if (!mounted || result == null || result.files.isEmpty) return;
        image = result.files.single;
      }
      final extension = image.extension?.toLowerCase();
      if (image.size > _maxImageBytes ||
          !const ['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw const DailyRecordsError(
            'Choose a JPG, PNG, or WebP image under 10 MB.');
      }
      final bytes = galleryBytes ?? await _readImage(image);
      if (!mounted) return;
      final name = 'note-image-${const Uuid().v4()}.$extension';
      widget.onImage
          ?.call(PlatformFile(name: name, bytes: bytes, size: bytes.length));
      final selection = _controller.selection;
      final max = _controller.document.length - 1;
      final offset = selection.start.clamp(0, max);
      _controller.replaceText(
        offset,
        0,
        quill.BlockEmbed.image(name),
        TextSelection.collapsed(offset: offset + 1),
      );
    } catch (error) {
      if (mounted) showRecordError(context, error);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<Uint8List> _readImage(PlatformFile file) async {
    final bytes = BytesBuilder(copy: false);
    final stream = file.readStream ??
        (file.bytes == null
            ? const Stream<List<int>>.empty()
            : Stream.value(file.bytes!));
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > _maxImageBytes) {
        throw const DailyRecordsError('Choose an image under 10 MB.');
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) {
      throw const DailyRecordsError('The selected image could not be read.');
    }
    return bytes.takeBytes();
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The current platform can decline handing the link off to a browser.
    }
    if (mounted)
      showRecordError(
          context, const DailyRecordsError('Unable to open the link.'));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = quill.QuillEditor.basic(
      controller: _controller,
      focusNode: _focus,
      config: quill.QuillEditorConfig(
        scrollable: false,
        minHeight: widget.readOnly ? null : 156,
        padding: widget.readOnly ? EdgeInsets.zero : const EdgeInsets.all(12),
        placeholder:
            widget.readOnly ? null : workText(context, 'Write your note'),
        onLaunchUrl: _openLink,
        customStyleBuilder: (attribute) => attribute.key == 'link'
            ? TextStyle(color: scheme.primary, decorationColor: scheme.primary)
            : const TextStyle(),
        embedBuilders: [
          _NoteImageBuilder(
            api: widget.api,
            entryId: widget.entryId,
            attachments: widget.attachments,
            pending: widget.pendingImages,
          ),
        ],
        unknownEmbedBuilder: const _UnsupportedNoteEmbed(),
      ),
    );
    return Localizations.override(
      context: context,
      delegates: const [_NoteQuillDelegate()],
      child: widget.readOnly
          ? editor
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(workText(context, 'Description'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: scheme.surfaceContainerLow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: quill.QuillSimpleToolbar(
                          controller: _controller,
                          config: quill.QuillSimpleToolbarConfig(
                            multiRowsDisplay: true,
                            toolbarRunSpacing: 0,
                            showDividers: false,
                            showSubscript: false,
                            showSuperscript: false,
                            showInlineCode: false,
                            showCodeBlock: false,
                            showSearchButton: false,
                            showListCheck: false,
                            showIndent: false,
                            showQuote: false,
                            customButtons: [
                              quill.QuillToolbarCustomButtonOptions(
                                tooltip: workText(context, 'Insert image'),
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                onPressed: _picking ? null : _insertImage,
                              ),
                            ],
                            buttonOptions:
                                const quill.QuillSimpleToolbarButtonOptions(
                              fontFamily:
                                  quill.QuillToolbarFontFamilyButtonOptions(
                                defaultDisplayText: 'Font',
                                items: {
                                  'Google Sans': 'GoogleSans',
                                  'Serif': 'serif',
                                  'Monospace': 'monospace'
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      editor,
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _NoteQuillDelegate
    extends LocalizationsDelegate<quill.FlutterQuillLocalizations> {
  const _NoteQuillDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<quill.FlutterQuillLocalizations> load(Locale locale) {
    const delegate = quill.FlutterQuillLocalizations.delegate;
    return delegate
        .load(delegate.isSupported(locale) ? locale : const Locale('en'));
  }

  @override
  bool shouldReload(_NoteQuillDelegate old) => false;
}

class _NoteImageBuilder extends quill.EmbedBuilder {
  const _NoteImageBuilder({
    required this.api,
    required this.entryId,
    required this.attachments,
    required this.pending,
  });

  final DailyRecordsApi api;
  final int? entryId;
  final List<RecordData> attachments;
  final Map<String, PlatformFile> pending;

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embed) {
    final name = embed.node.value.data.toString();
    final local = pending[name]?.bytes;
    final match = attachments.where((file) => file['name'] == name).firstOrNull;
    final path = entryId == null || match == null
        ? null
        : 'records/$entryId/files/${match['id']}';
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (local != null)
              _picture(local)
            else if (path != null)
              _SavedNoteImage(key: ValueKey(path), api: api, path: path)
            else
              Text(workText(context, 'Image unavailable')),
            if (!embed.readOnly)
              TextButton.icon(
                onPressed: () {
                  final offset = embed.node.documentOffset;
                  embed.controller.replaceText(
                    offset,
                    1,
                    '',
                    TextSelection.collapsed(offset: offset),
                  );
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(workText(context, 'Remove image')),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _picture(Uint8List bytes) => Image.memory(
      bytes,
      fit: BoxFit.contain,
      cacheWidth: 1200,
      height: 210,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Note image',
      errorBuilder: (context, error, stackTrace) =>
          Text(workText(context, 'Image unavailable')),
    );

class _SavedNoteImage extends StatefulWidget {
  const _SavedNoteImage({super.key, required this.api, required this.path});
  final DailyRecordsApi api;
  final String path;

  @override
  State<_SavedNoteImage> createState() => _SavedNoteImageState();
}

class _SavedNoteImageState extends State<_SavedNoteImage> {
  late Future<Uint8List> _image = widget.api.attachment(widget.path);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasData) return _picture(snapshot.data!);
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () {
                setState(() {
                  _image = widget.api.attachment(widget.path);
                });
              },
              child: Text(workText(context, 'Retry image')),
            );
          }
          return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
}

class _UnsupportedNoteEmbed extends quill.EmbedBuilder {
  const _UnsupportedNoteEmbed();

  @override
  String get key => 'unsupported';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) =>
      Text(workText(context, 'Image unavailable'));
}
