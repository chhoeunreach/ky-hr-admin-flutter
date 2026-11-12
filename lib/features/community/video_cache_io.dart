import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// On-demand cache for our immutable HLS playlists and transport stream segments.
/// A loopback server lets both native players reuse the same bounded disk cache.
class CommunityVideoCache {
  CommunityVideoCache(
      {Directory? directory,
      this.maxBytes = 100 * 1024 * 1024,
      this.maxAge = const Duration(days: 7)})
      : _directory = directory;

  static final instance = CommunityVideoCache();
  final int maxBytes;
  final Duration maxAge;
  Directory? _directory;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final _roots = <String, Uri>{};
  final _pending = <String, Future<File>>{};
  final _token = List.generate(24, (_) => Random.secure().nextInt(256))
      .map((n) => n.toRadixString(16).padLeft(2, '0'))
      .join();
  HttpServer? _server;
  Future<void>? _starting;
  Future<void>? _trimming;
  bool _closed = false;

  static bool _fileName(String name) =>
      RegExp(r'^(?:master|[0-9]+)\.m3u8$|^[0-9]+_[0-9]+\.ts$').hasMatch(name);

  Future<Uri> playbackUri(Uri source) async {
    if (!['http', 'https'].contains(source.scheme) ||
        source.userInfo.isNotEmpty ||
        source.hasQuery ||
        !source.path.startsWith('/storage/video-streams/') ||
        !source.path.endsWith('/master.m3u8')) return source;
    try {
      await (_starting ??= _start());
      if (_closed) return source;
      final root = source.resolve('.');
      final id = sha256.convert(utf8.encode(root.toString())).toString();
      _roots[id] = root;
      return _local(id, 'master.m3u8');
    } catch (_) {
      _starting = null;
      return source; // Cache failures must not prevent native network playback.
    }
  }

