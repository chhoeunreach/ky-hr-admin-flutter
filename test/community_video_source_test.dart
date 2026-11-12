import 'package:flutter_translate/flutter_translate.dart';
import 'package:video_player/video_player.dart' show VideoPlayer;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final seeks = <Duration>[];
  bool failHls = false;
  bool failAll = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    streams[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final stream = streams[playerId]!;
    scheduleMicrotask(() {
      if (failAll || (failHls && sources[playerId].uri!.endsWith('.m3u8'))) {
        stream.addError(PlatformException(
            code: 'stream_unavailable', message: 'Stream unavailable'));
      } else {
        stream.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 60),
            size: const Size(640, 360)));
      }
    });
    return stream.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await streams[playerId]?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      const Duration(seconds: 12);
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

void main() {
  setUpAll(() => Localization.load({}));
  final original = Uri.parse('https://example.test/storage/community/clip.mp4');
  test('uses optional HLS source on the original origin', () {
    const stream = 'https://example.test/storage/video-streams/abc/master.m3u8';
    expect(communityVideoPlaybackUri(original, stream), Uri.parse(stream));
    final local = Uri.parse('http://example.test/storage/stories/clip.mp4');
    expect(
        communityVideoPlaybackUri(local,
                'http://example.test/storage/video-streams/abc/master.m3u8')
            .path,
        endsWith('master.m3u8'));
  });
  test('keeps original for missing, invalid and cross-origin sources', () {
    for (final stream in [
      null,
      '',
      'javascript:alert(1)',
      'https://remote.test/master.m3u8',
      'https://example.test/movie.mp4',
      'https://user:pass@example.test/master.m3u8'
    ]) {
      expect(communityVideoPlaybackUri(original, stream), original);
    }
  });
  group('native adaptive playback', () {
    late FakeVideoPlatform platform;
    late VideoPlayerPlatform previous;
    late Duration visibilityInterval;
    setUp(() {
      previous = VideoPlayerPlatform.instance;
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      visibilityInterval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
    });
    tearDown(() {
      FeedVideoAutoplayManager.instance.pauseAll();
      VideoPlayerPlatform.instance = previous;
      VisibilityDetectorController.instance.updateInterval = visibilityInterval;
    });
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 300,
                  child: CommunityMedia(
                      type: 'video',
                      useVideoCache: false,
                      url: 'https://example.test/storage/community/clip.mp4',
                      playbackUrl:
                          'https://example.test/storage/video-streams/abc/master.m3u8')))));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('uses HLS and falls back if initialization fails',
        (tester) async {
      platform.failHls = true;
      await open(tester);
      expect(platform.sources.map((s) => s.uri).toList(), [
        'https://example.test/storage/video-streams/abc/master.m3u8',
        'https://example.test/storage/community/clip.mp4'
      ]);
      expect(platform.sources.first.formatHint, VideoFormat.hls);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    testWidgets(
        'failed playback offers an in-app retry that restarts streaming',
        (tester) async {
      platform.failAll = true;
      await open(tester);
      expect(find.text('Retry'), findsOneWidget);
      platform.failAll = false;
      await tester.tap(find.text('Retry'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.sources.last.uri, endsWith('master.m3u8'));
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(find.text('Video could not be loaded. Retry.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('runtime stream failure resumes original near current position',
        (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      platform.streams[0]!.addError(
          PlatformException(code: 'segment_failed', message: 'Segment failed'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.sources.last.uri, endsWith('clip.mp4'));
      expect(platform.seeks, contains(const Duration(seconds: 12)));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
