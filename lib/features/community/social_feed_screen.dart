import 'reaction_button.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'community_strings.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'community_api.dart';
import 'community_media_picker.dart';
import 'community_media.dart';
import 'feed_cache.dart';
import 'feed_performance.dart';
import 'mention_directory.dart';
import 'mention_field.dart';
import 'package:flutter/foundation.dart';

extension _CommunityTheme on BuildContext {
  ColorScheme get _communityColors => Theme.of(this).colorScheme;

  Color get _communitySurface => EnterpriseTheme.of(this).contentSurface;

  Color get _communityPage {
    final theme = EnterpriseTheme.of(this);
    return theme.isDark
        ? theme.colors.backgroundColor
        : _communityColors.surfaceContainerLow;
  }
}

AppBar _communityAppBar(BuildContext context, String title,
    {bool automaticallyImplyLeading = true, List<Widget>? actions}) {
  final colors = context._communityColors;
  final foreground = colors.onPrimaryContainer;
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: colors.primaryContainer,
    foregroundColor: foreground,
    iconTheme: IconThemeData(color: foreground),
    actionsIconTheme: IconThemeData(color: foreground),
    elevation: 0,
    scrolledUnderElevation: 0,
    title: Text(title,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
    actions: actions,
  );
}

Future<T?> _showCommunityDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final colors = context._communityColors;
      return Theme(
        data: theme.copyWith(
          dialogTheme: theme.dialogTheme.copyWith(
            backgroundColor: context._communitySurface,
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            hintStyle: TextStyle(color: colors.onSurfaceVariant),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: colors.onPrimaryContainer,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
          ),
        ),
        child: Builder(builder: builder),
      );
    },
  );
}

/// Opens the Facebook-style profile for a post author (works from any screen
/// that already has an [api] instance to share).
void _openAuthorProfile(BuildContext context, Map? author,
    {CommunityApi? api}) {
  if (author == null || author['id'] == null) return;
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => SocialFeedScreen(
          api: api, profileAuthor: Map<String, dynamic>.from(author))));
}

/// Opens the profile behind a tapped @mention. Unknown names (directory not
/// loaded or the person left) and `@everyone` do nothing.
void _openMentionProfile(BuildContext context, String name,
    {CommunityApi? api}) {
  final person = MentionDirectory.findByName(name);
  if (person == null || person.isEveryone || person.id.isEmpty) return;
  _openAuthorProfile(context, {'id': person.id, 'name': person.name}, api: api);
}

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen(
      {super.key,
      this.api,
      this.onImmersiveChanged,
      this.showBackButton = true,
      this.profileAuthor});
  final bool showBackButton;
  final CommunityApi? api;
  final ValueChanged<bool>? onImmersiveChanged;

  /// When set, the screen renders as that person's Facebook-style profile:
  /// a cover/avatar header followed by only their posts.
  final Map<String, dynamic>? profileAuthor;
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  late final _api = widget.api ?? CommunityApi();
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _storyGroups = [];
  final Set<int> _busyPosts = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveTimer;
  bool _loading = false;
  bool _storiesLoading = false;
  bool _immersive = false;
  double _lastScrollOffset = 0;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  String? _nextCursor;
  int _generation = 0;
  int _storiesGeneration = 0;
  String _filter = 'All Posts';
  String _profileAvatar = '';
  int _userId = 0;
  bool _cacheRestored = false;
  bool _scrollRestored = false;

  bool get _isProfile => widget.profileAuthor != null;

  List<Map<String, dynamic>> get _visiblePosts => _posts.where((post) {
        final category =
            '${post['category'] ?? post['post_type'] ?? ''}'.toLowerCase();
        return switch (_filter) {
          'Team' => post['visibility'] == 'department' ||
              post['visibility'] == 'users' ||
              post['visibility'] == 'employees' ||
              category == 'team',
          'Announcement' =>
            post['is_announcement'] == true || category == 'announcement',
          'Event' => post['event'] != null ||
              post['event_id'] != null ||
              category == 'event',
          _ => true,
        };
      }).toList();

  Future<void> _loadProfile() async {
    final user = await Preferences().getUser();
    if (!mounted) return;
    setState(() {
      _profileAvatar = user.avatar;
      _userId = user.id;
    });
    await _restoreCachedFeed();
    await _restoreScrollOffset();
  }

  String get _scrollKey => _isProfile
      ? 'social_feed_scroll_v1_profile_${widget.profileAuthor?['id']}'
      : 'social_feed_scroll_v1_$_userId';

  Future<void> _restoreCachedFeed() async {
    if (_isProfile) {
      _cacheRestored = true;
      return;
    }
    if (_cacheRestored || _posts.isNotEmpty || _userId <= 0) return;
    _cacheRestored = true;
    final cached = await FeedCache.read(_userId);
    if (!mounted || cached == null || _posts.isNotEmpty) return;
    setState(() {
      _posts.addAll(cached['data'] as List<Map<String, dynamic>>);
      _nextCursor = cached['next_cursor'] as String?;
      _hasMore = cached['has_more'] == true;
    });
    await _restoreScrollOffset();
  }

  Future<void> _restoreScrollOffset() async {
    if (_scrollRestored || _userId <= 0 || _isProfile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getDouble(_scrollKey) ?? 0;
      if (!mounted) return;
      if (offset <= 0) {
        _scrollRestored = true;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scrollRestored || !_scrollController.hasClients) {
          return;
        }
        final position = _scrollController.position;
        if (position.maxScrollExtent <= 0) return;
        _scrollRestored = true;
        _scrollController
            .jumpTo(offset.clamp(0, position.maxScrollExtent).toDouble());
      });
    } catch (_) {
      _scrollRestored = true;
    }
  }

  void _scheduleScrollSave() {
    if (_userId <= 0 || _isProfile) return;
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveScrollOffset());
    });
  }

  Future<void> _saveScrollOffset() async {
    if (_userId <= 0 || _isProfile) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_scrollKey, _lastScrollOffset);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    FeedPerformanceTracker.instance.startScrollTrace();
    unawaited(MentionDirectory.ensureLoaded());
    _load(reset: true);
    _loadStories();
    _loadProfile();
  }

  @override
  void dispose() {
    _generation++;
    _storiesGeneration++;
    _scrollSaveTimer?.cancel();
    unawaited(_saveScrollOffset());
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    if (_immersive) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onImmersiveChanged?.call(false));
    }
    FeedVideoAutoplayManager.instance.pauseAll();
    FeedPerformanceTracker.instance.stopScrollTrace();
    _api.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    _scheduleScrollSave();
    if (offset <= 0) {
      _setImmersive(false);
    } else if (delta > 8 && offset > 48) {
      _setImmersive(true);
    } else if (delta < -8) {
      _setImmersive(false);
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 900 &&
        _hasMore &&
        !_loading &&
        _posts.isNotEmpty &&
        _error == null) {
      _load();
    }
  }

  void _setImmersive(bool value) {
    if (_immersive == value) return;
    setState(() => _immersive = value);
    widget.onImmersiveChanged?.call(value);
  }

  bool _allows(String ability) =>
      context.read<DashboardProvider>().features[ability] == '1';

  bool _allowsStory(String ability, String fallback) {
    final features = context.read<DashboardProvider>().features;
    return features.containsKey(ability)
        ? features[ability] == '1'
        : features[fallback] == '1';
  }

  Future<void> _loadStories() async {
    if (_isProfile) return;
    if (!_allowsStory('social_feed.stories.view', 'social_feed.view')) return;
    final generation = ++_storiesGeneration;
    setState(() {
      _storiesLoading = true;
    });
    try {
      final response = await _api.request('GET', 'social-stories');
      if (!mounted || generation != _storiesGeneration) return;
      setState(() {
        _storyGroups
          ..clear()
          ..addAll((response['data'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map)));
      });
    } catch (_) {
      // Stories are an enhancement to the feed; keep the feed usable if the
      // optional stories endpoint is unavailable or not yet assigned.
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

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = ++_generation;
    if (reset) {
      _nextCursor = null;
      FeedPerformanceTracker.instance.startFeedLoad();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = reset ? 1 : _page + 1;
      final cursor = reset ? null : _nextCursor;
      final authorFilter =
          _isProfile ? '&user_id=${widget.profileAuthor?['id']}' : '';
      final path = cursor == null
          ? 'social-feed?page=$page$authorFilter'
          : 'social-feed?cursor=${Uri.encodeQueryComponent(cursor)}&per_page=12$authorFilter';
      final response = await _api.request('GET', path);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _posts.clear();
        final existing = _posts.map((post) => post['id']).toSet();
        _posts.addAll((response['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((post) => existing.add(post['id'])));
        _page = page;
        _nextCursor = response['next_cursor'] as String?;
        _hasMore = _nextCursor != null ||
            response['has_more'] == true ||
            response['next_page_url'] != null;
      });
      if (reset) {
        FeedPerformanceTracker.instance.markFeedLoaded();
        if (_posts.isNotEmpty) {
          FeedPerformanceTracker.instance.markFeedFirstPost();
        }
        if (_userId > 0 && !_isProfile) {
          unawaited(FeedCache.write(_userId, response));
        }
        await _restoreScrollOffset();
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        if (reset && _posts.isEmpty) {
          await _restoreCachedFeed();
        }
        if (_posts.isEmpty) {
          setState(() => _error = communityError(error));
        }
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _compose(
      {Map<String, dynamic>? post, String initialType = 'text'}) async {
    FeedVideoAutoplayManager.instance.pauseAll();
    var initialFiles = <PlatformFile>[];
    if (post == null && (initialType == 'image' || initialType == 'video')) {
      try {
        initialFiles = await pickCommunityMedia(context, initialType,
            multiple: initialType == 'image');
        if (!mounted || initialFiles.isEmpty) return;
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(communityError(error))));
        return;
      }
    }
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
            builder: (_) => SocialPostComposer(
                post: post,
                initialType: initialType,
                initialFiles: initialFiles,
                autofocusBody: post == null &&
                    initialType == 'text' &&
                    initialFiles.isEmpty)));
    if (changed == true && mounted) await _load(reset: true);
  }

  Future<void> _action(Map<String, dynamic> post, String action,
      {Map<String, dynamic>? data}) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
    Map<String, dynamic>? rollback;
    if (action == 'reaction') {
      final index = _posts.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        rollback = _posts[index];
        setState(() {
          _posts[index] = communityOptimisticReaction(
              rollback!, data?['reaction'] as String?);
        });
      }
    }
    setState(() => _busyPosts.add(id));
    try {
      final response = await _api.request(
          action == 'reaction'
              ? 'PUT'
              : action == 'delete'
                  ? 'DELETE'
                  : 'POST',
          'social-feed/$id${action == 'delete' ? '' : '/$action'}',
          data: data);
      if (!mounted) return;
      setState(() {
        if (action == 'delete') {
          _posts.removeWhere((item) => item['id'] == id);
        } else if (action == 'reaction') {
          final index = _posts.indexWhere((item) => item['id'] == id);
          if (index >= 0 && response['data'] is Map) {
            _posts[index] = Map<String, dynamic>.from(response['data'] as Map);
          }
        }
      });
      if (action == 'share') {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(communityText('Shared to the feed.'))));
        await _load(reset: true);
      }
    } catch (error) {
      if (mounted && rollback != null) {
        setState(() {
          final index = _posts.indexWhere((item) => item['id'] == id);
          if (index >= 0) _posts[index] = rollback!;
        });
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final confirmed = await _showCommunityDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(communityText('Delete your post?')),
                content: Text(communityText(
                    'It will be removed from the feed and shared posts.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(communityText('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(communityText('Delete')))
                ]));
    if (confirmed == true && mounted) await _action(post, 'delete');
  }

  Future<void> _share(Map<String, dynamic> post) async {
    final text = await _showCommunityDialog<String>(
        context: context, builder: (_) => _ShareCaptionDialog());
    if (text != null && mounted)
      await _action(post, 'share', data: {'body': text});
  }

  Future<void> _savePost(Map<String, dynamic> post) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
    setState(() => _busyPosts.add(id));
    try {
      final saved = post['is_saved'] == true;
      await _api.request(saved ? 'DELETE' : 'POST', 'social-feed/$id/save');
      if (mounted) {
        setState(() => post['is_saved'] = !saved);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(communityText(saved ? 'Post unsaved.' : 'Post saved.'))));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _pinPost(Map<String, dynamic> post) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
    setState(() => _busyPosts.add(id));
    try {
      final response = await _api.request('POST', 'social-feed/$id/pin');
      if (mounted && response['data'] is Map) {
        final index = _posts.indexWhere((item) => item['id'] == id);
        if (index >= 0)
          setState(() => _posts[index] =
              Map<String, dynamic>.from(response['data'] as Map));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _toggleNotifications(Map<String, dynamic> post) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
    setState(() => _busyPosts.add(id));
    try {
      final response =
          await _api.request('POST', 'social-feed/$id/notifications');
      if (!mounted) return;
      final enabled = response['notifications_enabled'] == true;
      setState(() => post['notifications_enabled'] = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(communityText(enabled
              ? 'Post notifications turned on.'
              : 'Post notifications turned off.'))));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _hidePost(Map<String, dynamic> post) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
    setState(() => _busyPosts.add(id));
    try {
      final response = await _api.request('POST', 'social-feed/$id/hide');
      if (!mounted) return;
      if (response['hidden'] == true) {
        setState(() => _posts.removeWhere((item) => item['id'] == id));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(communityText('Post hidden.'))));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _reportPost(Map<String, dynamic> post) async {
    final reason = await _showCommunityDialog<String>(
        context: context, builder: (_) => const _ReportPostDialog());
    if (reason == null || !mounted) return;
    final id = post['id'] as int;
    try {
      await _api
          .request('POST', 'social-feed/$id/report', data: {'reason': reason});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(communityText('Report submitted.'))));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    }
  }

  Future<void> _showReactions(Map<String, dynamic> post) async {
    try {
      final response =
          await _api.request('GET', 'social-feed/${post['id']}/reactions');
      if (!mounted) return;
      await _showCommunityDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(communityText('Reactions')),
                content: SizedBox(
                  width: 420,
                  child: (response['data'] as List? ?? []).isEmpty
                      ? Text(communityText('No reactions yet.'))
                      : ListView(shrinkWrap: true, children: [
                          for (final item in response['data'] as List)
                            ListTile(
                              leading: Text(
                                  communityReactions[item['reaction']] ?? '👍',
                                  style: const TextStyle(fontSize: 24)),
                              title: Text(
                                  '${(item['user'] as Map?)?['name'] ?? communityText('Employee')}'),
                            )
                        ]),
                ),
              ));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    }
  }

  Future<void> _copyPostLink(Map<String, dynamic> post) async {
    await Clipboard.setData(ClipboardData(text: 'social-feed/${post['id']}'));
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(communityText('Post link copied.'))));
  }

  Future<void> _comments(Map<String, dynamic> post) async {
    FeedVideoAutoplayManager.instance.pauseAll();
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => SocialCommentsScreen(
            postId: post['id'] as int,
            reactionsCount: (post['reactions_count'] as num?)?.toInt() ?? 0,
            commentsCount: (post['comments_count'] as num?)?.toInt() ?? 0,
            sharesCount: (post['shares_count'] as num?)?.toInt() ?? 0)));
    if (mounted) await _load(reset: true);
  }

  Future<void> _sendPost(Map<String, dynamic> post) async {
    final text = [
      '${post['body'] ?? ''}'.trim(),
      if (post['media_url'] != null) '${post['media_url']}',
      for (final media in post['media'] is List ? post['media'] as List : [])
        if (media is Map && media['media_url'] != null) '${media['media_url']}',
    ].where((part) => part.isNotEmpty).join('\n');
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(text.isEmpty ? communityText('Social Feed') : text,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    }
  }

  Widget _composerCard() => Card(
      elevation: 0,
      color: context._communitySurface,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundImage: _profileAvatar.isEmpty
                    ? null
                    : communityAvatarImage(_profileAvatar),
                child: _profileAvatar.isEmpty
                    ? const Icon(Icons.person_outline)
                    : null),
            const SizedBox(width: 8),
            Expanded(
                child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () => _compose(),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Text(communityText("What's on your mind?"),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)))))),
            IconButton(
                tooltip: communityText('Photo'),
                onPressed: () => _compose(initialType: 'image'),
                icon: Icon(Icons.image_outlined,
                    color: context._communityColors.onPrimaryContainer)),
            IconButton(
                tooltip: communityText('Video'),
                onPressed: () => _compose(initialType: 'video'),
                icon: Icon(Icons.videocam_outlined,
                    color: context._communityColors.onPrimaryContainer)),
          ])));

  Widget _filters() => SizedBox(
      height: 50,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            const labels = ['All Posts', 'Team', 'Announcement', 'Event'];
            const icons = [
              Icons.layers_outlined,
              Icons.groups_outlined,
              Icons.campaign_outlined,
              Icons.calendar_today_outlined
            ];
            final selected = _filter == labels[index];
            final colors = context._communityColors;
            return ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(icons[index],
                    size: 18,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant),
                label: Text(communityText(labels[index])),
                labelStyle: TextStyle(
                    color:
                        selected ? colors.onPrimaryContainer : colors.onSurface,
                    fontWeight: FontWeight.w600),
                selectedColor: colors.primaryContainer,
                backgroundColor: context._communitySurface,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                onSelected: (_) => setState(() => _filter = labels[index]));
          }));

  Widget _postCard(Map<String, dynamic> post, {int? feedPosition}) {
    final busy = _busyPosts.contains(post['id']);
    final author = post['author'] as Map?;
    final avatar = '${author?['avatar'] ?? ''}';
    final primaryType = '${post['media_type'] ?? 'text'}';
    final hasMedia = (primaryType != 'text' &&
            '${post['media_url'] ?? ''}'.trim().isNotEmpty) ||
        (post['media'] is List && (post['media'] as List).isNotEmpty);
    final inset = hasMedia ? 14.0 : 10.0;
    return Card(
        margin: EdgeInsets.fromLTRB(hasMedia ? 0 : 8, 4, hasMedia ? 0 : 8, 4),
        elevation: 0,
        color: context._communitySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Row(children: [
                Expanded(
                    child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openAuthorProfile(context, author,
                            api: widget.api),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            CircleAvatar(
                                backgroundImage: avatar.isNotEmpty
                                    ? communityAvatarImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person_outline)
                                    : null),
                            SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Flexible(
                                        child: Text(
                                            '${author?['name'] ?? communityText('Employee')}',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800))),
                                    if (post['is_announcement'] == true)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: Icon(Icons.verified,
                                              size: 16,
                                              color: context._communityColors
                                                  .onPrimaryContainer))
                                  ]),
                                  Text(
                                      '${author?['department'] ?? ''}${author?['department'] != null ? ' · ' : ''}${_date(post['created_at'])}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                          ]),
                        ))),
                if (post['can_edit'] == true ||
                    post['can_delete'] == true ||
                    post['can_pin'] == true ||
                    post['can_report'] == true ||
                    _allows('social_feed.save') ||
                    _allows('social_feed.follow') ||
                    _allows('social_feed.hide'))
                  PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _compose(post: post);
                            break;
                          case 'delete':
                            _delete(post);
                            break;
                          case 'save':
                            _savePost(post);
                            break;
                          case 'pin':
                            _pinPost(post);
                            break;
                          case 'report':
                            _reportPost(post);
                            break;
                          case 'copy':
                            _copyPostLink(post);
                            break;
                          case 'notifications':
                            _toggleNotifications(post);
                            break;
                          case 'hide':
                            _hidePost(post);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                            if (post['can_edit'] == true)
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Text(communityText('Edit post'))),
                            if (post['can_delete'] == true)
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(communityText('Delete post'))),
                            if (_allows('social_feed.save'))
                              PopupMenuItem(
                                  value: 'save',
                                  child: Text(communityText(
                                      post['is_saved'] == true
                                          ? 'Unsave post'
                                          : 'Save post'))),
                            if (post['can_pin'] == true)
                              PopupMenuItem(
                                  value: 'pin',
                                  child: Text(communityText(
                                      post['is_pinned'] == true
                                          ? 'Unpin post'
                                          : 'Pin post'))),
                            if (post['can_report'] == true)
                              PopupMenuItem(
                                  value: 'report',
                                  child: Text(communityText('Report post'))),
                            PopupMenuItem(
                                value: 'copy',
                                child: Text(communityText('Copy link'))),
                            if (_allows('social_feed.follow'))
                              PopupMenuItem(
                                  value: 'notifications',
                                  child: Text(communityText(
                                      post['notifications_enabled'] == true
                                          ? 'Turn notifications off'
                                          : 'Turn notifications on'))),
                            if (_allows('social_feed.hide'))
                              PopupMenuItem(
                                  value: 'hide',
                                  child: Text(communityText('Hide post'))),
                          ]),
              ]),
            ),
            const SizedBox(height: 6),
            _PostContent(
                post: post,
                feedPosition: feedPosition,
                inset: inset,
                onMentionTap: (name) =>
                    _openMentionProfile(context, name, api: widget.api)),
            if (post['poll'] is Map)
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: _PollWidget(post: post, api: _api)),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Row(children: [
                Expanded(
                    child: InkWell(
                        onTap: (post['reactions_count'] ?? 0) > 0
                            ? () => _showReactions(post)
                            : null,
                        child: Row(children: [
                          for (final reaction in communityReactions.keys
                              .where((key) =>
                                  ((post['reactions'] as Map?)?[key] as num? ??
                                      0) >
                                  0)
                              .take(3))
                            Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Text(communityReactions[reaction]!,
                                    style: const TextStyle(fontSize: 18))),
                          Flexible(
                              child: Text(
                                  '${post['reactions_count'] ?? 0} ${communityText('reactions')}',
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                        ]))),
                InkWell(
                    onTap: () => _comments(post),
                    child: Text(
                        '${post['comments_count'] ?? 0} ${communityText('comments')}',
                        style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(width: 8),
                Text('${post['shares_count'] ?? 0} ${communityText('shares')}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Divider(height: 8),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: inset - 4),
                child: LayoutBuilder(builder: (context, constraints) {
                  final actions = <Widget>[
                    if (_allows('social_feed.react'))
                      CommunityReactionButton(
                        reaction: post['my_reaction'] as String?,
                        enabled: !busy,
                        onChanged: (reaction) => _action(post, 'reaction',
                            data: {'reaction': reaction}),
                      ),
                    TextButton.icon(
                        onPressed: busy ? null : () => _comments(post),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 20),
                        label: Text(communityText('Comment'))),
                    if (_allows('social_feed.share')) ...[
                      TextButton.icon(
                          onPressed: busy ? null : () => _share(post),
                          icon: const Icon(Icons.reply_rounded, size: 22),
                          label: Text(communityText('Share'))),
                      TextButton.icon(
                          onPressed: busy ? null : () => _sendPost(post),
                          icon: const Icon(Icons.send_outlined, size: 20),
                          label: Text(communityText('Send'))),
                    ],
                  ];
                  return Theme(
                      data: Theme.of(context).copyWith(
                          textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)))),
                      child: constraints.maxWidth < 340
                          ? Wrap(spacing: 4, children: actions)
                          : Row(children: [
                              for (final action in actions)
                                Expanded(child: action)
                            ]));
                })),
            if (busy) LinearProgressIndicator(),
          ]),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final features = context.watch<DashboardProvider>().features;
    final accent = context._communityColors.onPrimaryContainer;
    final actionStyle = TextButton.styleFrom(foregroundColor: accent);
    final canViewStories =
        _allowsStory('social_feed.stories.view', 'social_feed.view');
    final canCreateStories =
        _allowsStory('social_feed.stories.create', 'social_feed.create');
    final visiblePosts = _visiblePosts;
    return Scaffold(
      backgroundColor: context._communityPage,
      appBar: _immersive
          ? null
          : _communityAppBar(
              context,
              _isProfile
                  ? '${widget.profileAuthor?['name'] ?? ''}'
                  : communityText('Social Feed'),
              automaticallyImplyLeading: widget.showBackButton,
              actions: [
                if (!_isProfile && features['social_feed.search'] == '1')
                  IconButton(
                      tooltip: communityText('Search'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SocialSearchScreen())),
                      icon: const Icon(Icons.search)),
                if (!_isProfile && features['social_feed.notifications'] == '1')
                  IconButton(
                      tooltip: communityText('Notifications'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SocialNotificationsScreen())),
                      icon: const Icon(Icons.notifications_none)),
                if (!_isProfile && features['social_feed.save'] == '1')
                  IconButton(
                      tooltip: communityText('Saved posts'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SocialSavedPostsScreen())),
                      icon: const Icon(Icons.bookmark_outline)),
                IconButton(
                    onPressed: _loading ? null : () => _load(reset: true),
                    icon: const Icon(Icons.refresh)),
              ],
            ),
      floatingActionButton: null,
      body: SafeArea(
        top: _immersive,
        bottom: false,
        child: features['social_feed.view'] != '1'
            ? Center(
                child: Text(communityText(
                    'You do not have permission to view the feed.')))
            : RefreshIndicator(
                color: accent,
                backgroundColor: context._communitySurface,
                onRefresh: () => _load(reset: true),
                child: CustomScrollView(
                  key: const PageStorageKey('social-feed-scroll'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 600,
                  slivers: [
                    SliverList.list(children: [
                      if (_isProfile)
                        _ProfileHeader(
                            author: widget.profileAuthor!, api: _api),
                      if (!_isProfile && features['social_feed.create'] == '1')
                        _composerCard(),
                      if (!_isProfile && canViewStories)
                        SocialStoriesStrip(
                            groups: _storyGroups,
                            loading: _storiesLoading,
                            error: null,
                            canCreate: canCreateStories,
                            onCreate: _composeStory,
                            onRetry: _loadStories,
                            onOpen: (index) async {
                              FeedVideoAutoplayManager.instance.pauseAll();
                              await Navigator.of(context, rootNavigator: true)
                                  .push(MaterialPageRoute(
                                      builder: (_) => SocialStoryViewer(
                                          groups: _storyGroups,
                                          initialGroup: index)));
                              if (mounted) await _loadStories();
                            }),
                      if (!_isProfile) _filters(),
                      if (_error != null)
                        Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(children: [
                              Text(_error!),
                              TextButton(
                                  style: actionStyle,
                                  onPressed: () => _load(reset: _posts.isEmpty),
                                  child: Text(communityText('Try again')))
                            ])),
                      if (visiblePosts.isEmpty && !_loading && _error == null)
                        Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                                communityText(_filter == 'All Posts'
                                    ? 'No posts yet. Start a conversation with your team.'
                                    : 'No posts in this category yet.'),
                                textAlign: TextAlign.center)),
                    ]),
                    SliverList.builder(
                      itemCount: visiblePosts.length,
                      itemBuilder: (context, index) {
                        final post = visiblePosts[index];
                        return KeyedSubtree(
                          key: ValueKey('post-${post['id']}'),
                          child: _postCard(post, feedPosition: index),
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: Column(children: [
                        if (_loading)
                          Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: accent))),
                        if (_hasMore && !_loading && _posts.isNotEmpty)
                          TextButton(
                              style: actionStyle,
                              onPressed: _load,
                              child: Text(communityText('Load more posts'))),
                      ]),
                    ),
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 8)),
                  ],
                )),
      ),
    );
  }
}