  Future<void> _start() async {
    _directory ??= Directory(
        '${(await getTemporaryDirectory()).path}/hrky-video-cache-v1');
    await _directory!.create(recursive: true);
    if (_closed) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) => unawaited(_serve(request)));
    unawaited(_trim());
  }

  Uri _local(String id, String name) => Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _server!.port,
      path: '/$_token/$id/$name');

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      final parts = request.uri.pathSegments;
      if (!['GET', 'HEAD'].contains(request.method) ||
          parts.length != 3 ||
          parts[0] != _token ||
          !_roots.containsKey(parts[1]) ||
          !_fileName(parts[2])) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final uri = _roots[parts[1]]!.resolve(parts[2]);
      final manifest = parts[2].endsWith('.m3u8');
      response.headers.set(HttpHeaders.contentTypeHeader,
          manifest ? 'application/vnd.apple.mpegurl' : 'video/mp2t');
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final range = request.headers.value(HttpHeaders.rangeHeader);
      // Stream uncached segments through as they arrive, preserving network timing.
      // Simultaneous requests wait for the same download instead of spending data twice.
      if (!manifest && request.method == 'GET' && range == null) {
        final cached = await _cached(uri);
        if (cached != null) {
          await _sendFile(response, cached);
        } else if (_pending.containsKey(uri.toString())) {
          await _sendFile(response, await _pending[uri.toString()]!);
        } else {
          final task = _download(uri, response: response);
          _pending[uri.toString()] = task;
          try {
            await task;
          } finally {
            _pending.remove(uri.toString());
          }
        }
      } else {
        final file = await _file(uri);
        if (manifest) {
          final bytes =
              utf8.encode(_rewrite(await file.readAsString(), parts[1]));
          response.contentLength = bytes.length;
          if (request.method != 'HEAD') response.add(bytes);
        } else {
          await _sendFile(response, file,
              range: range, head: request.method == 'HEAD');
        }
      }
    } catch (_) {
      // The native player's existing stream-error handler switches to the original.
      try {
        response.statusCode = HttpStatus.badGateway;
      } catch (_) {}
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  String _rewrite(String text, String id) {
    if (!text.startsWith('#EXTM3U'))
      throw const FormatException('Invalid playlist');
    return text.split('\n').map((raw) {
      final line = raw.trim();
      if (line.isEmpty) return line;
      if (line.startsWith('#')) {
        // Our generated MPEG-TS VOD has no encryption keys, maps or external URIs.
        if (line.contains('URI='))
          throw const FormatException('Unsupported playlist');
        return line;
      }
      if (!_fileName(line))
        throw const FormatException('Unexpected segment URL');
      return _local(id, line).toString();
    }).join('\n');
  }

  File _path(Uri uri) => File(
      '${_directory!.path}/${sha256.convert(utf8.encode(uri.toString()))}.cache');

  Future<File?> _cached(Uri uri) async {
    final file = _path(uri);
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;
      if (DateTime.now().difference(stat.modified) > maxAge) {
        await file.delete();
        return null;
      }
      await file.setLastModified(DateTime.now());
      return file;
    } on FileSystemException {
      return null;
    }
  }

  Future<File> _file(Uri uri) async {
    final cached = await _cached(uri);
    if (cached != null) return cached;
    final key = uri.toString();
    final pending = _pending[key];
    if (pending != null) return pending;
    final task = _download(uri);
    _pending[key] = task;
    try {
      return await task;
    } finally {
      _pending.remove(key);
    }
  }

  Future<File> _download(Uri uri, {HttpResponse? response}) async {
    final file = _path(uri);
    final partial = File('${file.path}.part');
    IOSink? sink;
    try {
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final upstream =
          await request.close().timeout(const Duration(seconds: 20));
      if (upstream.statusCode != HttpStatus.ok) {
        await upstream.listen(null).cancel();
        throw const HttpException('Video download failed');
      }
      final limit = uri.path.endsWith('.m3u8') ? 1024 * 1024 : 8 * 1024 * 1024;
      final expectedLength = upstream.compressionState ==
              HttpClientResponseCompressionState.decompressed
          ? -1
          : upstream.contentLength;
      if (expectedLength > limit) {
        await upstream.listen(null).cancel();
        throw const HttpException('Video segment too large');
      }
      if (response != null) {
        response.bufferOutput = false;
        if (expectedLength >= 0) response.contentLength = expectedLength;
      }
      sink = partial.openWrite();
      var length = 0;
      await for (final chunk in upstream.timeout(const Duration(seconds: 30))) {
        length += chunk.length;
        if (length > limit)
          throw const HttpException('Video segment too large');
        sink.add(chunk);
        response?.add(chunk);
      }
      if (length == 0 || (expectedLength >= 0 && length != expectedLength)) {
        throw const HttpException('Incomplete video segment');
      }
      await sink.close();
      sink = null;
      if (uri.path.endsWith('.m3u8') &&
          !(await partial.readAsString()).startsWith('#EXTM3U')) {
        throw const FormatException('Invalid playlist');
      }
      await partial.rename(file.path);
      unawaited(_trim());
      return file;
    } finally {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> _sendFile(HttpResponse response, File file,
      {String? range, bool head = false}) async {
    final length = await file.length();
    var start = 0;
    var end = length;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (range != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
      if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return;
      }
      if (match[1]!.isEmpty) {
        start = max(0, length - int.parse(match[2]!));
      } else {
        start = int.parse(match[1]!);
        if (match[2]!.isNotEmpty) end = min(length, int.parse(match[2]!) + 1);
      }
      if (start >= end) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
        return;
      }
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
          HttpHeaders.contentRangeHeader, 'bytes $start-${end - 1}/$length');
    }
    response.contentLength = end - start;
    if (!head) await response.addStream(file.openRead(start, end));
  }

  Future<void> _trim() {
    if (_trimming != null) return _trimming!;
    final task = _trimFiles();
    _trimming = task;
    return task.whenComplete(() => _trimming = null);
  }

  Future<void> _trimFiles() async {
    try {
      final entries = <MapEntry<File, FileStat>>[];
      await for (final entry in _directory!.list()) {
        if (entry is File && entry.path.endsWith('.part')) {
          if (DateTime.now().difference((await entry.stat()).modified) >
              const Duration(hours: 1)) {
            await entry.delete();
          }
        }
        if (entry is File && entry.path.endsWith('.cache')) {
          entries.add(MapEntry(entry, await entry.stat()));
        }
      }
      entries.sort((a, b) => a.value.modified.compareTo(b.value.modified));
      var total = entries.fold<int>(0, (sum, entry) => sum + entry.value.size);
      for (final entry in entries) {
        if (total <= maxBytes &&
            DateTime.now().difference(entry.value.modified) <= maxAge) continue;
        try {
          await entry.key.delete();
          total -= entry.value.size;
        } on FileSystemException {/* Another read/trim may have removed it. */}
      }
    } on FileSystemException {
      /* Full/unavailable cache must not interrupt playback. */
    }
  }

  Future<void> flush() async {
    await Future.wait(_pending.values.toList().map((task) async {
      try {
        await task;
      } catch (_) {/* Failed downloads are never committed. */}
    }));
    await _trimming;
  }

  Future<void> close() async {
    _closed = true;
    await _server?.close(force: true);
    _client.close(force: true);
    await flush();
  }
}
