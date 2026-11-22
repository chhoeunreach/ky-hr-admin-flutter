import 'community_strings.dart';
import 'feed_performance.dart';
import 'video_cache.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';

/// Only normalized provider URLs may be rendered as embeds. Never render user HTML.
Uri? communityMediaUri(String type, String value) {
  final candidate = value.trim();
  // A single URL never contains whitespace, and only one scheme may appear.
  // Reject pasted lists such as "https://a/b.jpg, https://c/d" so a broken
  // value cannot reach Image.network or the WebView.
  if (candidate.isEmpty ||
      RegExp(r'\s').hasMatch(candidate) ||
      RegExp(r'https?://', caseSensitive: false).allMatches(candidate).length >
          1) {
    return null;
  }
  final uri = Uri.tryParse(candidate);
  final isUploadedMedia = uri != null &&
      uri.scheme == 'http' &&
      RegExp(r'^/storage/(?:community|stories|video-streams)/[A-Za-z0-9._/-]+$')
          .hasMatch(uri.path);
  if (uri == null ||
      (uri.scheme != 'https' && !isUploadedMedia) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) return null;
  if (type == 'youtube' &&
      !(uri.host == 'www.youtube.com' &&
          RegExp(r'^/embed/[\w-]{11}$').hasMatch(uri.path))) return null;
  if (type == 'facebook') {
    if (uri.host != 'www.facebook.com' || uri.path != '/plugins/video.php')
      return null;
    final source = Uri.tryParse(uri.queryParameters['href'] ?? '');
    if (source == null ||
        source.scheme != 'https' ||
        ![
          'facebook.com',
          'www.facebook.com',
          'm.facebook.com',
          'web.facebook.com'
        ].contains(source.host)) return null;
  }
  return uri;
}

/// Streaming sources must share the original media's origin.
Uri communityVideoPlaybackUri(Uri original, String? playbackUrl) {
  final stream = communityMediaUri('video', playbackUrl ?? '');
  if (stream == null ||
      stream.origin != original.origin ||
      !stream.path.toLowerCase().endsWith('.m3u8')) return original;
  return stream;
}

/// Avatars are tiny on screen, so decode them at thumbnail size instead of
/// pulling full-resolution profile photos into the image cache.
ImageProvider<Object>? communityAvatarImage(String? url, {int pixels = 96}) {
  final value = (url ?? '').trim();
  if (value.isEmpty) return null;
  return ResizeImage.resizeIfNeeded(pixels, pixels, NetworkImage(value));
}

class CommunityMedia extends StatelessWidget {
  const CommunityMedia(
      {super.key,
      required this.type,
      required this.url,
      this.compact = false,
      this.onImageTap,
      this.thumbnailUrl,
      this.playbackUrl,
      this.durationSeconds,
      this.aspectRatio,
      this.autoPlay = false,
      this.useVideoCache = true,
      this.muteController,
      this.showMuteControl = true,
      this.feedPosition,
      this.onPlayStateChanged,
      this.onVideoDuration,
      this.loopVideo = true,
      this.rememberPlayback = true,
      this.videoTapEnabled = true,
      this.allowFullscreen = false});
  final String type;
  final String url;
  final bool compact;
  final VoidCallback? onImageTap;
  final String? thumbnailUrl;
  final String? playbackUrl;
  final Object? durationSeconds;
  final Object? aspectRatio;

  /// Index of the tile in the feed, used to preload only the videos adjacent
  /// to whichever one is currently playing.
  final int? feedPosition;

  /// When true, direct video files start playing automatically as they scroll
  /// into view (Facebook-style). Only the most visible video plays at a time.
  final bool autoPlay;
  final bool useVideoCache;

  /// Optional external mute state, for screens that render their own button.
  final CommunityVideoMuteController? muteController;

  /// Whether the video shows its built-in mute button.
  final bool showMuteControl;

  /// Notifies owners that render their own story-style controls when the
  /// native player starts or stops, so timers can follow real playback.
  final ValueChanged<bool>? onPlayStateChanged;

  /// Reports the real media duration once the player is initialized.
  final ValueChanged<Duration>? onVideoDuration;

  /// Feed videos loop; story videos play once and hand control back.
  final bool loopVideo;

  /// Disabled for stories so reopening always starts at the beginning.
  final bool rememberPlayback;

  /// Stories own all tap gestures (previous/next/pause); feed tiles keep their
  /// own play/pause toggle.
  final bool videoTapEnabled;

  /// Lets users open a native video in a full-screen player.
  final bool allowFullscreen;

  @override
  Widget build(BuildContext context) {
    if (type == 'text' || url.isEmpty) return SizedBox.shrink();
    final uri = communityMediaUri(type, url);
    if (uri == null) return _UnavailableMedia();
    if (type == 'image') {
      return _ImageMedia(uri: uri, compact: compact, onTap: onImageTap);
    }
    if (type == 'document') {
      return _DocumentMedia(uri: uri, compact: compact);
    }
    if (type == 'video') {
      return _AutoplayVideo(
          uri: uri,
          playbackUri: communityVideoPlaybackUri(uri, playbackUrl),
          autoPlay: autoPlay,
          useVideoCache: useVideoCache,
          compact: compact,
          thumbnailUrl: thumbnailUrl,
          durationSeconds: durationSeconds,
          aspectRatio: aspectRatio,
          muteController: muteController,
          showMuteControl: showMuteControl,
          feedPosition: feedPosition,
          onPlayStateChanged: onPlayStateChanged,
          onVideoDuration: onVideoDuration,
          loopVideo: loopVideo,
          rememberPlayback: rememberPlayback,
          videoTapEnabled: videoTapEnabled,
          allowFullscreen: allowFullscreen);
    }
    return _PlayableMedia(
        type: type,
        uri: uri,
        compact: compact,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        aspectRatio: aspectRatio);
  }
}

class _UnavailableMedia extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.customFFF3F6FA,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.link_off_rounded, color: AppColors.customFF718096),
        const SizedBox(width: 10),
        Expanded(
            child: Text(communityText('This media link is unavailable.'),
                style: const TextStyle(color: AppColors.customFF5F6F82)))
      ]));
}

