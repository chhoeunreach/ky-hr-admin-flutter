import 'community_strings.dart';
import 'video_cache.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      this.useVideoCache = true});
  final String type;
  final String url;
  final bool compact;
  final VoidCallback? onImageTap;
  final String? thumbnailUrl;
  final String? playbackUrl;
  final Object? durationSeconds;
  final Object? aspectRatio;

  /// When true, direct video files start playing automatically as they scroll
  /// into view (Facebook-style). Only the most visible video plays at a time.
  final bool autoPlay;
  final bool useVideoCache;

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
          aspectRatio: aspectRatio);
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
          color: const Color(0xfff3f6fa),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.link_off_rounded, color: Color(0xff718096)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(communityText('This media link is unavailable.'),
                style: const TextStyle(color: Color(0xff5f6f82))))
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

  Widget _imageStack() => Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
            imageUrl: widget.uri.toString(),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            progressIndicatorBuilder: (_, __, progress) => ColoredBox(
                color: const Color(0xffedf2f7),
                child: Center(
                    child: CircularProgressIndicator(
                        value: progress.progress, strokeWidth: 2))),
            errorWidget: (_, __, ___) => _MediaError(
                icon: Icons.broken_image_outlined,
                message: communityText('Image could not be loaded.'),
                uri: widget.uri,
                action: communityText('Open image'))),
      ]);

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: widget.onTap ??
          () => launchUrl(widget.uri, mode: LaunchMode.externalApplication),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.compact
              ? SizedBox.expand(child: _imageStack())
              : AspectRatio(aspectRatio: _aspectRatio, child: _imageStack())));
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
          color: const Color(0xfff3f6fa),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.description_rounded,
            color: const Color(0xff5068a0), size: compact ? 25 : 28),
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
      color: const Color(0xffedf2f7),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: const Color(0xff718096)),
        const SizedBox(height: 6),
        Text(message, style: const TextStyle(color: Color(0xff5f6f82))),
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
          color: Colors.black.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
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
<style>html,body{margin:0;width:100%;height:100%;background:#101826}</style>
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
            const Icon(Icons.link_rounded, size: 30, color: Color(0xff1769e8)),
            const SizedBox(height: 6),
            Text(communityText('Open link'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xff24466f)))
          ])
        : Row(children: [
            const Icon(Icons.link_rounded, color: Color(0xff1769e8)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(uri.toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.open_in_new, size: 17)
          ]);
    return Material(
        color: const Color(0xffeef4ff),
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
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlay,
            child: const Padding(
                padding: EdgeInsets.all(17),
                child: Icon(Icons.play_arrow_rounded,
                    size: 38, color: Color(0xff1769e8)))));
    final thumbnail =
        thumbnailUrl == null ? null : communityMediaUri('image', thumbnailUrl!);
    final duration = communityMediaDurationLabel(durationSeconds);
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff13243a), Color(0xff07111f)])),
        child: Stack(fit: StackFit.expand, children: [
          if (thumbnail != null)
            CachedNetworkImage(
                imageUrl: thumbnail.toString(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink()),
          if (thumbnail != null)
            ColoredBox(color: Colors.black.withValues(alpha: .28)),
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
                  ? const CircularProgressIndicator(color: Colors.white)
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
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])))
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
class FeedVideoAutoplayManager extends ChangeNotifier {
  FeedVideoAutoplayManager._() {
    WidgetsBinding.instance.addObserver(_AutoplayLifecycleObserver(this));
  }

  static final FeedVideoAutoplayManager instance = FeedVideoAutoplayManager._();

  Object? _active;
  bool _muted = true;
  bool _foreground = true;

  bool get muted => _muted;
  bool get foreground => _foreground;

  bool isActive(Object owner) => _foreground && identical(_active, owner);

  void activate(Object owner) {
    if (identical(_active, owner) && _foreground) return;
    _active = owner;
    notifyListeners();
  }

  void deactivate(Object owner) {
    if (!identical(_active, owner)) return;
    _active = null;
    notifyListeners();
  }

  /// Pauses the current video, for example before opening another screen.
  void pauseAll() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void toggleMuted() => setMuted(!_muted);

  void _setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    notifyListeners();
  }
}

class _AutoplayLifecycleObserver with WidgetsBindingObserver {
  _AutoplayLifecycleObserver(this._manager);

  final FeedVideoAutoplayManager _manager;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _manager._setForeground(state == AppLifecycleState.resumed);
  }
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
  });

  final Uri uri;
  final Uri playbackUri;
  final bool autoPlay;
  final bool useVideoCache;
  final bool compact;
  final String? thumbnailUrl;
  final Object? durationSeconds;
  final Object? aspectRatio;

  @override
  State<_AutoplayVideo> createState() => _AutoplayVideoState();
}

class _AutoplayVideoState extends State<_AutoplayVideo> {
  static const double _visibilityThreshold = .6;
  static const Duration _playDelay = Duration(milliseconds: 350);
  static const Duration _disposeDelay = Duration(seconds: 4);

  final FeedVideoAutoplayManager _manager = FeedVideoAutoplayManager.instance;
  final UniqueKey _visibilityKey = UniqueKey();