/// Facebook-style profile header: gradient cover with the avatar overlapping
/// it, the person's name/subtitle, a short info card, and a "Posts" label that
/// sits above their feed. Profile details are an enhancement — on failure the
/// header falls back to the author basics already present in post payloads.
class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({required this.author, required this.api});

  final Map<String, dynamic> author;
  final CommunityApi api;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.author['id'];
    if (id == null) return;
    try {
      final response =
          await widget.api.request('GET', 'users/profile-detail/$id');
      if (!mounted) return;
      final data = response['data'];
      if (data is Map) {
        setState(() => _detail = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Optional enrichment; the header still works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context._communityColors;
    final surface = context._communitySurface;
    final author = widget.author;
    final name = '${author['name'] ?? communityText('Employee')}';
    final department =
        '${_detail?['department'] ?? author['department'] ?? ''}';
    final position = '${_detail?['post'] ?? ''}';
    final branch = '${_detail?['branch'] ?? ''}';
    final avatar = '${_detail?['avatar'] ?? author['avatar'] ?? ''}';
    final subtitle = [
      if (department.isNotEmpty) department,
      if (position.isNotEmpty) position,
    ].join(' · ');
    final hasInfo =
        position.isNotEmpty || department.isNotEmpty || branch.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
            height: 132,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: .65)
                ]))),
        Positioned(
            left: 0,
            right: 0,
            bottom: -44,
            child: Center(
                child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration:
                        BoxDecoration(color: surface, shape: BoxShape.circle),
                    child: CircleAvatar(
                        radius: 44,
                        backgroundImage: avatar.isNotEmpty
                            ? communityAvatarImage(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? const Icon(Icons.person_outline, size: 40)
                            : null)))),
      ]),
      const SizedBox(height: 54),
      Center(
          child: Text(name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      if (subtitle.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4, left: 16, right: 16),
            child: Center(
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium))),
      if (hasInfo)
        Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: surface, borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (position.isNotEmpty)
                _infoRow(context, Icons.work_outline, communityText('Position'),
                    position),
              if (department.isNotEmpty)
                _infoRow(context, Icons.apartment, communityText('Department'),
                    department),
              if (branch.isNotEmpty)
                _infoRow(context, Icons.location_city, communityText('Branch'),
                    branch),
            ])),
      const SizedBox(height: 16),
      const Divider(height: 1),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Icon(Icons.article_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(communityText('Posts'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
    ]);
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]));
  }
}

class SocialStoriesStrip extends StatelessWidget {
  const SocialStoriesStrip({
    super.key,
    required this.groups,
    required this.loading,
    required this.error,
    required this.canCreate,
    required this.onCreate,
    required this.onRetry,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> groups;
  final bool loading;
  final String? error;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onRetry;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading && groups.isEmpty) {
      return const SizedBox(
          height: 88, child: Center(child: CircularProgressIndicator()));
    }
    if (error != null && groups.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: Text(error!)),
            TextButton(onPressed: onRetry, child: Text(communityText('Retry')))
          ]));
    }
    if (!canCreate && groups.isEmpty) return const SizedBox.shrink();
    return SizedBox(
        height: 88,
        child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
            scrollDirection: Axis.horizontal,
            itemCount: groups.length + (canCreate ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              if (canCreate && index == 0) {
                return _CreateStoryCard(onTap: onCreate);
              }
              final group = groups[index - (canCreate ? 1 : 0)];
              return _StoryCard(
                  group: group,
                  onTap: () => onOpen(index - (canCreate ? 1 : 0)));
            }));
  }
}

class _CreateStoryCard extends StatelessWidget {
  const _CreateStoryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context._communityColors;
    return SizedBox(
        width: 62,
        child: Card(
            color: context._communitySurface,
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
                onTap: onTap,
                child: Column(children: [
                  Expanded(
                    child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                              colors.surfaceContainerHigh,
                              colors.primaryContainer,
                            ])),
                        child: Center(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    shape: BoxShape.circle),
                                child: Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: Icon(Icons.add_rounded,
                                        color: colors.onPrimaryContainer,
                                        size: 20))))),
                  ),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: Text(communityText('Create story'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 8.5)))
                ]))));
  }
}

class _StoryDurationBadge extends StatelessWidget {
  const _StoryDurationBadge({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final label = communityMediaDurationLabel(seconds);
    if (label == null) return const SizedBox.shrink();
    return DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(9)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('${communityText('Video')} · $label',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800))));
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.group, required this.onTap});
  final Map<String, dynamic> group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final author = Map<String, dynamic>.from(group['author'] as Map? ?? {});
    final stories = (group['stories'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final story = stories.isNotEmpty ? stories.last : <String, dynamic>{};
    final type = '${story['media_type'] ?? 'text'}';
    final url = '${story['media_url'] ?? ''}';
    final thumbnailUrl = '${story['thumbnail_url'] ?? ''}';
    final caption = '${story['caption'] ?? ''}'.trim();
    final uri = type == 'image'
        ? communityMediaUri(type, url)
        : type == 'video'
            ? communityMediaUri('image', thumbnailUrl)
            : null;
    final duration = communityMediaDurationLabel(story['duration_seconds']);
    final avatar = '${author['avatar'] ?? ''}';
    final seen = group['has_unseen'] != true;
    final colors = context._communityColors;
    final ringColor = colors.onPrimaryContainer;
    return SizedBox(
        width: 62,
        child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: seen ? Colors.transparent : ringColor,
                    width: seen ? 0 : 2)),
            child: InkWell(
                onTap: onTap,
                child: Stack(fit: StackFit.expand, children: [
                  if (uri != null)
                    CachedNetworkImage(
                        imageUrl: uri.toString(),
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        maxWidthDiskCache: 600,
                        fadeInDuration: const Duration(milliseconds: 120),
                        errorWidget: (_, __, ___) => ColoredBox(
                            color: colors.surfaceContainerHigh,
                            child: Icon(Icons.image_not_supported_outlined,
                                color: colors.onSurfaceVariant)))
                  else
                    DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: type == 'video'
                                    ? const [
                                        Color(0xff172a46),
                                        Color(0xff07111f)
                                      ]
                                    : const [
                                        Color(0xff6246d9),
                                        Color(0xffa66cff)
                                      ])),
                        child: Center(
                            child: type == 'text' && caption.isNotEmpty
                                ? Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 24, 4, 18),
                                    child: Text(caption,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                            shadows: [
                                              Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black54)
                                            ])))
                                : const SizedBox.shrink())),
                  if (type == 'video') ...[
                    const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 24)),
                    if (duration != null)
                      Positioned(
                          top: 28,
                          right: 4,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .7),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  child: Text(duration,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800)))))
                  ],
                  const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                        Colors.transparent,
                        Color(0xaa000000)
                      ]))),
                  Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: seen ? Colors.white70 : ringColor,
                              shape: BoxShape.circle),
                          child: CircleAvatar(
                              radius: 9,
                              backgroundImage:
                                  communityAvatarImage(avatar, pixels: 84),
                              child: avatar.isEmpty
                                  ? const Icon(Icons.person, size: 12)
                                  : null))),
                  Positioned(
                      left: 4,
                      right: 4,
                      bottom: 4,
                      child: Text(
                          group['is_mine'] == true
                              ? communityText('Your story')
                              : '${author['name'] ?? communityText('Employee')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black)
                              ])))
                ]))));
  }
}

class SocialStoryViewer extends StatefulWidget {
  const SocialStoryViewer(
      {super.key, required this.groups, this.initialGroup = 0, this.api});
  final List<Map<String, dynamic>> groups;
  final int initialGroup;
  final CommunityApi? api;

  @override
  State<SocialStoryViewer> createState() => _SocialStoryViewerState();
}

