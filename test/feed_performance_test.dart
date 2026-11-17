import 'package:cnattendance/features/community/feed_performance.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FeedVideoAutoplayManager.instance.clearTileRegistry();
    FeedPerformanceTracker.instance.reset();
  });

  test('playback manager keeps one most-visible active tile', () {
    final manager = FeedVideoAutoplayManager.instance;
    manager.clearTileRegistry();
    final first = Object();
    final second = Object();

    manager.updateVisibility(first, .3, position: 0, autoPlay: true);
    manager.updateVisibility(second, .75, position: 1, autoPlay: true);
    expect(manager.isActive(second), isTrue);
    expect(manager.isActive(first), isFalse);

    manager.activate(second);
    manager.updateVisibility(first, .8, position: 0, autoPlay: true);
    expect(manager.isActive(first), isTrue);
    expect(manager.isActive(second), isFalse);

    final manual = Object();
    manager.updateVisibility(manual, .9, position: 2);
    expect(manager.isActive(manual), isFalse);

    manager.deactivate(first);
    expect(manager.isActive(first), isFalse);
  });

  test('playback manager pauses and resumes the active tile', () {
    final manager = FeedVideoAutoplayManager.instance;
    manager.clearTileRegistry();
    final only = Object();

    manager.updateVisibility(only, .9, position: 0, autoPlay: true);
    expect(manager.isActive(only), isTrue);
    expect(manager.activePaused, isFalse);

    manager.pauseActive();
    expect(manager.activePaused, isTrue);
    expect(manager.isActive(only), isTrue);

    manager.resumeActive();
    expect(manager.activePaused, isFalse);

    manager.pauseActive();
    manager.pauseAll();
    expect(manager.activePaused, isFalse);
    expect(manager.isActive(only), isFalse);
  });

  test('playback manager remembers recent positions only', () {
    final manager = FeedVideoAutoplayManager.instance;
    manager.rememberPosition('video-a', const Duration(seconds: 12));
    expect(manager.resumePosition('video-a'), const Duration(seconds: 12));
    manager.forgetPosition('video-a');
    expect(manager.resumePosition('video-a'), isNull);
    manager.rememberPosition('video-b', const Duration(milliseconds: 400));
    expect(manager.resumePosition('video-b'), isNull);
  });

  test('performance tracker reports startup, buffering and frame ratios', () {
    final tracker = FeedPerformanceTracker.instance;
    tracker.reset();
    final start = DateTime(2026, 1, 1, 12);
    tracker.now = () => start;
    tracker.startFeedLoad();
    tracker.now = () => start.add(const Duration(milliseconds: 200));
    tracker.markFeedLoaded();
    tracker.now = () => start.add(const Duration(milliseconds: 320));
    tracker.markFeedFirstPost();
    tracker.videoInitializeStarted('video-a');
    tracker.now = () => start.add(const Duration(milliseconds: 900));
    tracker.videoFirstFrame('video-a');
    tracker.videoBufferingSpan('video-a', const Duration(milliseconds: 400));
    tracker.videoPlaybackSpan('video-a', const Duration(milliseconds: 1600));

    final snapshot = tracker.snapshot();
    expect(snapshot['feed_load_ms'], 200);
    expect(snapshot['feed_first_post_ms'], 320);
    expect(snapshot['buffering_ratio'], .2);
    final videos = snapshot['videos'] as Map<String, dynamic>;
    expect((videos['video-a'] as Map)['first_frame_ms'], 580);
    tracker.now = DateTime.now;
  });
  test('optimistic reactions update counts and can be rolled back', () {
    final post = <String, dynamic>{
      'id': 1,
      'my_reaction': 'like',
      'reactions': {'like': 2, 'love': 1},
      'reactions_count': 3,
    };

    final loved = communityOptimisticReaction(post, 'love');
    expect(loved['my_reaction'], 'love');
    expect(loved['reactions'], {'like': 1, 'love': 2});
    expect(loved['reactions_count'], 3);

    final removed = communityOptimisticReaction(loved, null);
    expect(removed['my_reaction'], isNull);
    expect(removed['reactions'], {'like': 1, 'love': 1});
    expect(removed['reactions_count'], 2);
    expect(post['reactions'], {'like': 2, 'love': 1});
  });
}