  VideoPlayerController? _controller;
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
  Duration? _resumePosition;
  Duration _lastPosition = Duration.zero;
  int _initializationEpoch = 0;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerChanged);
  }

  @override
  void didUpdateWidget(covariant _AutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _resumePosition = null;
    _lastPosition = Duration.zero;
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
    _manager.deactivate(this);
    _initializationEpoch++;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    super.dispose();
  }

  void _onManagerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && _ready) {
      controller.setVolume(_manager.muted ? 0 : 1);
    }
    _syncPlayback();
    setState(() {});
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (_manager.isActive(this)) {
      if (!controller.value.isPlaying) controller.play();
    } else if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final nowVisible = info.visibleFraction >= _visibilityThreshold;
    if (nowVisible == _visible) return;
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
    _disposeTimer = Timer(_disposeDelay, () {
      if (!mounted || _visible || _manager.isActive(this)) return;
      _releaseController();
    });
  }

  void _releaseController() {
    _initializationEpoch++;
    final controller = _controller;
    _controller = null;
    _initializing = false;
    _ready = false;
    controller?.removeListener(_onPlayerChanged);
    controller?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initializing) return;
    _initializing = true;
    _failed = false;
    if (mounted) setState(() {});
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
      await controller.setLooping(true);
      await controller.setVolume(_manager.muted ? 0 : 1);
      final resume = _resumePosition;
      _resumePosition = null;
      if (resume != null && resume > Duration.zero)
        await controller.seekTo(resume);
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
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
      setState(() {
        _initializing = false;
        _ready = false;
        _failed = true;
      });
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (!controller.value.hasError) {
      _lastPosition = controller.value.position;
      return;
    }
    controller.removeListener(_onPlayerChanged);
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
      setState(() => _failed = true);
    }
  }

  void _togglePlay() {
    if (_failed) {
      _userPaused = false;
      _manager.activate(this);
      _retry();
      return;
    }
    if (_manager.isActive(this)) {
      _userPaused = true;
      _manager.deactivate(this);
    } else {
      _userPaused = false;
      _manager.activate(this);
      _ensureController();
    }
  }

  void _retry() {
    _userPaused = false;
    _manager.activate(this);
    _usingFallback = false;
    _bypassCache = false;
    _resumePosition = _lastPosition;
    _releaseController();
    _failed = false;
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

  @override
  Widget build(BuildContext context) {
    final aspectRatio = communityMediaAspectRatio(widget.aspectRatio);
    return LayoutBuilder(builder: (context, constraints) {
      final height = widget.compact
          ? (constraints.hasBoundedHeight
              ? constraints.maxHeight
              : constraints.maxWidth)
          : math.max(180.0, constraints.maxWidth / aspectRatio);
      return SizedBox(
          height: height,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VisibilityDetector(
                  key: _visibilityKey,
                  onVisibilityChanged: _onVisibilityChanged,
                  child: GestureDetector(
                      onTap: _togglePlay,
                      child: Stack(fit: StackFit.expand, children: [
                        _thumbnailLayer(),
                        if (_ready && _controller != null) _playerLayer(),
                        if (!_ready) _statusOverlay(),
                        if (_ready) _pausedOverlay(),
                        if (_ready) _topControls(),
                        if (_ready && _controller != null) _progressLayer(),
                      ])))));
    });
  }

  Widget _thumbnailLayer() {
    final thumbnail = widget.thumbnailUrl == null
        ? null
        : communityMediaUri('image', widget.thumbnailUrl!);
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff13243a), Color(0xff07111f)])),
        child: thumbnail == null
            ? const SizedBox.expand()
            : CachedNetworkImage(
                imageUrl: thumbnail.toString(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.expand()));
  }

  Widget _playerLayer() {
    final controller = _controller!;
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller)));
  }

  Widget _statusOverlay() {
    if (_failed) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: .5),
        child: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(communityText('Video could not be loaded. Retry.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: Text(communityText('Retry'),
                      style: const TextStyle(color: Colors.white))),
              TextButton(
                  onPressed: _openExternal,
                  child: Text(communityText('Open video in browser'),
                      style: const TextStyle(color: Colors.white))),
            ]),
          ]),
        )),
      );
    }
    if (_initializing || (_visible && _manager.isActive(this))) {
      return const ColoredBox(
          color: Colors.black26,
          child: Center(child: CircularProgressIndicator(color: Colors.white)));
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
                        color: Colors.white, strokeWidth: 2)));
          }
          if (value.isPlaying) return const SizedBox.shrink();
          return Center(
              child: Material(
                  color: Colors.black.withValues(alpha: .42),
                  shape: const CircleBorder(),
                  child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 34))));
        });
  }

  Widget _topControls() {
    final duration = communityMediaDurationLabel(widget.durationSeconds);
    return Positioned(
        top: 10,
        left: 10,
        right: 10,
        child: Row(children: [
          if (duration != null)
            _MediaBadge(icon: Icons.play_circle_fill_rounded, label: duration),
          const Spacer(),
          Material(
              color: Colors.black.withValues(alpha: .5),
              shape: const CircleBorder(),
              child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _manager.toggleMuted,
                  child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                          _manager.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 18))))
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
                playedColor: Color(0xff1769e8),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white54)));
  }
}
