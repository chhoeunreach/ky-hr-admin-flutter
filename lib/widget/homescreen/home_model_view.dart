import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
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
  });

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

  @override
  State<HomeModelView> createState() => _HomeModelViewState();
}

class _HomeModelViewState extends State<HomeModelView> {
  final CommunityApi _communityApi = CommunityApi();
  final Preferences _preferences = Preferences();
  HomeBannerConfig _bannerConfig = const HomeBannerConfig();
  final List<Map<String, dynamic>> _storyGroups = [];
  bool _storiesLoading = true;
  int _storiesTab = 0; // 0 = Stories, 1 = Highlights

  @override
  void initState() {
    super.initState();
    _loadStories();
    _loadBannerConfig();
    _preferences.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferencesChanged);
    _communityApi.dispose();
    super.dispose();
  }

  void _onPreferencesChanged() {
    _loadBannerConfig();
  }

  Future<void> _loadBannerConfig() async {
    final bannerUrl = await _preferences.getHomeBannerUrl();
    final bannerLink = await _preferences.getHomeBannerLinkUrl();
    final bannerTitle = await _preferences.getHomeBannerTitle();
    final quote = await _preferences.getHomeQuote();
    final showQuote = await _preferences.getHomeQuoteShow();

    if (!mounted) return;
    setState(() {
      _bannerConfig = HomeBannerConfig(
        bannerImageUrl: bannerUrl,
        bannerLinkUrl: bannerLink,
        bannerTitle: bannerTitle,
        quote: quote,
        showQuote: showQuote,
        isAngkorWatDefault: bannerUrl == null || bannerUrl.trim().isEmpty,
      );
    });
  }

  Future<void> _handleSaveBannerConfig(HomeBannerConfig newConfig) async {
    if (newConfig.isAngkorWatDefault ||
        newConfig.bannerImageUrl == null ||
        newConfig.bannerImageUrl!.trim().isEmpty) {
      await _preferences.resetHomeBanner();
    } else {
      await _preferences.saveHomeBannerUrl(newConfig.bannerImageUrl);
      await _preferences.saveHomeBannerLinkUrl(newConfig.bannerLinkUrl);
      await _preferences.saveHomeBannerTitle(newConfig.bannerTitle);
    }

    await _preferences.saveHomeQuote(newConfig.quote);
    await _preferences.saveHomeQuoteShow(newConfig.showQuote);

    if (mounted) {
      setState(() {
        _bannerConfig = newConfig;
      });
      EasyLoading.showSuccess('បានរក្សាទុកដោយជោគជ័យ / Saved successfully');
    }
  }

  Future<void> _handleResetBanner() async {
    await _preferences.resetHomeBanner();
    if (mounted) {
      setState(() {
        _bannerConfig = _bannerConfig.copyWith(
          bannerImageUrl: null,
          bannerLinkUrl: null,
          bannerTitle: null,
          isAngkorWatDefault: true,
        );
      });
      EasyLoading.showToast(
          'បានស្តាររូបអង្គរវត្តឡើងវិញ / Banner reset to Angkor Wat');
    }
  }

  Future<void> _handleResetQuote() async {
    await _preferences.resetHomeQuote();
    if (mounted) {
      setState(() {
        _bannerConfig = _bannerConfig.copyWith(
          quote: HomeBannerConfig.defaultQuote,
          showQuote: true,
        );
      });
      EasyLoading.showToast(
          'បានស្តារពាក្យស្លោកដើមឡើងវិញ / Quote reset to default');
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

  void _showManageBannerAndQuoteSheet(BuildContext context) {
    final currentConfig = widget.bannerConfig ?? _bannerConfig;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ManageBannerAndQuoteModal(
          currentConfig: currentConfig,
          onSave: (newConfig) => _handleSaveBannerConfig(newConfig),
          onResetBanner: () => _handleResetBanner(),
          onResetQuote: () => _handleResetQuote(),
        );
      },
    );
  }

  Future<void> _loadStories() async {
    try {
      final response = await _communityApi.request('GET', 'social-stories');
      if (!mounted) return;
      setState(() {
        _storyGroups
          ..clear()
          ..addAll((response['data'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map)));
        _storiesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storiesLoading = false);
    }
  }

  Future<void> _composeStory() async {
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
    final isCheckedIn = (widget.attendanceList['check-in'] ?? '').trim().isNotEmpty &&
        widget.attendanceList['check-in'] != '-' &&
        widget.attendanceList['check-out'] == '-';
    final attendanceMethod = dashboardProvider.attendanceMethods;
    final showMapAndZone = dashboardProvider.isAttendanceMapEnabled &&
        dashboardProvider.isWorkspaceRadiusEnabled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Cambodian Heritage Banner with Digital Clock & Angkor Wat
        ValueListenableBuilder<DateTime>(
          valueListenable: widget.clockNow,
          builder: (context, now, _) => _buildHeroBanner(context, now),
        ),

        // 2. Dual Stats Row: Late & Bonus (Left) + Highlights (Right)
        _buildDualStatsRow(context, widget.summary, enterprise),

        // 3. Stories & Highlights Row + Horizontal Carousel
        _buildStoriesSection(context, enterprise),

        // 4. Old Attendance Button Scan QR
        if (attendanceMethod.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildOldAttendanceControl(
            enterprise: enterprise,
            attandanceType: attandanceType,
            animated: widget.animated,
            isCheckedIn: isCheckedIn,
            onTap: widget.onAttendanceTap,
            pulseController: widget.pulseController,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Center(
              child: Text(
                "${translate('home_screen.check_in')} | ${translate('home_screen.check_out')}",
                style: TextStyle(
                  color: enterprise.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: enterprise.isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // 5. Attendance Map & Zone Status (Permission Gated)
        if (showMapAndZone)
          _buildZoneStatusCard(
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

        // 6. Working Time Card
        _buildWorkingTimeCard(
          context: context,
          attendanceList: widget.attendanceList,
          enterprise: enterprise,
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // ==========================================
  // 1. HERO CAMBODIAN HERITAGE / PROMOTIONAL BANNER
  // ==========================================
  Widget _buildHeroBanner(BuildContext context, DateTime now) {
    final config = widget.bannerConfig ?? _bannerConfig;
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning!'
        : hour < 17
            ? 'Good Afternoon!'
            : 'Good Evening!';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      height: 142,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0052D4), // Royal blue
            Color(0xFF1677FF), // Vivid blue
            Color(0xFF4364F7), // Soft purple-blue
            Color(0xFF6FB1FC), // Light blue
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D6EFD).withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Layer 1: Banner Artwork (Custom URL/Asset or Angkor Wat Default)
            if (config.hasCustomBanner)
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (config.bannerImageUrl!.startsWith('http://') ||
                        config.bannerImageUrl!.startsWith('https://'))
                      CachedNetworkImage(
                        imageUrl: config.bannerImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFF0052D4),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          HomeBannerConfig.defaultAngkorWatAsset,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Image.asset(
                        config.bannerImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          HomeBannerConfig.defaultAngkorWatAsset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    // High-legibility scrim overlay for custom banners
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF002255).withValues(alpha: 0.88),
                            const Color(0xFF003D99).withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Angkor Wat temple silhouette on the right (Default)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      HomeBannerConfig.defaultAngkorWatAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    // Gradient fade to blend into the blue background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF1677FF),
                            const Color(0xFF1677FF).withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.28, 0.65],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Layer 2: Main Content (Greeting, Digital Clock, Date on Left; Quote on Right)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (config.bannerLinkUrl != null &&
                      config.bannerLinkUrl!.trim().isNotEmpty) {
                    _launchBannerUrl(config.bannerLinkUrl!);
                  } else {
                    _showManageBannerAndQuoteSheet(context);
                  }
                },
                onLongPress: () => _showManageBannerAndQuoteSheet(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Row(
                    children: [
                      // Left: Greetings, Live Digital Clock, Date
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (config.bannerTitle != null &&
                                config.bannerTitle!.trim().isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  config.bannerTitle!,
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
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
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
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ],
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
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
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
                      if (config.showQuote)
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, right: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Text(
                                  '“',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '${config.quote} ”',
                                  textAlign: TextAlign.right,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFFFFF7ED),
                                    fontSize: 9.8,
                                    fontWeight: FontWeight.w800,
                                    height: 1.34,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.70),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 3: Top-right Manage Banner & Quote Button
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showManageBannerAndQuoteSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. DUAL STATS ROW: LATE & BONUS + HIGHLIGHTS
  // ==========================================
  Widget _buildDualStatsRow(
      BuildContext context, MonthlyAttendanceSummary? summary, EnterpriseTheme enterprise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          // Left Card: Late & Bonus
          Expanded(
            child: Container(
              height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enterprise.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.90) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: enterprise.accent,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Late & Bonus',
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Late Today box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: enterprise.isDark
                                ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                                : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Late Today',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: enterprise.mutedText,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${summary?.lateCount ?? 0}',
                                      style: TextStyle(
                                        color: enterprise.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Bonus (Month) box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 5),
                          decoration: BoxDecoration(
                            color: enterprise.isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Bonus (Month)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: enterprise.mutedText,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '\$${(summary?.bonusTarget ?? 25.0).toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: enterprise.text,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Right Card: Highlights
          Expanded(
            child: Container(
              height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enterprise.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.90) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: enterprise.accent,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Highlights',
                            style: TextStyle(
                              color: enterprise.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                HomeHighlightsScreen(api: HomeHighlightApi()),
                          ));
                        },
                        child: Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                color: enterprise.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: enterprise.accent,
                              size: 11,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Top Bonus Row
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFF59E0B),
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Top Bonus',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: enterprise.text,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'This Month',
                              maxLines: 1,
                              style: TextStyle(
                                color: enterprise.mutedText,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 3 Overlapping mini avatars
                      SizedBox(
                        width: 42,
                        height: 20,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              child:
                                  _miniAvatar('assets/images/dummy_avatar.png'),
                            ),
                            Positioned(
                              left: 11,
                              child:
                                  _miniAvatar('assets/images/dummy_avatar.png'),
                            ),
                            Positioned(
                              left: 22,
                              child:
                                  _miniAvatar('assets/images/dummy_avatar.png'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Quotation Row
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: enterprise.accent,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Quotation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: enterprise.text,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Latest Offers',
                              maxLines: 1,
                              style: TextStyle(
                                color: enterprise.mutedText,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Product preview icons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 13,
                            height: 19,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(3),
                              border:
                                  Border.all(color: enterprise.isDark ? const Color(0xFF334155) : Colors.white, width: 0.8),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Container(
                            width: 13,
                            height: 19,
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(3),
                              border:
                                  Border.all(color: enterprise.isDark ? const Color(0xFF334155) : Colors.white, width: 0.8),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Container(
                            width: 13,
                            height: 19,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(3),
                              border:
                                  Border.all(color: enterprise.isDark ? const Color(0xFF334155) : Colors.white, width: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _miniAvatar(String asset) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ==========================================
  // 3. STORIES & HIGHLIGHTS STRIP
  // ==========================================
  Widget _buildStoriesSection(BuildContext context) {
    final userAvatar = context.watch<PrefProvider>().avatar;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Active Stories Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1677FF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1677FF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
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
                  ),
                  const SizedBox(width: 8),
                  // Highlights Pill
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            HomeHighlightsScreen(api: HomeHighlightApi()),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.style_outlined,
                            color: Color(0xFF1677FF),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Highlights',
                            style: TextStyle(
                              color: Color(0xFF1677FF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SocialFeedScreen(),
                  ));
                },
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF1677FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF1677FF),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal Stories Cards
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                // 1. Add Story
                _buildAddStoryCard(context),
                const SizedBox(width: 8),
                // 2. Your Story
                _buildYourStoryCard(context, userAvatar),
                const SizedBox(width: 8),
                // 3. Video Story
                _buildVideoStoryCard(context),
                const SizedBox(width: 8),
                // 4. Person Story
                _buildPersonStoryCard(
                    context, 'assets/images/dummy_avatar.png'),
                const SizedBox(width: 8),
                // 5. Team Story
                _buildGroupStoryCard(context),
                if (_storyGroups.isNotEmpty) ...[
                  for (int i = 0; i < _storyGroups.length; i++) ...[
                    const SizedBox(width: 8),
                    _buildDynamicStoryCard(context, _storyGroups[i], i),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStoryCard(BuildContext context) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _composeStory,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(15)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEAF2FF), Color(0xFFCFE0FF)],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1677FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  'Add Story',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYourStoryCard(BuildContext context, String avatarUrl) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.20),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_storyGroups.isNotEmpty) {
              _openStory(0);
            } else {
              _composeStory();
            }
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Image.asset(
                            'assets/images/dummy_avatar.png',
                            fit: BoxFit.cover,
                          ),
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/dummy_avatar.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/dummy_avatar.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  'Your Story',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoStoryCard(BuildContext context) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_storyGroups.isNotEmpty) _openStory(0);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E7D32), Color(0xFF004D40)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF0F172A),
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '0:30',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
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

  Widget _buildPersonStoryCard(BuildContext context, String asset) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildGroupStoryCard(BuildContext context) {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF64748B), Color(0xFF334155)],
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.groups_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicStoryCard(
      BuildContext context, Map<String, dynamic> group, int index) {
    final avatar = group['avatar']?.toString() ?? '';
    final name = group['name']?.toString() ?? 'Story';
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _openStory(index),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/dummy_avatar.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/dummy_avatar.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final diameter =
        MediaQuery.sizeOf(context).shortestSide >= 600 ? 190.0 : 168.0;
    final qrCircleColor = isCheckedIn ? enterprise.accent : enterprise.primary;
    final qrIconColor =
        _readableColor(qrCircleColor, Colors.white, Colors.black);

    return RepaintBoundary(
      child: Center(
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            final pulse = animated ? pulseController.value : 0.0;
            final spread = 5 + (pulse * 18);
            final ringOpacity = animated ? 0.32 - (pulse * 0.18) : 0.22;
            return Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: qrCircleColor.withValues(alpha: ringOpacity),
                    blurRadius: 34 + (pulse * 18),
                    spreadRadius: spread,
                  ),
                  BoxShadow(
                    color: enterprise.accent.withValues(alpha: 0.20),
                    blurRadius: 46,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + (pulse * 0.10),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: qrCircleColor.withValues(alpha: ringOpacity),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: enterprise.accent.withValues(alpha: 0.42),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: enterprise.accent.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          enterprise.accent,
                          qrCircleColor,
                          enterprise.secondary,
                          enterprise.accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: qrCircleColor.withValues(alpha: 0.26),
                          blurRadius: 26,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: enterprise.isDark ? 0.18 : 0.70),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(
                              alpha: enterprise.isDark ? 0.18 : 0.74),
                          qrCircleColor.withValues(
                              alpha: enterprise.isDark ? 0.36 : 0.18),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: enterprise.isDark ? 0.20 : 0.82),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap();
                      },
                      child: SizedBox(
                        width: diameter - 58,
                        height: diameter - 58,
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
                    ? 'attendance_messages.scan_available'
                    : 'attendance_messages.scan_not_available')
                : translate('attendance_messages.zone_unavailable');
    final detail = !hasBranchLocation
        ? translate('attendance_messages.branch_location_missing_detail')
        : hasDistance
            ? (isInZone
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
                  width: 32,
                  height: 32,
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
            if (mapWidget != null)
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
    final color =
        isCheckedIn ? const Color(0xFF10B981) : enterprise.accent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: enterprise.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.90) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            backgroundColor: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            progressColor: color,
          ),
          const SizedBox(height: 5),
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

// ============================================================================
// MANAGE BANNER & QUOTE MODAL (INDEPENDENT CONTROLLER)
// ============================================================================

class _ManageBannerAndQuoteModal extends StatefulWidget {
  final HomeBannerConfig currentConfig;
  final ValueChanged<HomeBannerConfig> onSave;
  final VoidCallback onResetBanner;
  final VoidCallback onResetQuote;

  const _ManageBannerAndQuoteModal({
    required this.currentConfig,
    required this.onSave,
    required this.onResetBanner,
    required this.onResetQuote,
  });

  @override
  State<_ManageBannerAndQuoteModal> createState() =>
      _ManageBannerAndQuoteModalState();
}

class _ManageBannerAndQuoteModalState extends State<_ManageBannerAndQuoteModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _bannerUrlController;
  late TextEditingController _bannerLinkController;
  late TextEditingController _bannerTitleController;
  late TextEditingController _quoteController;
  late bool _showQuote;
  late bool _useAngkorWat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _useAngkorWat = widget.currentConfig.isAngkorWatDefault ||
        !widget.currentConfig.hasCustomBanner;
    _bannerUrlController =
        TextEditingController(text: widget.currentConfig.bannerImageUrl ?? '');
    _bannerLinkController =
        TextEditingController(text: widget.currentConfig.bannerLinkUrl ?? '');
    _bannerTitleController =
        TextEditingController(text: widget.currentConfig.bannerTitle ?? '');
    _quoteController = TextEditingController(text: widget.currentConfig.quote);
    _showQuote = widget.currentConfig.showQuote;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerUrlController.dispose();
    _bannerLinkController.dispose();
    _bannerTitleController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  void _applySave() {
    final bannerUrl = _useAngkorWat ? null : _bannerUrlController.text.trim();
    final bannerLink = _useAngkorWat ? null : _bannerLinkController.text.trim();
    final bannerTitle =
        _useAngkorWat ? null : _bannerTitleController.text.trim();
    final quoteText = _quoteController.text.trim().isEmpty
        ? HomeBannerConfig.defaultQuote
        : _quoteController.text.trim();

    final updated = HomeBannerConfig(
      bannerImageUrl: bannerUrl,
      bannerLinkUrl: bannerLink,
      bannerTitle: bannerTitle,
      quote: quoteText,
      showQuote: _showQuote,
      isAngkorWatDefault: _useAngkorWat,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: enterprise.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: enterprise.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: enterprise.isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: enterprise.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'គ្រប់គ្រងបដា & ពាក្យស្លោក',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: enterprise.text,
                        ),
                      ),
                      Text(
                        'Manage Banner & Quote Independently',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: enterprise.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: enterprise.mutedText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: enterprise.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: enterprise.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: enterprise.accent,
              unselectedLabelColor: enterprise.mutedText,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.image_outlined, size: 18),
                  text: 'បដា (Banner)',
                ),
                Tab(
                  icon: Icon(Icons.format_quote_rounded, size: 18),
                  text: 'ពាក្យស្លោក (Quote)',
                ),
              ],
            ),
          ),

          // Tab views
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBannerTab(enterprise),
                _buildQuoteTab(enterprise),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: BoxDecoration(
              color: enterprise.isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: enterprise.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'បោះបង់ / Cancel',
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enterprise.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _applySave,
                    child: const Text(
                      'រក្សាទុក & អនុវត្ត / Save & Apply',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerTab(EnterpriseTheme enterprise) {
    final activeCardBg = enterprise.isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
        : const Color(0xFFEFF6FF);
    final inactiveCardBg = enterprise.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardBorder = enterprise.isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputFill = enterprise.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ជ្រើសរើសប្រភេទបដា / Banner Type',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: enterprise.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _useAngkorWat = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _useAngkorWat ? activeCardBg : inactiveCardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _useAngkorWat ? enterprise.accent : cardBorder,
                        width: _useAngkorWat ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _useAngkorWat
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _useAngkorWat
                              ? enterprise.accent
                              : enterprise.mutedText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'អង្គរវត្ត (Angkor Wat)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: enterprise.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _useAngkorWat = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_useAngkorWat ? activeCardBg : inactiveCardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !_useAngkorWat ? enterprise.accent : cardBorder,
                        width: !_useAngkorWat ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_useAngkorWat
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: !_useAngkorWat
                              ? enterprise.accent
                              : enterprise.mutedText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'បដាផ្សព្វផ្សាយ (Custom)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: enterprise.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_useAngkorWat) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage(HomeBannerConfig.defaultAngkorWatAsset),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: cardBorder),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      enterprise.accent.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.bottomLeft,
                child: const Text(
                  '✓ សកម្មជាលំនាំដើម / Active Heritage Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Custom banner input fields
            Text(
              'តំណភ្ជាប់រូបភាពបដា (Banner Image URL)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: enterprise.mutedText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bannerUrlController,
              style: TextStyle(color: enterprise.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://example.com/banner.jpg',
                hintStyle: TextStyle(color: enterprise.mutedText.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.image_rounded, size: 18, color: enterprise.mutedText),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_bannerUrlController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear_rounded, size: 16, color: enterprise.mutedText),
                        onPressed: () {
                          setState(() => _bannerUrlController.clear());
                        },
                      ),
                  ],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: enterprise.accent),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            Text(
              'តំណភ្ជាប់ពេលចុចលើបដា (Action / Promo Link - Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: enterprise.mutedText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bannerLinkController,
              style: TextStyle(color: enterprise.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://example.com/promotion',
                hintStyle: TextStyle(color: enterprise.mutedText.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.link_rounded, size: 18, color: enterprise.mutedText),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: enterprise.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'ចំណងជើងបដា (Banner Tag / Title - Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: enterprise.mutedText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bannerTitleController,
              style: TextStyle(color: enterprise.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Special Announcement / ការជូនដំណឹង',
                hintStyle: TextStyle(color: enterprise.mutedText.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18, color: enterprise.mutedText),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: enterprise.accent),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'បដាគំរូរហ័ស (Preset Promotional Banners)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: enterprise.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HomeBannerConfig.presetBanners.map((item) {
                final isAngkor = item['type'] == 'angkor';
                return ActionChip(
                  avatar: Icon(
                    isAngkor
                        ? Icons.temple_buddhist_rounded
                        : Icons.star_rounded,
                    size: 15,
                    color: enterprise.accent,
                  ),
                  label: Text(
                    item['title']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: enterprise.text,
                    ),
                  ),
                  backgroundColor: enterprise.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: cardBorder),
                  ),
                  onPressed: () {
                    setState(() {
                      if (isAngkor) {
                        _useAngkorWat = true;
                        _bannerUrlController.clear();
                        _bannerTitleController.clear();
                      } else {
                        _useAngkorWat = false;
                        _bannerUrlController.text = item['url']!;
                        _bannerTitleController.text = item['title']!;
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'ស្តាររូបអង្គរវត្តឡើងវិញ / Reset Banner to Default',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                ),
              ),
              onPressed: () {
                setState(() {
                  _useAngkorWat = true;
                  _bannerUrlController.clear();
                  _bannerLinkController.clear();
                  _bannerTitleController.clear();
                });
                widget.onResetBanner();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteTab(EnterpriseTheme enterprise) {
    final cardBg = enterprise.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardBorder = enterprise.isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputFill = enterprise.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'បង្ហាញពាក្យស្លោកលើបដា',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: enterprise.text,
                        ),
                      ),
                      Text(
                        'Show Motivational Quote on Banner',
                        style: TextStyle(
                          fontSize: 11,
                          color: enterprise.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showQuote,
                  activeColor: enterprise.accent,
                  onChanged: (val) => setState(() => _showQuote = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'កែប្រែពាក្យស្លោកលើកទឹកចិត្ត (Motivational Quote Text)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: enterprise.text,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _quoteController,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: enterprise.text,
            ),
            decoration: InputDecoration(
              hintText: 'វាយបញ្ចូលពាក្យស្លោកលើកទឹកចិត្តថ្មី...',
              hintStyle: TextStyle(color: enterprise.mutedText.withValues(alpha: 0.6)),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: enterprise.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ពាក្យស្លោកគំរូ (Quick Preset Motivational Quotes)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: enterprise.mutedText,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: HomeBannerConfig.presetQuotes.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _quoteController.text = item['quote']!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: enterprise.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  color: enterprise.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['quote']!.replaceAll('\n', ' '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: enterprise.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.touch_app_rounded,
                          size: 14,
                          color: enterprise.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'ស្តារពាក្យស្លោកដើមឡើងវិញ / Reset Quote to Default',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                ),
              ),
              onPressed: () {
                setState(() {
                  _quoteController.text = HomeBannerConfig.defaultQuote;
                  _showQuote = true;
                });
                widget.onResetQuote();
              },
            ),
          ),
        ],
      ),
    );
  }
}
