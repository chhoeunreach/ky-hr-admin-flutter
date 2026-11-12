import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_detail_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_strings.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeHighlightCarousel extends StatefulWidget {
  const HomeHighlightCarousel({
    super.key,
    required this.api,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final HomeHighlightApi api;
  final List<HomeHighlight> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<HomeHighlightCarousel> createState() => _HomeHighlightCarouselState();
}

class _HomeHighlightCarouselState extends State<HomeHighlightCarousel>
    with WidgetsBindingObserver {
  bool _foreground = true;
  bool _routeOpen = false;
  final PageController _pageController = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant HomeHighlightCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.items.length && widget.items.isNotEmpty) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients)
          _pageController.jumpToPage(0);
      });
    }
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.loading != widget.loading) {
      _syncAutoRotate();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAutoRotate();
  }

  void _syncAutoRotate() {
    _timer?.cancel();
    _timer = null;
    if (widget.loading || widget.items.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted ||
          !_foreground ||
          _routeOpen ||
          !_pageController.hasClients ||
          MediaQuery.disableAnimationsOf(context) ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          _pageController.position.isScrollingNotifier.value) return;
      final next = (_page + 1) % widget.items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openAll() async {
    _routeOpen = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeHighlightsScreen(api: widget.api),
      ));
    } finally {
      _routeOpen = false;
    }
  }

  Future<void> _open(HomeHighlight item) async {
    _routeOpen = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeHighlightDetailScreen(highlight: item),
      ));
    } finally {
      _routeOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  homeHighlightsText('Latest highlights'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openAll,
                style: TextButton.styleFrom(
                  foregroundColor: theme.secondary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  homeHighlightsText('View all'),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _buildBody(theme),
        ],
      ),
    );
  }

  Widget _buildBody(EnterpriseTheme theme) {
    if (widget.loading) {
      return SizedBox(
        height: 132,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: theme.secondary),
          ),
        ),
      );
    }
    if (widget.error != null) {
      return SizedBox(
        height: 132,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homeHighlightsText('Unable to load highlights.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: theme.secondary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  homeHighlightsText('Retry'),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.items.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: theme.mutedText, size: 26),
              const SizedBox(height: 6),
              Text(
                homeHighlightsText('No highlights yet'),
                style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 142,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _HighlightSlide(
                item: item,
                theme: theme,
                onTap: () => _open(item),
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (index) {
              final selected = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: selected ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.secondary
                      : theme.text.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HighlightSlide extends StatelessWidget {
  const _HighlightSlide({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final HomeHighlight item;
  final EnterpriseTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.startsAt ?? item.createdAt;
    return Material(
      color: theme.text.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 92,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 92,
                          color: theme.text.withValues(alpha: .06),
                        ),
                        errorWidget: (_, __, ___) => _fallbackImage(),
                      )
                    : _fallbackImage(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          item.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.mutedText,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (date != null)
                      Text(
                        DateFormat('MMM d').format(date.toLocal()),
                        style: TextStyle(
                          color: theme.secondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.mutedText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 92,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.secondary.withValues(alpha: .22),
            theme.accent.withValues(alpha: .18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.auto_awesome_rounded, color: theme.secondary, size: 24),
    );
  }
}
