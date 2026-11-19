import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_detail_screen.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/features/banner_slideshow/banner_slideshow_api.dart';
import 'package:cnattendance/features/banner_slideshow/banner_border_animation.dart';
import 'package:cnattendance/features/banner_slideshow/banner_slide_switcher.dart';
import 'package:cnattendance/features/quotes/mobile_quote_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/widget/homescreen/home_attendance_highlights.dart';
import 'package:cnattendance/widget/homescreen/khmer_heritage_home.dart';
import 'royal_dashboard_widgets.dart';
import 'royal_quick_actions.dart';
import 'royal_calendar_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

Color _premiumTone(Color color, double amount) =>
    Color.lerp(color, Colors.black, amount)!;

class HomeModelView extends StatefulWidget {
  const HomeModelView({
    super.key,
    required this.clockNow,
    required this.summary,
    required this.pulseController,
    required this.animated,
    required this.onAttendanceTap,
    required this.onRefreshZone,
    required this.allowedDistanceMeters,
    required this.distanceMeters,
    required this.isInZone,
    required this.isRefreshingZone,
    required this.attendanceList,
    this.mapWidget,
    this.controller,
    this.bannerConfig,
    this.otherSections = const {},
    this.scannerBusy = false,
    this.dashboardLoading = false,
    this.dashboardError = false,
    this.onRetryDashboard,
  });

  final bool scannerBusy;
  final bool dashboardLoading;
  final bool dashboardError;
  final VoidCallback? onRetryDashboard;
  final ValueNotifier<DateTime> clockNow;
  final MonthlyAttendanceSummary? summary;
  final AnimationController pulseController;
  final bool animated;
  final VoidCallback onAttendanceTap;
  final VoidCallback onRefreshZone;
  final double allowedDistanceMeters;
  final double? distanceMeters;
  final bool isInZone;
  final bool isRefreshingZone;
  final Map<String, dynamic> attendanceList;
  final Widget? mapWidget;
  final PersistentTabController? controller;
  final HomeBannerConfig? bannerConfig;
  final Map<LayoutItem, Widget> otherSections;

  @override
  State<HomeModelView> createState() => _HomeModelViewState();
}