class _ImageMedia extends StatefulWidget {
  const _ImageMedia({required this.uri, this.compact = false, this.onTap});
  final Uri uri;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<_ImageMedia> createState() => _ImageMediaState();
}

class _ImageMediaState extends State<_ImageMedia> {
  final Object _heroTag = Object();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _aspectRatio = 16 / 9;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenForDimensions();
  }

  void _listenForDimensions() {
    final stream = CachedNetworkImageProvider(widget.uri.toString())
        .resolve(createLocalImageConfiguration(context));
    _stream?.removeListener(_listener!);
    final listener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) return;
      setState(() => _aspectRatio = (width / height).clamp(.65, 2.2));
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  int get _cacheWidth {
    final logicalWidth = MediaQuery.maybeSizeOf(context)?.width ?? 720;
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return (logicalWidth * pixelRatio).clamp(320, 1280).round();
  }

  Future<void> _openViewer() async {
    FeedVideoAutoplayManager.instance.pauseAll();
    await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
            builder: (_) =>
                _ImageViewerScreen(uri: widget.uri, heroTag: _heroTag)));
  }

  Widget _progressiveImage(
          {required int cacheWidth, BoxFit fit = BoxFit.cover}) =>
      CachedNetworkImage(
          imageUrl: widget.uri.toString(),
          fit: fit,
          memCacheWidth: cacheWidth,
          maxWidthDiskCache: 1600,
          fadeInDuration: const Duration(milliseconds: 140),
          filterQuality: FilterQuality.medium,
          progressIndicatorBuilder: (_, __, progress) => ColoredBox(
              color: AppColors.customFFEDF2F7,
              child: Center(
                  child: CircularProgressIndicator(
                      value: progress.progress, strokeWidth: 2))),
          errorWidget: (_, __, ___) => _MediaError(
              icon: Icons.broken_image_outlined,
              message: communityText('Image could not be loaded.'),
              uri: widget.uri,
              action: communityText('Open image')));

  Widget _imageStack() => Stack(fit: StackFit.expand, children: [
        Hero(tag: _heroTag, child: _progressiveImage(cacheWidth: _cacheWidth)),
      ]);

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: widget.onTap ?? _openViewer,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.compact
              ? SizedBox.expand(child: _imageStack())
              : AspectRatio(aspectRatio: _aspectRatio, child: _imageStack())));
}

/// Full-screen image viewer with pinch-to-zoom, launched from feed images.
class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({required this.uri, required this.heroTag});

  final Uri uri;
  final Object heroTag;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          iconTheme: const IconThemeData(color: AppColors.white),
          actions: [
            IconButton(
                tooltip: communityText('Open image'),
                onPressed: () =>
                    launchUrl(uri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new)),
          ],
        ),
        body: Center(
            child: Hero(
                tag: heroTag,
                child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: CachedNetworkImage(
                        imageUrl: uri.toString(),
                        fit: BoxFit.contain,
                        memCacheWidth: 1600,
                        progressIndicatorBuilder: (_, __, progress) => Center(
                            child: CircularProgressIndicator(
                                value: progress.progress,
                                color: AppColors.white,
                                strokeWidth: 2)),
                        errorWidget: (_, __, ___) => _MediaError(
                            icon: Icons.broken_image_outlined,
                            message:
                                communityText('Image could not be loaded.'),
                            uri: uri,
                            action: communityText('Open image')))))),
      );
}

class _DocumentMedia extends StatelessWidget {
  const _DocumentMedia({required this.uri, this.compact = false});
  final Uri uri;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
          color: AppColors.customFFF3F6FA,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.description_rounded,
            color: AppColors.customFF5068A0, size: compact ? 25 : 28),
        const SizedBox(width: 10),
        Expanded(
            child: Text(communityText('Attached document'),
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: () =>
                launchUrl(uri, mode: LaunchMode.externalApplication),
            child: Text(communityText('Open')))
      ]));
}

class _MediaError extends StatelessWidget {
  const _MediaError(
      {required this.icon,
      required this.message,
      required this.uri,
      required this.action});
  final IconData icon;
  final String message;
  final Uri uri;
  final String action;

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: AppColors.customFFEDF2F7,
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: AppColors.customFF718096),
        const SizedBox(height: 6),
        Text(message, style: const TextStyle(color: AppColors.customFF5F6F82)),
        TextButton(
            onPressed: () =>
                launchUrl(uri, mode: LaunchMode.externalApplication),
            child: Text(action))
      ])));
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.white, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))
          ])));
}

class _PlayableMedia extends StatefulWidget {
  _PlayableMedia(
      {required this.type,
      required this.uri,
      this.compact = false,
      this.thumbnailUrl,
      this.durationSeconds,
      this.aspectRatio});
  final String type;
  final Uri uri;
  final bool compact;
  final String? thumbnailUrl;
  final Object? durationSeconds;
  final Object? aspectRatio;
  @override
  State<_PlayableMedia> createState() => _PlayableMediaState();
}

