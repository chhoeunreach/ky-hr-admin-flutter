import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_detail_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_strings.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeHighlightsScreen extends StatefulWidget {
  const HomeHighlightsScreen({super.key, this.api});

  final HomeHighlightApi? api;

  @override
  State<HomeHighlightsScreen> createState() => _HomeHighlightsScreenState();
}

class _HomeHighlightsScreenState extends State<HomeHighlightsScreen> {
  late final HomeHighlightApi _api = widget.api ?? HomeHighlightApi();
  late final bool _ownsApi = widget.api == null;
  final ScrollController _scrollController = ScrollController();
  final List<HomeHighlight> _items = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _loadMoreError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      if (_loadMoreError == null) _loadMore();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
      _loadingMore = false;
    });
    try {
      final page = await _api.history(page: 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _lastPage) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await _api.history(page: _page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => ids.add(item.id)));
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString();
      });
    }
  }

  void _open(HomeHighlight item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HomeHighlightDetailScreen(highlight: item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.surface,
        foregroundColor: theme.text,
        iconTheme: IconThemeData(color: theme.text),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? BackButton(color: theme.text)
            : null,
        title: Text(homeHighlightsText('Home Highlights')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: theme.secondary,
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(EnterpriseTheme theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.mutedText),
          const SizedBox(height: 12),
          Text(
            homeHighlightsText('Unable to load highlights.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.text, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(homeHighlightsText('Retry')),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 70),
          Icon(Icons.auto_awesome_outlined, size: 52, color: theme.mutedText),
          const SizedBox(height: 12),
          Text(
            homeHighlightsText('No highlights yet'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.text, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            homeHighlightsText(
                'New stories and updates from your company will appear here.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedText, fontSize: 13),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
      itemCount: _items.length + (_page < _lastPage ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          if (!_loadingMore)
            return Column(children: [
              if (_loadMoreError != null)
                Text(_loadMoreError!, textAlign: TextAlign.center),
              TextButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: Text(homeHighlightsText(
                      _loadMoreError == null ? 'Load more' : 'Retry'))),
            ]);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
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
        return _HistoryTile(
          item: _items[index],
          theme: theme,
          onTap: () => _open(_items[index]),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
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
    final hasImage = item.imageUrl != null;
    final body = hasImage ? item.snippet : item.plainBody;
    return Material(
      color: theme.surface.withValues(alpha: .86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.text.withValues(alpha: .09)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 72,
                      height: 72,
                      color: theme.text.withValues(alpha: .06),
                    ),
                    errorWidget: (_, __, ___) => _thumbFallback(theme),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: hasImage ? 2 : null,
                      overflow: hasImage ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: hasImage ? 2 : null,
                        overflow: hasImage ? TextOverflow.ellipsis : null,
                        style: TextStyle(
                          color: theme.mutedText,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (date != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM d, yyyy').format(date.toLocal()),
                        style: TextStyle(
                          color: theme.secondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: theme.mutedText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(EnterpriseTheme theme) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            theme.secondary.withValues(alpha: .22),
            theme.accent.withValues(alpha: .18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.auto_awesome_rounded, color: theme.secondary, size: 26),
    );
  }
}