class _HomeModelViewState extends State<HomeModelView>
    with WidgetsBindingObserver {
  final CommunityApi _communityApi = CommunityApi();
  final Preferences _preferences = Preferences();
  HomeBannerConfig _bannerConfig = const HomeBannerConfig();
  BannerSlideshowConfig _slideshow = const BannerSlideshowConfig();
  final List<Map<String, dynamic>> _storyGroups = [];
  bool _storiesLoading = true;
  String? _storiesError;
  int _storiesGeneration = 0;
  bool _storiesPermissionWasEnabled = false;
  int _storiesTab = 0;
  final HomeHighlightApi _homeHighlights = HomeHighlightApi();
  Future<List<HomeHighlight>>? _highlights;
  final ValueNotifier<int> _royalQuoteTick = ValueNotifier<int>(0);

  // Slideshow rotation state. Rotation only notifies [slideTick] so the rest
  // of the home column is not rebuilt on every slide change.
  int _slideIndex = 0;
  bool _contentLoading = false;
  bool _reloadContent = false;
  bool _royalTheme = false;
  bool _motionDisabled = false;
  double _royalBannerDrag = 0;
  Timer? _publicationTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final royal = EnterpriseTheme.of(context).isRoyalBlueGold;
    final motionDisabled = MediaQuery.disableAnimationsOf(context);
    if (_royalTheme != royal || _motionDisabled != motionDisabled) {
      _royalTheme = royal;
      _motionDisabled = motionDisabled;
      _syncSlideTimer();
      _syncQuoteTimer();
    }
  }

  final ValueNotifier<int> slideTick = ValueNotifier<int>(0);
  Timer? _slideTimer;
  Timer? _quoteTimer;
  MobileQuotePlayback _quotePlayback = const MobileQuotePlayback();
  int _quoteIndex = 0;
  bool _slideTouchPaused = false;
  bool _appForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerConfig();
    _preferences.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _storiesGeneration++;
    _slideTimer?.cancel();
    _publicationTimer?.cancel();
    _quoteTimer?.cancel();
    slideTick.dispose();
    _royalQuoteTick.dispose();
    _homeHighlights.dispose();
    _preferences.removeListener(_onPreferencesChanged);
    _communityApi.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appForeground;
    _appForeground = state == AppLifecycleState.resumed;
    _syncSlideTimer();
    _syncQuoteTimer();
    if (wasForeground != _appForeground && _activeSlideshow.animateBorder) {
      slideTick.value++;
    }
    if (_appForeground) {
      unawaited(_loadBannerConfig());
      if (_royalTheme && _highlights != null) {
        setState(() => _highlights = null);
      }
    }
  }

  void _onPreferencesChanged() {
    _loadBannerConfig();
  }

  /// Slides currently rendered on the hero banner.
  List<BannerSlide> get _activeSlides {
    // An externally supplied config always wins and renders as a single slide.
    final external = widget.bannerConfig;
    if (external != null) {
      return [
        BannerSlide(
          id: 'external',
          imageUrl: external.bannerImageUrl ?? '',
          linkUrl: external.bannerLinkUrl ?? '',
          title: external.bannerTitle ?? '',
        ),
      ];
    }
    if (!_royalTheme) return _slideshow.enabledSlides;
    final now = DateTime.now();
    return _slideshow.slides.where((slide) => slide.isPublished(now)).toList();
  }

  BannerSlideshowConfig get _activeSlideshow => widget.bannerConfig != null
      ? const BannerSlideshowConfig(autoplay: false, showIndicators: false)
      : _slideshow;

  void _syncSlideTimer() {
    _slideTimer?.cancel();
    _slideTimer = null;

    final slides = _activeSlides;
    final config = _activeSlideshow;
    _publicationTimer?.cancel();
    final royal = _royalTheme;
    if (royal && _appForeground) {
      final now = DateTime.now();
      final boundaries = [
        for (final slide in _slideshow.enabledSlides)
          ...[slide.startsAt, slide.endsAt].whereType<DateTime>(),
      ].where((time) => time.isAfter(now)).toList()
        ..sort();
      if (boundaries.isNotEmpty) {
        _publicationTimer = Timer(boundaries.first.difference(now), () {
          if (!mounted) return;
          _slideIndex = 0;
          slideTick.value++;
          _syncSlideTimer();
          _precacheUpcomingSlides();
        });
      }
    }
    if (_motionDisabled ||
        !config.autoplay ||
        slides.length <= 1 ||
        (_slideTouchPaused && (royal || config.pauseOnTouch)) ||
        !_appForeground ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }

    _slideTimer = Timer.periodic(
      Duration(seconds: royal ? 5 : config.effectiveIntervalSeconds),
      (_) {
        if (!mounted ||
            !_appForeground ||
            (_slideTouchPaused && (royal || config.pauseOnTouch)) ||
            !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return;
        }
        final count = _activeSlides.length;
        if (count <= 1) return;
        if (_slideIndex >= count - 1 && !config.loop) {
          _slideTimer?.cancel();
          _slideTimer = null;
          return;
        }
        _slideIndex = (_slideIndex + 1) % count;
        slideTick.value++;
        _precacheUpcomingSlides();
      },
    );
  }

  void _syncQuoteTimer() {
    _quoteTimer?.cancel();
    final settings = _quotePlayback.settings;
    if (!mounted ||
        widget.bannerConfig != null ||
        _motionDisabled ||
        !_appForeground ||
        (_slideTouchPaused && settings.pauseOnTouch) ||
        !settings.autoplay ||
        _quotePlayback.quotes.length < 2 ||
        (!settings.loop && _quoteIndex == _quotePlayback.quotes.length - 1)) {
      return;
    }

    _quoteTimer = Timer.periodic(
      Duration(seconds: settings.effectiveIntervalSeconds),
      (timer) {
        if (!mounted ||
            !_appForeground ||
            !(ModalRoute.of(context)?.isCurrent ?? true)) {
          return;
        }
        final count = _quotePlayback.quotes.length;
        _quoteIndex = (_quoteIndex + 1) % count;
        if (_royalTheme) {
          _royalQuoteTick.value++;
        } else {
          slideTick.value++;
        }
        if (!settings.loop && _quoteIndex == count - 1) timer.cancel();
      },
    );
  }

  void _handleSlideTouchPause(bool paused) {
    if (_slideTouchPaused == paused) return;
    _slideTouchPaused = paused;
    _syncSlideTimer();
    _syncQuoteTimer();
  }

  Future<void> _loadBannerConfig() async {
    if (_contentLoading) {
      _reloadContent = true;
      return;
    }
    _contentLoading = true;
    try {
      final cached = await _preferences.getHomeSlideshow();
      final quote = await _preferences.getHomeQuote();
      final quoteAuthor = await _preferences.getHomeQuoteAuthor();
      final quoteStyle = await _preferences.getHomeQuoteStyle();
      final showQuote = await _preferences.getHomeQuoteShow();
      if (!mounted) return;

      _applyBannerConfig(
        cached,
        quote: quote,
        quoteAuthor: quoteAuthor,
        quoteStyle: quoteStyle,
        showQuote: showQuote,
      );

      final banner = _refreshBanner(cached);
      if (_royalTheme) {
        await Future.wait([banner, _refreshQuotes()]);
      } else {
        await banner;
        if (mounted) await _refreshQuotes();
      }
    } finally {
      _contentLoading = false;
      if (_reloadContent && mounted) {
        _reloadContent = false;
        unawaited(_loadBannerConfig());
      }
    }
  }

  Future<void> _refreshBanner(BannerSlideshowConfig cached) async {
    try {
      final fresh = await BannerSlideshowApi()
          .fetch()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      await _preferences.cacheHomeSlideshow(fresh);
      if (!mounted ||
          jsonEncode(fresh.toJson()) == jsonEncode(cached.toJson())) {
        return;
      }
      final quote = _bannerConfig;
      _applyBannerConfig(
        fresh,
        quote: quote.quote,
        quoteAuthor: quote.quoteAuthor,
        quoteStyle: quote.quoteStyle,
        showQuote: quote.showQuote,
      );
    } catch (_) {
      // The saved config remains available offline.
    }
  }

  Future<void> _refreshQuotes() async {
    try {
      final playback = await MobileQuoteApi()
          .fetchActive()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final active = playback.quotes.firstOrNull;
      final text = active?.text ?? HomeBannerConfig.defaultQuote;
      await _preferences.cacheHomeQuote(
        text: text,
        author: active?.author,
        style: active?.style,
      );
      if (!mounted) return;
      setState(() {
        _quotePlayback = playback;
        _quoteIndex = 0;
        _bannerConfig = HomeBannerConfig(
          quote: text,
          quoteAuthor: active?.author,
          quoteStyle: active?.style,
          showQuote: active != null || _bannerConfig.showQuote,
        );
      });
      _syncQuoteTimer();
    } catch (_) {
      // The saved quotation remains available offline.
    }
  }

  void _applyBannerConfig(
    BannerSlideshowConfig slideshow, {
    required String quote,
    String? quoteAuthor,
    QuoteStyle? quoteStyle,
    required bool showQuote,
  }) {
    final slides = slideshow.enabledSlides;
    final first = slides.isNotEmpty ? slides.first : null;
    setState(() {
      _slideshow = slideshow;
      _slideIndex = 0;
      _bannerConfig = HomeBannerConfig(
        bannerImageUrl:
            (first?.imageUrl ?? '').trim().isEmpty ? null : first!.imageUrl,
        bannerLinkUrl:
            (first?.linkUrl ?? '').trim().isEmpty ? null : first!.linkUrl,
        bannerTitle: (first?.title ?? '').trim().isEmpty ? null : first!.title,
        quote: quote,
        quoteAuthor: quoteAuthor,
        quoteStyle: quoteStyle,
        showQuote: showQuote,
        isAngkorWatDefault: first == null || !first.hasImage,
      );
    });
    slideTick.value++;
    _syncSlideTimer();
    _precacheUpcomingSlides();
  }

  void _precacheUpcomingSlides() {
    if (!mounted) return;
    final slides = _activeSlides;
    if (slides.isEmpty) return;
    final indexes = <int>{
      _slideIndex % slides.length,
      (_slideIndex + 1) % slides.length
    };
    for (final index in indexes) {
      final slide = slides[index];
      if (!slide.isNetworkImage) continue;
      unawaited(
        precacheImage(
          ResizeImage(CachedNetworkImageProvider(slide.imageUrl.trim()),
              width: 1000),
          context,
        ).catchError((_) {}),
      );
    }
  }

  Future<void> _launchBannerUrl(String url) async {
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        EasyLoading.showToast('Could not open link: $url');
      }
    } catch (_) {
      EasyLoading.showToast('Invalid link format');
    }
  }

  Future<void> _loadStories() async {
    final generation = ++_storiesGeneration;
    if (mounted) {
      setState(() {
        _storiesLoading = true;
        _storiesError = null;
      });
    }
    try {
      final response = await _communityApi.request('GET', 'social-stories');
      if (!mounted || generation != _storiesGeneration) return;
      final rawGroups = response['data'];
      if (rawGroups != null && rawGroups is! List) {
        throw const FormatException('The stories response is invalid.');
      }
      final groups = (rawGroups as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((group) =>
              group['author'] is Map &&
              group['stories'] is List &&
              (group['stories'] as List).isNotEmpty)
          .toList(growable: false);
      setState(() {
        _storyGroups
          ..clear()
          ..addAll(groups);
      });
    } catch (error) {
      if (mounted && generation == _storiesGeneration) {
        setState(() => _storiesError = communityError(error));
      }
    } finally {
      if (mounted && generation == _storiesGeneration) {
        setState(() => _storiesLoading = false);
      }
    }
  }

  Future<void> _composeStory() async {
    FeedVideoAutoplayManager.instance.pauseAll();
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SocialStoryComposer(autofocusCaption: true),
      ),
    );
    if (changed == true && mounted) await _loadStories();
  }

  Future<void> _openStory(int index) async {
    FeedVideoAutoplayManager.instance.pauseAll();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SocialStoryViewer(
          groups: _storyGroups,
          initialGroup: index,
          api: _communityApi,
        ),
      ),
    );
    if (mounted) await _loadStories();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final attandanceType = context.watch<PrefProvider>().attendanceType;
    final enterprise = EnterpriseTheme.of(context);
    final isCheckedIn =
        (widget.attendanceList['check-in'] ?? '').trim().isNotEmpty &&
            widget.attendanceList['check-in'] != '-' &&
            widget.attendanceList['check-out'] == '-';
    final attendanceMethod = dashboardProvider.attendanceMethods;
    if (enterprise.isRoyalBlueGold) {
      return _buildRoyalDashboard(dashboardProvider, attandanceType);
    }

    final sections = <LayoutItem, Widget Function()>{
      for (final entry in widget.otherSections.entries)
        entry.key: () => entry.value,
      LayoutItem.banner: () => _heroSection(LayoutItem.banner),
      if (enterprise.layout.separatesBanner(enterprise.mode)) ...{
        LayoutItem.quote: () => _heroSection(LayoutItem.quote),
        LayoutItem.clock: () => _heroSection(LayoutItem.clock),
      },
      LayoutItem.summary: () =>
          HomeAttendanceHighlights(summary: widget.summary),
      LayoutItem.stories: () => _buildStoriesSection(context),
      if (attendanceMethod.isNotEmpty)
        LayoutItem.scanner: () => Column(
              children: [
                const SizedBox(height: 4),
                _buildOldAttendanceControl(
                  enterprise: enterprise,
                  attandanceType: attandanceType,
                  animated: widget.animated &&
                      context.select<ThemeProvider, bool>(
                        (provider) => provider.effectEnabled('qr_pulse'),
                      ),
                  isCheckedIn: isCheckedIn,
                  onTap: widget.onAttendanceTap,
                  pulseController: widget.pulseController,
                ),
                if (enterprise.isKhmerHeritage) ...[
                  Text(
                    attandanceType == 'QR'
                        ? 'Scan for Attendance'
                        : translate('dashboard_screen.attendance'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 3, bottom: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [enterprise.text, enterprise.accent]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${translate('home_screen.check_in')} / ${translate('home_screen.check_out')}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: enterprise.colors.backgroundColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 2),
                    child: Center(
                      child: Text(
                        "${translate('home_screen.check_in')} | ${translate('home_screen.check_out')}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded,
                            color: Color(0xFF5EB1FF), size: 14),
                        const SizedBox(width: 5),
                        const Text(
                          'Scan for Attendance',
                          style: TextStyle(
                            color: Color(0xFF5EB1FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 2),
              ],
            ),
      LayoutItem.workingTime: () => _buildWorkingTimeCard(
            context: context,
            attendanceList: widget.attendanceList,
            enterprise: enterprise,
          ),
      if (dashboardProvider.isAttendanceMapEnabled &&
          (dashboardProvider.isWorkspaceRadiusEnabled ||
              dashboardProvider.isLocationEnabled))
        LayoutItem.attendanceZone: () => _buildZoneStatusCard(
              context: context,
              provider: dashboardProvider,
              enterprise: enterprise,
              isInZone: widget.isInZone,
              distanceMeters: widget.distanceMeters,
              allowedDistance: widget.allowedDistanceMeters,
              isRefreshingZone: widget.isRefreshingZone,
              onRefresh: widget.onRefreshZone,
              mapWidget: widget.mapWidget,
            ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in enterprise.layout.visible(LayoutArea.home))
          if (sections[item] case final Widget Function() buildSection)
            KeyedSubtree(key: ValueKey(item), child: buildSection()),
        const SizedBox(height: 8),
      ],
    );
  }

  HomeBannerConfig get _royalQuote {
    final remote = _quotePlayback.quotes.elementAtOrNull(_quoteIndex);
    return widget.bannerConfig ??
        (remote == null
            ? _bannerConfig
            : HomeBannerConfig(quote: remote.text, quoteAuthor: remote.author));
  }

  String? _royalQuoteTranslation(HomeBannerConfig quote) {
    final translation = widget.bannerConfig == null
        ? _quotePlayback.quotes
            .elementAtOrNull(_quoteIndex)
            ?.translation
            ?.trim()
        : null;
    if (translation != null && translation.isNotEmpty) return translation;
    return quote.quote == HomeBannerConfig.defaultQuote
        ? translate('royal.quote_translation')
        : null;
  }

  void _openRoyalQuote(HomeBannerConfig quote) {
    final translation = _royalQuoteTranslation(quote);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(translate('royal.quotation'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('“ ${quote.quote} ”',
                    style: Theme.of(context).textTheme.headlineSmall),
                if (translation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(translation),
                  ),
                if (quote.quoteAuthor case final String author)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(author),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoyalDashboard(DashboardProvider provider, String method) {
    final theme = EnterpriseTheme.of(context);
    final hasAttendance = provider.features['attendance'] == '1';
    final showScanner = hasAttendance &&
        provider.attendanceMethods.isNotEmpty &&
        (method.toLowerCase() != 'qr' ||
            provider.attendanceMethods
                .any((item) => item.toLowerCase() == 'qr'));
    final radiusBlocked = provider.isWorkspaceRadiusEnabled &&
        widget.distanceMeters != null &&
        !widget.isInZone;
    final showLocation = hasAttendance &&
        (provider.isWorkspaceRadiusEnabled || provider.isLocationEnabled) &&
        (provider.isAttendanceMapEnabled || provider.isWorkspaceRadiusEnabled);
    final quote = _royalQuote;
    final checkIn = '${widget.attendanceList['check-in'] ?? ''}';
    final checkOut = '${widget.attendanceList['check-out'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (theme.layout.shows(LayoutItem.profile))
            if (widget.otherSections[LayoutItem.profile]
                case final Widget header)
              header,
          if (theme.layout.shows(LayoutItem.banner))
            ValueListenableBuilder<int>(
              valueListenable: slideTick,
              builder: (context, _, __) => _buildRoyalBanner(),
            ),
          if (theme.layout.shows(LayoutItem.quote) && quote.showQuote)
            ValueListenableBuilder<int>(
              valueListenable: _royalQuoteTick,
              builder: (context, _, __) {
                final current = _royalQuote;
                return RoyalQuotation(
                  text: current.quote,
                  author: current.quoteAuthor,
                  translation: _royalQuoteTranslation(current),
                  onTap: () => _openRoyalQuote(current),
                );
              },
            ),
          if (widget.dashboardError && provider.features.isEmpty)
            RoyalPanel(
              child: TextButton(
                onPressed: widget.onRetryDashboard,
                child: Text(translate('royal.retry')),
              ),
            ),
          RoyalCalendarActivity(
            clock: widget.clockNow,
            checkIn: checkIn,
            checkOut: checkOut,
            hours: '${widget.attendanceList['production_hour'] ?? ''}',
            hasAttendance: hasAttendance,
            showClock: theme.layout.shows(LayoutItem.clock),
            showTodayAttendance: theme.layout.shows(LayoutItem.workingTime),
            hasHolidays: provider.features['holiday'] == '1',
            hasOfficeCalendar: provider.features['leave-calendar'] == '1',
            isAd: provider.isAD,
            attendanceLoading: widget.dashboardLoading,
            attendanceError: widget.dashboardError,
            between: [
              if (hasAttendance && theme.layout.shows(LayoutItem.summary))
                ValueListenableBuilder<int>(
                  valueListenable: _royalQuoteTick,
                  builder: (context, _, __) {
                    final current = _royalQuote;
                    return RoyalAttendanceHighlights(
                      summary: widget.summary,
                      employees: provider.topBonusEmployees,
                      quote: current.showQuote ? current.quote : null,
                      onQuote: () => _openRoyalQuote(current),
                      loading:
                          widget.dashboardLoading && widget.summary == null,
                      onRetry: widget.dashboardError
                          ? widget.onRetryDashboard
                          : null,
                    );
                  },
                ),
              if (theme.layout.shows(LayoutItem.stories))
                _buildStoriesSection(context),
              if (showScanner && theme.layout.shows(LayoutItem.scanner))
                RoyalAttendanceScanner(
                  animation: widget.pulseController,
                  animate: widget.animated &&
                      context.select<ThemeProvider, bool>(
                          (provider) => provider.effectEnabled('qr_pulse')),
                  method: method,
                  status: widget.scannerBusy
                      ? translate('royal.checking_attendance')
                      : widget.isRefreshingZone
                          ? translate('attendance_messages.zone_checking')
                          : radiusBlocked
                              ? translate('royal.outside_area')
                              : null,
                  onTap: widget.scannerBusy ? null : widget.onAttendanceTap,
                ),
              if (theme.layout.shows(LayoutItem.quickServices))
                const RoyalQuickActions(),
            ],
          ),
          if (showLocation && theme.layout.shows(LayoutItem.attendanceZone))
            _buildZoneStatusCard(
              context: context,
              provider: provider,
              enterprise: theme,
              isInZone: widget.isInZone,
              distanceMeters: widget.distanceMeters,
              allowedDistance: widget.allowedDistanceMeters,
              isRefreshingZone: widget.isRefreshingZone,
              onRefresh: widget.onRefreshZone,
              mapWidget:
                  provider.isAttendanceMapEnabled ? widget.mapWidget : null,
            ),
          if (theme.layout.shows(LayoutItem.weeklyReport))
            if (widget.otherSections[LayoutItem.weeklyReport]
                case final Widget report)
              report,
          if (theme.layout.shows(LayoutItem.team))
            if (widget.otherSections[LayoutItem.team] case final Widget team)
              team,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRoyalBanner() {
    final theme = EnterpriseTheme.of(context);
    final slides = _activeSlides;
    final index = slides.isEmpty ? 0 : _slideIndex % slides.length;
    final slide =
        slides.elementAtOrNull(index) ?? const BannerSlide(id: 'angkor');
    final config = _activeSlideshow;
    return RepaintBoundary(
      child: RoyalPanel(
        padding: EdgeInsets.zero,
        radius: 24,
        goldEdge: true,
        child: Listener(
          onPointerDown: (_) => _handleSlideTouchPause(true),
          onPointerUp: (_) => _handleSlideTouchPause(false),
          onPointerCancel: (_) => _handleSlideTouchPause(false),
          child: GestureDetector(
            onHorizontalDragStart:
                slides.length < 2 ? null : (_) => _royalBannerDrag = 0,
            onHorizontalDragUpdate: slides.length < 2
                ? null
                : (details) => _royalBannerDrag += details.primaryDelta ?? 0,
            onHorizontalDragEnd: slides.length < 2
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    final direction = _royalBannerDrag.abs() >= 24
                        ? _royalBannerDrag
                        : velocity;
                    if (direction.abs() >= 24) {
                      _showRoyalSlide(
                          index + (direction < 0 ? 1 : -1), slides.length);
                    }
                  },
            child: Stack(
              children: [
                Positioned.fill(
                  child: BannerSlideSwitcher(
                    transition: config.transition,
                    child: KeyedSubtree(
                      key: ValueKey((slide.id, slide.imageUrl)),
                      child: SizedBox.expand(
                        child: _buildSlideArtwork(slide, theme, null),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xee061a40),
                          Color(0x99061a40),
                          Color(0x00061a40)
                        ],
                        stops: [0, .45, .88],
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: slide.hasLink
                        ? () => _launchBannerUrl(slide.linkUrl)
                        : null,
                    child: ConstrainedBox(
                      key: const ValueKey('home-banner-canvas'),
                      constraints: const BoxConstraints(minHeight: 120),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            FractionallySizedBox(
                              widthFactor: .62,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 3,
                                children: [
                                  Text('KNEAYERNG  /  DIGITAL HRMS',
                                      style: TextStyle(
                                          color: theme.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
                                  Text(
                                      slide.title.trim().isEmpty
                                          ? translate('royal.banner_title')
                                          : slide.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900)),
                                  if (slide.subtitle.isNotEmpty ||
                                      slide.title.isEmpty)
                                    Text(
                                        slide.subtitle.isEmpty
                                            ? translate('royal.banner_subtitle')
                                            : slide.subtitle,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10)),
                                  if (slide.hasLink &&
                                      slide.actionLabel.isNotEmpty)
                                    Text(slide.actionLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: theme.accent,
                                            fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            if (config.showIndicators && slides.length > 1)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 4,
                                children: [
                                  for (var i = 0; i < slides.length; i++)
                                    Semantics(
                                      selected: i == index,
                                      label:
                                          '${translate('royal.banner_slide')} ${i + 1}',
                                      child: Container(
                                        key: ValueKey('royal-slide-$i'),
                                        width: i == index ? 14 : 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: i == index
                                              ? theme.accent
                                              : Colors.white70,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoyalSlide(int index, int count) {
    _slideIndex =
        _activeSlideshow.loop ? index % count : index.clamp(0, count - 1);
    slideTick.value++;
    _syncSlideTimer();
    _precacheUpcomingSlides();
  }

  Widget _heroSection(LayoutItem item) => ValueListenableBuilder<DateTime>(
        valueListenable: widget.clockNow,
        builder: (context, now, _) => _buildHeroBanner(context, now, item),
      );

  // ==========================================
  // 1. HERO CAMBODIAN HERITAGE / PROMOTIONAL BANNER
  // ==========================================
  Widget _buildHeroBanner(BuildContext context, DateTime now, LayoutItem item) {
    final enterprise = EnterpriseTheme.of(context);
    final heroGradient = [
      _premiumTone(enterprise.primary, 0.42),
      _premiumTone(enterprise.secondary, 0.30),
      _premiumTone(enterprise.colors.backgroundColor, 0.36),
    ];
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning!'
        : hour < 17
            ? 'Good Afternoon!'
            : 'Good Evening!';

    return ValueListenableBuilder<int>(
      valueListenable: slideTick,
      builder: (context, _, __) {
        final slides = _activeSlides;
        final safeIndex = slides.isEmpty ? 0 : _slideIndex % slides.length;
        final currentSlide = slides.isEmpty
            ? const BannerSlide(id: 'default')
            : slides[safeIndex];
        final slideshow = _activeSlideshow;
        final activeQuote = widget.bannerConfig == null
            ? _quotePlayback.quotes.elementAtOrNull(_quoteIndex)
            : null;
        final config = activeQuote == null
            ? widget.bannerConfig ?? _bannerConfig
            : HomeBannerConfig(
                quote: activeQuote.text,
                quoteAuthor: activeQuote.author,
                quoteStyle: activeQuote.style,
              );
        final rotatingQuotes =
            activeQuote != null && _quotePlayback.settings.autoplay;
        final quoteSettings = _quotePlayback.settings;
        final quoteOnCanvas =
            config.quoteStyle?.hasCustomPosition == true || rotatingQuotes;
        final pauseOnTouch =
            slideshow.pauseOnTouch || quoteSettings.pauseOnTouch;
        final style = config.showQuote ? config.quoteStyle : null;
        final overlayOpacity = (style?.bannerOverlay ?? .35).clamp(0.0, .8);

        final artwork = Positioned.fill(
          child: BannerSlideSwitcher(
            transition: currentSlide.hasImage || !rotatingQuotes
                ? slideshow.transition
                : quoteSettings.transition,
            child: KeyedSubtree(
              key: ValueKey((
                safeIndex,
                currentSlide.id,
                currentSlide.imageUrl,
                currentSlide.hasImage ? null : style?.bannerImage,
              )),
              child: SizedBox.expand(
                child: _buildSlideArtwork(currentSlide, enterprise, style),
              ),
            ),
          ),
        );
        final overlay = Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              key: const ValueKey('home-banner-darkening-overlay'),
              color: const Color(0xff0a192f).withValues(alpha: overlayOpacity),
            ),
          ),
        );
        final indicators = slideshow.showIndicators && slides.length > 1
            ? Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(slides.length, (index) {
                        final selected = index == safeIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: selected ? 12 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: selected
                                ? (enterprise.isKhmerHeritage
                                    ? enterprise.accent
                                    : Colors.white)
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              )
            : null;
        final animateBorder = slideshow.animateBorder && _appForeground;
        if (enterprise.layout.separatesBanner(enterprise.mode)) {
          if (item == LayoutItem.quote && !config.showQuote) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 4),
            child: switch (item) {
              LayoutItem.quote => KhmerHeritagePanel(
                  ornaments: enterprise.isKhmerHeritage,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: quoteSettings.pauseOnTouch
                        ? (_) => _handleSlideTouchPause(true)
                        : null,
                    onPointerUp: quoteSettings.pauseOnTouch
                        ? (_) => _handleSlideTouchPause(false)
                        : null,
                    onPointerCancel: quoteSettings.pauseOnTouch
                        ? (_) => _handleSlideTouchPause(false)
                        : null,
                    child: BannerSlideSwitcher(
                      transition: quoteSettings.transition,
                      child: Padding(
                        key: ValueKey(activeQuote?.id),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 6),
                        child: Align(
                          alignment: Alignment(
                            ((style?.posX ?? 50) - 50) / 50,
                            ((style?.posY ?? 50) - 50) / 50,
                          ),
                          child: _buildQuoteWidget(config, heritage: true),
                        ),
                      ),
                    ),
                  ),
                ),
              LayoutItem.clock => KhmerHeritageStatus(
                  now: now,
                  greeting: greeting,
                  khmerGreeting: config.greetingKhmer,
                ),
              _ => KhmerHeritagePanel(
                  child: AspectRatio(
                    key: const ValueKey('home-banner-canvas'),
                    aspectRatio: 3 / 1,
                    child: Listener(
                      onPointerDown: pauseOnTouch
                          ? (_) => _handleSlideTouchPause(true)
                          : null,
                      onPointerUp: pauseOnTouch
                          ? (_) => _handleSlideTouchPause(false)
                          : null,
                      onPointerCancel: pauseOnTouch
                          ? (_) => _handleSlideTouchPause(false)
                          : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          artwork,
                          overlay,
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: currentSlide.hasLink
                                  ? () => _launchBannerUrl(currentSlide.linkUrl)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: .59,
                                    child: _buildHeritageBannerTitle(
                                        currentSlide, enterprise),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (indicators != null) indicators,
                          if (animateBorder)
                            const Positioned.fill(
                                child: BannerBorderAnimation()),
                        ],
                      ),
                    ),
                  ),
                ),
            },
          );
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.all(1.4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                enterprise.accent.withValues(alpha: 0.96),
                enterprise.primary.withValues(alpha: 0.82),
                enterprise.secondary.withValues(alpha: 0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: enterprise.primary.withValues(alpha: 0.34),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: enterprise.accent.withValues(alpha: 0.22),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: heroGradient,
                  stops: const [0.0, 0.56, 1.0],
                ),
              ),
              child: LayoutBuilder(
                key: const ValueKey('home-banner-canvas'),
                builder: (context, constraints) => ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxWidth / 3),
                  child: Listener(
                    onPointerDown: pauseOnTouch
                        ? (_) => _handleSlideTouchPause(true)
                        : null,
                    onPointerUp: pauseOnTouch
                        ? (_) => _handleSlideTouchPause(false)
                        : null,
                    onPointerCancel: pauseOnTouch
                        ? (_) => _handleSlideTouchPause(false)
                        : null,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Layer 1: Rotating slideshow artwork (admin-managed slides)
                        artwork,
                        overlay,

                        // Layer 2: Main Content (Greeting, Digital Clock, Date on Left; Quote on Right)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: currentSlide.hasLink
                                ? () => _launchBannerUrl(currentSlide.linkUrl)
                                : null,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 14, 12),
                              child: Row(
                                children: [
                                  // Left: Greetings, Live Digital Clock, Date
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (currentSlide.title
                                            .trim()
                                            .isNotEmpty) ...[
                                          Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 2),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.24),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              currentSlide.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Text(
                                          config.greetingKhmer,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        Text(
                                          greeting,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.88),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                DateFormat('HH:mm').format(now),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                  height: 1,
                                                ),
                                              ),
                                              Text(
                                                ':${DateFormat('ss').format(now)}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.90),
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              color: Colors.white70,
                                              size: 11,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                DateFormat('EEEE, MMMM d, yyyy')
                                                    .format(now),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.92),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right: Khmer Motivational Quote (Updated Independently)
                                  if (config.showQuote && !quoteOnCanvas)
                                    Expanded(
                                      flex: 5,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            top: 2, right: 2),
                                        child: _buildQuoteWidget(config),
                                      ),
                                    )
                                  else
                                    const Spacer(flex: 5),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (config.showQuote && quoteOnCanvas)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: BannerSlideSwitcher(
                                transition: quoteSettings.transition,
                                child: LayoutBuilder(
                                  key: ValueKey(activeQuote?.id),
                                  builder: (context, constraints) => Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: constraints.maxWidth *
                                            (style?.posX ?? 65) /
                                            100,
                                        top: constraints.maxHeight *
                                            (style?.posY ?? 30) /
                                            100,
                                        width: constraints.maxWidth * .50,
                                        child: FractionalTranslation(
                                          key: const ValueKey(
                                              'home-banner-positioned-quote'),
                                          translation: const Offset(-.5, -.5),
                                          child: _buildQuoteWidget(config),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Layer 3: Slideshow indicators (dots)
                        if (indicators != null) indicators,
                        if (animateBorder)
                          const Positioned.fill(child: BannerBorderAnimation()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeritageBannerTitle(
      BannerSlide slide, EnterpriseTheme enterprise) {
    final title = slide.title.trim();
    return DefaultTextStyle(
      style: TextStyle(
        color: enterprise.text,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(Icons.badge_outlined, color: enterprise.accent, size: 22),
                const Text('KNEAYERNG HRMS',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ],
            ),
            const Text('Employee Management System',
                style: TextStyle(fontSize: 11)),
            Text(
              title.isEmpty ? 'ប្រព័ន្ធគ្រប់គ្រងធនធានមនុស្ស' : title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteWidget(HomeBannerConfig config, {bool heritage = false}) {
    final style = config.quoteStyle;
    final text = config.quote;
    final author = config.quoteAuthor;
    final quoteText = heritage ? '“ $text ”' : '$text ”';

    final fontSize = (style?.fontSize != null)
        ? style!.fontSize!.clamp(8.0, 40.0)
        : (heritage ? 15.0 : 9.8);
    final fontWeight = style?.fontWeight ?? FontWeight.w800;
    final fontStyle = style?.fontStyle ?? FontStyle.normal;
    final textAlign =
        style?.textAlign ?? (heritage ? TextAlign.center : TextAlign.right);
    final baseColor = style?.color ?? const Color(0xFFFFF7ED);
    final opacity = (style?.opacity ?? 1.0).clamp(0.05, 1.0);

    final shadows = <Shadow>[
      if (style == null || style.shadowBlur > 0)
        Shadow(
          color: style?.shadowColor ?? Colors.black.withValues(alpha: .7),
          blurRadius: style?.shadowBlur ?? 5,
          offset: Offset(style?.shadowX ?? 0, style?.shadowY ?? 2),
        ),
    ];

    final baseTextStyle = TextStyle(
      fontFamily: style?.fontFamily,
      color: baseColor.withValues(alpha: opacity),
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: 1.34,
      shadows: shadows,
    );

    Widget textWidget;
    if (style != null && style.strokeWidth > 0 && style.strokeColor != null) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth * 2
        ..color = style.strokeColor!;

      textWidget = Stack(
        alignment: switch (textAlign) {
          TextAlign.left => Alignment.centerLeft,
          TextAlign.center => Alignment.center,
          _ => Alignment.centerRight,
        },
        children: [
          Text(
            quoteText,
            textAlign: textAlign,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: baseTextStyle.copyWith(
              foreground: strokePaint,
              shadows: null,
            ),
          ),
          Text(
            quoteText,
            textAlign: textAlign,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: baseTextStyle,
          ),
        ],
      );
    } else {
      textWidget = Text(
        quoteText,
        textAlign: textAlign,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: baseTextStyle,
      );
    }

    if (style != null &&
        style.gradientEnabled &&
        style.gradientStart != null &&
        style.gradientEnd != null) {
      final radians = style.gradientAngle * math.pi / 180;
      final direction = Alignment(math.sin(radians), -math.cos(radians));
      textWidget = ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: -direction,
          end: direction,
          colors: [style.gradientStart!, style.gradientEnd!],
        ).createShader(bounds),
        child: textWidget,
      );
    }

    Widget content = Column(
      crossAxisAlignment: switch (textAlign) {
        TextAlign.left => CrossAxisAlignment.start,
        TextAlign.center => CrossAxisAlignment.center,
        _ => CrossAxisAlignment.end,
      },
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!heritage)
          Text(
            '“',
            style: TextStyle(
              color: style != null &&
                      style.gradientEnabled &&
                      style.gradientStart != null
                  ? style.gradientStart!
                  : const Color(0xFFFFD54F),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        textWidget,
        if (author != null && author.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '— ${author.trim()}',
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: style?.fontFamily,
              color:
                  baseColor.withValues(alpha: (opacity * 0.85).clamp(0.2, 1.0)),
              fontSize: (fontSize * 0.82).clamp(7.5, 12.0),
              fontWeight: FontWeight.w600,
              fontStyle: fontStyle,
            ),
          ),
        ],
      ],
    );

    if (style != null && style.rotation != 0) {
      content = Transform.rotate(
        angle: (style.rotation * 3.141592653589793) / 180,
        child: content,
      );
    }

    return content;
  }

  /// Renders the slide image or the quote wallpaper and its fallback.
  Widget _buildSlideArtwork(
    BannerSlide slide,
    EnterpriseTheme enterprise,
    QuoteStyle? style,
  ) {
    final wallpaper =
        slide.hasImage ? slide.imageUrl.trim() : style?.bannerImage?.trim();
    final fallback = Image.asset(
      enterprise.isRoyalBlueGold
          ? 'assets/images/angkor_wat_banner.jpg'
          : HomeBannerConfig.defaultAngkorWatAsset,
      fit: BoxFit.cover,
      cacheWidth: enterprise.isRoyalBlueGold ? 1024 : null,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    final gradients = switch (wallpaper) {
      'gradient:royal' => const [Color(0xff0b192c), Color(0xff1e3e62)],
      'gradient:sunset' => const [
          Color(0xff1e1b4b),
          Color(0xff831843),
          Color(0xfff59e0b)
        ],
      'gradient:emerald' => const [
          Color(0xff064e3b),
          Color(0xff047857),
          Color(0xff10b981)
        ],
      _ => null,
    };
    if (gradients != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradients,
          ),
        ),
      );
    }
    if (wallpaper == null ||
        wallpaper.isEmpty ||
        Uri.tryParse(wallpaper)
                ?.path
                .endsWith('/assets/images/angkor_wat_banner.jpg') ==
            true) {
      return fallback;
    }
    if (wallpaper.startsWith('https://') || wallpaper.startsWith('http://')) {
      return CachedNetworkImage(
        imageUrl: wallpaper,
        fit: BoxFit.cover,
        memCacheWidth: 1000,
        placeholder: (_, __) => ColoredBox(color: enterprise.secondary),
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return Image.asset(
      wallpaper,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  // ==========================================
  // 3. STORIES & HIGHLIGHTS STRIP
  // ==========================================
  Widget _buildStoriesSection(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final features = context.watch<DashboardProvider>().features;
    final canViewStories = features.containsKey('social_feed.stories.view')
        ? features['social_feed.stories.view'] == '1'
        : features['social_feed.view'] == '1';
    final canCreateStories = features.containsKey('social_feed.stories.create')
        ? features['social_feed.stories.create'] == '1'
        : features['social_feed.create'] == '1';
    final showStoryStrip = !enterprise.isRoyalBlueGold || _storiesTab == 0;
    if (canViewStories && showStoryStrip && !_storiesPermissionWasEnabled) {
      _storiesPermissionWasEnabled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadStories();
      });
    } else if (!canViewStories) {
      _storiesPermissionWasEnabled = false;
    }

    if (enterprise.isRoyalBlueGold) {
      return _buildRoyalMedia(canViewStories, canCreateStories);
    }

    final storiesTitle = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _premiumTone(enterprise.primary, 0.40),
            _premiumTone(enterprise.secondary, 0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: enterprise.primary.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 14,
          ),
          SizedBox(width: 5),
          Text(
            'Stories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    final highlights = InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HomeHighlightsScreen(api: HomeHighlightApi()),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enterprise.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: enterprise.glassStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.style_outlined,
              color: enterprise.accent,
              size: 14,
            ),
            SizedBox(width: 5),
            Text(
              'Highlights',
              style: TextStyle(
                color: enterprise.accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    final viewAll = InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const SocialFeedScreen(),
        ));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View All',
            style: TextStyle(
              color: enterprise.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 2),
          Icon(
            Icons.arrow_forward_rounded,
            color: enterprise.accent,
            size: 13,
          ),
        ],
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enterprise.isKhmerHeritage)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 5,
            children: [storiesTitle, highlights, viewAll],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                storiesTitle,
                const SizedBox(width: 8),
                highlights
              ]),
              viewAll,
            ],
          ),
        const SizedBox(height: 10),
        if (canViewStories)
          SocialStoriesStrip(
            groups: _storyGroups,
            loading: _storiesLoading,
            error: _storiesError,
            canCreate: canCreateStories,
            onCreate: _composeStory,
            onRetry: _loadStories,
            onOpen: _openStory,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: enterprise.isKhmerHeritage
          ? KhmerHeritagePanel(
              child: Padding(padding: const EdgeInsets.all(8), child: content),
            )
          : content,
    );
  }

  Widget _buildRoyalMedia(bool canViewStories, bool canCreateStories) {
    final selected = canViewStories ? _storiesTab : 1;
    if (selected == 1) _highlights ??= _homeHighlights.index();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (canViewStories) _mediaTab(0, selected, 'royal.stories'),
            _mediaTab(1, selected, 'royal.highlights'),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => selected == 0
                        ? const SocialFeedScreen()
                        : const HomeHighlightsScreen()),
              ),
              child: Text(translate('royal.view_all')),
            ),
          ],
        ),
        if (selected == 0)
          if (_storyGroups.isEmpty &&
              !_storiesLoading &&
              _storiesError == null &&
              !canCreateStories)
            RoyalPanel(child: Text(translate('royal.no_stories')))
          else
            SocialStoriesStrip(
              groups: _storyGroups,
              loading: _storiesLoading,
              error: _storiesError,
              canCreate: canCreateStories,
              onCreate: _composeStory,
              onRetry: _loadStories,
              onOpen: _openStory,
            )
        else
          FutureBuilder<List<HomeHighlight>>(
            future: _highlights,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return RoyalPanel(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _highlights = _homeHighlights.index()),
                    child: Text(translate('royal.retry')),
                  ),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return RoyalPanel(
                    child: Text(translate('royal.no_highlights')));
              }
              return SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: 106,
                      child: RoyalPanel(
                        padding: EdgeInsets.zero,
                        radius: 13,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HomeHighlightDetailScreen(highlight: item),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: item.imageUrl == null
                                    ? const Icon(Icons.auto_awesome)
                                    : CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 320,
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.image_outlined),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _mediaTab(int index, int selected, String label) => Semantics(
        selected: index == selected,
        child: index == selected
            ? FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: EnterpriseTheme.of(context).accent,
                  foregroundColor: RoyalColors.navy,
                ),
                onPressed: () => setState(() => _storiesTab = index),
                child: Text(translate(label)),
              )
            : OutlinedButton(
                onPressed: () => setState(() => _storiesTab = index),
                child: Text(translate(label)),
              ),
      );

  Color _readableColor(Color background, Color light, Color dark) {
    return background.computeLuminance() > 0.45 ? dark : light;
  }

  Widget _attendanceIcon({
    required String attendanceType,
    required bool repeat,
    required Color color,
  }) {
    return Lottie.asset(
      attendanceType == "QR"
          ? 'assets/raw/qr.json'
          : attendanceType == "NFC"
              ? 'assets/raw/nfc.json'
              : 'assets/raw/fingerprint.json',
      width: 60,
      height: 60,
      animate: repeat,
      repeat: repeat,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.colorFilter(
            ['**'],
            value: ColorFilter.mode(color, BlendMode.srcATop),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. CLASSIC ATTENDANCE BUTTON SCAN QR
  // ==========================================
  Widget _buildOldAttendanceControl({
    required EnterpriseTheme enterprise,
    required String attandanceType,
    required bool animated,
    required bool isCheckedIn,
    required VoidCallback onTap,
    required AnimationController pulseController,
  }) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final diameter = enterprise.isKhmerHeritage && !isTablet
        ? 128.0
        : (isTablet ? 172.0 : 152.0);
    final touchDiameter = enterprise.isKhmerHeritage && !isTablet
        ? 100.0
        : (isTablet ? 132.0 : 110.0);
    final qrCircleColor = isCheckedIn ? enterprise.accent : enterprise.primary;
    final qrFaceColors = [
      _premiumTone(enterprise.accent, 0.38),
      _premiumTone(enterprise.primary, 0.28),
      _premiumTone(enterprise.secondary, 0.18),
      _premiumTone(enterprise.secondary, 0.42),
    ];
    final qrIconColor =
        _readableColor(qrFaceColors.last, Colors.white, Colors.black);

    return RepaintBoundary(
      child: Center(
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            final pulse = animated ? pulseController.value : 0.0;
            final spread = 6 + (pulse * 16);
            final ringOpacity = animated ? 0.38 - (pulse * 0.20) : 0.26;
            return SizedBox(
              width: diameter + 30,
              height: diameter + 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Silk-wave halo behind the sphere
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _QrHaloPainter(
                        progress: pulse,
                        color: enterprise.accent,
                      ),
                    ),
                  ),
                  // Outer glow
                  Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: qrCircleColor.withValues(alpha: ringOpacity),
                          blurRadius: 30 + (pulse * 14),
                          spreadRadius: spread,
                        ),
                        BoxShadow(
                          color: enterprise.accent.withValues(alpha: 0.24),
                          blurRadius: 44,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Pulse ring
                  Transform.scale(
                    scale: 1 + (pulse * 0.10),
                    child: Container(
                      width: diameter,
                      height: diameter,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              enterprise.accent.withValues(alpha: ringOpacity),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Mid accent ring
                  Container(
                    width: diameter - 14,
                    height: diameter - 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: enterprise.accent.withValues(alpha: 0.56),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: enterprise.primary.withValues(alpha: 0.34),
                          blurRadius: 30,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  // 3D glossy sphere face
                  Container(
                    width: diameter - 30,
                    height: diameter - 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.32, -0.38),
                        radius: 1.15,
                        colors: qrFaceColors,
                        stops: const [0.0, 0.32, 0.68, 1.0],
                      ),
                      border: Border.all(
                        color: enterprise.accent.withValues(alpha: 0.68),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: qrFaceColors.last.withValues(alpha: 0.55),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: enterprise.accent.withValues(alpha: 0.32),
                          blurRadius: 34,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Specular highlight
                        Positioned(
                          top: 10,
                          left: 18,
                          child: Container(
                            width: (diameter - 30) * 0.42,
                            height: (diameter - 30) * 0.24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tap target + icon
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('home-attendance-action'),
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap();
                      },
                      child: SizedBox(
                        width: touchDiameter,
                        height: touchDiameter,
                        child: Center(
                          child: _attendanceIcon(
                            attendanceType: attandanceType,
                            repeat: animated,
                            color: qrIconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 5. ATTENDANCE MAP & ZONE STATUS (PERMISSION GATED)
  // ==========================================
  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Widget _buildZoneStatusCard({
    required BuildContext context,
    required DashboardProvider provider,
    required EnterpriseTheme enterprise,
    required bool isInZone,
    required double? distanceMeters,
    required double allowedDistance,
    required bool isRefreshingZone,
    required VoidCallback onRefresh,
    Widget? mapWidget,
  }) {
    final hasBranchLocation = provider.workspaceLatitude != null &&
        provider.workspaceLongitude != null;
    final distance = distanceMeters ?? provider.lastWorkspaceDistanceMeters;
    final hasDistance = hasBranchLocation && distance != null;
    final statusColor = isRefreshingZone
        ? enterprise.secondary
        : hasDistance
            ? (isInZone ? Colors.green.shade600 : Colors.redAccent)
            : enterprise.secondary;
    final title = !hasBranchLocation
        ? translate('attendance_messages.branch_location_missing')
        : isRefreshingZone
            ? translate('attendance_messages.zone_checking')
            : hasDistance
                ? translate(isInZone
                    ? (enterprise.isRoyalBlueGold
                        ? 'royal.inside_area'
                        : 'attendance_messages.scan_available')
                    : 'attendance_messages.scan_not_available')
                : translate('attendance_messages.zone_unavailable');
    final detail = !hasBranchLocation
        ? translate('attendance_messages.branch_location_missing_detail')
        : hasDistance
            ? (enterprise.isRoyalBlueGold
                ? translate('royal.location_distance')
                    .replaceAll('{distance}', _formatDistance(distance))
                    .replaceAll('{allowed}', allowedDistance.toStringAsFixed(0))
                : isInZone
                    ? 'You are within allowed radius (${allowedDistance.toStringAsFixed(0)} m).'
                    : 'You are ${_formatDistance(distance)} from branch. Allowed: ${allowedDistance.toStringAsFixed(0)} m.')
            : translate('attendance_messages.zone_unavailable_detail');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: EnterpriseGlass(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        radius: 16,
        glowColor: statusColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInZone
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enterprise.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: enterprise.isRoyalBlueGold ? 48 : 32,
                  height: enterprise.isRoyalBlueGold ? 48 : 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: isRefreshingZone ? null : onRefresh,
                    icon: isRefreshingZone
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          )
                        : Icon(Icons.refresh_rounded,
                            color: statusColor, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mapWidget != null && enterprise.isRoyalBlueGold)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(translate('royal.show_map')),
                children: [SizedBox(height: 160, child: mapWidget)],
              )
            else if (mapWidget != null)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: mapWidget,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 8. WORKING TIME CARD
  // ==========================================
  Widget _buildWorkingTimeCard({
    required BuildContext context,
    required Map<String, dynamic> attendanceList,
    required EnterpriseTheme enterprise,
  }) {
    final percent =
        (attendanceList['production-time'] as num?)?.toDouble() ?? 0.0;
    final safePercent = percent.clamp(0.0, 1.0);
    final isCheckedIn =
        attendanceList['check-in'] != "-" && attendanceList['check-out'] == "-";
    final color = isCheckedIn ? const Color(0xFF10B981) : enterprise.accent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: enterprise.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enterprise.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: enterprise.isDark ? 0.16 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  translate('attendance_screen.working_time'),
                  style: TextStyle(
                    color: enterprise.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                attendanceList['production_hour']?.toString() ?? '00:00',
                style: TextStyle(
                  color: enterprise.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearPercentIndicator(
            lineHeight: 8.0,
            padding: EdgeInsets.zero,
            percent: safePercent,
            barRadius: const Radius.circular(20),
            backgroundColor: enterprise.text.withValues(
              alpha: enterprise.isDark ? 0.18 : 0.12,
            ),
            progressColor: color,
          ),
          const SizedBox(height: 5),
          if (enterprise.isKhmerHeritage)
            DecoratedBox(
              decoration: BoxDecoration(
                color: enterprise.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final (key, label, icon) in [
                    (
                      'check-in',
                      'attendance_screen.check_in',
                      Icons.login_rounded
                    ),
                    (
                      'check-out',
                      'attendance_screen.check_out',
                      Icons.logout_rounded
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        spacing: 8,
                        children: [
                          Icon(icon, size: 16, color: enterprise.primary),
                          Expanded(
                            child: Text(
                              translate(label),
                              style: TextStyle(
                                  color: enterprise.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            attendanceList[key]?.toString() ?? '-',
                            style: TextStyle(
                                color: enterprise.secondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  attendanceList['check-in']?.toString() ?? '-',
                  style: TextStyle(
                    color: enterprise.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  attendanceList['check-out']?.toString() ?? '-',
                  style: TextStyle(
                    color: enterprise.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Soft silk-wave arcs behind the 3D QR attendance sphere.
class _QrHaloPainter extends CustomPainter {
  final double progress;
  final Color color;

  _QrHaloPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.27;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final radius = baseRadius + 12 + i * 8 + progress * 6;
      paint
        ..color = color.withValues(alpha: 0.10 + i * 0.045)
        ..strokeWidth = 1.4 + (i.isEven ? 0.4 : 0);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final start = -0.85 - i * 0.15 + progress * 0.4;
      canvas.drawArc(rect, start, 3.6 - i * 0.25, false, paint);
      canvas.drawArc(rect, start + 3.14, 2.4 - i * 0.2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _QrHaloPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