class _SocialStoryViewerState extends State<SocialStoryViewer> {
  late final CommunityApi _api;
  late final bool _ownsApi;
  late final PageController _pages;
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _viewedStories = {};
  final Map<int, Duration> _videoDurations = {};
  final ValueNotifier<double> _progress = ValueNotifier(0);
  int _index = 0;
  Timer? _progressTimer;
  bool _paused = false;
  bool _awaitingVideo = false;
  String? _burstEmoji;
  int _burstSerial = 0;
  final CommunityVideoMuteController _mute = CommunityVideoMuteController();

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? CommunityApi();
    for (var groupIndex = 0; groupIndex < widget.groups.length; groupIndex++) {
      final group = widget.groups[groupIndex];
      final author = Map<String, dynamic>.from(group['author'] as Map? ?? {});
      for (final raw in (group['stories'] as List? ?? [])) {
        _items.add({
          'story': Map<String, dynamic>.from(raw as Map),
          'author': author,
          'group_index': groupIndex,
        });
      }
    }
    _index = _initialStoryIndex();
    _pages = PageController(initialPage: _index);
    if (_items.isNotEmpty) {
      _markViewed(_items[_index]);
      _startProgress();
    }
  }

  int _initialStoryIndex() {
    if (widget.initialGroup <= 0) return 0;
    var index = 0;
    for (var i = 0; i < widget.initialGroup && i < widget.groups.length; i++) {
      index += (widget.groups[i]['stories'] as List? ?? []).length;
    }
    return index.clamp(0, math.max(0, _items.length - 1));
  }

  Future<void> _markViewed(Map<String, dynamic> item) async {
    final id = (item['story'] as Map)['id'];
    if (id == null) return;
    if (!_viewedStories.add('$id')) return;
    try {
      await _api.request('POST', 'social-stories/$id/view');
    } catch (_) {}
  }

  Duration _storyDuration(Map<String, dynamic> story) {
    final raw = story['duration_seconds'];
    final seconds = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds.clamp(3, 300));
    }
    return const Duration(seconds: 6);
  }

  void _startProgress({bool reset = true, bool? awaitVideo}) {
    _progressTimer?.cancel();
    if (reset) _progress.value = 0;
    _paused = false;
    FeedVideoAutoplayManager.instance.resumeActive();
    if (_items.isEmpty) return;
    final story = _items[_index]['story'] as Map<String, dynamic>;
    _awaitingVideo =
        awaitVideo ?? (reset && '${story['media_type']}' == 'video');
    final duration = _videoDurations[_index] ?? _storyDuration(story);
    final totalMs = duration.inMilliseconds.clamp(1000, 300000).toInt();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _paused || _awaitingVideo) return;
      final next = _progress.value + 100 / totalMs;
      if (next < 1) {
        _progress.value = next;
        return;
      }
      timer.cancel();
      _nextStory();
    });
  }

  void _pauseProgress() {
    if (_paused || _items.isEmpty) return;
    _progressTimer?.cancel();
    FeedVideoAutoplayManager.instance.pauseActive();
    setState(() => _paused = true);
  }

  void _resumeProgress() {
    if (!_paused || _items.isEmpty) return;
    FeedVideoAutoplayManager.instance.resumeActive();
    _startProgress(reset: false);
  }

  /// Uses the real video length instead of the server hint so video stories
  /// end exactly when the video does.
  void _onStoryVideoDuration(int index, Duration duration) {
    if (!mounted || duration <= Duration.zero) return;
    if (_videoDurations[index] == duration) return;
    _videoDurations[index] = duration;
    if (index != _index || _paused) return;
    _startProgress(reset: false, awaitVideo: _awaitingVideo);
  }

  /// Keeps the story progress bar in sync when the native video is paused or
  /// resumed by its own play control.
  void _onStoryPlaybackChanged(int index, bool playing) {
    if (!mounted || index != _index) return;
    if (playing) {
      _awaitingVideo = false;
      _resumeProgress();
    } else if (!_paused && !_awaitingVideo) {
      _pauseProgress();
    }
  }

  void _nextStory() {
    if (_index >= _items.length - 1) {
      _progressTimer?.cancel();
      Navigator.maybePop(context);
      return;
    }
    _pages.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  void _previousStory() {
    if (_index <= 0) {
      _progress.value = 0;
      _startProgress();
      return;
    }
    _pages.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  Future<void> _react(String reaction) async {
    if (_items.isEmpty) return;
    final story = _items[_index]['story'] as Map<String, dynamic>;
    if (story['can_react'] != true || story['id'] == null) return;
    final previous = story['my_reaction'] as String?;
    final next = previous == reaction ? null : reaction;
    final oldReactions = Map<String, dynamic>.from(
        story['reactions'] is Map ? story['reactions'] as Map : {});
    final oldCount = (story['reactions_count'] as num?)?.toInt() ?? 0;
    HapticFeedback.mediumImpact();
    setState(() {
      final reactions = Map<String, dynamic>.from(oldReactions);
      if (previous != null) {
        final remaining = ((reactions[previous] as num?)?.toInt() ?? 1) - 1;
        if (remaining <= 0)
          reactions.remove(previous);
        else
          reactions[previous] = remaining;
      }
      if (next != null)
        reactions[next] = ((reactions[next] as num?)?.toInt() ?? 0) + 1;
      story['reactions'] = reactions;
      story['my_reaction'] = next;
      story['reactions_count'] =
          oldCount + (next != null ? 1 : 0) - (previous != null ? 1 : 0);
      if (next != null) {
        _burstEmoji = communityReactions[next];
        _burstSerial++;
      }
    });
    try {
      final response = await _api.request(
          'PUT', 'social-stories/${story['id']}/reaction',
          data: {'reaction': next});
      if (!mounted) return;
      final data = response['data'];
      if (data is Map) {
        final updated = Map<String, dynamic>.from(data);
        setState(() {
          if (updated.containsKey('my_reaction'))
            story['my_reaction'] = updated['my_reaction'];
          if (updated.containsKey('reactions'))
            story['reactions'] = updated['reactions'];
          if (updated.containsKey('reactions_count'))
            story['reactions_count'] = updated['reactions_count'];
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        story['reactions'] = oldReactions;
        story['reactions_count'] = oldCount;
        story['my_reaction'] = previous;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(communityError(error))));
    }
  }

  Future<void> _showReactions() async {
    if (_items.isEmpty) return;
    final story = _items[_index]['story'] as Map<String, dynamic>;
    final id = story['id'];
    if (id == null) return;
    final wasPaused = _paused;
    _pauseProgress();
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: context._communitySurface,
        builder: (_) => _StoryReactionsSheet(api: _api, storyId: id));
    if (mounted && !wasPaused) _resumeProgress();
  }

  Future<void> _deleteCurrent() async {
    final story = _items[_index]['story'] as Map<String, dynamic>;
    final wasPaused = _paused;
    _pauseProgress();
    final confirmed = await _showCommunityDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(communityText('Delete this story?')),
                content: Text(communityText('This cannot be undone.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(communityText('Cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(communityText('Delete')))
                ]));
    if (!mounted) return;
    if (confirmed != true) {
      if (!wasPaused) _resumeProgress();
      return;
    }
    try {
      await _api.request('DELETE', 'social-stories/${story['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        if (!wasPaused) _resumeProgress();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _progress.dispose();
    _mute.dispose();
    _pages.dispose();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  Widget _storyMedia(Map<String, dynamic> story, int index) {
    final type = '${story['media_type'] ?? 'text'}';
    final url = '${story['media_url'] ?? ''}';
    if (type == 'text') {
      return Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff6246d9), Color(0xffa66cff)])),
          alignment: Alignment.center,
          child: Text('${story['caption'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w800)));
    }
    if (type == 'image') {
      final uri = communityMediaUri(type, url);
      final cacheWidth = ((MediaQuery.maybeSizeOf(context)?.width ?? 720) *
              (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2))
          .round()
          .clamp(720, 1600)
          .toInt();
      return uri == null
          ? Center(
              child: Text(communityText('This media link is unavailable.'),
                  style: const TextStyle(color: Colors.white)))
          : CachedNetworkImage(
              imageUrl: uri.toString(),
              fit: BoxFit.contain,
              memCacheWidth: cacheWidth,
              maxWidthDiskCache: 1600,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white, size: 54)));
    }
    return Center(
        child: CommunityMedia(
            type: type,
            url: url,
            playbackUrl: story['playback_url'] as String?,
            thumbnailUrl: '${story['thumbnail_url'] ?? ''}',
            durationSeconds: story['duration_seconds'],
            aspectRatio: story['aspect_ratio'],
            autoPlay: true,
            useVideoCache: false,
            feedPosition: index,
            muteController: _mute,
            showMuteControl: false,
            loopVideo: false,
            rememberPlayback: false,
            videoTapEnabled: false,
            onVideoDuration: (duration) =>
                _onStoryVideoDuration(index, duration),
            onPlayStateChanged: (playing) =>
                _onStoryPlaybackChanged(index, playing)));
  }

  Widget _progressBars() => ValueListenableBuilder<double>(
      valueListenable: _progress,
      builder: (context, progress, _) => Row(
          children: List.generate(
              _items.length,
              (index) => Expanded(
                  child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4)),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                              widthFactor: index < _index
                                  ? 1
                                  : index == _index
                                      ? progress.clamp(0, 1).toDouble()
                                      : 0,
                              child:
                                  const ColoredBox(color: Colors.white))))))));

  Widget _topOverlay(Map author, Map<String, dynamic> story) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent])),
          child: SafeArea(
              bottom: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: _progressBars()),
                Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage:
                              '${author['avatar'] ?? ''}'.isNotEmpty
                                  ? communityAvatarImage('${author['avatar']}')
                                  : null,
                          child: '${author['avatar'] ?? ''}'.isEmpty
                              ? const Icon(Icons.person,
                                  size: 20, color: Colors.white)
                              : null),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                story['is_mine'] == true
                                    ? communityText('Your story')
                                    : '${author['name'] ?? communityText('Employee')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            if (_paused)
                              Text(communityText('Paused'),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11))
                          ])),
                      if (story['media_type'] == 'video')
                        ListenableBuilder(
                            listenable: _mute,
                            builder: (context, _) => IconButton(
                                key: const ValueKey('story-sound'),
                                tooltip: _mute.muted
                                    ? communityText('Unmute')
                                    : communityText('Mute'),
                                onPressed: _mute.toggle,
                                icon: Icon(
                                    _mute.muted
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                    color: Colors.white))),
                      if (story['can_delete'] == true)
                        IconButton(
                            tooltip: communityText('Delete story'),
                            onPressed: _deleteCurrent,
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white)),
                      IconButton(
                          tooltip: communityText('Close'),
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white))
                    ]))
              ]))));

  Widget _reactionBar(Map<String, dynamic> story) {
    final selected = story['my_reaction'] as String?;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white24)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final entry in communityReactions.entries)
            Semantics(
                label: entry.key,
                button: true,
                selected: selected == entry.key,
                child: InkWell(
                    key: ValueKey('story-reaction-${entry.key}'),
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => _react(entry.key),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.all(selected == entry.key ? 7 : 5),
                        decoration: BoxDecoration(
                            color: selected == entry.key
                                ? Colors.white24
                                : Colors.transparent,
                            shape: BoxShape.circle),
                        child: Text(entry.value,
                            style: TextStyle(
                                fontSize: selected == entry.key ? 28 : 24)))))
        ]));
  }

  Widget _ownerReactionsButton(Map<String, dynamic> story) {
    final reactions =
        story['reactions'] is Map ? story['reactions'] as Map : const {};
    final emoji = reactions.isEmpty
        ? '❤️'
        : communityReactions['${reactions.keys.first}'] ?? '❤️';
    final count = (story['reactions_count'] as num?)?.toInt() ?? 0;
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: _showReactions,
            style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .45),
                foregroundColor: Colors.white,
                shape: const StadiumBorder()),
            icon: Text(emoji, style: const TextStyle(fontSize: 18)),
            label: Text('$count')));
  }

  Widget _bottomOverlay(Map<String, dynamic> story) {
    final canReact = story['can_react'] == true;
    final count = (story['reactions_count'] as num?)?.toInt() ?? 0;
    if (!canReact && count <= 0) return const SizedBox.shrink();
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: DecoratedBox(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent])),
            child: SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                    child: canReact
                        ? _reactionBar(story)
                        : _ownerReactionsButton(story)))));
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded))),
          body: Center(
              child: Text(communityText('No active stories.'),
                  style: const TextStyle(color: Colors.white))));
    }
    final current = _items[_index];
    final author = current['author'] as Map;
    final story = current['story'] as Map<String, dynamic>;
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.sizeOf(context).width;
                if (details.localPosition.dx < width / 3) {
                  _previousStory();
                } else if (details.localPosition.dx > width * 2 / 3) {
                  _nextStory();
                } else {
                  _paused ? _resumeProgress() : _pauseProgress();
                }
              },
              onLongPressStart: (_) => _pauseProgress(),
              onLongPressEnd: (_) => _resumeProgress(),
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 250)
                  Navigator.maybePop(context);
              },
              child: PageView.builder(
                  controller: _pages,
                  allowImplicitScrolling: true,
                  itemCount: _items.length,
                  onPageChanged: (value) {
                    setState(() => _index = value);
                    _markViewed(_items[value]);
                    _startProgress();
                  },
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final story = item['story'] as Map<String, dynamic>;
                    return Stack(fit: StackFit.expand, children: [
                      _storyMedia(story, index),
                      if ('${story['caption'] ?? ''}'.trim().isNotEmpty &&
                          story['media_type'] != 'text')
                        Positioned(
                            left: 22,
                            right: 22,
                            bottom: story['can_react'] == true ? 108 : 28,
                            child: Text('${story['caption']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(blurRadius: 5, color: Colors.black)
                                    ])))
                    ]);
                  })),
          Positioned(
              top: 0, left: 0, right: 0, child: _topOverlay(author, story)),
          Positioned(
              left: 0, right: 0, bottom: 0, child: _bottomOverlay(story)),
          if (_burstEmoji != null)
            Positioned.fill(
                child: IgnorePointer(
                    child: _StoryReactionBurst(
                        key: ValueKey('story-burst-$_burstSerial'),
                        emoji: _burstEmoji!)))
        ]));
  }
}

class _StoryReactionBurst extends StatefulWidget {
  const _StoryReactionBurst({super.key, required this.emoji});
  final String emoji;

  @override
  State<_StoryReactionBurst> createState() => _StoryReactionBurstState();
}

class _StoryReactionBurstState extends State<_StoryReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final Animation<double> _animation =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        return Align(
            alignment: Alignment(0, .72 - t * 1.15),
            child: Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Transform.scale(
                    scale: .6 + t * .9,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 64)))));
      });
}

class _StoryReactionsSheet extends StatefulWidget {
  const _StoryReactionsSheet({required this.api, required this.storyId});
  final CommunityApi api;
  final int storyId;

  @override
  State<_StoryReactionsSheet> createState() => _StoryReactionsSheetState();
}

class _StoryReactionsSheetState extends State<_StoryReactionsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api
          .request('GET', 'social-stories/${widget.storyId}/reactions');
      if (!mounted) return;
      setState(() {
        _items = (response['data'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = communityError(error);
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: math.min(420, MediaQuery.sizeOf(context).height * .5),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _items.isEmpty
                      ? Center(child: Text(communityText('No reactions yet.')))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final colors = context._communityColors;
                            final user = Map<String, dynamic>.from(
                                item['user'] as Map? ?? {});
                            final avatar = '${user['avatar'] ?? ''}';
                            final emoji =
                                communityReactions['${item['reaction']}'] ??
                                    '👍';
                            return ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: colors.secondaryContainer,
                                    backgroundImage: avatar.isNotEmpty
                                        ? communityAvatarImage(avatar)
                                        : null,
                                    child: avatar.isEmpty
                                        ? Icon(Icons.person_outline,
                                            color: colors.onSecondaryContainer)
                                        : null),
                                title: Text(
                                    '${user['name'] ?? communityText('Employee')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle:
                                    '${user['department'] ?? ''}'.trim().isEmpty
                                        ? null
                                        : Text('${user['department']}'),
                                trailing: Text(emoji,
                                    style: const TextStyle(fontSize: 24)));
                          })));
}

const _storySurface = Color(0xff161d27);

void _requestTextKeyboard(BuildContext context, FocusNode focusNode,
    TextEditingController controller) {
  if (!controller.selection.isValid) {
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }
  focusNode.requestFocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !focusNode.hasFocus) return;
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
  });
}

class SocialStoryComposer extends StatefulWidget {
  const SocialStoryComposer({
    super.key,
    this.api,
    this.autofocusCaption = false,
  });
  final CommunityApi? api;
  final bool autofocusCaption;

  @override
  State<SocialStoryComposer> createState() => _SocialStoryComposerState();
}

