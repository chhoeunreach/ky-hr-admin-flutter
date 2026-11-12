import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/video_cache_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late HttpServer upstream;
  late HttpClient client;
  late CommunityVideoCache cache;
  late Uri source;
  late Map<String, int> requests;
  late bool broken;
  late bool gzipManifest;
  Completer<void>? releaseChunk;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hrky-video-cache-test');
    requests = {};
    broken = false;
    gzipManifest = false;
    releaseChunk = null;
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source = Uri.parse(
        'http://127.0.0.1:${upstream.port}/storage/video-streams/v2/abc/master.m3u8');
    upstream.listen((request) async {
      final name = request.uri.pathSegments.last;
      requests[name] = (requests[name] ?? 0) + 1;
      if (name == 'master.m3u8') {
        final bytes = utf8
            .encode('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=190000\n144.m3u8\n');
        if (gzipManifest) {
          final compressed = gzip.encode(bytes);
          request.response.headers.set('Content-Encoding', 'gzip');
          request.response.contentLength = compressed.length;
          request.response.add(compressed);
        } else {
          request.response.add(bytes);
        }
      } else if (name == '144.m3u8') {
        request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\n144_00000.ts\n#EXTINF:2,\n144_00001.ts\n#EXT-X-ENDLIST\n');
      } else if (name.endsWith('.ts')) {
        if (broken) {
          request.response.statusCode = 503;
        } else {
          request.response.contentLength = 4096;
          final value = name.contains('00001') ? 2 : 1;
          if (releaseChunk != null) {
            request.response.bufferOutput = false;
            request.response.add(List.filled(2048, value));
            await request.response.flush();
            await releaseChunk!.future;
            request.response.add(List.filled(2048, value));
          } else {
            request.response.add(List.filled(4096, value));
          }
        }
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    client = HttpClient();
    cache = CommunityVideoCache(directory: directory);
  });

  tearDown(() async {
    if (releaseChunk != null && !releaseChunk!.isCompleted)
      releaseChunk!.complete();
    await cache.close();
    client.close(force: true);
    await upstream.close(force: true);
    await directory.delete(recursive: true);
  });

  Future<List<int>> get(Uri uri, {String? range, int status = 200}) async {
    final request = await client.getUrl(uri);
    if (range != null) request.headers.set('Range', range);
    final response = await request.close();
    expect(response.statusCode, status);
    return response.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  }

  test(
      'rewrites playlists locally and reuses segments after restarting the cache',
      () async {
    var local = await cache.playbackUri(source);
    var master = utf8.decode(await get(local));
    final variant = Uri.parse(
        master.split('\n').firstWhere((line) => line.startsWith('http')));
    final playlist = utf8.decode(await get(variant));
    final segment = Uri.parse(
        playlist.split('\n').firstWhere((line) => line.startsWith('http')));
    expect(segment.host, '127.0.0.1');
    expect(segment.port, local.port);
    expect(await get(segment), List.filled(4096, 1));
    expect(await get(segment), List.filled(4096, 1));
    expect(requests['144_00000.ts'], 1);
    await cache.close();
    cache = CommunityVideoCache(directory: directory);
    local = await cache.playbackUri(source);
    master = utf8.decode(await get(local));
    expect(master, contains(':${local.port}/'));
    final again = local.resolve('144_00000.ts');
    expect(await get(again), List.filled(4096, 1));
    expect(requests['master.m3u8'], 1);
    expect(requests['144_00000.ts'], 1);
  });

  test('gzip playlists are decoded and cached using the uncompressed length',
      () async {
    gzipManifest = true;
    final local = await cache.playbackUri(source);
    expect(utf8.decode(await get(local)), contains('144.m3u8'));
    expect(utf8.decode(await get(local)), startsWith('#EXTM3U'));
    expect(requests['master.m3u8'], 1);
  });

  test('first segment bytes stream before the entire download completes',
      () async {
    releaseChunk = Completer<void>();
    final segment = (await cache.playbackUri(source)).resolve('144_00000.ts');
    final response = await (await client.getUrl(segment)).close();
    final chunks = StreamIterator<List<int>>(response);
    expect(await chunks.moveNext().timeout(const Duration(seconds: 5)), isTrue);
    expect(chunks.current, List.filled(2048, 1));
    releaseChunk!.complete();
    while (await chunks.moveNext()) {}
    await cache.flush();
    expect(await get(segment), List.filled(4096, 1));
    expect(requests['144_00000.ts'], 1);
  });

  test('concurrent segment requests share a download and support byte ranges',
      () async {
    final local = await cache.playbackUri(source);
    final segment = local.resolve('144_00000.ts');
    final results = await Future.wait([get(segment), get(segment)]);
    expect(results.first, results.last);
    expect(requests['144_00000.ts'], 1);
    expect(await get(segment, range: 'bytes=10-19', status: 206),
        List.filled(10, 1));
    expect(
        await get(segment, range: 'bytes=-5', status: 206), List.filled(5, 1));
    await get(segment, range: 'bytes=99999-', status: 416);
    expect(requests['144_00000.ts'], 1);
  });

  test('failed segments are not cached and retry can recover', () async {
    final segment = (await cache.playbackUri(source)).resolve('144_00000.ts');
    broken = true;
    await get(segment, status: 502);
    expect(await directory.list().toList(), isEmpty);
    broken = false;
    expect(await get(segment), List.filled(4096, 1));
    expect(requests['144_00000.ts'], 2);
  });

  test('cache expiry downloads fresh bytes and disk usage stays bounded',
      () async {
    await cache.close();
    cache = CommunityVideoCache(directory: directory, maxBytes: 5000);
    final local = await cache.playbackUri(source);
    await get(local.resolve('144_00000.ts'));
    await cache.flush();
    await for (final file in directory.list()) {
      if (file is File)
        await file
            .setLastModified(DateTime.now().subtract(const Duration(days: 8)));
    }
    await get(local.resolve('144_00000.ts'));
    expect(requests['144_00000.ts'], 2);
    await get(local.resolve('144_00001.ts'));
    await cache.close();
    var size = 0;
    await for (final file in directory.list()) {
      size += (await file.stat()).size;
    }
    expect(size, lessThanOrEqualTo(5000));
  });

  test(
      'local server rejects unregistered routes and unrelated sources bypass it',
      () async {
    final local = await cache.playbackUri(source);
    await get(local.replace(path: '/wrong-token/144_00000.ts'), status: 404);
    await get(local.resolve('secret.txt'), status: 404);
    expect(requests, isEmpty);
    final remote = Uri.parse('https://elsewhere.test/video.mp4');
    expect(await cache.playbackUri(remote), remote);
    expect(await cache.playbackUri(source.replace(query: 'signed=secret')),
        source.replace(query: 'signed=secret'));
  });
}
