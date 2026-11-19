import 'package:uuid/uuid.dart';

/// A single slide inside the home hero banner slideshow.
///
/// [imageUrl] accepts an http(s) URL, an asset path (e.g.
/// `assets/images/angkor_wat_banner.png`) or an empty value which renders the
/// built-in Angkor Wat heritage artwork.
class BannerSlide {
  final String id;
  final String imageUrl;
  final String linkUrl;
  final String title;
  final String subtitle;
  final String actionLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool enabled;

  const BannerSlide({
    required this.id,
    this.imageUrl = '',
    this.linkUrl = '',
    this.title = '',
    this.subtitle = '',
    this.actionLabel = '',
    this.startsAt,
    this.endsAt,
    this.enabled = true,
  });

  static String newId() => const Uuid().v4();

  bool isPublished(DateTime now) =>
      enabled &&
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || now.isBefore(endsAt!));

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get hasLink => linkUrl.trim().isNotEmpty;

  bool get isDefaultArtwork => !hasImage;

  bool get isNetworkImage {
    final value = imageUrl.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  BannerSlide copyWith({
    String? id,
    String? imageUrl,
    String? linkUrl,
    String? title,
    String? subtitle,
    String? actionLabel,
    bool? enabled,
  }) {
    return BannerSlide(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      actionLabel: actionLabel ?? this.actionLabel,
      startsAt: startsAt,
      endsAt: endsAt,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageUrl': imageUrl,
        'linkUrl': linkUrl,
        'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        if (actionLabel.isNotEmpty) 'actionLabel': actionLabel,
        if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
        'enabled': enabled,
      };

  factory BannerSlide.fromJson(Map<String, dynamic> json) {
    return BannerSlide(
      id: (json['id'] ?? '').toString().trim().isEmpty
          ? newId()
          : json['id'].toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      linkUrl: (json['linkUrl'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      actionLabel: (json['actionLabel'] ?? '').toString(),
      startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}'),
      endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}'),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }
}

/// Slideshow behaviour for the home hero banner.
///
/// Stored locally (SharedPreferences) so admins can tune the rotation speed
/// and slide list per device without a backend round-trip.
class BannerSlideshowConfig {
  static const int minIntervalSeconds = 2;
  static const int maxIntervalSeconds = 30;
  static const int defaultIntervalSeconds = 5;

  static const String transitionFade = 'fade';
  static const String transitionSlide = 'slide';
  static const String transitionSlideUp = 'slide-up';
  static const String transitionZoom = 'zoom';
  static const String transitionInstant = 'instant';

  static const transitionLabels = {
    transitionFade: 'Fade',
    transitionSlide: 'Slide left',
    transitionSlideUp: 'Slide up',
    transitionZoom: 'Zoom in',
    transitionInstant: 'Instant',
  };

  final List<BannerSlide> slides;
  final int intervalSeconds;
  final bool autoplay;
  final bool showIndicators;
  final bool animateBorder;
  final bool pauseOnTouch;
  final bool loop;
  final String transition;

  const BannerSlideshowConfig({
    this.slides = const [],
    this.intervalSeconds = defaultIntervalSeconds,
    this.autoplay = true,
    this.showIndicators = true,
    this.animateBorder = false,
    this.pauseOnTouch = true,
    this.loop = true,
    this.transition = transitionFade,
  });

  /// Slides that actually render, in display order.
  List<BannerSlide> get enabledSlides =>
      slides.where((slide) => slide.enabled).toList();

  int get effectiveIntervalSeconds {
    if (intervalSeconds < minIntervalSeconds) return minIntervalSeconds;
    if (intervalSeconds > maxIntervalSeconds) return maxIntervalSeconds;
    return intervalSeconds;
  }

  bool get isLooping => transition.isNotEmpty && loop;

  BannerSlideshowConfig copyWith({
    List<BannerSlide>? slides,
    int? intervalSeconds,
    bool? autoplay,
    bool? showIndicators,
    bool? animateBorder,
    bool? pauseOnTouch,
    bool? loop,
    String? transition,
  }) {
    return BannerSlideshowConfig(
      slides: slides ?? this.slides,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      autoplay: autoplay ?? this.autoplay,
      showIndicators: showIndicators ?? this.showIndicators,
      animateBorder: animateBorder ?? this.animateBorder,
      pauseOnTouch: pauseOnTouch ?? this.pauseOnTouch,
      loop: loop ?? this.loop,
      transition: transition ?? this.transition,
    );
  }

  /// Builds a single-slide config from the legacy single-banner preferences.
  factory BannerSlideshowConfig.legacy({
    required String imageUrl,
    String linkUrl = '',
    String title = '',
  }) {
    return BannerSlideshowConfig(slides: [
      BannerSlide(
        id: BannerSlide.newId(),
        imageUrl: imageUrl.trim(),
        linkUrl: linkUrl.trim(),
        title: title.trim(),
      ),
    ]);
  }

  Map<String, dynamic> toJson() => {
        'slides': slides.map((slide) => slide.toJson()).toList(),
        'intervalSeconds': effectiveIntervalSeconds,
        'autoplay': autoplay,
        'showIndicators': showIndicators,
        'animateBorder': animateBorder,
        'pauseOnTouch': pauseOnTouch,
        'loop': loop,
        'transition': transition,
      };

  factory BannerSlideshowConfig.fromJson(Map<String, dynamic> json) {
    final rawSlides = json['slides'];
    final slides = <BannerSlide>[];
    if (rawSlides is List) {
      for (final item in rawSlides) {
        if (item is Map) {
          slides.add(BannerSlide.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawInterval = json['intervalSeconds'];
    var interval = defaultIntervalSeconds;
    if (rawInterval is num) {
      interval = rawInterval.toInt();
    } else {
      interval = int.tryParse('${rawInterval ?? ''}') ?? defaultIntervalSeconds;
    }
    if (interval < minIntervalSeconds) interval = minIntervalSeconds;
    if (interval > maxIntervalSeconds) interval = maxIntervalSeconds;

    final rawTransition = json['transition']?.toString().trim();
    final transition = transitionLabels.containsKey(rawTransition)
        ? rawTransition!
        : transitionFade;

    return BannerSlideshowConfig(
      slides: slides,
      intervalSeconds: interval,
      autoplay: json['autoplay'] is bool ? json['autoplay'] as bool : true,
      showIndicators: json['showIndicators'] is bool
          ? json['showIndicators'] as bool
          : true,
      animateBorder: json['animateBorder'] == true,
      pauseOnTouch:
          json['pauseOnTouch'] is bool ? json['pauseOnTouch'] as bool : true,
      loop: json['loop'] is bool ? json['loop'] as bool : true,
      transition: transition,
    );
  }
}