class _SocialStoryComposerState extends State<SocialStoryComposer> {
  late final CommunityApi _api;
  late final bool _ownsApi;
  final _caption = TextEditingController();
  final _captionFocusNode = FocusNode();
  PlatformFile? _file;
  Uint8List? _thumbnailBytes;
  int? _durationSeconds;
  double? _aspectRatio;
  String _type = 'text';
  int _gradient = 0;
  static const _storyGradients = [
    [Color(0xff1877f2), Color(0xff0a2f6b)],
    [Color(0xff7b2ff7), Color(0xfff107a3)],
    [Color(0xffff7a18), Color(0xffc81d77)],
    [Color(0xff00c6ff), Color(0xff005bea)],
    [Color(0xff0f2027), Color(0xff2c5364)],
    [Color(0xfff953c6), Color(0xff8a0e68)],
  ];
  bool _saving = false;
  bool _metadataLoading = false;
  String? _error;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? CommunityApi();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_handleRouteAnimation);
    if (animation?.status == AnimationStatus.completed) {
      _focusCaptionWhenReady();
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) _focusCaptionWhenReady();
  }

  void _focusCaptionWhenReady() {
    if (mounted && widget.autofocusCaption) {
      _requestTextKeyboard(context, _captionFocusNode, _caption);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _captionFocusNode.dispose();
    _caption.dispose();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  Future<void> _pick(String type) async {
    _captionFocusNode.unfocus();
    List<PlatformFile> files;
    try {
      files = await pickCommunityMedia(context, type, multiple: false);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
      return;
    }
    if (!mounted || files.isEmpty) return;
    final file = files.single;
    final max = type == 'image' ? 10 * 1024 * 1024 : 100 * 1024 * 1024;
    if (file.path == null || file.size > max) {
      if (!mounted) return;
      setState(() {
        _error = type == 'image'
            ? communityText('Select an image of 10 MB or smaller.')
            : communityText('Select a video of 100 MB or smaller.');
      });
      return;
    }
    setState(() {
      _type = type;
      _file = file;
      _thumbnailBytes = null;
      _durationSeconds = null;
      _aspectRatio = null;
      _metadataLoading = type == 'video';
      _error = null;
    });
    if (type != 'video') return;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
          video: file.path!,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 960,
          quality: 82);
      int? duration;
      double? aspectRatio;
      final controller = VideoPlayerController.file(File(file.path!));
      try {
        await controller.initialize();
        duration = controller.value.duration.inSeconds;
        final value = controller.value.aspectRatio;
        if (value.isFinite && value > 0) aspectRatio = value;
      } finally {
        await controller.dispose();
      }
      if (!mounted) return;
      setState(() {
        _thumbnailBytes = bytes;
        _durationSeconds = duration;
        _aspectRatio = aspectRatio;
        _metadataLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _metadataLoading = false);
    }
  }

  String? _mime(String? extension) => {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'heic': 'image/heic',
        'heif': 'image/heif',
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'webm': 'video/webm',
      }[extension?.toLowerCase()];

  Future<void> _save() async {
    if (_saving) return;
    if (_type == 'text' && _caption.text.trim().isEmpty) {
      setState(() => _error = communityText('Write something for your story.'));
      return;
    }
    if (_type != 'text' && _file?.path == null) {
      setState(() => _error = communityText('Choose a photo or video first.'));
      return;
    }
    if (_metadataLoading) {
      setState(() => _error = communityText(
          'Preparing the video preview. Please try again in a moment.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final storyData = {
        'media_type': _type,
        'caption': _caption.text.trim(),
        if (_durationSeconds != null) 'duration_seconds': _durationSeconds,
        if (_aspectRatio != null) 'aspect_ratio': _aspectRatio,
      };
      if (_thumbnailBytes != null) {
        await _api.requestWithThumbnail('POST', 'social-stories',
            data: storyData,
            filePath: _type == 'text' ? null : _file?.path,
            fileMime: _mime(_file?.extension),
            thumbnailBytes: _thumbnailBytes,
            thumbnailFileName: 'story-thumbnail.jpg',
            thumbnailMime: 'image/jpeg');
      } else {
        await _api.request('POST', 'social-stories',
            data: storyData,
            filePath: _type == 'text' ? null : _file?.path,
            fileMime: _type == 'text' ? null : _mime(_file?.extension));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _storyEditor(
      {required String hint, required TextStyle style, int? maxLines = 3}) {
    return TextField(
        key: const ValueKey('story-editor'),
        controller: _caption,
        focusNode: _captionFocusNode,
        enabled: !_saving,
        maxLength: 1000,
        maxLines: maxLines,
        minLines: 1,
        autofocus: false,
        onTap: () => _requestTextKeyboard(context, _captionFocusNode, _caption),
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: Colors.white,
        style: style,
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: style.copyWith(color: Colors.white60),
            counterText: '',
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero));
  }

  Widget _mediaPreview(BoxFit fit, {double radius = 24}) {
    if (_file?.path != null && _type == 'image') {
      return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(File(_file!.path!), fit: fit));
    }
    if (_file?.path != null && _type == 'video') {
      if (_metadataLoading) {
        return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: const ColoredBox(
                color: _storySurface,
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white))));
      }
      return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
              decoration: const BoxDecoration(color: _storySurface),
              child: Stack(fit: StackFit.expand, children: [
                if (_thumbnailBytes != null)
                  Image.memory(_thumbnailBytes!, fit: fit, cacheWidth: 1080),
                const ColoredBox(color: Colors.black26),
                const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 66)),
                if (_durationSeconds != null)
                  Positioned(
                      right: 12,
                      bottom: 12,
                      child: _StoryDurationBadge(seconds: _durationSeconds!))
              ])));
    }
    final gradient = _storyGradients[_gradient];
    final text = _caption.text.trim();
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient)),
            child: Stack(fit: StackFit.expand, children: [
              Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .08)))),
              Positioned(
                  bottom: -60,
                  left: -30,
                  child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .12)))),
              Positioned.fill(
                  child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.all(28),
                          child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight:
                                      math.max(0, constraints.maxHeight - 56)),
                              child: Center(
                                  child: _storyEditor(
                                      hint: communityText('Your story preview'),
                                      maxLines: null,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: text.length > 80 ? 22 : 27,
                                          height: 1.25,
                                          fontWeight: FontWeight.w800,
                                          shadows: const [
                                            Shadow(
                                                blurRadius: 12,
                                                color: Colors.black38)
                                          ])))))))
            ])));
  }

  Widget _preview() {
    return ValueListenableBuilder<TextEditingValue>(
        valueListenable: _caption, builder: (_, __, ___) => _buildPreview());
  }

  Widget _buildPreview() {
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: .08))),
          child: _mediaPreview(BoxFit.cover)),
      if (_type != 'text')
        Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(26)),
                child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 40, 18, 18),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                          Colors.black.withValues(
                              alpha: _caption.text.trim().isEmpty ? .35 : .87),
                          Colors.transparent
                        ])),
                    child: _storyEditor(
                        hint: communityText('Add a caption…'),
                        maxLines: 3,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54)
                            ])))))
    ]);
  }

  Widget _typeChip(String type, IconData icon, String label) {
    final selected = _type == type;
    final colors = context._communityColors;
    final foreground =
        selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    return Expanded(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
                color: selected
                    ? colors.primaryContainer
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _saving
                        ? null
                        : () {
                            if (type == 'text') {
                              setState(() {
                                _type = 'text';
                                _file = null;
                                _thumbnailBytes = null;
                                _durationSeconds = null;
                                _aspectRatio = null;
                                _error = null;
                              });
                              _requestTextKeyboard(
                                  context, _captionFocusNode, _caption);
                            } else {
                              _pick(type);
                            }
                          },
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 19, color: foreground),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: TextStyle(
                                      color: foreground,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13))
                            ]))))));
  }

  Widget _controls() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _typeChip('text', Icons.text_fields_rounded, communityText('Text')),
            _typeChip(
                'image', Icons.photo_library_rounded, communityText('Photo')),
            _typeChip('video', Icons.videocam_rounded, communityText('Video')),
          ]),
          if (_type == 'text')
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _storyGradients.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => GestureDetector(
                            key: ValueKey('story-gradient-$index'),
                            onTap: _saving
                                ? null
                                : () => setState(() => _gradient = index),
                            child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: _storyGradients[index]),
                                    border: Border.all(
                                        color: _gradient == index
                                            ? context._communityColors.onSurface
                                            : Colors.transparent,
                                        width: 2))))))),
        ]));
  }

  Widget? _errorBanner() {
    final color = context._communityColors.error;
    final error = _error;
    if (error == null) return null;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: color, size: 17),
          const SizedBox(width: 6),
          Expanded(
              child: Text(error,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13)))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context._communityColors;
    final foreground = colors.onPrimaryContainer;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            backgroundColor: context._communityPage,
            appBar: AppBar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: foreground,
                iconTheme: IconThemeData(color: foreground),
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: IconButton(
                    tooltip: communityText('Close'),
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded)),
                title: Text(communityText('Create story'),
                    style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 17))),
            bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_error != null) _errorBanner()!,
                  const SizedBox(height: 4),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: foreground,
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: foreground))
                            else
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(_saving
                                ? communityText('Publishing…')
                                : communityText('Share story'))
                          ]))
                ])),
            body: SafeArea(
                top: false,
                child: LayoutBuilder(builder: (context, constraints) {
                  final previewHeight =
                      (constraints.maxHeight * .66).clamp(220.0, 560.0);
                  return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            child: SizedBox(
                                height: previewHeight, child: _preview())),
                        _controls()
                      ]));
                }))));
  }
}

class _ShareCaptionDialog extends StatefulWidget {
  @override
  State<_ShareCaptionDialog> createState() => _ShareCaptionDialogState();
}

class _ShareCaptionDialogState extends State<_ShareCaptionDialog> {
  final _caption = TextEditingController();
  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(communityText('Share to feed')),
        content: TextField(
            controller: _caption,
            maxLength: 10000,
            maxLines: 4,
            decoration: InputDecoration(
                hintText: communityText('Add a message (optional)'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(communityText('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, _caption.text.trim()),
              child: Text(communityText('Share'))),
        ],
      );
}

class _ReportPostDialog extends StatefulWidget {
  const _ReportPostDialog();
  @override
  State<_ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<_ReportPostDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(communityText('Report post')),
        content: TextField(
            controller: _reason,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
                hintText: communityText('Why are you reporting this post?'),
                border: const OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(communityText('Cancel'))),
          FilledButton(
              onPressed: () {
                final value = _reason.text.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: Text(communityText('Report'))),
        ],
      );
}

class SocialSearchScreen extends StatefulWidget {
  const SocialSearchScreen({super.key, this.api});
  final CommunityApi? api;
  @override
  State<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends State<SocialSearchScreen> {
  late final _api = widget.api ?? CommunityApi();
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.request(
          'GET', 'social-search?q=${Uri.encodeQueryComponent(value)}');
      if (!mounted) return;
      setState(() => _results = (response['data'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList());
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context._communityPage,
        appBar: _communityAppBar(context, communityText('Search feed')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: context._communityColors.surfaceContainerHigh,
                      hintStyle: TextStyle(
                          color: context._communityColors.onSurfaceVariant),
                      hintText: communityText('Search posts or employees'),
                      suffixIcon: IconButton(
                          onPressed: _loading ? null : _search,
                          icon: const Icon(Icons.search)),
                      border: const OutlineInputBorder()))),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _results.length,
                  itemBuilder: (_, index) {
                    final post = _results[index];
                    return Card(
                        color: context._communitySurface,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                            title: Text(
                                '${(post['author'] as Map?)?['name'] ?? communityText('Employee')}'),
                            subtitle: Text('${post['body'] ?? ''}'),
                            isThreeLine: true));
                  }))
        ]),
      );
}

class SocialNotificationsScreen extends StatefulWidget {
  const SocialNotificationsScreen({super.key, this.api});
  final CommunityApi? api;
  @override
  State<SocialNotificationsScreen> createState() =>
      _SocialNotificationsScreenState();
}

class _SocialNotificationsScreenState extends State<SocialNotificationsScreen> {
  late final _api = widget.api ?? CommunityApi();
  final List<Map<String, dynamic>> _items = [];
  final Set<dynamic> _busy = {};
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  int _page = 0;
  bool _hasMore = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  int get _unreadCount =>
      _items.where((item) => item['read_at'] == null).length;

  Future<void> _load({bool reset = false}) async {
    if (!reset && (!_hasMore || _loadingMore || _loading)) return;
    final generation = ++_generation;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = reset ? 1 : _page + 1;
      final response =
          await _api.request('GET', 'social-notifications?page=$page');
      if (!mounted || generation != _generation) return;
      final raw = response['data'];
      final incoming = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        if (reset) _items.clear();
        final existing = _items.map((item) => item['id']).toSet();
        _items.addAll(incoming.where((item) => existing.add(item['id'])));
        _page = page;
        final currentPage = response['current_page'];
        final lastPage = response['last_page'];
        _hasMore = response['next_page_url'] != null ||
            (currentPage is num &&
                lastPage is num &&
                currentPage.toInt() < lastPage.toInt());
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final message = communityError(error);
      if (reset || _items.isEmpty) {
        setState(() => _error = message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  int? _postIdFor(Map<String, dynamic> item) {
    final data = item['data'];
    final raw =
        item['social_post_id'] ?? (data is Map ? data['post_id'] : null);
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}');
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null || item['read_at'] != null || _busy.contains(id)) return;
    final previous = item['read_at'];
    setState(() {
      _busy.add(id);
      item['read_at'] = DateTime.now().toIso8601String();
    });
    try {
      await _api.request('POST', 'social-notifications/$id/read');
    } catch (error) {
      if (mounted) {
        setState(() => item['read_at'] = previous);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _markAll() async {
    if (_markingAll || _unreadCount == 0) return;
    final previous = {
      for (final item in _items) item['id']: item['read_at'],
    };
    final now = DateTime.now().toIso8601String();
    setState(() {
      _markingAll = true;
      for (final item in _items) item['read_at'] = item['read_at'] ?? now;
    });
    try {
      await _api.request('POST', 'social-notifications/read-all');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(communityText('All notifications marked as read.'))));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          for (final item in _items) {
            item['read_at'] = previous[item['id']];
          }
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await _markRead(item);
    if (!mounted) return;
    final postId = _postIdFor(item);
    if (postId == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                SocialPostDetailScreen(postId: postId, api: widget.api)));
    if (mounted) await _load(reset: true);
  }

  String _messageFor(Map<String, dynamic> item) {
    final actor =
        '${(item['actor'] as Map?)?['name'] ?? communityText('Employee')}';
    switch ('${item['type']}') {
      case 'reaction':
        return '$actor ${communityText('reacted to your post.')}';
      case 'share':
        return '$actor ${communityText('shared your post.')}';
      case 'comment':
        return '$actor ${communityText('commented on your post.')}';
      case 'reply':
        return '$actor ${communityText('replied to your comment.')}';
      default:
        return '$actor ${communityText('interacted with your post.')}';
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'reaction':
        return Icons.favorite_rounded;
      case 'share':
        return Icons.share_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'reply':
        return Icons.reply_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Widget _emptyState(BuildContext context) =>
      ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.notifications_off_outlined,
                  size: 44, color: Theme.of(context).disabledColor),
              const SizedBox(height: 12),
              Text(communityText('No notifications yet.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                  communityText(
                      'Reactions, comments and shares on your posts will appear here.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall)
            ]))
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context._communityPage,
      appBar: _communityAppBar(
          context,
          _unreadCount > 0
              ? '${communityText('Notifications')} ($_unreadCount)'
              : communityText('Notifications'),
          actions: [
            if (_unreadCount > 0)
              TextButton(
                  onPressed: _markingAll ? null : _markAll,
                  style: TextButton.styleFrom(
                      foregroundColor:
                          context._communityColors.onPrimaryContainer),
                  child: Text(communityText('Mark all read')))
          ]),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? _ErrorState(message: _error!, onRetry: () => _load(reset: true))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _items.isEmpty
                      ? _emptyState(context)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                      child: _loadingMore
                                          ? const CircularProgressIndicator()
                                          : TextButton(
                                              onPressed: () => _load(),
                                              child: Text(communityText(
                                                  'Load more notifications')))));
                            }
                            final item = _items[index];
                            final unread = item['read_at'] == null;
                            final busy = _busy.contains(item['id']);
                            return ListTile(
                                enabled: !busy,
                                onTap: () => _open(item),
                                leading: CircleAvatar(
                                    backgroundColor: unread
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : null,
                                    child: Icon(_iconFor('${item['type']}'),
                                        size: 20)),
                                title: Text(_messageFor(item)),
                                subtitle: Text(_date(item['created_at'])),
                                trailing: unread
                                    ? Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            shape: BoxShape.circle))
                                    : null);
                          })));
}

class SocialPostDetailScreen extends StatefulWidget {
  const SocialPostDetailScreen({super.key, required this.postId, this.api});
  final int postId;
  final CommunityApi? api;
  @override
  State<SocialPostDetailScreen> createState() => _SocialPostDetailScreenState();
}

class _SocialPostDetailScreenState extends State<SocialPostDetailScreen> {
  late final _api = widget.api ?? CommunityApi();
  Map<String, dynamic>? _post;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Needed so tapping an @mention in this post can resolve the person even
    // when the detail screen is the first community screen to open.
    unawaited(MentionDirectory.ensureLoaded());
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await _api.request('GET', 'social-feed/${widget.postId}');
      if (!mounted) return;
      final data = response['data'];
      setState(() {
        _post = data is Map ? Map<String, dynamic>.from(data) : null;
        if (_post == null)
          _error = communityText('This post is no longer available.');
      });
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openComments() {
    final post = _post;
    if (post == null) return;
    FeedVideoAutoplayManager.instance.pauseAll();
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => SocialCommentsScreen(
            postId: widget.postId,
            reactionsCount: (post['reactions_count'] as num?)?.toInt() ?? 0,
            commentsCount: (post['comments_count'] as num?)?.toInt() ?? 0,
            sharesCount: (post['shares_count'] as num?)?.toInt() ?? 0)));
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final author = post?['author'] as Map?;
    final avatar = '${author?['avatar'] ?? ''}';
    return Scaffold(
        backgroundColor: context._communityPage,
        appBar: _communityAppBar(context, communityText('Post')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || post == null
                ? _ErrorState(
                    message: _error ??
                        communityText('This post is no longer available.'),
                    onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                        children: [
                          Card(
                              color: context._communitySurface,
                              margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 12, 0, 12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14),
                                            child: Row(children: [
                                              Expanded(
                                                  child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      onTap: () =>
                                                          _openAuthorProfile(
                                                              context, author,
                                                              api: _api),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 2),
                                                        child: Row(children: [
                                                          CircleAvatar(
                                                              backgroundImage: avatar
                                                                      .isNotEmpty
                                                                  ? communityAvatarImage(
                                                                      avatar)
                                                                  : null,
                                                              child: avatar
                                                                      .isEmpty
                                                                  ? const Icon(Icons
                                                                      .person_outline)
                                                                  : null),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                Text(
                                                                    '${author?['name'] ?? communityText('Employee')}',
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold)),
                                                                Text(
                                                                    '${author?['department'] ?? ''}${author?['department'] != null ? ' · ' : ''}${_date(post['created_at'])}',
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodySmall),
                                                              ])),
                                                        ]),
                                                      ))),
                                            ])),
                                        const SizedBox(height: 6),
                                        _PostContent(
                                            post: post,
                                            inset: 14,
                                            onMentionTap: (name) =>
                                                _openMentionProfile(
                                                    context, name,
                                                    api: _api)),
                                        const SizedBox(height: 6),
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14),
                                            child: Row(children: [
                                              Text(
                                                  '${post['reactions_count'] ?? 0} ${communityText('reactions')}'),
                                              const SizedBox(width: 12),
                                              Text(
                                                  '${post['comments_count'] ?? 0} ${communityText('comments')}'),
                                              const Spacer(),
                                              TextButton.icon(
                                                  onPressed: _openComments,
                                                  icon: const Icon(
                                                      Icons.chat_bubble_outline,
                                                      size: 18),
                                                  label: Text(communityText(
                                                      'Comments')))
                                            ])),
                                      ]))),
                        ])));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: onRetry, child: Text(communityText('Try again')))
          ])));
}