class _PlayableMediaState extends State<_PlayableMedia> {
  WebViewController? _controller;
  String? _error;
  bool _opening = false;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final isUploadedMedia = widget.uri.scheme == 'http' &&
          RegExp(r'^/storage/(?:community|stories|video-streams)/[A-Za-z0-9._/-]+$')
              .hasMatch(widget.uri.path);
      final origin = isUploadedMedia
          ? widget.uri.replace(path: '/', query: '', fragment: '').toString()
          : 'https://${info.packageName.toLowerCase()}/';
      final escaped = HtmlEscape().convert(widget.uri.toString());
      final content = widget.type == 'video'
          ? '<video controls playsinline style="width:100%;height:100%" src="$escaped"></video>'
          : '<iframe src="$escaped" style="width:100%;height:100%;border:0" allow="encrypted-media; fullscreen; picture-in-picture" allowfullscreen></iframe>';
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
            NavigationDelegate(onNavigationRequest: (request) {
          final requestUri = Uri.tryParse(request.url);
          final allowedUploadedMedia = isUploadedMedia &&
              requestUri != null &&
              requestUri.scheme == 'http' &&
              requestUri.host == widget.uri.host &&
              requestUri.port == widget.uri.port;
          if (requestUri == null ||
              ((requestUri.scheme != 'https' && !allowedUploadedMedia) &&
                  request.url != 'about:blank'))
            return NavigationDecision.prevent;
          if (request.isMainFrame &&
              request.url != origin &&
              request.url != 'about:blank') {
            launchUrl(requestUri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        }));
      await controller.loadHtmlString('''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;width:100%;height:100%;background:${AppPalette.cssRgb(AppPalette.customFF101826)}}</style>
</head><body>$content</body></html>''', baseUrl: origin);
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = communityText('Video could not be loaded. Tap to retry.'));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openExternal() async {
    final uri = widget.type == 'facebook'
        ? Uri.parse(widget.uri.queryParameters['href']!)
        : widget.uri;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Surface missing browser/player handlers as a recoverable error.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(communityText('Could not open link.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'link') {
      return _LinkMedia(uri: widget.uri, compact: widget.compact);
    }
    final canEmbed = !kIsWeb &&
        [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]
            .contains(defaultTargetPlatform);
    final aspectRatio = communityMediaAspectRatio(widget.aspectRatio);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.type != 'link')
        LayoutBuilder(
            builder: (context, constraints) => SizedBox(
                  height: widget.compact
                      ? (constraints.hasBoundedHeight
                          ? constraints.maxHeight
                          : constraints.maxWidth)
                      : math.max(180, constraints.maxWidth / aspectRatio),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _controller != null
                          ? WebViewWidget(controller: _controller!)
                          : _VideoPreview(
                              error: _error,
                              opening: _opening,
                              canEmbed: canEmbed,
                              onPlay: canEmbed ? _open : _openExternal,
                              thumbnailUrl: widget.thumbnailUrl,
                              durationSeconds: widget.durationSeconds)),
                )),
    ]);
  }
}

class _LinkMedia extends StatelessWidget {
  const _LinkMedia({required this.uri, required this.compact});
  final Uri uri;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget content = compact
        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.link_rounded,
                size: 30, color: AppColors.customFF1769E8),
            const SizedBox(height: 6),
            Text(communityText('Open link'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.customFF24466F))
          ])
        : Row(children: [
            const Icon(Icons.link_rounded, color: AppColors.customFF1769E8),
            const SizedBox(width: 8),
            Expanded(
                child: Text(uri.toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.open_in_new, size: 17)
          ]);
    return Material(
        color: AppColors.customFFEEF4FF,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
            child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 16), child: content)));
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview(
      {required this.error,
      required this.opening,
      required this.canEmbed,
      required this.onPlay,
      this.thumbnailUrl,
      this.durationSeconds});
  final String? error;
  final bool opening;
  final bool canEmbed;
  final VoidCallback onPlay;
  final String? thumbnailUrl;
  final Object? durationSeconds;

  @override
  Widget build(BuildContext context) {
    final playButton = Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlay,
            child: const Padding(
                padding: EdgeInsets.all(17),
                child: Icon(Icons.play_arrow_rounded,
                    size: 38, color: AppColors.customFF1769E8))));
    final thumbnail =
        thumbnailUrl == null ? null : communityMediaUri('image', thumbnailUrl!);
    final duration = communityMediaDurationLabel(durationSeconds);
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.customFF13243A, AppColors.customFF07111F])),
        child: Stack(fit: StackFit.expand, children: [
          if (thumbnail != null)
            CachedNetworkImage(
                imageUrl: thumbnail.toString(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink()),
          if (thumbnail != null)
            ColoredBox(color: AppColors.black.withValues(alpha: .28)),
          Positioned(
              top: 14,
              left: 14,
              child: _MediaBadge(
                  icon: Icons.play_circle_fill_rounded,
                  label: duration == null
                      ? communityText('Video')
                      : '${communityText('Video')} · $duration')),
          Center(
              child: opening
                  ? const CircularProgressIndicator(color: AppColors.white)
                  : playButton),
          Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Text(
                  error ??
                      (canEmbed
                          ? communityText('Tap to play video')
                          : communityText('Open video in browser')),
                  style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(blurRadius: 4, color: AppColors.black)
                      ])))
        ]));
  }
}

