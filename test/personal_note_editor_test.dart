import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/daily_records/daily_records_api.dart';
import 'package:cnattendance/features/daily_records/employee_records.dart';
import 'package:cnattendance/features/daily_records/record_theme.dart';
import 'package:cnattendance/features/daily_records/record_widgets.dart';
import 'package:cnattendance/features/daily_records/work_record_editor.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+lEuoAAAAASUVORK5CYII=');

class _Preferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';

  @override
  Future<String> getToken() async => 'token';
}

class _ImagePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult([
        PlatformFile(
            name: 'test.png',
            size: _png.length,
            readStream: Stream.value(_png)),
      ]);
}

http.Response _data(RecordData result, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode({'data': result})), status);

void main() {
  testWidgets('attachment source chooser follows every app theme',
      (tester) async {
    for (final mode in AppThemeMode.values) {
      await tester.pumpWidget(MaterialApp(
        theme: AppThemeData.themeData(mode),
        home: const Scaffold(
          body: RecordFilePicker(files: [], onChanged: _ignoreFiles),
        ),
      ));
      await tester.tap(find.text('Attach files'));
      await tester.pumpAndSettle();
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      Navigator.of(tester.element(find.text('Files'))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Formats an older description, uploads a private inline image, and reopens the note',
      (tester) async {
    FilePicker.platform = _ImagePicker();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<dynamic>? savedOperations;
    String? imageName;
    var downloads = 0;
    final api = DailyRecordsApi(
        preferences: _Preferences(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/work-records/7') &&
              request.method == 'POST') {
            final body = latin1.decode(request.bodyBytes);
            final match =
                RegExp(r'name="payload"\r\n\r\n([^\r]+)').firstMatch(body);
            final data = jsonDecode(match!.group(1)!) as RecordData;
            savedOperations =
                jsonDecode(data['note_document'] as String) as List<dynamic>;
            imageName = RegExp(r'filename="(note-image-[^"]+)"')
                .firstMatch(body)
                ?.group(1);
            expect(data['body'], 'Old description');
            expect(imageName, isNotNull);
            return _data({'id': 7});
          }
          if (request.url.path.endsWith('/files/9')) {
            expect(request.headers['Authorization'], 'Bearer token');
            downloads++;
            return http.Response.bytes(_png, 200);
          }
          if (request.url.path.endsWith('/records/7')) {
            return _data({
              'entry': {
                'id': 7,
                'kind': 'note',
                'title': 'Planning',
                'body': 'Old description',
                'revision': 2,
                'private': 1,
                'details': jsonEncode({'note_document': savedOperations}),
              },
              'files': [
                {'id': 9, 'name': imageName}
              ],
            });
          }
          return _data({});
        }));

    await tester.pumpWidget(MaterialApp(
      theme: AppThemeData.themeData(AppThemeMode.royalBlueGold),
      home: Builder(
          builder: (context) => Scaffold(
                  body: Column(children: [
                TextButton(
                    onPressed: () =>
                        Navigator.of(context).push<bool>(recordRoute(
                          builder: (_) => WorkRecordEditor(
                              api: api,
                              kind: 'note',
                              entry: const {
                                'id': 7,
                                'kind': 'note',
                                'title': 'Planning',
                                'body': 'Old description',
                                'revision': 1,
                              }),
                        )),
                    child: const Text('Edit')),
                TextButton(
                    onPressed: () =>
                        Navigator.of(context).push<void>(recordRoute(
                          builder: (_) => DailyRecordScreen(
                              api: api, id: 7, workRecords: true),
                        )),
                    child: const Text('Read')),
              ]))),
    ));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final editor =
        tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    final controller = editor.controller;
    expect(controller.document.toPlainText(), 'Old description\n');
    controller.formatText(0, 3, quill.Attribute.bold);
    controller.formatText(
        0, 3, quill.Attribute.fromKeyValue('font', 'GoogleSans')!);
    controller.formatText(
        4, 11, quill.LinkAttribute('https://example.test/reference'));
    controller.updateSelection(
        const TextSelection.collapsed(offset: 15), quill.ChangeSource.local);
    final insert = find.byTooltip('Insert image');
    await tester.ensureVisible(insert);
    await tester.tap(insert);
    await tester.pumpAndSettle();
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Remove image'), findsOneWidget);

    final save = find.text('Save record');
    if (save.evaluate().isEmpty) {
      await tester.scrollUntilVisible(save, 200,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
        savedOperations,
        contains(equals({
          'insert': 'Old',
          'attributes': {'bold': true, 'font': 'GoogleSans'},
        })));
    expect(
        savedOperations,
        contains(equals({
          'insert': 'description',
          'attributes': {'link': 'https://example.test/reference'},
        })));
    expect(
        savedOperations,
        contains(equals({
          'insert': {'image': imageName}
        })));

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    final reader =
        tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    expect(reader.controller.readOnly, true);
    expect(reader.controller.document.toDelta().toJson(), savedOperations);
    expect(downloads, 1);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreFiles(List<PlatformFile> _) {}