class SocialSavedPostsScreen extends StatefulWidget {
  const SocialSavedPostsScreen({super.key, this.api});
  final CommunityApi? api;
  @override
  State<SocialSavedPostsScreen> createState() => _SocialSavedPostsScreenState();
}

class _SocialSavedPostsScreenState extends State<SocialSavedPostsScreen> {
  late final _api = widget.api ?? CommunityApi();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await _api.request('GET', 'social-saved');
      if (mounted)
        setState(() => _posts = (response['data'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList());
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context._communityPage,
      appBar: _communityAppBar(context, communityText('Saved posts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                      children: [
                        if (_posts.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(communityText('No saved posts yet.'),
                                  textAlign: TextAlign.center)),
                        for (final post in _posts)
                          Card(
                              color: context._communitySurface,
                              margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 12, 0, 12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${(post['author'] as Map?)?['name'] ?? communityText('Employee')}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text(
                                                      _date(post['created_at']),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall),
                                                ])),
                                        const SizedBox(height: 6),
                                        _PostContent(
                                            post: post,
                                            inset: 14,
                                            onMentionTap: (name) =>
                                                _openMentionProfile(
                                                    context, name,
                                                    api: _api)),
                                      ])))
                      ])));
}

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _PollWidget extends StatefulWidget {
  const _PollWidget({required this.post, required this.api});
  final Map<String, dynamic> post;
  final CommunityApi api;
  @override
  State<_PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<_PollWidget> {
  late Set<int> _selected;
  bool _saving = false;

  Map<String, dynamic> get _poll =>
      Map<String, dynamic>.from(widget.post['poll'] as Map);

  @override
  void initState() {
    super.initState();
    _selected = ((_poll['my_option_ids'] as List?) ?? [])
        .map((id) => id as int)
        .toSet();
  }

  Future<void> _vote() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final response = await widget.api.request(
          'POST', 'social-feed/${widget.post['id']}/poll/vote',
          data: {'option_ids': _selected.toList()});
      if (mounted && response['data'] is Map)
        setState(() => widget.post['poll'] = response['data']);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = (_poll['options'] as List? ?? []).cast<Map>();
    final closed = _poll['closed'] == true;
    final multiple = _poll['allow_multiple'] == true;
    final total = options.fold<int>(0,
        (sum, option) => sum + ((option['votes_count'] as num?)?.toInt() ?? 0));
    return Card(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .45),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${_poll['question']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  for (final option in options)
                    multiple
                        ? CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _selected.contains(option['id']),
                            title: Text(
                                '${option['label']} (${option['votes_count'] ?? 0})'),
                            onChanged: closed
                                ? null
                                : (value) => setState(() => value == true
                                    ? _selected.add(option['id'] as int)
                                    : _selected.remove(option['id'] as int)))
                        : RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: option['id'] as int,
                            groupValue:
                                _selected.isEmpty ? null : _selected.first,
                            title: Text(
                                '${option['label']} (${option['votes_count'] ?? 0})'),
                            onChanged: closed
                                ? null
                                : (value) => setState(() =>
                                    _selected = {if (value != null) value})),
                  Text('$total ${communityText('votes')}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                          onPressed: closed || _saving ? null : _vote,
                          child: Text(closed
                              ? communityText('Poll closed')
                              : communityText('Vote'))))
                ])));
  }
}

class _PostContent extends StatefulWidget {
  _PostContent(
      {required this.post,
      this.nested = false,
      this.feedPosition,
      this.inset = 0,
      this.onMentionTap});
  final Map<String, dynamic> post;
  final bool nested;
  final int? feedPosition;
  final double inset;

  /// Tapping a rendered @mention opens that person's profile.
  final CommunityMentionTap? onMentionTap;

  @override
  State<_PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<_PostContent> {
  /// Recognizers created for the @mention spans of the current build, disposed
  /// whenever the text is rebuilt or the widget goes away.
  final List<TapGestureRecognizer> _mentionTaps = [];

  @override
  void dispose() {
    _disposeMentionTaps();
    super.dispose();
  }

  void _disposeMentionTaps() {
    for (final recognizer in _mentionTaps) {
      recognizer.dispose();
    }
    _mentionTaps.clear();
  }

  TextSpan _span(String body, TextStyle style,
      {Color mentionColor = const Color(0xff2563eb)}) {
    _disposeMentionTaps();
    return communityFormattedSpan(body, style,
        mentionColor: mentionColor,
        onMentionTap: widget.onMentionTap,
        recognizers: _mentionTaps);
  }

  List<Map<String, dynamic>> _mediaItems() {
    final post = widget.post;
    final items = <Map<String, dynamic>>[];
    final primaryType = '${post['media_type'] ?? 'text'}';
    final primaryUrl = '${post['media_url'] ?? ''}'.trim();
    if (primaryType != 'text' && primaryUrl.isNotEmpty) {
      items.add({
        'media_type': primaryType,
        'media_url': primaryUrl,
        'thumbnail_url': post['thumbnail_url'],
        'playback_url': post['playback_url'],
        'duration_seconds': post['duration_seconds'],
        'aspect_ratio': post['aspect_ratio'],
      });
    }
    for (final raw
        in post['media'] is List ? post['media'] as List : const []) {
      if (raw is! Map) continue;
      final type = '${raw['media_type'] ?? ''}';
      final url = '${raw['media_url'] ?? ''}'.trim();
      if (type.isNotEmpty && url.isNotEmpty) {
        items.add({
          'media_type': type,
          'media_url': url,
          'thumbnail_url': raw['thumbnail_url'],
          'playback_url': raw['playback_url'],
          'duration_seconds': raw['duration_seconds'],
          'aspect_ratio': raw['aspect_ratio'],
        });
      }
    }
    return items;
  }

  void _openViewer(
      BuildContext context, List<Map<String, dynamic>> items, int index) {
    FeedVideoAutoplayManager.instance.pauseAll();
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SocialMediaViewer(items: items, initialIndex: index)));
  }

  @override
  Widget build(BuildContext context) {
    final media = _mediaItems();
    final body = '${widget.post['body'] ?? ''}';
    final background =
        communityPostBackground('${widget.post['background'] ?? ''}');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (body.isNotEmpty)
        if (background != null && media.isEmpty)
          Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.inset),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: background.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16)),
                  child: communityNeedsRichText(body)
                      ? SelectableText.rich(
                          _span(
                              body,
                              TextStyle(
                                  color: background.foreground,
                                  fontSize: 22,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600),
                              mentionColor: background.foreground),
                          textAlign: TextAlign.center)
                      : SelectableText(body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: background.foreground,
                              fontSize: 22,
                              height: 1.35,
                              fontWeight: FontWeight.w600))))
        else
          Padding(
              padding: EdgeInsets.fromLTRB(
                  widget.inset, 0, widget.inset, media.isEmpty ? 0 : 4),
              child: communityNeedsRichText(body)
                  ? SelectableText.rich(_span(body, Theme.of(context).textTheme.bodyLarge ?? const TextStyle(), mentionColor: context._communityColors.primary), textAlign: TextAlign.left)
                  : SelectableText(body)),
      if (media.length == 1)
        CommunityMedia(
            type: media.first['media_type'] as String,
            url: media.first['media_url'] as String,
            playbackUrl: media.first['playback_url'] as String?,
            thumbnailUrl: '${media.first['thumbnail_url'] ?? ''}',
            durationSeconds: media.first['duration_seconds'],
            aspectRatio: media.first['aspect_ratio'],
            feedPosition: widget.feedPosition,
            autoPlay: media.first['media_type'] == 'video',
            allowFullscreen: true,
            onImageTap: media.first['media_type'] == 'image'
                ? () => _openViewer(context, media, 0)
                : null)
      else if (media.length > 1)
        _PostMediaGallery(
            items: media,
            feedPosition: widget.feedPosition,
            onImageTap: (index) => _openViewer(context, media, index)),
      if (!widget.nested && widget.post['original_post_id'] != null)
        Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.inset),
            child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12)),
                child: widget.post['original'] is Map
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Text(
                                '${(widget.post['original']['author'] as Map?)?['name'] ?? communityText('Employee')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _PostContent(
                                post: Map<String, dynamic>.from(
                                    widget.post['original'] as Map),
                                nested: true,
                                onMentionTap: widget.onMentionTap),
                          ])
                    : Text(communityText(
                        'The original post is no longer available.')))),
    ]);
  }
}

class _PostMediaGallery extends StatelessWidget {
  const _PostMediaGallery(
      {required this.items, required this.onImageTap, this.feedPosition});
  final List<Map<String, dynamic>> items;
  final ValueChanged<int> onImageTap;
  final int? feedPosition;

  Widget _tile(Map<String, dynamic> item, int index) {
    return Stack(fit: StackFit.expand, children: [
      CommunityMedia(
          type: item['media_type'] as String,
          url: item['media_url'] as String,
          playbackUrl: item['playback_url'] as String?,
          thumbnailUrl: '${item['thumbnail_url'] ?? ''}',
          durationSeconds: item['duration_seconds'],
          aspectRatio: item['aspect_ratio'],
          compact: true,
          autoPlay: item['media_type'] == 'video',
          allowFullscreen: true,
          feedPosition: feedPosition == null ? null : feedPosition! * 4 + index,
          onImageTap:
              item['media_type'] == 'image' ? () => onImageTap(index) : null),
      if (index == 3 && items.length > 4)
        DecoratedBox(
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .56),
                borderRadius: BorderRadius.circular(16)),
            child: Center(
                child: Text('+${items.length - 4}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800))))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList();
    if (visible.length == 3) {
      return LayoutBuilder(builder: (context, constraints) {
        final cell = (constraints.maxWidth - 4) / 2;
        return SizedBox(
            height: cell * 2 + 4,
            child: Row(children: [
              Expanded(child: _tile(visible[0], 0)),
              const SizedBox(width: 4),
              Expanded(
                  child: Column(children: [
                Expanded(child: _tile(visible[1], 1)),
                const SizedBox(height: 4),
                Expanded(child: _tile(visible[2], 2))
              ]))
            ]));
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemBuilder: (context, index) {
            return _tile(visible[index], index);
          }),
      Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.collections_rounded,
                size: 16, color: context._communityColors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text('${items.length} ${communityText('media items')}',
                style: TextStyle(
                    color: context._communityColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600))
          ]))
    ]);
  }
}

class SocialMediaViewer extends StatefulWidget {
  const SocialMediaViewer(
      {super.key, required this.items, this.initialIndex = 0});
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  @override
  State<SocialMediaViewer> createState() => _SocialMediaViewerState();
}

class _SocialMediaViewerState extends State<SocialMediaViewer> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _shareCurrent() async {
    final url = '${widget.items[_index]['media_url'] ?? ''}'.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await Share.shareUri(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${widget.items.length}'),
          leading: IconButton(
              tooltip: communityText('Close'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded)),
          actions: [
            IconButton(
                tooltip: communityText('Share image'),
                onPressed: _shareCurrent,
                icon: const Icon(Icons.share_rounded))
          ]),
      body: PageView.builder(
          controller: _pages,
          itemCount: widget.items.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final type = '${item['media_type'] ?? ''}';
            final url = '${item['media_url'] ?? ''}';
            if (type == 'image') {
              final uri = communityMediaUri(type, url);
              if (uri == null) {
                return Center(
                    child: Text(
                        communityText('This media link is unavailable.'),
                        style: const TextStyle(color: Colors.white)));
              }
              return _ZoomableFeedImage(uri: uri);
            }
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CommunityMedia(
                        type: type,
                        url: url,
                        allowFullscreen: true,
                        playbackUrl: item['playback_url'] as String?,
                        thumbnailUrl: '${item['thumbnail_url'] ?? ''}',
                        durationSeconds: item['duration_seconds'],
                        aspectRatio: item['aspect_ratio'])));
          }));
}

class _ZoomableFeedImage extends StatefulWidget {
  const _ZoomableFeedImage({required this.uri});
  final Uri uri;

  @override
  State<_ZoomableFeedImage> createState() => _ZoomableFeedImageState();
}

class _ZoomableFeedImageState extends State<_ZoomableFeedImage> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final scale = _transform.value.getMaxScaleOnAxis();
    _transform.value =
        scale > 1.05 ? Matrix4.identity() : (Matrix4.identity()..scale(2.2));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
              child: CachedNetworkImage(
                  imageUrl: widget.uri.toString(),
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 52)))));
}

class CommunityPostBackground {
  const CommunityPostBackground(this.colors);
  final List<Color> colors;
  Color get foreground => Colors.white;
}

const communityPostBackgrounds = <String, CommunityPostBackground>{
  'ocean': CommunityPostBackground([Color(0xff1877f2), Color(0xff0a3d91)]),
  'midnight': CommunityPostBackground([Color(0xff1d2939), Color(0xff344054)]),
  'forest': CommunityPostBackground([Color(0xff1d7a46), Color(0xff0b4f2c)]),
  'sunset': CommunityPostBackground([Color(0xfff5533d), Color(0xffb4235a)]),
  'plum': CommunityPostBackground([Color(0xff7b2d8e), Color(0xff4a148c)]),
  'rose': CommunityPostBackground([Color(0xffe83e8c), Color(0xff9d174d)]),
};

CommunityPostBackground? communityPostBackground(String? value) =>
    value == null ? null : communityPostBackgrounds[value];

final _communityFormatPattern =
    RegExp(r'(\*\*|__)(.+?)\1|(?<!\w)_([^_\n]+?)_(?!\w)');

/// True when the body contains bold/italic markup or an @mention, i.e. when
/// it must render through [communityFormattedSpan] instead of plain text.
bool communityNeedsRichText(String body) =>
    body.contains('@') || _communityFormatPattern.hasMatch(body);

final RegExp _mentionWordChar = RegExp(r'\w', unicode: true);
final RegExp _mentionToken = RegExp(r'^\w+', unicode: true);

bool _mentionBoundary(String rest, int length) =>
    length >= rest.length || !_mentionWordChar.hasMatch(rest[length]);

/// End offset (exclusive, relative to [text]) of the mention starting at
/// [at], or -1 when that position does not start a mention. Matches the
/// longest known employee name, then `everyone`, and falls back to a single
/// `@word` token only while the directory has not loaded yet.
int _mentionEnd(String text, int at) {
  if (at > 0 && _mentionWordChar.hasMatch(text[at - 1])) return -1;
  final rest = text.substring(at + 1);
  if (rest.isEmpty || !_mentionWordChar.hasMatch(rest[0])) return -1;
  final lower = rest.toLowerCase();
  for (final name in MentionDirectory.names) {
    final value = name.toLowerCase();
    if (lower.startsWith(value) && _mentionBoundary(rest, value.length)) {
      return at + 1 + value.length;
    }
  }
  if (lower.startsWith('everyone') &&
      _mentionBoundary(rest, 'everyone'.length)) {
    return at + 1 + 'everyone'.length;
  }
  if (!MentionDirectory.isLoaded) {
    final token = _mentionToken.firstMatch(rest);
    if (token != null) return at + 1 + token.end;
  }
  return -1;
}

/// Called when the user taps an @mention in rendered post or comment text.
/// [name] is the mentioned name without the leading `@`.
typedef CommunityMentionTap = void Function(String name);

/// Splits [text] into plain and highlighted @mention spans. When
/// [onMentionTap] is given, each resolvable mention gets a
/// [TapGestureRecognizer] so it can be tapped to open that person's profile;
/// the recognizers are collected in [recognizers] so the caller can dispose
/// them with the widget.
List<InlineSpan> _mentionSpans(String text, TextStyle base, Color color,
    {CommunityMentionTap? onMentionTap,
    List<TapGestureRecognizer>? recognizers}) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  var index = text.indexOf('@');
  while (index != -1) {
    final end = _mentionEnd(text, index);
    if (end > 0) {
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      final mention = text.substring(index, end);
      final name = mention.substring(1);
      TapGestureRecognizer? recognizer;
      if (onMentionTap != null && name.toLowerCase() != 'everyone') {
        recognizer = TapGestureRecognizer()..onTap = () => onMentionTap(name);
        recognizers?.add(recognizer);
      }
      spans.add(TextSpan(
          text: mention,
          style: base.copyWith(color: color, fontWeight: FontWeight.w700),
          recognizer: recognizer));
      cursor = end;
      index = text.indexOf('@', end);
      continue;
    }
    index = text.indexOf('@', index + 1);
  }
  if (cursor == 0) return [TextSpan(text: text)];
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