String? communityMediaDurationLabel(Object? value) {
  final seconds = value is num ? value.toInt() : int.tryParse('$value');
  if (seconds == null || seconds < 0) return null;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

double communityMediaAspectRatio(Object? value) {
  final ratio = value is num ? value.toDouble() : double.tryParse('$value');
  if (ratio == null || !ratio.isFinite || ratio <= 0) return 16 / 9;
  return ratio.clamp(.5, 2.5).toDouble();
}

/// Coordinates Facebook-style autoplay across every feed video.
///
/// Only one video may play at a time and playback stops when the app is sent
/// to the background. Tiles register themselves by identity, so rebuilding a
/// post or showing a second feed cannot steal playback from a live tile.
///
/// The manager also owns the visibility registry that decides which tile is
/// most worth initializing, gates preloading to the videos adjacent to the
/// active one, and remembers playback positions so scrolling back resumes
/// where the user left off.
class FeedVideoAutoplayManager extends ChangeNotifier {
  FeedVideoAutoplayManager._() {
    WidgetsBinding.instance.addObserver(_AutoplayLifecycleObserver(this));
    unawaited(_probeNetwork());
  }

  static final FeedVideoAutoplayManager instance = FeedVideoAutoplayManager._();

  /// A tile must be at least this visible before it can auto-play.
  static const double visibilityThreshold = .6;

  static const int _maxRememberedPositions = 80;

  final Map<Object, _TileVisibility> _tiles = {};
  final Map<String, Duration> _resumePositions = {};

  Object? _active;
  Object? _suppressed;
  Object? _fullscreenOwner;
  bool _activePaused = false;
  bool _muted = true;
  bool _foreground = true;
  bool _preloadAllowed = false;
  bool _preloadProbed = false;
  bool _lowMemoryMode = false;

  bool get muted => _muted;
  bool get foreground => _foreground;
  bool get preloadAllowed => _preloadAllowed && !_lowMemoryMode;
  bool get lowMemoryMode => _lowMemoryMode;

  /// True while the active video is held paused by a screen-owned control
  /// (for example a story progress bar) without losing ownership.
  bool get activePaused => _activePaused;

  /// Whether this exact tile is the one allowed to play right now.
  bool isActive(Object owner) =>
      _foreground &&
      identical(_active, owner) &&
      !identical(_suppressed, owner);

  /// Called when a tile crosses the visibility threshold and wants to play.
  void activate(Object owner) {
    if (_fullscreenOwner != null && !identical(_fullscreenOwner, owner)) return;
    _suppressed = null;
    _activePaused = false;
    if (identical(_active, owner) && _foreground) {
      notifyListeners();
      return;
    }
    _active = owner;
    notifyListeners();
  }

  void _enterFullscreen(Object owner) {
    _fullscreenOwner = owner;
    activate(owner);
  }

  void _leaveFullscreen(Object owner) {
    if (identical(_fullscreenOwner, owner)) _fullscreenOwner = null;
  }

  /// Pauses a tile the user explicitly stopped so visibility changes do not
  /// immediately auto-play it again.
  void suppress(Object owner) {
    if (identical(_active, owner)) _active = null;
    _activePaused = false;
    _suppressed = owner;
    notifyListeners();
  }

  void deactivate(Object owner) {
    if (identical(_active, owner)) {
      _active = null;
      _activePaused = false;
    }
    if (identical(_suppressed, owner)) _suppressed = null;
    notifyListeners();
  }

  /// Pauses the active video but keeps ownership, so it can be resumed
  /// without a new visibility event (used by story viewers).
  void pauseActive() {
    if (_active == null || _activePaused) return;
    _activePaused = true;
    notifyListeners();
  }

  void resumeActive() {
    if (!_activePaused) return;
    _activePaused = false;
    notifyListeners();
  }

  /// Pauses the current video, for example before opening another screen.
  void pauseAll() {
    _activePaused = false;
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  /// Reports how much of a tile is on screen. Fraction changes alone do not
  /// notify listeners; only ownership changes do, so scrolling stays cheap.
  void updateVisibility(Object owner, double fraction,
      {int? position,
      String? mediaId,
      bool autoPlay = false,
      Duration? playbackPosition}) {
    final entry = _tiles.putIfAbsent(owner, _TileVisibility.new);
    final wasVisible = entry.fraction >= visibilityThreshold;
    entry.fraction = fraction.clamp(0.0, 1.0);
    entry.autoPlay = autoPlay;
    entry.position = position ?? entry.position;
    entry.mediaId = mediaId ?? entry.mediaId;
    entry.playbackPosition = playbackPosition ?? entry.playbackPosition;

    if (fraction <= 0 && identical(_active, owner)) {
      _active = null;
      _activePaused = false;
    }
    if (fraction <= 0 && identical(_suppressed, owner)) _suppressed = null;
    final nowVisible = entry.fraction >= visibilityThreshold;
    if (nowVisible != wasVisible || (_active == null && nowVisible)) {
      _promoteMostVisible();
    }
  }

  void unregister(Object owner) {
    _leaveFullscreen(owner);
    final entry = _tiles.remove(owner);
    if (entry?.mediaId != null && entry?.playbackPosition != null) {
      rememberPosition(entry!.mediaId!, entry.playbackPosition!);
    }
    if (identical(_active, owner)) {
      _active = null;
      _activePaused = false;
    }
    if (identical(_suppressed, owner)) _suppressed = null;
    if (_active == null) _promoteMostVisible();
  }

  /// Whether [owner] sits directly next to the active video and may be
  /// initialized ahead of time. Only allowed on fast, unmetered networks.
  bool shouldPreload(Object owner) {
    if (!preloadAllowed) return false;
    final active = _active;
    if (active == null) return false;
    final activePosition = _tiles[active]?.position;
    final position = _tiles[owner]?.position;
    if (activePosition == null || position == null) return false;
    final distance = (position - activePosition).abs();
    return distance == 1;
  }

  /// Playback position previously remembered for [mediaId], if any.
  Duration? resumePosition(String mediaId) => _resumePositions[mediaId];

  void rememberPosition(String mediaId, Duration position) {
    if (mediaId.isEmpty || position <= const Duration(seconds: 1)) return;
    _resumePositions.remove(mediaId);
    _resumePositions[mediaId] = position;
    while (_resumePositions.length > _maxRememberedPositions) {
      _resumePositions.remove(_resumePositions.keys.first);
    }
  }

  void forgetPosition(String mediaId) => _resumePositions.remove(mediaId);

  @visibleForTesting
  void clearTileRegistry() {
    _tiles.clear();
    _active = null;
    _suppressed = null;
    _fullscreenOwner = null;
    _activePaused = false;
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void toggleMuted() => setMuted(!_muted);

  /// Low-RAM devices skip preloading and release idle players sooner.
  void setLowMemoryMode(bool value) {
    if (_lowMemoryMode == value) return;
    _lowMemoryMode = value;
    notifyListeners();
  }

  void _promoteMostVisible() {
    if (_fullscreenOwner != null) return;
    Object? best;
    double bestFraction = visibilityThreshold;
    for (final entry in _tiles.entries) {
      if (identical(entry.key, _suppressed) || !entry.value.autoPlay) continue;
      final fraction = entry.value.fraction;
      if (fraction < bestFraction) continue;
      if (fraction == bestFraction && best != null) continue;
      best = entry.key;
      bestFraction = fraction;
    }
    if (identical(best, _active)) return;
    _active = best;
    _activePaused = false;
    notifyListeners();
  }

  Future<void> _probeNetwork() async {
    if (_preloadProbed) return;
    _preloadProbed = true;
    try {
      final connectivity = Connectivity();
      _preloadAllowed = _isUnmetered(await connectivity.checkConnectivity());
      connectivity.onConnectivityChanged.listen((results) {
        final allowed = _isUnmetered(results);
        if (allowed == _preloadAllowed) return;
        _preloadAllowed = allowed;
        notifyListeners();
      });
    } catch (_) {
      // Without connectivity information preloading stays disabled.
      _preloadAllowed = false;
    }
  }

  static bool _isUnmetered(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);

  void _setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    notifyListeners();
  }
}

/// Alias for callers that only care about playback policy, not the singleton.
typedef VideoPlaybackManager = FeedVideoAutoplayManager;

class _TileVisibility {
  double fraction = 0;
  bool autoPlay = false;
  int? position;
  String? mediaId;
  Duration? playbackPosition;
}

class _AutoplayLifecycleObserver with WidgetsBindingObserver {
  _AutoplayLifecycleObserver(this._manager);

  final FeedVideoAutoplayManager _manager;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _manager._setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void didHaveMemoryPressure() {
    // Keep only the active player alive and stop speculative preloading until
    // the app is restarted. This is intentionally sticky: a second pressure
    // event is a strong signal that the device is under sustained pressure.
    _manager.setLowMemoryMode(true);
  }
}

/// Optional external mute state for a video surface.
///
/// Screens that draw their own mute button (for example full-screen stories)
/// can pass one of these to [CommunityMedia] and hide the built-in control so
/// both buttons live in the screen chrome instead of overlapping.
class CommunityVideoMuteController extends ChangeNotifier {
  CommunityVideoMuteController({bool muted = true}) : _muted = muted;

  bool _muted;
  bool get muted => _muted;

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void toggle() => setMuted(!_muted);
}

/// Native video tile that starts muted when it scrolls into view, pauses when
/// it leaves, and hands playback over to whichever tile becomes most visible.
class _AutoplayVideo extends StatefulWidget {
  const _AutoplayVideo({
    required this.uri,
    required this.playbackUri,
    required this.autoPlay,
    required this.useVideoCache,
    required this.compact,
    this.thumbnailUrl,
    this.durationSeconds,
    this.aspectRatio,
    this.muteController,
    this.showMuteControl = true,
    this.feedPosition,
    this.onPlayStateChanged,
    this.onVideoDuration,
    this.loopVideo = true,
    this.rememberPlayback = true,
    this.videoTapEnabled = true,
    this.allowFullscreen = false,
  });

  final Uri uri;
  final Uri playbackUri;
  final bool autoPlay;
  final bool useVideoCache;
  final bool compact;
  final String? thumbnailUrl;
  final Object? durationSeconds;
  final Object? aspectRatio;
  final CommunityVideoMuteController? muteController;
  final bool showMuteControl;
  final int? feedPosition;
  final ValueChanged<bool>? onPlayStateChanged;
  final ValueChanged<Duration>? onVideoDuration;
  final bool loopVideo;
  final bool rememberPlayback;
  final bool videoTapEnabled;
  final bool allowFullscreen;

  @override
  State<_AutoplayVideo> createState() => _AutoplayVideoState();
}

class _AutoplayVideoState extends State<_AutoplayVideo> {
  static const double _visibilityThreshold =
      FeedVideoAutoplayManager.visibilityThreshold;
  static const Duration _playDelay = Duration(milliseconds: 200);
  static const Duration _disposeDelay = Duration(seconds: 3);
  static const Duration _rememberEvery = Duration(seconds: 2);

  final FeedVideoAutoplayManager _manager = FeedVideoAutoplayManager.instance;
  final FeedPerformanceTracker _tracker = FeedPerformanceTracker.instance;
  final UniqueKey _visibilityKey = UniqueKey();

  VideoPlayerController? _controller;
  ValueNotifier<int>? _fullscreenRefresh;
  VisibilityInfo? _fullscreenVisibility;
  Timer? _playTimer;
  Timer? _disposeTimer;
  bool _visible = false;
  bool _userPaused = false;
  bool _initializing = false;
  bool _ready = false;
  bool _failed = false;
  bool _usingFallback = false;
  bool _bypassCache = false;
  bool _cacheInUse = false;
  bool _firstFrameReported = false;
  bool _reportedPlaying = false;
  Duration? _resumePosition;
  Duration _lastPosition = Duration.zero;
  DateTime? _bufferingSince;
  DateTime? _playingSince;
  DateTime? _rememberedAt;
  int _initializationEpoch = 0;

  String get _mediaId => widget.playbackUri.toString();

  int get _feedPosition => widget.feedPosition ?? 0;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerChanged);
    widget.muteController?.addListener(_onMuteChanged);
  }

  bool get _muted => widget.muteController?.muted ?? _manager.muted;

  void _onMuteChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && _ready) {
      controller.setVolume(_muted ? 0 : 1);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _AutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muteController != widget.muteController) {
      oldWidget.muteController?.removeListener(_onMuteChanged);
      widget.muteController?.addListener(_onMuteChanged);
    }
    if (oldWidget.feedPosition != widget.feedPosition) {
      _manager.updateVisibility(this, _visible ? 1 : 0,
          position: _feedPosition,
          mediaId: _mediaId,
          autoPlay: widget.autoPlay,
          playbackPosition: _lastPosition);
    }
    if (oldWidget.uri == widget.uri &&
        oldWidget.playbackUri == widget.playbackUri &&
        oldWidget.useVideoCache == widget.useVideoCache) return;
    _playTimer?.cancel();
    _playTimer = null;
    _disposeTimer?.cancel();
    _disposeTimer = null;
    _initializationEpoch++;
    final controller = _controller;
    _controller = null;
    _initializing = false;
    _ready = false;
    _failed = false;
    _userPaused = false;
    _usingFallback = false;
    _bypassCache = false;
    _cacheInUse = false;
    _firstFrameReported = false;
    _resumePosition = null;
    _lastPosition = Duration.zero;
    _flushPlaybackTracking();
    _reportPlayState(false);
    _tracker.videoReleased(_mediaId);
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    if (_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) _ensureController();
      });
    }
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _disposeTimer?.cancel();
    _manager.removeListener(_onManagerChanged);
    widget.muteController?.removeListener(_onMuteChanged);
    _rememberPosition(force: true);
    _flushPlaybackTracking();
    _tracker.videoReleased(_mediaId);
    _manager.deactivate(this);
    _manager.unregister(this);
    _initializationEpoch++;
    final controller = _controller;
    _controller = null;
    final fullscreen = _fullscreenRefresh;
    if (fullscreen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(fullscreen, _fullscreenRefresh)) fullscreen.value++;
      });
    }
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    super.dispose();
  }

  void _rememberPosition({bool force = false}) {
    if (!widget.rememberPlayback) return;
    if (_lastPosition <= Duration.zero) return;
    final now = DateTime.now();
    if (!force &&
        _rememberedAt != null &&
        now.difference(_rememberedAt!) < _rememberEvery) return;
    _rememberedAt = now;
    _manager.rememberPosition(_mediaId, _lastPosition);
  }

  void _flushPlaybackTracking() {
    final now = DateTime.now();
    final buffering = _bufferingSince;
    if (buffering != null) {
      _tracker.videoBufferingSpan(_mediaId, now.difference(buffering));
      _bufferingSince = null;
    }
    final playing = _playingSince;
    if (playing != null) {
      _tracker.videoPlaybackSpan(_mediaId, now.difference(playing));
      _playingSince = null;
    }
  }

  void _onManagerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && _ready) {
      controller.setVolume(_muted ? 0 : 1);
    }
    _syncPlayback();
    setState(() {});
  }

  void _updatePlayerView(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    final fullscreen = _fullscreenRefresh;
    if (fullscreen != null) fullscreen.value++;
  }

  void _syncPlayback() {
    final controller = _controller;
    if (_manager.isActive(this)) {
      _ensureController();
      if (controller == null || !_ready) return;
      if (_manager.activePaused) {
        if (controller.value.isPlaying) {
          _rememberPosition(force: true);
          controller.pause();
          _reportPlayState(false);
        }
        return;
      }
      if (!controller.value.isPlaying) controller.play();
    } else {
      if (controller != null && controller.value.isPlaying) {
        _rememberPosition(force: true);
        controller.pause();
        _reportPlayState(false);
      }
    }
  }

  void _reportPlayState(bool playing) {
    if (_reportedPlaying == playing) return;
    _reportedPlaying = playing;
    widget.onPlayStateChanged?.call(playing);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (_fullscreenRefresh != null) {
      _fullscreenVisibility = info;
      return;
    }
    final fraction = info.visibleFraction;
    _manager.updateVisibility(this, fraction,
        position: _feedPosition,
        mediaId: _mediaId,
        autoPlay: widget.autoPlay,
        playbackPosition: widget.rememberPlayback ? _lastPosition : null);
    final nowVisible = fraction >= _visibilityThreshold;
    if (nowVisible == _visible) {
      if (!nowVisible && widget.autoPlay && _manager.shouldPreload(this)) {
        _ensureController();
      }
      return;
    }
    _visible = nowVisible;
    if (nowVisible) {
      _disposeTimer?.cancel();
      _disposeTimer = null;
      _userPaused = false;
      _ensureController();
      _playTimer?.cancel();
      if (!widget.autoPlay) return;
      _playTimer = Timer(_playDelay, () {
        if (!mounted || !_visible || _userPaused) return;
        _manager.activate(this);
      });
    } else {
      _playTimer?.cancel();
      _playTimer = null;
      if (_manager.isActive(this)) _manager.deactivate(this);
      _scheduleDispose();
    }
  }

  void _scheduleDispose() {
    _disposeTimer?.cancel();
    final delay = _manager.lowMemoryMode
        ? const Duration(milliseconds: 1200)
        : _disposeDelay;
    _disposeTimer = Timer(delay, () {
      if (!mounted || _visible || _manager.isActive(this)) return;
      _releaseController();
    });
  }

  void _releaseController() {
    _initializationEpoch++;
    _rememberPosition(force: true);
    _flushPlaybackTracking();
    _reportPlayState(false);
    _tracker.videoReleased(_mediaId);
    final controller = _controller;
    _controller = null;
    _initializing = false;
    _ready = false;
    _firstFrameReported = false;
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    _updatePlayerView(() {});
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initializing) return;
    _initializing = true;
    _failed = false;
    _tracker.videoInitializeStarted(_mediaId);
    _updatePlayerView(() {});
    final epoch = ++_initializationEpoch;
    final remote = _usingFallback ? widget.uri : widget.playbackUri;
    final source = widget.useVideoCache && !_bypassCache
        ? await CommunityVideoCache.instance
            .playbackUri(remote)
            .timeout(const Duration(seconds: 2), onTimeout: () => remote)
        : remote;
    if (!mounted || epoch != _initializationEpoch) return;
    _cacheInUse = source != remote;
    final controller = VideoPlayerController.networkUrl(source,
        formatHint: source.path.toLowerCase().endsWith('.m3u8')
            ? VideoFormat.hls
            : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || !identical(_controller, controller)) return;
      await controller.setLooping(widget.loopVideo);
      await controller.setVolume(_muted ? 0 : 1);
      final resume = widget.rememberPlayback
          ? (_resumePosition ?? _manager.resumePosition(_mediaId))
          : null;
      _resumePosition = null;
      if (resume != null && resume > const Duration(seconds: 1)) {
        await controller.seekTo(resume);
      }
      final duration = controller.value.duration;
      if (duration > Duration.zero) {
        widget.onVideoDuration?.call(duration);
      }
      if (!mounted || !identical(_controller, controller)) return;
      _updatePlayerView(() {
        _initializing = false;
        _ready = true;
      });
      controller.addListener(_onPlayerChanged);
      _syncPlayback();
    } catch (_) {
      if (!mounted || !identical(_controller, controller)) return;
      _controller = null;
      // Native teardown can lag after a failed stream. Recover independently.
      unawaited(controller.dispose());
      if (!mounted) return;
      if (_cacheInUse && !_bypassCache) {
        _bypassCache = true;
        _initializing = false;
        await _ensureController();
        return;
      }
      if (!_usingFallback && widget.playbackUri != widget.uri) {
        _usingFallback = true;
        _initializing = false;
        await _ensureController();
        return;
      }
      _updatePlayerView(() {
        _initializing = false;
        _ready = false;
        _failed = true;
      });
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final value = controller.value;
    if (!value.hasError) {
      _lastPosition = value.position;
      if (value.isBuffering) {
        if (_bufferingSince == null) _bufferingSince = DateTime.now();
        final playing = _playingSince;
        if (playing != null) {
          _tracker.videoPlaybackSpan(
              _mediaId, DateTime.now().difference(playing));
          _playingSince = null;
        }
      } else {
        final buffering = _bufferingSince;
        if (buffering != null) {
          _tracker.videoBufferingSpan(
              _mediaId, DateTime.now().difference(buffering));
          _bufferingSince = null;
        }
        if (value.isPlaying) {
          _playingSince ??= DateTime.now();
          if (!_firstFrameReported) {
            _firstFrameReported = true;
            _tracker.videoFirstFrame(_mediaId);
          }
        } else {
          final playing = _playingSince;
          if (playing != null) {
            _tracker.videoPlaybackSpan(
                _mediaId, DateTime.now().difference(playing));
            _playingSince = null;
          }
        }
      }
      if (value.isPlaying) _rememberPosition();
      _reportPlayState(value.isPlaying && !value.isBuffering);
      return;
    }
    controller.removeListener(_onPlayerChanged);
    _reportPlayState(false);
    if (_cacheInUse || (!_usingFallback && widget.playbackUri != widget.uri)) {
      if (_cacheInUse) {
        _bypassCache = true;
      } else {
        _usingFallback = true;
      }
      _resumePosition = _lastPosition;
      _releaseController();
      _ensureController();
    } else {
      _releaseController();
      _updatePlayerView(() => _failed = true);
    }
  }

  void _togglePlay() {
    if (_failed) {
      _userPaused = false;
      _manager.activate(this);
      _retry();
      return;
    }
    final playing = _controller?.value.isPlaying ?? false;
    if (_manager.isActive(this) && playing) {
      _userPaused = true;
      _manager.suppress(this);
    } else {
      _userPaused = false;
      _manager.activate(this);
      _ensureController();
    }
  }

  void _retry() {
    _userPaused = false;
    _resumePosition = _lastPosition;
    _releaseController();
    _usingFallback = false;
    _bypassCache = false;
    _failed = false;
    _manager.activate(this);
    _ensureController();
  }

  Future<void> _openExternal() async {
    try {
      if (await launchUrl(widget.uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to the snackbar below.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(communityText('Could not open link.'))));
    }
  }

  Future<void> _openFullscreen() async {
    if (_fullscreenRefresh != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final refresh = ValueNotifier<int>(0);
    _fullscreenVisibility = null;
    _playTimer?.cancel();
    _disposeTimer?.cancel();
    setState(() => _fullscreenRefresh = refresh);
    _manager._enterFullscreen(this);
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: communityText('Close'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.white),
          ),
          title: Text(communityText('Video'),
              style: const TextStyle(color: AppColors.white)),
        ),
        body: SafeArea(
          top: false,
          child: ValueListenableBuilder<int>(
            valueListenable: refresh,
            builder: (context, _, __) {
              if (!mounted) {
                return Center(
                    child: Text(
                        communityText('This media link is unavailable.'),
                        style: const TextStyle(color: AppColors.white)));
              }
              final controller = _ready ? _controller : null;
              return Column(
                children: [
                  Expanded(
                    child: controller == null
                        ? Stack(fit: StackFit.expand, children: [
                            _thumbnailLayer(),
                            _statusOverlay(),
                          ])
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _togglePlay,
                            child: Stack(fit: StackFit.expand, children: [
                              _playerLayer(fit: BoxFit.contain),
                              _pausedOverlay(),
                            ]),
                          ),
                  ),
                  if (controller != null)
                    _FullscreenVideoControls(
                      key: ObjectKey(controller),
                      controller: controller,
                      onTogglePlay: _togglePlay,
                      onToggleMute: _toggleMute,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    try {
      await navigator.push(route);
      await route.completed;
    } finally {
      _manager._leaveFullscreen(this);
      _fullscreenRefresh = null;
      refresh.dispose();
      if (mounted) {
        _rememberPosition(force: true);
        setState(() {});
        final visibility = _fullscreenVisibility;
        if (visibility != null) _onVisibilityChanged(visibility);
        if (!_visible) {
          if (_manager.isActive(this)) _manager.deactivate(this);
          _scheduleDispose();
        }
      }
    }
  }

  void _toggleMute() {
    final controller = widget.muteController;
    if (controller != null) {
      controller.toggle();
    } else {
      _manager.toggleMuted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = communityMediaAspectRatio(widget.aspectRatio);
    return LayoutBuilder(builder: (context, constraints) {
      final contentHeight = widget.compact
          ? (constraints.hasBoundedHeight
              ? constraints.maxHeight
              : constraints.maxWidth)
          : math.max(180.0, constraints.maxWidth / aspectRatio);
      final height = widget.allowFullscreen && !widget.compact
          ? math.min(contentHeight,
              math.max(180.0, MediaQuery.sizeOf(context).height * .64))
          : contentHeight;
      return SizedBox(
          height: height,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VisibilityDetector(
                  key: _visibilityKey,
                  onVisibilityChanged: _onVisibilityChanged,
                  child: GestureDetector(
                      onTap: widget.videoTapEnabled ? _togglePlay : null,
                      child: Stack(fit: StackFit.expand, children: [
                        _thumbnailLayer(),
                        if (_ready &&
                            _controller != null &&
                            _fullscreenRefresh == null)
                          _playerLayer(),
                        if (!_ready) _statusOverlay(),
                        if (_ready) _pausedOverlay(),
                        if (_ready || widget.allowFullscreen) _topControls(),
                        if (_ready && _controller != null) _progressLayer(),
                      ])))));
    });
  }

  Widget _thumbnailLayer() {
    final thumbnail = widget.thumbnailUrl == null
        ? null
        : communityMediaUri('image', widget.thumbnailUrl!);
    final cacheWidth = ((MediaQuery.maybeSizeOf(context)?.width ?? 720) *
            (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2))
        .clamp(320, 1280)
        .round();
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.customFF13243A, AppColors.customFF07111F])),
        child: thumbnail == null
            ? const SizedBox.expand()
            : CachedNetworkImage(
                imageUrl: thumbnail.toString(),
                fit: BoxFit.cover,
                memCacheWidth: cacheWidth,
                maxWidthDiskCache: 1600,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, __, ___) => const SizedBox.expand()));
  }

  Widget _playerLayer({BoxFit fit = BoxFit.cover}) {
    final controller = _controller!;
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    return FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller)));
  }

  Widget _statusOverlay() {
    if (_failed) {
      return ColoredBox(
        color: AppColors.black.withValues(alpha: .5),
        child: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded,
                color: AppColors.white, size: 28),
            const SizedBox(height: 6),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(communityText('Video could not be loaded. Retry.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.w600))),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, color: AppColors.white),
                  label: Text(communityText('Retry'),
                      style: const TextStyle(color: AppColors.white))),
              TextButton(
                  onPressed: _openExternal,
                  child: Text(communityText('Open video in browser'),
                      style: const TextStyle(color: AppColors.white))),
            ]),
          ]),
        )),
      );
    }
    if (_initializing || (_visible && _manager.isActive(this))) {
      return const ColoredBox(
          color: AppColors.black26,
          child:
              Center(child: CircularProgressIndicator(color: AppColors.white)));
    }
    return const SizedBox.shrink();
  }

  Widget _pausedOverlay() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          if (value.isBuffering) {
            return const Center(
                child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        color: AppColors.white, strokeWidth: 2)));
          }
          if (value.isPlaying) return const SizedBox.shrink();
          return Center(
              child: Material(
                  color: AppColors.black.withValues(alpha: .42),
                  shape: const CircleBorder(),
                  child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.play_arrow_rounded,
                          color: AppColors.white, size: 34))));
        });
  }

  Widget _topControls() {
    final duration = communityMediaDurationLabel(widget.durationSeconds);
    return Positioned(
        top: 10,
        left: 10,
        right: 10,
        child: Row(children: [
          if (_ready && !widget.compact && duration != null)
            _MediaBadge(icon: Icons.play_circle_fill_rounded, label: duration),
          const Spacer(),
          if (widget.showMuteControl && _ready)
            Material(
                color: AppColors.black.withValues(alpha: .5),
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: communityText(_muted ? 'Unmute' : 'Mute'),
                    onPressed: _toggleMute,
                    icon: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: AppColors.white,
                        size: 18))),
          if (widget.allowFullscreen) ...[
            const SizedBox(width: 4),
            Material(
                color: AppColors.black.withValues(alpha: .5),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: communityText('Full screen'),
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded,
                      color: AppColors.white, size: 22),
                )),
          ],
        ]));
  }

  Widget _progressLayer() {
    return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: VideoProgressIndicator(_controller!,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 5),
            colors: const VideoProgressColors(
                playedColor: AppColors.customFF1769E8,
                bufferedColor: AppColors.white24,
                backgroundColor: AppColors.white54)));
  }
}

