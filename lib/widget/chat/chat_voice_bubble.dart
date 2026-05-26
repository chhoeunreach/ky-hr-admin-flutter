import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ChatVoiceBubble extends StatefulWidget {
  final String mediaUrl;
  final String mediaPath;
  final bool isIncoming;
  final int? durationSeconds;

  const ChatVoiceBubble({
    super.key,
    required this.mediaUrl,
    this.mediaPath = '',
    required this.isIncoming,
    this.durationSeconds,
  });

  @override
  State<ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<ChatVoiceBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration? _audioDuration;

  static final AudioContext _voiceAudioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransient,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
    ),
  );

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _audioDuration = duration;
      });
    });
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      final playbackUrl = await _playbackUrl(widget.mediaUrl, widget.mediaPath);
      debugPrint('[VOICE_PLAYBACK] url=$playbackUrl');
      await _audioPlayer
          .play(
            UrlSource(playbackUrl),
            ctx: _voiceAudioContext,
            mode: PlayerMode.mediaPlayer,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[VOICE_PLAYBACK] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _audioPlayer.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isLoading = false;
      });
      showToast(_playbackErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    final secondary = Colors.white;
    final playBackground =
        widget.isIncoming ? const Color(0xff1684f8) : const Color(0x26000000);
    final playForeground = Colors.white;
    final progress = _playbackProgress();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: playBackground,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: playForeground,
                      size: 25,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 30,
              child: _Waveform(
                baseColor: foreground,
                activeColor: Colors.white,
                isPlaying: _isPlaying,
                progress: progress,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_displaySeconds()),
            style: TextStyle(
              color: secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _playbackProgress() {
    final duration = _audioDuration ??
        (widget.durationSeconds == null
            ? null
            : Duration(seconds: widget.durationSeconds!));
    if (duration == null || duration.inMilliseconds <= 0) {
      return 0;
    }

    return (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  int _displaySeconds() {
    if (_isPlaying && _position.inSeconds > 0) {
      return _position.inSeconds;
    }

    final duration = _audioDuration;
    if (duration != null && duration.inSeconds > 0) {
      return duration.inSeconds;
    }

    final fallback = widget.durationSeconds;
    return fallback == null || fallback <= 0 ? 0 : fallback;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<String> _playbackUrl(String value, String mediaPath) async {
    final url = value.trim();
    final path = mediaPath.trim();
    final resolvedFromPath = await _resolveUrlFromMediaPath(path);
    final resolvedUrl = resolvedFromPath.isNotEmpty
        ? resolvedFromPath
        : await _repairAudioUrl(url);

    if (resolvedUrl.trim().isEmpty) {
      throw const FormatException('Voice message URL is empty');
    }

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme) {
      throw FormatException('Voice message URL is invalid: $resolvedUrl');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS && uri.scheme == 'http') {
      throw const FormatException(
        'iOS blocked insecure voice URL. Please use HTTPS media URLs.',
      );
    }

    return Uri.encodeFull(resolvedUrl);
  }

  bool _looksLikeAudioUrl(String value) {
    if (value.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final path = uri.path.trim().toLowerCase();
    if (path.isEmpty || path == '/' || path.endsWith('.html')) {
      return false;
    }

    const audioExtensions = [
      '.m4a',
      '.mp4',
      '.mp3',
      '.wav',
      '.aac',
      '.webm',
      '.ogg',
      '.oga',
    ];
    return audioExtensions.any(path.endsWith) ||
        path.contains('/voice/') ||
        path.contains('/audio/');
  }

  Future<String> _repairAudioUrl(String value) async {
    final url = value.trim();
    if (!_looksLikeAudioUrl(url)) {
      return '';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '';
    }

    final appUrl = (await Preferences().getAppUrl()).trim();
    final appUri = Uri.tryParse(appUrl);
    if (appUri == null || appUri.host != uri.host) {
      return url;
    }

    final path = uri.path.trim();
    if (path.startsWith('/storage/')) {
      return url;
    }

    final lowerPath = path.toLowerCase();
    if (lowerPath.startsWith('/chat/voice/') || lowerPath.startsWith('chat/voice/')) {
      final normalizedPath = path.startsWith('/')
          ? '/storage$path'
          : '/storage/$path';
      return uri.replace(path: normalizedPath).toString();
    }

    return url;
  }

  Future<String> _resolveUrlFromMediaPath(String mediaPath) async {
    if (mediaPath.isEmpty) {
      return '';
    }

    final baseUrl = await Preferences().getAppUrl();
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null) {
      return mediaPath;
    }

    if (mediaPath.startsWith('http://') || mediaPath.startsWith('https://')) {
      return mediaPath;
    }

    final normalizedPath = mediaPath.startsWith('/storage/')
        ? mediaPath
        : mediaPath.startsWith('storage/')
            ? '/$mediaPath'
            : '/storage/${mediaPath.replaceFirst(RegExp(r'^/+'), '')}';
    return baseUri.resolve(normalizedPath).toString();
  }

  String _playbackErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('insecure voice URL')) {
      return 'Voice cannot play on iOS because the media URL is not HTTPS.';
    }
    if (message.contains('TimeoutException')) {
      return 'Voice message took too long to load.';
    }
    return 'Unable to play this voice message.';
  }
}

class _Waveform extends StatelessWidget {
  final Color baseColor;
  final Color activeColor;
  final bool isPlaying;
  final double progress;

  const _Waveform({
    required this.baseColor,
    required this.activeColor,
    required this.isPlaying,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    const heights = <double>[
      10,
      18,
      25,
      16,
      28,
      20,
      13,
      24,
      29,
      17,
      22,
      12,
      27,
      19,
      15,
      24,
      28,
      14,
      20,
      26,
      12,
      18,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < heights.length; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 3,
            height: isPlaying && index.isEven
                ? (heights[index] + 4).clamp(8.0, 30.0)
                : heights[index],
            decoration: BoxDecoration(
              color: index / heights.length <= progress
                  ? activeColor
                  : baseColor.withValues(alpha: index.isEven ? .72 : .48),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
