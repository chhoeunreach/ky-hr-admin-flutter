import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight, dependency-free telemetry for the social feed.
///
/// It deliberately keeps only bounded counters and samples so it can stay
/// enabled in production without affecting scroll performance. UI code reports
/// spans it already measures (controller initialization, buffering, playback)
/// instead of polling media state.
class FeedPerformanceTracker {
  FeedPerformanceTracker._();

  static final FeedPerformanceTracker instance = FeedPerformanceTracker._();

  /// Set to false to disable frame sampling entirely.
  bool enabled = true;

  static const int _maxFrameSamples = 240;
  static const Duration _jankBudget = Duration(milliseconds: 16);

  final Map<String, _VideoMetrics> _videos = {};
  final List<int> _frameMicros = [];

  DateTime? _feedStartedAt;
  Duration? _feedLoad;
  Duration? _feedFirstPost;
  int _frameCount = 0;
  int _jankyFrames = 0;
  bool _tracing = false;

  /// Overridable clock so tests never depend on wall time.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  void startFeedLoad() {
    _feedStartedAt = now();
    _feedLoad = null;
    _feedFirstPost = null;
  }

  void markFeedLoaded() {
    final started = _feedStartedAt;
    if (started == null || _feedLoad != null) return;
    _feedLoad = now().difference(started);
  }

  void markFeedFirstPost() {
    final started = _feedStartedAt;
    if (started == null || _feedFirstPost != null) return;
    _feedFirstPost = now().difference(started);
  }

  /// Starts sampling frame timings for scroll FPS / jank.
  void startScrollTrace() {
    if (!enabled || _tracing) return;
    _tracing = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stopScrollTrace() {
    if (!_tracing) return;
    _tracing = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final total = timing.totalSpan.inMicroseconds;
      if (total <= 0) continue;
      _frameCount++;
      if (timing.totalSpan > _jankBudget) _jankyFrames++;
      _frameMicros.add(total);
    }
    if (_frameMicros.length > _maxFrameSamples) {
      _frameMicros.removeRange(0, _frameMicros.length - _maxFrameSamples);
    }
  }

  void videoInitializeStarted(String id) {
    _videos.putIfAbsent(id, _VideoMetrics.new).initializeStartedAt ??= now();
  }

  void videoFirstFrame(String id) {
    final metrics = _videos.putIfAbsent(id, _VideoMetrics.new);
    if (metrics.firstFrame != null) return;
    final started = metrics.initializeStartedAt;
    if (started != null) metrics.firstFrame = now().difference(started);
  }

  void videoBufferingSpan(String id, Duration span) {
    if (span <= Duration.zero) return;
    _videos.putIfAbsent(id, _VideoMetrics.new).buffering += span;
  }

  void videoPlaybackSpan(String id, Duration span) {
    if (span <= Duration.zero) return;
    _videos.putIfAbsent(id, _VideoMetrics.new).playing += span;
  }

  void videoReleased(String id) {
    _videos.remove(id);
  }

  /// Ratio of time spent buffering to total watched time across videos.
  double get bufferingRatio {
    var buffered = Duration.zero;
    var played = Duration.zero;
    for (final metrics in _videos.values) {
      buffered += metrics.buffering;
      played += metrics.playing;
    }
    final total = buffered + played;
    return total <= Duration.zero
        ? 0
        : buffered.inMilliseconds / total.inMilliseconds;
  }

  /// Approximate FPS from sampled frame intervals.
  double get scrollFps {
    if (_frameMicros.isEmpty) return 0;
    final average = _frameMicros.reduce((a, b) => a + b) / _frameMicros.length;
    return average <= 0 ? 0 : 1000000 / average;
  }

  double get droppedFrameRatio =>
      _frameCount == 0 ? 0 : _jankyFrames / _frameCount;

  int get memoryMb {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return 0;
    }
    try {
      return ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> snapshot() => {
        'feed_load_ms': _feedLoad?.inMilliseconds,
        'feed_first_post_ms': _feedFirstPost?.inMilliseconds,
        'scroll_fps': double.parse(scrollFps.toStringAsFixed(1)),
        'dropped_frame_ratio':
            double.parse(droppedFrameRatio.toStringAsFixed(3)),
        'frame_samples': _frameCount,
        'memory_mb': memoryMb,
        'buffering_ratio': double.parse(bufferingRatio.toStringAsFixed(3)),
        'videos': {
          for (final entry in _videos.entries)
            entry.key: {
              'first_frame_ms': entry.value.firstFrame?.inMilliseconds,
              'buffering_ms': entry.value.buffering.inMilliseconds,
              'playing_ms': entry.value.playing.inMilliseconds,
            },
        },
      };

  void reset() {
    _videos.clear();
    _frameMicros.clear();
    _feedStartedAt = null;
    _feedLoad = null;
    _feedFirstPost = null;
    _frameCount = 0;
    _jankyFrames = 0;
  }
}

class _VideoMetrics {
  DateTime? initializeStartedAt;
  Duration? firstFrame;
  Duration buffering = Duration.zero;
  Duration playing = Duration.zero;
}