TextSpan _styledChunk(String text, TextStyle base, Color mentionColor,
    {CommunityMentionTap? onMentionTap,
    List<TapGestureRecognizer>? recognizers}) {
  final parts = _mentionSpans(text, base, mentionColor,
      onMentionTap: onMentionTap, recognizers: recognizers);
  if (parts.length == 1) {
    final only = parts.first as TextSpan;
    if (only.children == null) {
      return TextSpan(
          text: only.text, style: base, recognizer: only.recognizer);
    }
  }
  return TextSpan(style: base, children: parts);
}

TextSpan communityFormattedSpan(String body, TextStyle style,
    {Color mentionColor = const Color(0xff2563eb),
    CommunityMentionTap? onMentionTap,
    List<TapGestureRecognizer>? recognizers}) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _communityFormatPattern.allMatches(body)) {
    if (match.start > cursor) {
      spans.addAll(_mentionSpans(
          body.substring(cursor, match.start), style, mentionColor,
          onMentionTap: onMentionTap, recognizers: recognizers));
    }
    if (match.group(1) != null) {
      spans.add(_styledChunk(match.group(2)!,
          style.copyWith(fontWeight: FontWeight.w800), mentionColor,
          onMentionTap: onMentionTap, recognizers: recognizers));
    } else {
      spans.add(_styledChunk(match.group(3)!,
          style.copyWith(fontStyle: FontStyle.italic), mentionColor,
          onMentionTap: onMentionTap, recognizers: recognizers));
    }
    cursor = match.end;
  }
  if (cursor < body.length) {
    spans.addAll(_mentionSpans(body.substring(cursor), style, mentionColor,
        onMentionTap: onMentionTap, recognizers: recognizers));
  }
  return TextSpan(style: style, children: spans);
}

/// Applies a reaction locally so the button and count respond immediately.
/// Callers roll back to the previous map if the server rejects the change.
Map<String, dynamic> communityOptimisticReaction(
    Map<String, dynamic> post, String? next) {
  final previous = post['my_reaction'] as String?;
  if (previous == next) return post;
  final reactions = Map<String, dynamic>.from(
      post['reactions'] is Map ? post['reactions'] as Map : const {});
  void decrement(String? key) {
    if (key == null) return;
    final remaining = ((reactions[key] as num?)?.toInt() ?? 1) - 1;
    if (remaining <= 0) {
      reactions.remove(key);
    } else {
      reactions[key] = remaining;
    }
  }

  if (previous != null) decrement(previous);
  if (next != null) {
    reactions[next] = ((reactions[next] as num?)?.toInt() ?? 0) + 1;
  }
  final count = (post['reactions_count'] as num?)?.toInt() ?? 0;
  final delta = (next == null ? 0 : 1) - (previous == null ? 0 : 1);
  return {
    ...post,
    'my_reaction': next,
    'reactions': reactions,
    'reactions_count': (count + delta).clamp(0, 1 << 31),
  };
}

class SocialPostComposer extends StatefulWidget {
  SocialPostComposer(
      {super.key,
      this.post,
      this.api,
      this.initialType = 'text',
      this.initialFiles = const [],
      this.autofocusBody = false});
  final List<PlatformFile> initialFiles;
  final String initialType;
  final bool autofocusBody;
  final CommunityApi? api;
  final Map<String, dynamic>? post;
  @override
  State<SocialPostComposer> createState() => _SocialPostComposerState();
}

class _SocialPostComposerState extends State<SocialPostComposer> {
  final _body = TextEditingController();
  final _bodyFocusNode = FocusNode();
  final _url = TextEditingController();
  final _audienceIds = TextEditingController();
  final _location = TextEditingController();
  final _pollQuestion = TextEditingController();
  final _pollClosesAt = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  Animation<double>? _routeAnimation;
  late final _api = widget.api ?? CommunityApi();
  String _type = 'text';
  String _visibility = 'company';
  bool _pollEnabled = false;
  bool _pollMultiple = false;
  bool _showAudience = false;
  bool _showMore = false;
  Map<String, dynamic>? _profile;
  PlatformFile? _file;
  List<PlatformFile> _files = [];
  Uint8List? _thumbnailBytes;
  int? _durationSeconds;
  double? _aspectRatio;
  bool _metadataLoading = false;
  bool _saving = false;
  bool _bodyEdited = false;
  String? _background;
  Timer? _draftTimer;
  String? _error;
  bool get _isShare => widget.post?['original_post_id'] != null;

