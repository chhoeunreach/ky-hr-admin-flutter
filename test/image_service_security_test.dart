import 'dart:io';

import 'package:cnattendance/services/image_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File image;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ky-image-security-');
    image = File('${directory.path}/image.jpg');
    await image.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('unconfigured upload endpoint makes no network request', () async {
    var requestCount = 0;
    final dio = Dio(BaseOptions(followRedirects: true))
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.next(options);
        },
      ));
    final service = ImageService(dio: dio);

    expect(dio.options.followRedirects, isFalse);
    expect(await service.uploadImageFile(image.path), isFalse);
    expect(requestCount, 0);
  });

  test('HTTP and unpinned hosts are rejected before upload', () async {
    var requestCount = 0;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.next(options);
        },
      ));

    final insecure =
        ImageService(dio: dio, uploadUri: Uri.http('kneayerng.com', '/upload'));
    final missingPins = ImageService(
        dio: dio, uploadUri: Uri.https('kneayerng.com', '/upload'));
    final unpinned = ImageService(
        dio: dio, uploadUri: Uri.https('api.example.com', '/upload'));

    expect(await insecure.uploadImageFile(image.path), isFalse);
    expect(await missingPins.uploadImageFile(image.path), isFalse);
    expect(await unpinned.uploadImageFile(image.path), isFalse);
    expect(requestCount, 0);
  });
}