class _FullscreenVideoControls extends StatefulWidget {
  const _FullscreenVideoControls({
    super.key,
    required this.controller,
    required this.onTogglePlay,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;

  @override
  State<_FullscreenVideoControls> createState() =>
      _FullscreenVideoControlsState();
}

class _FullscreenVideoControlsState extends State<_FullscreenVideoControls> {
  double? _dragPosition;

  void _seek(double milliseconds) {
    final duration = widget.controller.value.duration.inMilliseconds;
    final position = milliseconds.round().clamp(0, duration).toInt();
    unawaited(widget.controller.seekTo(Duration(milliseconds: position)));
  }

  String _time(double milliseconds) =>
      communityMediaDurationLabel(milliseconds ~/ 1000)!;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final total = value.duration.inMilliseconds.toDouble();
          final position = (_dragPosition ?? value.position.inMilliseconds)
              .clamp(0, total)
              .toDouble();
          final canSeek = total > 0;
          final muted = value.volume == 0;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(_time(position),
                        style: const TextStyle(color: AppColors.white)),
                    Expanded(
                      child: Slider(
                        value: position,
                        max: canSeek ? total : 1,
                        activeColor: AppColors.white,
                        inactiveColor: AppColors.white30,
                        label: _time(position),
                        semanticFormatterCallback: _time,
                        onChanged: canSeek
                            ? (value) => setState(() => _dragPosition = value)
                            : null,
                        onChangeEnd: (value) {
                          _seek(value);
                          setState(() => _dragPosition = null);
                        },
                      ),
                    ),
                    Text(_time(total),
                        style: const TextStyle(color: AppColors.white)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: communityText('Back 10 seconds'),
                      onPressed: canSeek ? () => _seek(position - 10000) : null,
                      icon: const Icon(Icons.replay_10_rounded),
                      color: AppColors.white,
                    ),
                    IconButton(
                      tooltip: communityText(
                          value.isPlaying ? 'Pause video' : 'Play video'),
                      onPressed: widget.onTogglePlay,
                      icon: Icon(value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      color: AppColors.white,
                    ),
                    IconButton(
                      tooltip: communityText('Forward 10 seconds'),
                      onPressed: canSeek ? () => _seek(position + 10000) : null,
                      icon: const Icon(Icons.forward_10_rounded),
                      color: AppColors.white,
                    ),
                    IconButton(
                      tooltip: communityText(muted ? 'Unmute' : 'Mute'),
                      onPressed: widget.onToggleMute,
                      icon: Icon(muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded),
                      color: AppColors.white,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