  @override
  void initState() {
    super.initState();
    _body.text = '${widget.post?['body'] ?? ''}';
    _url.text = '${widget.post?['media_url'] ?? ''}';
    _type = '${widget.post?['media_type'] ?? widget.initialType}';
    _visibility = '${widget.post?['visibility'] ?? 'company'}';
    _location.text = '${widget.post?['location_name'] ?? ''}';
    final background = '${widget.post?['background'] ?? ''}';
    _background = background.isEmpty ? null : background;
    if (widget.initialFiles.isNotEmpty) {
      unawaited(_applyPickedFiles(widget.initialFiles, _type));
    }
    _loadComposerProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_handleRouteAnimation);
    if (animation?.status == AnimationStatus.completed) {
      _focusBodyWhenReady();
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) _focusBodyWhenReady();
  }

  void _focusBodyWhenReady() {
    if (mounted && widget.autofocusBody) {
      _requestTextKeyboard(context, _bodyFocusNode, _body);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _bodyFocusNode.dispose();
    _body.dispose();
    _url.dispose();
    _audienceIds.dispose();
    _location.dispose();
    _pollQuestion.dispose();
    _pollClosesAt.dispose();
    for (final option in _pollOptions) option.dispose();
    _draftTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadComposerProfile() async {
    try {
      final user = await Preferences().getUser();
      if (!mounted) return;
      var department = '';
      try {
        department = context.read<DashboardProvider>().department.trim();
      } catch (_) {}
      setState(() => _profile = {
            'name': user.name,
            'avatar': user.avatar,
            'department':
                department.isNotEmpty ? department : communityText('Employee'),
          });
      await _restoreDraft();
    } catch (error) { if (kDebugMode) debugPrint('Social feed: failed to restore draft: $error'); }
  }

  String get _draftKey => 'social_feed_draft_${widget.post?['id'] ?? 'new'}';

  Future<void> _restoreDraft() async {
    if (widget.post != null || _bodyEdited) return;
    final prefs = await SharedPreferences.getInstance();
    // The composer is already editable while preferences are loading. Keep a
    // draft restore from replacing text the user entered in that interval.
    if (!mounted || _bodyEdited) return;
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      final draft = jsonDecode(raw) as Map;
      setState(() {
        final restoredBody = '${draft['body'] ?? _body.text}';
        _body.value = TextEditingValue(
            text: restoredBody,
            selection: TextSelection.collapsed(offset: restoredBody.length));
        if (_files.isEmpty) _url.text = '${draft['media_url'] ?? _url.text}';
        _location.text = '${draft['location_name'] ?? _location.text}';
        _visibility = '${draft['visibility'] ?? _visibility}';
        if (draft.containsKey('background')) {
          final background = '${draft['background'] ?? ''}';
          _background = background.isEmpty ? null : background;
        }
        _pollEnabled = draft['poll_enabled'] == true;
        _pollMultiple = draft['poll_multiple'] == true;
        _pollQuestion.text = '${draft['poll_question'] ?? ''}';
        _pollClosesAt.text = '${draft['poll_closes_at'] ?? ''}';
        final options = (draft['poll_options'] as List? ?? []);
        while (
            _pollOptions.length < options.length && _pollOptions.length < 6) {
          _pollOptions.add(TextEditingController());
        }
        for (var i = 0; i < options.length && i < _pollOptions.length; i++) {
          _pollOptions[i].text = '${options[i]}';
        }
      });
    } catch (_) {}
  }

  Future<void> _writeDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _draftKey,
        jsonEncode({
          'body': _body.text,
          'media_url': _url.text,
          'location_name': _location.text,
          'visibility': _visibility,
          'background': _background,
          'poll_enabled': _pollEnabled,
          'poll_multiple': _pollMultiple,
          'poll_question': _pollQuestion.text,
          'poll_closes_at': _pollClosesAt.text,
          'poll_options': _pollOptions.map((item) => item.text).toList(),
        }));
  }

  void _scheduleDraftSave() {
    if (widget.post != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), _writeDraft);
  }

  Future<void> _saveDraft() async {
    _draftTimer?.cancel();
    await _writeDraft();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(communityText('Draft saved on this device.'))));
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _pickEmoji() async {
    const emojis = [
      '😀',
      '😂',
      '😍',
      '🥳',
      '👍',
      '👏',
      '🎉',
      '❤️',
      '🙏',
      '💡',
      '🔥',
      '✨'
    ];
    final emoji = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: context._communitySurface,
        builder: (context) => SafeArea(
              child: GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                padding: const EdgeInsets.all(18),
                children: [
                  for (final item in emojis)
                    InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Center(
                            child: Text(item,
                                style: const TextStyle(fontSize: 28))))
                ],
              ),
            ));
    if (emoji != null && mounted) _insertAtCursor(emoji);
  }

  Future<void> _chooseLocation() async {
    final value = await _showCommunityDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: _location.text);
          return AlertDialog(
              title: Text(communityText('Add location')),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: communityText('Office, city or event'),
                      prefixIcon: const Icon(Icons.location_on_outlined))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(communityText('Cancel'))),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: Text(communityText('Add'))),
              ]);
        });
    if (value != null && mounted) {
      setState(() => _location.text = value);
      _scheduleDraftSave();
    }
  }

  Future<void> _pick([String? overrideType]) async {
    final type = overrideType ?? (_type == 'text' ? 'image' : _type);
    _bodyFocusNode.unfocus();
    try {
      final files = type == 'image' || type == 'video'
          ? await pickCommunityMedia(context, type, multiple: type == 'image')
          : (await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx']))
                  ?.files ??
              [];
      if (!mounted || files.isEmpty) return;
      await _applyPickedFiles(files, type);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    }
  }

  Future<void> _applyPickedFiles(List<PlatformFile> files, String type,
      {bool append = false}) async {
    final max = (type == 'image'
            ? 10
            : type == 'document'
                ? 25
                : 100) *
        1024 *
        1024;
    if (files.any((file) => file.size > max || file.path == null)) {
      setState(() => _error = communityText(type == 'image'
          ? 'Select a 10 MB or smaller file.'
          : type == 'document'
              ? 'Select a 25 MB or smaller file.'
              : 'Select a 100 MB or smaller file.'));
      return;
    }
    final next =
        append && _type == type ? <PlatformFile>[..._files, ...files] : files;
    final unique = <String, PlatformFile>{};
    for (final file in next) {
      unique[file.path ?? file.name] = file;
    }
    final selected = unique.values.take(10).toList();
    final tooMany = type == 'image' && unique.length > 10;
    setState(() {
      _type = type;
      if (type != 'text') _background = null;
      _files = selected;
      _file = selected.length == 1 ? selected.first : null;
      _thumbnailBytes = null;
      _durationSeconds = null;
      _aspectRatio = null;
      _metadataLoading = type == 'video' && selected.length == 1;
      if (!append) _url.clear();
      _error = tooMany ? communityText('You can add up to 10 photos.') : null;
    });
    _scheduleDraftSave();
    if (_metadataLoading) await _prepareVideoMetadata(selected.first);
  }

  Future<void> _prepareVideoMetadata(PlatformFile file) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
          video: file.path!,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 1280,
          quality: 84);
      int? duration;
      double? aspectRatio;
      final controller = VideoPlayerController.file(File(file.path!));
      try {
        await controller.initialize();
        duration = controller.value.duration.inSeconds;
        final value = controller.value.aspectRatio;
        if (value.isFinite && value > 0) aspectRatio = value;
      } finally {
        await controller.dispose();
      }
      if (!mounted || _type != 'video' || _file?.path != file.path) return;
      setState(() {
        _thumbnailBytes = bytes;
        _durationSeconds = duration;
        _aspectRatio = aspectRatio;
        _metadataLoading = false;
      });
    } catch (_) {
      if (mounted && _type == 'video' && _file?.path == file.path)
        setState(() => _metadataLoading = false);
    }
  }

  String? _mime() {
    return _extensionMime(_file?.extension);
  }

  String? _extensionMime(String? extension) {
    return {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    }[extension?.toLowerCase()];
  }

  Future<void> _save() async {
    if (_saving) return;
    final pollReady = _pollEnabled && _pollQuestion.text.trim().isNotEmpty;
    if (!_isShare &&
        _type == 'text' &&
        _body.text.trim().isEmpty &&
        !pollReady) {
      setState(() => _error = communityText('Write a message.'));
      return;
    }
    if (!_isShare &&
        _type != 'text' &&
        _url.text.trim().isEmpty &&
        _files.isEmpty) {
      setState(
          () => _error = communityText('Add a media URL or upload a file.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_metadataLoading) {
      setState(() {
        _saving = false;
        _error = communityText(
            'Preparing the video preview. Please try again in a moment.');
      });
      return;
    }
    try {
      final payload = <String, dynamic>{
        'body': _body.text.trim(),
        'media_type': _type,
        if (_type == 'text' && _background != null) 'background': _background,
        'media_url': _url.text.trim(),
        'location_name': _location.text.trim(),
        if (_type == 'video' && _durationSeconds != null)
          'duration_seconds': _durationSeconds,
        if (_type == 'video' && _aspectRatio != null)
          'aspect_ratio': _aspectRatio,
      };
      if (_visibility != 'company') {
        payload['visibility'] = _visibility;
        final ids = _audienceIds.text
            .split(',')
            .map((value) => int.tryParse(value.trim()))
            .whereType<int>()
            .toList();
        if (_visibility == 'department') {
          payload['audience_department_ids'] = ids;
        } else if (_visibility == 'employees') {
          payload['audience_user_ids'] = ids;
        }
      }
      if (_pollEnabled) {
        final options = _pollOptions
            .map((option) => option.text.trim())
            .where((option) => option.isNotEmpty)
            .toList();
        if (_pollQuestion.text.trim().isEmpty || options.length < 2) {
          setState(() => _error =
              communityText('Add a poll question and at least two options.'));
          return;
        }
        payload['poll_question'] = _pollQuestion.text.trim();
        payload['poll_options'] = options;
        payload['poll_allow_multiple'] = _pollMultiple;
        if (_pollClosesAt.text.trim().isNotEmpty) {
          final closesAt = DateTime.tryParse(_pollClosesAt.text.trim());
          payload['poll_closes_at'] =
              closesAt?.toUtc().toIso8601String() ?? _pollClosesAt.text.trim();
        }
      }
      final endpoint = widget.post == null
          ? 'social-feed'
          : 'social-feed/${widget.post!['id']}';
      final filePath = _files.length == 1 ? _file?.path : null;
      final fileMime = _files.length == 1 ? _mime() : null;
      final filePaths =
          _files.length > 1 ? _files.map((file) => file.path!).toList() : null;
      final fileMimes = _files.length > 1
          ? _files
              .map((file) =>
                  _extensionMime(file.extension) ?? 'application/octet-stream')
              .toList()
          : null;
      if (_thumbnailBytes != null) {
        await _api.requestWithThumbnail('POST', endpoint,
            data: payload,
            filePath: filePath,
            fileMime: fileMime,
            filePaths: filePaths,
            fileMimes: fileMimes,
            thumbnailBytes: _thumbnailBytes,
            thumbnailFileName: 'post-thumbnail.jpg',
            thumbnailMime: 'image/jpeg');
      } else {
        await _api.request('POST', endpoint,
            data: payload,
            filePath: filePath,
            fileMime: fileMime,
            filePaths: filePaths,
            fileMimes: fileMimes);
      }
      _draftTimer?.cancel();
      await _clearDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _visibilityLabel() {
    switch (_visibility) {
      case 'department':
        return communityText('Specific departments');
      case 'employees':
        return communityText('Selected employees');
      case 'management':
        return communityText('Management only');
      case 'hr':
        return communityText('HR only');
      default:
        return communityText('All company employees');
    }
  }

  Color get _composerInk => context._communityColors.onSurface;
  Color get _composerMuted => context._communityColors.onSurfaceVariant;
  Color get _composerLine => context._communityColors.outlineVariant;
  Color get _composerWash => context._communityColors.surfaceContainerHigh;

  bool get _hasContent =>
      _body.text.trim().isNotEmpty ||
      _files.isNotEmpty ||
      _url.text.trim().isNotEmpty ||
      _location.text.isNotEmpty ||
      _background != null ||
      _pollEnabled;

  Future<void> _closeComposer() async {
    if (_saving) return;
    if (!_hasContent) {
      _draftTimer?.cancel();
      await _clearDraft();
      if (mounted) Navigator.maybePop(context);
      return;
    }
    final discard = await _showCommunityDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(communityText('Discard post?')),
                content: Text(communityText(
                    'If you leave now, your changes will be lost.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(communityText('Keep editing'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(communityText('Discard')))
                ]));
    if (discard == true && mounted) {
      _draftTimer?.cancel();
      await _clearDraft();
      if (mounted) Navigator.maybePop(context);
    }
  }

  Future<void> _choosePollClose() async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_pollClosesAt.text.trim())?.toLocal();
    final initial = parsed != null && parsed.isAfter(now)
        ? parsed
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
        context: context,
        initialDate: DateUtils.dateOnly(initial),
        firstDate: DateUtils.dateOnly(now),
        lastDate: DateTime(now.year + 1, now.month, now.day),
        helpText: communityText('Poll ends'));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: communityText('Poll ends'));
    if (!mounted) return;
    final chosen = DateTime(
        date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59);
    if (!chosen.isAfter(DateTime.now())) {
      setState(() =>
          _error = communityText('Choose an end date and time in the future.'));
      return;
    }
    String two(int value) => value.toString().padLeft(2, '0');
    setState(() {
      _error = null;
      _pollClosesAt.text =
          '${chosen.year}-${two(chosen.month)}-${two(chosen.day)} ${two(chosen.hour)}:${two(chosen.minute)}';
    });
    _scheduleDraftSave();
  }

  void _wrapSelection(String before, String after) {
    final value = _body.value;
    final text = value.text;
    final start = value.selection.start;
    final end = value.selection.end;
    if (start < 0 || end < 0) {
      _insertAtCursor('$before$after');
      return;
    }
    if (start == end) {
      _body.value = value.copyWith(
          text: text.replaceRange(start, end, '$before$after'),
          selection: TextSelection.collapsed(offset: start + before.length));
    } else {
      final selected = text.substring(start, end);
      _body.value = value.copyWith(
          text: text.replaceRange(start, end, '$before$selected$after'),
          selection: TextSelection.collapsed(
              offset: start + before.length + selected.length + after.length));
    }
    _bodyEdited = true;
    setState(() {});
    _scheduleDraftSave();
  }

  void _insertAtCursor(String value) {
    final selection = _body.selection;
    final offset = selection.isValid
        ? selection.baseOffset.clamp(0, _body.text.length).toInt()
        : _body.text.length;
    _body.value = _body.value.copyWith(
        text: _body.text.replaceRange(offset, offset, value),
        selection: TextSelection.collapsed(offset: offset + value.length));
    _bodyEdited = true;
    setState(() {});
    _scheduleDraftSave();
  }

  void _setVisibility(String value) {
    setState(() => _visibility = value);
    _scheduleDraftSave();
  }

  void _addPollOption() {
    if (_pollOptions.length >= 6) return;
    setState(() => _pollOptions.add(TextEditingController()));
    _scheduleDraftSave();
  }

  void _removePollOption(int index) {
    if (_pollOptions.length <= 2) return;
    final controller = _pollOptions[index];
    setState(() => _pollOptions.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    _scheduleDraftSave();
  }

  void _removeFile(int index) {
    final files = List<PlatformFile>.of(_files)..removeAt(index);
    setState(() {
      _files = files;
      _file = files.length == 1 ? files.first : null;
      _thumbnailBytes = null;
      _durationSeconds = null;
      _aspectRatio = null;
      _metadataLoading = false;
      if (files.isEmpty) {
        _type = 'text';
        _url.clear();
      }
    });
    _scheduleDraftSave();
  }

  Future<void> _addMoreImages() async {
    _bodyFocusNode.unfocus();
    try {
      final files = await pickCommunityMedia(context, 'image',
          multiple: true, maxSelection: 10);
      if (!mounted || files.isEmpty) return;
      await _applyPickedFiles(files, 'image', append: true);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    }
  }

  IconData _audienceIcon() {
    switch (_visibility) {
      case 'department':
        return Icons.apartment_rounded;
      case 'employees':
        return Icons.group_rounded;
      case 'management':
        return Icons.verified_user_outlined;
      case 'hr':
        return Icons.badge_outlined;
      default:
        return Icons.public;
    }
  }

  Widget _errorCard() {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    final colors = context._communityColors;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant)),
        child: Row(children: [
          Icon(Icons.error_outline_rounded,
              color: colors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(error,
                  style: TextStyle(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)))
        ]));
  }

  Widget _headerCard(String name, String avatar, Color primary) {
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              CircleAvatar(
                  radius: 25,
                  backgroundColor: primary.withValues(alpha: .12),
                  backgroundImage:
                      avatar.isNotEmpty ? communityAvatarImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Icon(Icons.person, color: primary, size: 26)
                      : null),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _composerInk)),
                    const SizedBox(height: 4),
                    Material(
                        color: _composerWash,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _saving
                                ? null
                                : () => setState(
                                    () => _showAudience = !_showAudience),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_audienceIcon(),
                                          size: 15, color: _composerInk),
                                      const SizedBox(width: 5),
                                      Flexible(
                                          child: Text(_visibilityLabel(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _composerInk))),
                                      Icon(Icons.arrow_drop_down,
                                          size: 18, color: _composerInk)
                                    ]))))
                  ])),
              if (_isShare)
                Chip(
                    label: Text(communityText('Share'),
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact)
            ])));
  }

  Widget _textCard(Color primary) {
    final background = communityPostBackground(_background);
    final foreground = background?.foreground ?? _composerInk;
    final muted = background == null ? _composerMuted : Colors.white70;
    final canSetBackground = _type == 'text' && _files.isEmpty;
    return Container(
        decoration: BoxDecoration(
            color: background == null ? context._communitySurface : null,
            gradient: background == null
                ? null
                : LinearGradient(
                    colors: background.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    background == null ? _composerLine : Colors.transparent)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            child: Column(children: [
              MentionField(
                  controller: _body,
                  focusNode: _bodyFocusNode,
                  enabled: !_saving,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 10000,
                  autofocus: false,
                  onTap: () =>
                      _requestTextKeyboard(context, _bodyFocusNode, _body),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: background == null ? primary : Colors.white,
                  style:
                      TextStyle(color: foreground, fontSize: 20, height: 1.34),
                  onChanged: (_) {
                    _bodyEdited = true;
                    _scheduleDraftSave();
                  },
                  decoration: InputDecoration(
                      hintText: communityText("What's on your mind?"),
                      hintStyle: TextStyle(color: muted, fontSize: 20),
                      border: InputBorder.none,
                      counterText: '')),
              if (canSetBackground) _backgroundPicker(foreground),
              Row(children: [
                IconButton(
                    tooltip: communityText('Emoji'),
                    onPressed: _saving ? null : _pickEmoji,
                    icon: Icon(Icons.emoji_emotions_outlined,
                        color: background == null ? primary : Colors.white)),
                IconButton(
                    tooltip: communityText('Bold'),
                    onPressed:
                        _saving ? null : () => _wrapSelection('**', '**'),
                    icon: Icon(Icons.format_bold_rounded, color: foreground)),
                IconButton(
                    tooltip: communityText('Italic'),
                    onPressed: _saving ? null : () => _wrapSelection('_', '_'),
                    icon: Icon(Icons.format_italic_rounded, color: foreground)),
                const Spacer(),
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _body,
                        builder: (_, value, __) => Text(
                            '${value.text.length}/10000',
                            style: TextStyle(color: muted, fontSize: 12))))
              ])
            ])));
  }

  Widget _backgroundPicker(Color foreground) {
    return SizedBox(
        height: 48,
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _backgroundSwatch(null, foreground),
              for (final entry in communityPostBackgrounds.entries)
                _backgroundSwatch(entry.key, foreground),
            ])));
  }

  Widget _backgroundSwatch(String? value, Color foreground) {
    final selected = _background == value;
    final background = communityPostBackground(value);
    return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 6),
        child: Semantics(
            button: true,
            selected: selected,
            label: value == null
                ? communityText('No background')
                : '${communityText('Background')} $value',
            child: Tooltip(
                message: value == null
                    ? communityText('No background')
                    : '${communityText('Background')} $value',
                child: InkWell(
                    key: ValueKey('post-background-${value ?? 'none'}'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: _saving
                        ? null
                        : () {
                            setState(() => _background = value);
                            _scheduleDraftSave();
                          },
                    child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: background == null
                                ? context._communitySurface
                                : null,
                            gradient: background == null
                                ? null
                                : LinearGradient(
                                    colors: background.colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            border: Border.all(
                                color: selected
                                    ? (background == null
                                        ? _composerInk
                                        : foreground)
                                    : _composerLine,
                                width: selected ? 3 : 1)),
                        child: Center(
                            child: background == null
                                ? Icon(Icons.format_color_reset_outlined,
                                    size: 15, color: _composerMuted)
                                : selected
                                    ? Icon(Icons.check_rounded,
                                        size: 16, color: background.foreground)
                                    : Text('Aa',
                                        style: TextStyle(
                                            color: background.foreground,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800))))))));
  }

  Widget _singleMedia(PlatformFile file, Color primary) {
    final isImage = _type == 'image';
    final isVideo = _type == 'video';
    final media = isVideo && _thumbnailBytes != null
        ? Image.memory(_thumbnailBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
                color: _composerWash,
                child: Icon(Icons.videocam_outlined,
                    color: _composerMuted, size: 42)))
        : isImage
            ? Image.file(File(file.path!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                    color: _composerWash,
                    child: Icon(Icons.image_outlined,
                        color: _composerMuted, size: 42)))
            : ColoredBox(
                color: _composerWash,
                child: Icon(Icons.description_outlined,
                    color: _composerMuted, size: 42));
    return Stack(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
              height: 210,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                media,
                if (isVideo) const ColoredBox(color: Colors.black26),
                if (isVideo)
                  const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 56)),
                if (isVideo && _durationSeconds != null)
                  Positioned(
                      right: 10,
                      bottom: 10,
                      child: _StoryDurationBadge(seconds: _durationSeconds!)),
                Positioned(
                    left: 10,
                    right: 44,
                    bottom: 10,
                    child: Text(file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black54)
                            ])))
              ]))),
      Positioned(
          right: 6,
          top: 6,
          child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                  tooltip: communityText('Remove'),
                  onPressed: _saving ? null : () => _removeFile(0),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 18))))
    ]);
  }

  Widget _mediaGrid(Color primary) {
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _files.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemBuilder: (context, index) {
          final file = _files[index];
          return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(File(file.path!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                        color: _composerWash,
                        child:
                            Icon(Icons.image_outlined, color: _composerMuted))),
                Positioned(
                    left: 3,
                    right: 3,
                    bottom: 3,
                    child: Text(file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 3, color: Colors.black87)
                            ]))),
                Positioned(
                    right: 2,
                    top: 2,
                    child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _saving ? null : () => _removeFile(index),
                            child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.white, size: 15)))))
              ]));
        });
  }

  Widget _mediaCard(Color primary) {
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_files.isEmpty)
                TextField(
                    controller: _url,
                    enabled: !_saving,
                    style: TextStyle(color: _composerInk, fontSize: 14),
                    onChanged: (_) {
                      setState(() {});
                      _scheduleDraftSave();
                    },
                    decoration: InputDecoration(
                        labelText: communityText('Paste a link or video URL'),
                        labelStyle: TextStyle(color: _composerMuted),
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: const OutlineInputBorder()))
              else if (_files.length == 1)
                _singleMedia(_files.first, primary)
              else
                _mediaGrid(primary),
              if (_type == 'image' && _files.isNotEmpty)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: _saving ? null : _addMoreImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(communityText('Add more photos')))),
              if (_type == 'video' && _metadataLoading)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator())
            ])));
  }

  Widget _composeActionsCard(Color primary) {
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(communityText('Add to your post'),
                  style: TextStyle(
                      color: _composerInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                  height: 78,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _actionTile(
                        icon: Icons.photo_library_rounded,
                        color: const Color(0xff45bd62),
                        label: communityText('Photo'),
                        onTap: _saving ? null : () => _pick('image')),
                    const SizedBox(width: 6),
                    _actionTile(
                        icon: Icons.videocam_rounded,
                        color: const Color(0xfff3425f),
                        label: communityText('Video'),
                        onTap: _saving ? null : () => _pick('video')),
                    const SizedBox(width: 6),
                    _actionTile(
                        icon: Icons.emoji_emotions_outlined,
                        color: const Color(0xfff7b928),
                        label: communityText('Emoji'),
                        onTap: _saving ? null : _pickEmoji),
                    const SizedBox(width: 6),
                    _actionTile(
                        icon: Icons.location_on_rounded,
                        color: const Color(0xfff5533d),
                        label: communityText('Location'),
                        onTap: _saving ? null : _chooseLocation),
                    const SizedBox(width: 6),
                    _actionTile(
                        icon: Icons.poll_rounded,
                        color: primary,
                        label: communityText('Poll'),
                        onTap: _saving
                            ? null
                            : () =>
                                setState(() => _pollEnabled = !_pollEnabled)),
                    const SizedBox(width: 6),
                    _actionTile(
                        icon: Icons.more_horiz_rounded,
                        color: _composerMuted,
                        label: communityText('More'),
                        onTap: _saving
                            ? null
                            : () => setState(() => _showMore = !_showMore))
                  ]))
            ])));
  }

  Widget _moreCard(Color primary) {
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                  leading: Icon(Icons.attach_file_rounded, color: primary),
                  title: Text(communityText('Add a document'),
                      style: TextStyle(
                          color: _composerInk, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      communityText('PDF, Word or Excel up to 25 MB'),
                      style: TextStyle(color: _composerMuted, fontSize: 12)),
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: _composerMuted),
                  onTap: _saving ? null : () => _pick('document')),
              if (_location.text.isNotEmpty)
                ListTile(
                    leading: const Icon(Icons.location_on_outlined,
                        color: Color(0xfff5533d)),
                    title: Text(_location.text,
                        style: TextStyle(
                            color: _composerInk, fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                        tooltip: communityText('Remove'),
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() => _location.clear());
                                _scheduleDraftSave();
                              },
                        icon: const Icon(Icons.close_rounded)))
            ])));
  }

  Widget _pollCard(Color primary) {
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Icon(Icons.poll_rounded, color: primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(communityText('Create a poll'),
                        style: TextStyle(
                            color: _composerInk, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: communityText('Remove'),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _pollEnabled = false),
                    icon: Icon(Icons.close_rounded, color: _composerMuted))
              ]),
              TextField(
                  controller: _pollQuestion,
                  enabled: !_saving,
                  maxLength: 500,
                  style: TextStyle(color: _composerInk),
                  onChanged: (_) {
                    setState(() {});
                    _scheduleDraftSave();
                  },
                  decoration: InputDecoration(
                      labelText: communityText('Poll question'),
                      labelStyle: TextStyle(color: _composerMuted),
                      counterText: '',
                      border: const OutlineInputBorder())),
              for (var index = 0; index < _pollOptions.length; index++)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _pollOptions[index],
                              enabled: !_saving,
                              maxLength: 160,
                              style: TextStyle(color: _composerInk),
                              onChanged: (_) => _scheduleDraftSave(),
                              decoration: InputDecoration(
                                  labelText:
                                      '${communityText('Option')} ${index + 1}',
                                  labelStyle: TextStyle(color: _composerMuted),
                                  counterText: '',
                                  border: const OutlineInputBorder()))),
                      if (_pollOptions.length > 2)
                        IconButton(
                            tooltip: communityText('Remove'),
                            onPressed:
                                _saving ? null : () => _removePollOption(index),
                            icon: Icon(Icons.remove_circle_outline,
                                color: _composerMuted))
                    ])),
              if (_pollOptions.length < 6)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: _saving ? null : _addPollOption,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(communityText('Add option')))),
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(communityText('Allow multiple answers'),
                      style: TextStyle(
                          color: _composerInk, fontWeight: FontWeight.w600)),
                  value: _pollMultiple,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _pollMultiple = value)),
              TextField(
                  controller: _pollClosesAt,
                  enabled: !_saving,
                  readOnly: true,
                  onTap: _saving ? null : _choosePollClose,
                  style: TextStyle(color: _composerInk, fontSize: 13),
                  decoration: InputDecoration(
                      labelText: communityText('Poll ends'),
                      hintText: communityText('Choose an end date and time'),
                      labelStyle: TextStyle(color: _composerMuted),
                      helperText: communityText('Optional'),
                      helperStyle: TextStyle(color: _composerMuted),
                      suffixIcon: _pollClosesAt.text.isEmpty
                          ? Icon(Icons.event_outlined, color: _composerMuted)
                          : IconButton(
                              tooltip: communityText('Clear'),
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() => _pollClosesAt.clear());
                                      _scheduleDraftSave();
                                    },
                              icon: Icon(Icons.close_rounded,
                                  color: _composerMuted)),
                      border: const OutlineInputBorder()))
            ])));
  }

  Widget _visibilityOption(String value, IconData icon, String title,
      String subtitle, Color primary) {
    final selected = _visibility == value;
    return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: selected ? primary : _composerMuted),
        title: Text(title,
            style: TextStyle(
                color: _composerInk,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: _composerMuted, fontSize: 12)),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: primary, size: 20)
            : null,
        onTap: _saving ? null : () => _setVisibility(value));
  }

  Widget _audienceCard(Color primary) {
    if (!_showAudience) return const SizedBox.shrink();
    return Card(
        elevation: 0,
        color: context._communitySurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _composerLine)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(communityText('Who can see your post?'),
                  style: TextStyle(
                      color: _composerInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 4),
              _visibilityOption(
                  'company',
                  Icons.public,
                  communityText('All company employees'),
                  communityText('Anyone in your company can see this post'),
                  primary),
              _visibilityOption(
                  'department',
                  Icons.apartment_rounded,
                  communityText('Specific departments'),
                  communityText('Only people in selected departments'),
                  primary),
              _visibilityOption(
                  'employees',
                  Icons.group_rounded,
                  communityText('Selected employees'),
                  communityText('Only the people you choose'),
                  primary),
              _visibilityOption(
                  'management',
                  Icons.verified_user_outlined,
                  communityText('Management only'),
                  communityText('Managers and company leadership'),
                  primary),
              _visibilityOption(
                  'hr',
                  Icons.badge_outlined,
                  communityText('HR only'),
                  communityText('HR team members only'),
                  primary),
              if (_visibility == 'department' || _visibility == 'employees')
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                        controller: _audienceIds,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _composerInk),
                        onChanged: (_) => _scheduleDraftSave(),
                        decoration: InputDecoration(
                            labelText:
                                communityText('Audience IDs (comma separated)'),
                            labelStyle: TextStyle(color: _composerMuted),
                            border: const OutlineInputBorder())))
            ])));
  }

  Widget _actionTile(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback? onTap}) {
    return SizedBox(
        width: 84,
        child: Material(
            color: _composerWash,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: color, size: 26),
                      const SizedBox(height: 5),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _composerInk,
                              fontWeight: FontWeight.w700,
                              fontSize: 12))
                    ])))));
  }

  ThemeData _composerTheme(BuildContext context) {
    final base = Theme.of(context);
    final colors = base.colorScheme;
    final primary = colors.onPrimaryContainer;
    return base.copyWith(
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primary)),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: colors.outline))),
        inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: _composerMuted),
            hintStyle: TextStyle(color: _composerMuted),
            helperStyle: TextStyle(color: _composerMuted),
            counterStyle: TextStyle(color: _composerMuted),
            prefixIconColor: _composerMuted,
            suffixIconColor: _composerMuted),
        textSelectionTheme: TextSelectionThemeData(
            cursorColor: primary,
            selectionColor: primary.withValues(alpha: .22),
            selectionHandleColor: primary));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context._communityColors;
    final primary = colors.onPrimaryContainer;
    final name = '${_profile?['name'] ?? communityText('Your name')}';
    final avatar = '${_profile?['avatar'] ?? ''}';
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            backgroundColor: context._communityPage,
            appBar: AppBar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: primary,
                iconTheme: IconThemeData(color: primary),
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                    tooltip: communityText('Back'),
                    onPressed: _saving ? null : _closeComposer,
                    icon: const Icon(Icons.close_rounded)),
                centerTitle: true,
                title: Text(
                    widget.post == null
                        ? communityText('Create post')
                        : communityText('Edit post'),
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                actions: [
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: TextButton(
                          onPressed: _saving ? null : _save,
                          style: TextButton.styleFrom(
                              foregroundColor: colors.onSecondaryContainer,
                              backgroundColor: colors.secondaryContainer,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16)),
                          child: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onSecondaryContainer))
                              : Text(
                                  widget.post == null
                                      ? communityText('Publish post')
                                      : communityText('Save changes'),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800))))
                ]),
            body: Theme(
                data: _composerTheme(context),
                child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(12, 12, 12,
                        24 + MediaQuery.viewInsetsOf(context).bottom),
                    children: [
                      if (_error != null) _errorCard(),
                      _headerCard(name, avatar, primary),
                      const SizedBox(height: 10),
                      _textCard(primary),
                      if (_type != 'text') ...[
                        const SizedBox(height: 10),
                        _mediaCard(primary),
                      ],
                      const SizedBox(height: 10),
                      _composeActionsCard(primary),
                      if (_showMore) ...[
                        const SizedBox(height: 10),
                        _moreCard(primary),
                      ],
                      if (_showAudience) ...[
                        const SizedBox(height: 10),
                        _audienceCard(primary),
                      ],
                      if (_pollEnabled) ...[
                        const SizedBox(height: 10),
                        _pollCard(primary),
                      ],
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: _saving ? null : _saveDraft,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(communityText('Save draft')))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextButton.icon(
                                onPressed: _saving ? null : _closeComposer,
                                icon: const Icon(Icons.close_rounded),
                                label: Text(communityText('Discard'))))
                      ])
                    ]))));
  }
}

