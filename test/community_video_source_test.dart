import 'package:flutter_translate/flutter_translate.dart';
import 'package:video_player/video_player.dart' show VideoPlayer;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class SilentCommunityApi extends CommunityApi {
  @override
  Future<Map<String, dynamic>> request(String method, String path,
          {Map<String, dynamic>? data,
          String? filePath,
          String? fileMime,
          List<String>? filePaths,
          List<String>? fileMimes}) async =>
      {'data': <String, dynamic>{}};
}

class FakeVideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final seeks = <Duration>[];
  final plays = <int>[];
  final volumes = <int, double>{};
  final loopings = <int, bool>{};
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
  Future<void> setLooping(int playerId, bool looping) async {
    loopings[playerId] = looping;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes[playerId] = volume;
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> play(int playerId) async {
    plays.add(playerId);
  }

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
    Future<void> open(WidgetTester tester,
        {bool allowFullscreen = false}) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 300,
                  child: CommunityMedia(
                      type: 'video',
                      allowFullscreen: allowFullscreen,
                      useVideoCache: false,
                      url: 'https://example.test/storage/community/clip.mp4',
                      playbackUrl:
                          'https://example.test/storage/video-streams/abc/master.m3u8')))));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('fullscreen keeps the native player and adds playback controls',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = FeedVideoAutoplayManager.instance..setMuted(true);
      addTearDown(() => manager.setMuted(true));
      await open(tester, allowFullscreen: true);
      final controller =
          tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
      expect(platform.sources, hasLength(1));
      await controller.seekTo(const Duration(seconds: 12));

      await tester.tap(find.byTooltip('Full screen'));
      await tester.pumpAndSettle();
      final fullscreen = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(fullscreen.controller, same(controller));
      expect(controller.value.position, const Duration(seconds: 12));
      expect(
          find.ancestor(
              of: find.byType(VideoPlayer),
              matching: find.byWidgetPredicate((widget) =>
                  widget is FittedBox && widget.fit == BoxFit.contain)),
          findsOneWidget);

      manager.activate(Object());
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      await tester.tap(find.byTooltip('Pause video'));
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      await tester.tap(find.byTooltip('Forward 10 seconds'));
      await tester.pump();
      expect(platform.seeks.last, const Duration(seconds: 22));
      await tester.tap(find.byTooltip('Back 10 seconds'));
      await tester.pump();
      expect(platform.seeks.last, const Duration(seconds: 12));
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pump();
      expect(platform.volumes[0], 1);
      await tester.tap(find.byType(Slider));
      await tester.pump();
      expect(platform.seeks.last.inSeconds, inInclusiveRange(25, 35));
      final position = platform.seeks.last;

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(platform.sources, hasLength(1));
      expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
          same(controller));
      expect(controller.value.position, position);
      expect(controller.value.isPlaying, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

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

    testWidgets('story video autoplays muted and follows manager pause',
        (tester) async {
      FeedVideoAutoplayManager.instance.pauseAll();
      await tester.pumpWidget(MaterialApp(
          home: SocialStoryViewer(api: SilentCommunityApi(), groups: [
        {
          'author': {'name': 'Dara', 'avatar': null},
          'is_mine': false,
          'has_unseen': true,
          'stories': [
            {
              'id': 7,
              'media_type': 'video',
              'media_url': 'https://example.test/storage/stories/story.mp4',
              'playback_url':
                  'https://example.test/storage/video-streams/story/master.m3u8',
              'thumbnail_url':
                  'https://example.test/storage/video-streams/story/poster.jpg',
              'duration_seconds': 30,
              'caption': '',
              'can_react': false,
              'reactions_count': 0,
              'aspect_ratio': '16:9',
            }
          ],
        }
      ])));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(platform.plays, isNotEmpty);
      expect(platform.loopings[0], isFalse);
      expect(find.byType(VideoPlayer), findsOneWidget);

      FeedVideoAutoplayManager.instance.pauseActive();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
          tester
              .widget<VideoPlayer>(find.byType(VideoPlayer))
              .controller
              .value
              .isPlaying,
          isFalse);

      FeedVideoAutoplayManager.instance.resumeActive();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
          tester
              .widget<VideoPlayer>(find.byType(VideoPlayer))
              .controller
              .value
              .isPlaying,
          isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('story video taps still move to the next story',
        (tester) async {
      FeedVideoAutoplayManager.instance.pauseAll();
      await tester.pumpWidget(MaterialApp(
          home: SocialStoryViewer(api: SilentCommunityApi(), groups: [
        {
          'author': {'name': 'Dara', 'avatar': null},
          'is_mine': false,
          'has_unseen': true,
          'stories': [
            {
              'id': 7,
              'media_type': 'video',
              'media_url': 'https://example.test/storage/stories/story.mp4',
              'playback_url':
                  'https://example.test/storage/video-streams/story/master.m3u8',
              'duration_seconds': 30,
              'caption': '',
              'can_react': false,
              'reactions_count': 0,
            },
            {
              'id': 8,
              'media_type': 'text',
              'caption': 'Second story',
              'duration_seconds': 30,
              'can_react': false,
              'reactions_count': 0,
            },
          ],
        }
      ])));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(VideoPlayer), findsOneWidget);
      final size = tester.getSize(find.byType(SocialStoryViewer));
      await tester.tapAt(Offset(size.width * 0.85, size.height * 0.6));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Second story'), findsOneWidget);

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