class _ExpandableCommentText extends StatefulWidget {
  const _ExpandableCommentText(
      {super.key, required this.text, this.onMentionTap});
  final String text;

  /// Tapping a rendered @mention opens that person's profile.
  final CommunityMentionTap? onMentionTap;
  @override
  State<_ExpandableCommentText> createState() => _ExpandableCommentTextState();
}

class _ExpandableCommentTextState extends State<_ExpandableCommentText> {
  static const _style = TextStyle(fontSize: 16, height: 1.18);
  static const _maxLines = 4;
  bool _expanded = false;

  /// Recognizers created for the @mention spans of the current build, disposed
  /// whenever the text is rebuilt or the widget goes away.
  final List<TapGestureRecognizer> _mentionTaps = [];

  @override
  void dispose() {
    _disposeMentionTaps();
    super.dispose();
  }

  void _disposeMentionTaps() {
    for (final recognizer in _mentionTaps) {
      recognizer.dispose();
    }
    _mentionTaps.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeMentionTaps();
    final span = communityNeedsRichText(widget.text)
        ? communityFormattedSpan(widget.text, _style,
            mentionColor: context._communityColors.primary,
            onMentionTap: widget.onMentionTap,
            recognizers: _mentionTaps)
        : TextSpan(text: widget.text, style: _style);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: span,
        maxLines: _maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      if (!overflows) {
        return Text.rich(span);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text.rich(
              span,
              maxLines: _expanded ? null : _maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _expanded
                    ? communityText('See less')
                    : communityText('See more'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context._communityColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class SocialCommentsScreen extends StatefulWidget {
  SocialCommentsScreen(
      {super.key,
      required this.postId,
      this.api,
      this.reactionsCount = 0,
      this.commentsCount = 0,
      this.sharesCount = 0});
  final CommunityApi? api;
  final int postId;
  final int reactionsCount;
  final int commentsCount;
  final int sharesCount;
  @override
  State<SocialCommentsScreen> createState() => _SocialCommentsScreenState();
}

class _SocialCommentsScreenState extends State<SocialCommentsScreen> {
  late final _api = widget.api ?? CommunityApi();
  final _text = TextEditingController();
  final _composerFocus = FocusNode();
  final List<Map<String, dynamic>> _comments = [];
  bool _loading = false;
  bool _sending = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  int? _replyParent;
  double _dragOffset = 0;
  bool _dragging = false;
  @override
  void initState() {
    super.initState();
    unawaited(MentionDirectory.ensureLoaded());
    _load(reset: true);
  }

  @override
  void dispose() {
    _api.dispose();
    _composerFocus.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = reset ? 1 : _page + 1;
      final response = await _api.request(
          'GET', 'social-feed/${widget.postId}/comments?page=$page');
      if (!mounted) return;
      setState(() {
        if (reset) _comments.clear();
        _comments.addAll((response['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map)));
        _page = page;
        _hasMore = response['next_page_url'] != null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{'body': _text.text.trim()};
      if (_replyParent != null) payload['parent_id'] = _replyParent;
      await _api.request('POST', 'social-feed/${widget.postId}/comments',
          data: payload);
      if (!mounted) return;
      _text.clear();
      setState(() => _replyParent = null);
      if (mounted) await _load(reset: true);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> comment) async {
    final controller = TextEditingController(text: '${comment['body'] ?? ''}');
    final value = await _showCommunityDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(communityText('Edit comment')),
              content: MentionField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 2000,
                  maxPanelHeight: 160),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(communityText('Cancel'))),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: Text(communityText('Save')))
              ],
            ));
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    try {
      final response = await _api.request(
          'PUT', 'social-feed/${widget.postId}/comments/${comment['id']}',
          data: {'body': value});
      if (mounted && response['data'] is Map) {
        final index =
            _comments.indexWhere((item) => item['id'] == comment['id']);
        if (index >= 0)
          setState(() => _comments[index] =
              Map<String, dynamic>.from(response['data'] as Map));
      }
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    }
  }

  Future<void> _loadReplies(Map<String, dynamic> comment) async {
    try {
      final response = await _api.request('GET',
          'social-feed/${widget.postId}/comments/${comment['id']}/replies');
      if (mounted) {
        setState(() => comment['replies'] = (response['data'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList());
      }
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    final confirm = await _showCommunityDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(communityText('Delete your comment?')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(communityText('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(communityText('Delete')))
                ]));
    if (confirm != true || !mounted) return;
    try {
      await _api.request(
          'DELETE', 'social-feed/${widget.postId}/comments/${comment['id']}');
      if (mounted)
        setState(
            () => _comments.removeWhere((item) => item['id'] == comment['id']));
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    }
  }

  Future<void> _reactComment(
      Map<String, dynamic> comment, String? reaction) async {
    try {
      final response = await _api.request('PUT',
          'social-feed/${widget.postId}/comments/${comment['id']}/reaction',
          data: {'reaction': reaction});
      if (!mounted || response['data'] is! Map) return;
      final index = _comments.indexWhere((item) => item['id'] == comment['id']);
      if (index >= 0) {
        setState(() => _comments[index] =
            Map<String, dynamic>.from(response['data'] as Map));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    }
  }

  Future<void> _chooseCommentReaction(Map<String, dynamic> comment) async {
    final reaction = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: context._communitySurface,
        builder: (context) => SafeArea(
              child:
                  Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                for (final entry in communityReactions.entries)
                  InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, entry.key),
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(entry.value,
                                style: const TextStyle(fontSize: 28)),
                            Text(communityText(entry.key),
                                style: const TextStyle(fontSize: 11))
                          ]))),
                if (comment['my_reaction'] != null)
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'remove'),
                      child: Text(communityText('Remove reaction')))
              ]),
            ));
    if (!mounted || reaction == null) return;
    await _reactComment(comment, reaction == 'remove' ? null : reaction);
  }

  Widget _commentAvatar(Map<String, dynamic> comment, {double radius = 21}) {
    final author = comment['author'] as Map?;
    final avatar = '${author?['avatar'] ?? ''}';
    return CircleAvatar(
        radius: radius,
        backgroundColor: context._communityColors.secondaryContainer,
        backgroundImage:
            avatar.isNotEmpty ? communityAvatarImage(avatar) : null,
        child: avatar.isEmpty
            ? Icon(Icons.person_outline_rounded,
                color: context._communityColors.onSecondaryContainer)
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context._communityColors;
    final surface = context._communitySurface;
    final canComment =
        context.watch<DashboardProvider>().features['social_feed.comment'] ==
            '1';
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: Colors.black.withValues(alpha: .35)),
      AnimatedContainer(
          duration:
              _dragging ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: Scaffold(
              backgroundColor: surface,
              appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight + 22),
                  child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => setState(() {
                            _dragging = true;
                            _dragOffset = 0;
                          }),
                      onVerticalDragUpdate: (details) => setState(() {
                            _dragOffset =
                                (_dragOffset + details.delta.dy).clamp(0, 320);
                          }),
                      onVerticalDragEnd: (details) {
                        setState(() => _dragging = false);
                        if (_dragOffset > 80 ||
                            (details.primaryVelocity ?? 0) > 300) {
                          Navigator.maybePop(context);
                        } else {
                          setState(() => _dragOffset = 0);
                        }
                      },
                      onVerticalDragCancel: () => setState(() {
                            _dragging = false;
                            _dragOffset = 0;
                          }),
                      child: AppBar(
                          backgroundColor: surface,
                          foregroundColor: colors.onSurface,
                          iconTheme: IconThemeData(color: colors.onSurface),
                          elevation: 0,
                          centerTitle: true,
                          leading: IconButton(
                              tooltip: communityText('Close'),
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(Icons.close_rounded)),
                          title: Text(communityText('Comments'),
                              style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w800)),
                          bottom: PreferredSize(
                              preferredSize: const Size.fromHeight(22),
                              child: GestureDetector(
                                  key: const ValueKey('comments-drag-handle'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => Navigator.maybePop(context),
                                  child: Center(
                                      child: Container(
                                          width: 44,
                                          height: 5,
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          decoration: BoxDecoration(
                                              color: colors.outline,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      4))))))))),
              body: Column(children: [
                if (_error != null)
                  Padding(padding: EdgeInsets.all(12), child: Text(_error!)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                    child: Row(children: [
                      if (widget.reactionsCount > 0) ...[
                        const Text('👍', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 5),
                        Text('${widget.reactionsCount}',
                            style: const TextStyle(fontWeight: FontWeight.w700))
                      ],
                      const Spacer(),
                      if (widget.sharesCount > 0)
                        Text('${widget.sharesCount} ${communityText('shares')}',
                            style: const TextStyle(fontWeight: FontWeight.w700))
                    ])),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: communityText('Sort comments'),
                            onSelected: (_) {},
                            itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'relevant',
                                      child:
                                          Text(communityText('Most relevant'))),
                                  PopupMenuItem(
                                      value: 'newest',
                                      child: Text(communityText('Newest'))),
                                ],
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(communityText('Most relevant'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20)
                            ])))),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView(
                          physics: AlwaysScrollableScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                          children: [
                            if (_comments.isEmpty && !_loading)
                              Padding(
                                  padding: EdgeInsets.all(32),
                                  child:
                                      Text(communityText('No comments yet.'))),
                            for (final comment in _comments)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _commentAvatar(comment),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        '${(comment['author'] as Map?)?['name'] ?? communityText('Employee')}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800))),
                                                Text(
                                                    ' · ${_date(comment['created_at'])}',
                                                    style: TextStyle(
                                                        color: colors
                                                            .onSurfaceVariant,
                                                        fontSize: 12))
                                              ]),
                                              const SizedBox(height: 4),
                                              Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 9),
                                                  decoration: BoxDecoration(
                                                      color: colors
                                                          .surfaceContainerHigh,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16)),
                                                  child: _ExpandableCommentText(
                                                      key: ValueKey(
                                                          comment['id']),
                                                      text:
                                                          '${comment['body']}',
                                                      onMentionTap: (name) =>
                                                          _openMentionProfile(
                                                              context, name,
                                                              api: _api))),
                                              Row(children: [
                                                if (canComment)
                                                  TextButton(
                                                      onPressed: () {
                                                        setState(() =>
                                                            _replyParent =
                                                                comment['id']
                                                                    as int);
                                                        _composerFocus
                                                            .requestFocus();
                                                      },
                                                      style: TextButton.styleFrom(
                                                          minimumSize:
                                                              Size.zero,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 4)),
                                                      child: Text(
                                                          communityText(
                                                              'Reply'),
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                GestureDetector(
                                                    onTap: () => _reactComment(
                                                        comment,
                                                        comment['my_reaction'] ==
                                                                'like'
                                                            ? null
                                                            : 'like'),
                                                    onLongPress: () =>
                                                        _chooseCommentReaction(
                                                            comment),
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(6),
                                                        child: Row(children: [
                                                          Text(
                                                              comment['my_reaction'] ==
                                                                      null
                                                                  ? '♡'
                                                                  : (communityReactions[
                                                                          comment[
                                                                              'my_reaction']] ??
                                                                      '👍'),
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          17)),
                                                          if ((comment[
                                                                      'reactions_count'] ??
                                                                  0) >
                                                              0)
                                                            Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            3),
                                                                child: Text(
                                                                    '${comment['reactions_count']}',
                                                                    style: TextStyle(
                                                                        color: colors
                                                                            .onSurfaceVariant,
                                                                        fontWeight:
                                                                            FontWeight.w700)))
                                                        ]))),
                                                if ((comment['replies_count'] ?? 0) > 0)
                                                  TextButton(
                                                      onPressed: () =>
                                                          comment['replies'] is List
                                                              ? setState(() =>
                                                                  comment.remove(
                                                                      'replies'))
                                                              : _loadReplies(
                                                                  comment),
                                                      style: TextButton.styleFrom(
                                                          minimumSize:
                                                              Size.zero,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 4)),
                                                      child: Text(
                                                          comment['replies'] is List
                                                              ? communityText('Hide replies')
                                                              : '${comment['replies_count']} ${communityText('replies')}',
                                                          style: const TextStyle(fontWeight: FontWeight.w700))),
                                                const Spacer(),
                                                if (comment['can_edit'] == true)
                                                  IconButton(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      onPressed: () =>
                                                          _edit(comment),
                                                      icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 18)),
                                                if (comment['can_delete'] ==
                                                    true)
                                                  IconButton(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      onPressed: () =>
                                                          _delete(comment),
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18))
                                              ]),
                                              if (comment['replies'] is List)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8, top: 2),
                                                    child: Column(children: [
                                                      for (final reply
                                                          in comment['replies']
                                                              as List)
                                                        ListTile(
                                                            dense: true,
                                                            leading: const Icon(
                                                                Icons
                                                                    .subdirectory_arrow_right,
                                                                size: 18),
                                                            title: Text(
                                                                '${(reply['author'] as Map?)?['name'] ?? communityText('Employee')}'),
                                                            subtitle: _ExpandableCommentText(
                                                                key: ValueKey(
                                                                    'reply-${reply['id']}'),
                                                                text:
                                                                    '${reply['body']}',
                                                                onMentionTap: (name) =>
                                                                    _openMentionProfile(
                                                                        context,
                                                                        name,
                                                                        api:
                                                                            _api))),
                                                    ])),
                                            ]))
                                      ])),
                            if (_loading)
                              Center(child: CircularProgressIndicator()),
                            if (_hasMore && !_loading && _comments.isNotEmpty)
                              TextButton(
                                  onPressed: _load,
                                  child: Text(
                                      communityText('Load more comments'))),
                            if (_error != null)
                              TextButton(
                                  onPressed: () =>
                                      _load(reset: _comments.isEmpty),
                                  child: Text(communityText('Try again'))),
                          ],
                        ))),
                if (canComment)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: MentionField(
                              controller: _text,
                              focusNode: _composerFocus,
                              panelAbove: true,
                              enabled: !_sending,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: _replyParent == null
                                    ? communityText('Write a comment…')
                                    : communityText('Write a reply…'),
                                counterText: '',
                                filled: true,
                                fillColor: colors.surfaceContainerHigh,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                      color: colors.onPrimaryContainer),
                                ),
                              ),
                            ),
                          ),
                          if (_replyParent != null)
                            IconButton(
                              tooltip: communityText('Cancel reply'),
                              onPressed: _sending
                                  ? null
                                  : () => setState(() => _replyParent = null),
                              icon: const Icon(Icons.close),
                            ),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.onPrimaryContainer,
                            ),
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: colors.onPrimaryContainer),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
              ])))
    ]);
  }
}
