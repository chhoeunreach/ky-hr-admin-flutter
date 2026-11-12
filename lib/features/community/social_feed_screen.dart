import 'reaction_button.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'community_strings.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:file_picker/file_picker.dart';
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
import 'community_media.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key, this.api});
  final CommunityApi? api;
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  late final _api = widget.api ?? CommunityApi();
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _storyGroups = [];
  final Set<int> _busyPosts = {};
  bool _loading = false;
  bool _storiesLoading = false;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  int _generation = 0;
  int _storiesGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadStories();
  }

  @override
  void dispose() {
    _generation++;
    _storiesGeneration++;
    FeedVideoAutoplayManager.instance.pauseAll();
    _api.dispose();
    super.dispose();
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
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const SocialStoryComposer()));
    if (changed == true && mounted) await _loadStories();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = reset ? 1 : _page + 1;
      final response = await _api.request('GET', 'social-feed?page=$page');
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _posts.clear();
        final existing = _posts.map((post) => post['id']).toSet();
        _posts.addAll((response['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((post) => existing.add(post['id'])));
        _page = page;
        _hasMore = response['next_page_url'] != null;
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _error = communityError(error));
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _compose({Map<String, dynamic>? post}) async {
    FeedVideoAutoplayManager.instance.pauseAll();
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => SocialPostComposer(post: post)));
    if (changed == true && mounted) await _load(reset: true);
  }

  Future<void> _action(Map<String, dynamic> post, String action,
      {Map<String, dynamic>? data}) async {
    final id = post['id'] as int;
    if (_busyPosts.contains(id)) return;
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
    } finally {
      if (mounted) setState(() => _busyPosts.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
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
    final text = await showDialog<String>(
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
    final reason = await showDialog<String>(
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
      await showDialog<void>(
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
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SocialCommentsScreen(
                postId: post['id'] as int,
                reactionsCount: (post['reactions_count'] as num?)?.toInt() ?? 0,
                commentsCount: (post['comments_count'] as num?)?.toInt() ?? 0,
                sharesCount: (post['shares_count'] as num?)?.toInt() ?? 0)));
    if (mounted) await _load(reset: true);
  }

  Widget _postCard(Map<String, dynamic> post) {
    final busy = _busyPosts.contains(post['id']);
    final author = post['author'] as Map?;
    final avatar = '${author?['avatar'] ?? ''}';
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child:
                      avatar.isEmpty ? const Icon(Icons.person_outline) : null),
              SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(
                              '${author?['name'] ?? communityText('Employee')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      if (post['is_announcement'] == true)
                        const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified,
                                size: 16, color: Colors.blue))
                    ]),
                    Text(
                        '${author?['department'] ?? ''}${author?['department'] != null ? ' · ' : ''}${_date(post['created_at'])}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
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
            SizedBox(height: 12),
            _PostContent(post: post),
            if (post['poll'] is Map) _PollWidget(post: post, api: _api),
            SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: [
              InkWell(
                  onTap: (post['reactions_count'] ?? 0) > 0
                      ? () => _showReactions(post)
                      : null,
                  child: Text(
                      '${post['reactions_count'] ?? 0} ${communityText('reactions')}')),
              Text(
                  '${post['comments_count'] ?? 0} ${communityText('comments')}'),
              Text('${post['shares_count'] ?? 0} ${communityText('shares')}'),
            ]),
            if (post['reactions'] is Map &&
                (post['reactions'] as Map).isNotEmpty)
              Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, children: [
                    for (final entry in (post['reactions'] as Map).entries)
                      Text(
                          '${communityReactions[entry.key] ?? entry.key} ${entry.value}'),
                  ])),
            Divider(),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (_allows('social_feed.react'))
                CommunityReactionButton(
                  reaction: post['my_reaction'] as String?,
                  enabled: !busy,
                  onChanged: (reaction) =>
                      _action(post, 'reaction', data: {'reaction': reaction}),
                ),
              TextButton.icon(
                  onPressed: busy ? null : () => _comments(post),
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(communityText('Comments'))),
              if (_allows('social_feed.share'))
                TextButton.icon(
                    onPressed: busy ? null : () => _share(post),
                    icon: Icon(Icons.share_outlined, size: 18),
                    label: Text(communityText('Share'))),
            ]),
            if (busy) LinearProgressIndicator(),
          ]),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final features = context.watch<DashboardProvider>().features;
    final canViewStories =
        _allowsStory('social_feed.stories.view', 'social_feed.view');
    final canCreateStories =
        _allowsStory('social_feed.stories.create', 'social_feed.create');
    return Scaffold(
      appBar: AppBar(title: Text(communityText('Social Feed')), actions: [
        if (features['social_feed.search'] == '1')
          IconButton(
              tooltip: communityText('Search'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SocialSearchScreen())),
              icon: const Icon(Icons.search)),
        if (features['social_feed.notifications'] == '1')
          IconButton(
              tooltip: communityText('Notifications'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SocialNotificationsScreen())),
              icon: const Icon(Icons.notifications_none)),
        if (features['social_feed.save'] == '1')
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
      ]),
      floatingActionButton: null,
      body: features['social_feed.view'] != '1'
          ? Center(
              child: Text(communityText(
                  'You do not have permission to view the feed.')))
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 2, bottom: 100),
                children: [
                  if (features['social_feed.create'] == '1')
                    Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _compose(),
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(children: [
                                  const CircleAvatar(
                                      child: Icon(Icons.person_outline)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(
                                          communityText("What's on your mind?"),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge)),
                                  IconButton(
                                      onPressed: () => _compose(),
                                      icon: const Icon(Icons.image_outlined,
                                          color: Colors.blue)),
                                  IconButton(
                                      onPressed: () => _compose(),
                                      icon: const Icon(Icons.videocam_outlined,
                                          color: Colors.blue)),
                                ])))),
                  if (canViewStories)
                    SocialStoriesStrip(
                        groups: _storyGroups,
                        loading: _storiesLoading,
                        error: null,
                        canCreate: canCreateStories,
                        onCreate: _composeStory,
                        onRetry: _loadStories,
                        onOpen: (index) {
                          FeedVideoAutoplayManager.instance.pauseAll();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SocialStoryViewer(
                                      groups: _storyGroups,
                                      initialGroup: index)));
                        }),
                  Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(communityText('Connect with your team'),
                          style: Theme.of(context).textTheme.titleLarge)),
                  if (_error != null)
                    Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(children: [
                          Text(_error!),
                          TextButton(
                              onPressed: () => _load(reset: _posts.isEmpty),
                              child: Text(communityText('Try again')))
                        ])),
                  if (_posts.isEmpty && !_loading && _error == null)
                    Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                            'No posts yet. Start a conversation with your team.',
                            textAlign: TextAlign.center)),
                  ..._posts.map(_postCard),
                  if (_loading)
                    Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator())),
                  if (_hasMore && !_loading && _posts.isNotEmpty)
                    TextButton(
                        onPressed: _load,
                        child: Text(communityText('Load more posts'))),
                ],
              )),
    );
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
          height: 164, child: Center(child: CircularProgressIndicator()));
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
        height: 164,
        child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            scrollDirection: Axis.horizontal,
            itemCount: groups.length + (canCreate ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
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
    return SizedBox(
        width: 92,
        child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: 1,
            child: InkWell(
                onTap: onTap,
                child: Column(children: [
                  Expanded(
                    child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                              Color(0xffeaf2ff),
                              Color(0xffcfe0ff)
                            ])),
                        child: Center(
                            child: DecoratedBox(
                                decoration: const BoxDecoration(
                                    color: Color(0xff1769e8),
                                    shape: BoxShape.circle),
                                child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.add_rounded,
                                        color: Colors.white, size: 23))))),
                  ),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(communityText('Create story'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)))
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
    return SizedBox(
        width: 92,
        child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: seen ? Colors.transparent : const Color(0xff1769e8),
                    width: seen ? 0 : 2)),
            child: InkWell(
                onTap: onTap,
                child: Stack(fit: StackFit.expand, children: [
                  if (uri != null)
                    CachedNetworkImage(
                        imageUrl: uri.toString(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xffdbe7fa),
                            child: Icon(Icons.image_not_supported_outlined)))
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
                                        const EdgeInsets.fromLTRB(8, 42, 8, 30),
                                    child: Text(caption,
                                        maxLines: 7,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                            shadows: [
                                              Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black54)
                                            ])))
                                : Icon(
                                    type == 'video'
                                        ? Icons.play_circle_fill_rounded
                                        : Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 38))),
                  if (type == 'video') ...[
                    const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 38)),
                    if (duration != null)
                      Positioned(
                          top: 8,
                          right: 7,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .7),
                                  borderRadius: BorderRadius.circular(9)),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: Text(duration,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
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
                      top: 8,
                      left: 8,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: seen
                                  ? Colors.white70
                                  : const Color(0xff1769e8),
                              shape: BoxShape.circle),
                          child: CircleAvatar(
                              radius: 14,
                              backgroundImage: avatar.isNotEmpty
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar.isEmpty
                                  ? const Icon(Icons.person, size: 18)
                                  : null))),
                  Positioned(
                      left: 8,
                      right: 8,
                      bottom: 7,
                      child: Text(
                          group['is_mine'] == true
                              ? communityText('Your story')
                              : '${author['name'] ?? communityText('Employee')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black)
                              ])))
                ]))));
  }
}

class SocialStoryViewer extends StatefulWidget {
  const SocialStoryViewer(
      {super.key, required this.groups, this.initialGroup = 0});
  final List<Map<String, dynamic>> groups;
  final int initialGroup;

  @override
  State<SocialStoryViewer> createState() => _SocialStoryViewerState();
}

class _SocialStoryViewerState extends State<SocialStoryViewer> {
  late final CommunityApi _api;
  late final PageController _pages;
  final List<Map<String, dynamic>> _items = [];
  int _index = 0;
  Timer? _progressTimer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _api = CommunityApi();
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

  void _startProgress() {
    _progressTimer?.cancel();
    _progress = 0;
    if (_items.isEmpty) return;
    final story = _items[_index]['story'] as Map<String, dynamic>;
    final totalMs = _storyDuration(story).inMilliseconds;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      final next = _progress + 100 / totalMs;
      if (next < 1) {
        setState(() => _progress = next);
        return;
      }
      timer.cancel();
      if (_index < _items.length - 1) {
        _pages.nextPage(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic);
      } else {
        Navigator.maybePop(context);
      }
    });
  }

  Future<void> _deleteCurrent() async {
    final story = _items[_index]['story'] as Map<String, dynamic>;
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true || !mounted) return;
    try {
      await _api.request('DELETE', 'social-stories/${story['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pages.dispose();
    _api.dispose();
    super.dispose();
  }

  Widget _storyMedia(Map<String, dynamic> story) {
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
      return uri == null
          ? Center(
              child: Text(communityText('This media link is unavailable.'),
                  style: const TextStyle(color: Colors.white)))
          : CachedNetworkImage(
              imageUrl: uri.toString(),
              fit: BoxFit.contain,
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
            aspectRatio: story['aspect_ratio']));
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
        appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
                tooltip: communityText('Close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
            titleSpacing: 0,
            title: Row(children: [
              CircleAvatar(
                  radius: 16,
                  backgroundImage: '${author['avatar'] ?? ''}'.isNotEmpty
                      ? NetworkImage('${author['avatar']}')
                      : null,
                  child: '${author['avatar'] ?? ''}'.isEmpty
                      ? const Icon(Icons.person, size: 18)
                      : null),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('${author['name'] ?? communityText('Employee')}',
                      maxLines: 1, overflow: TextOverflow.ellipsis))
            ]),
            actions: [
              if ((story['can_delete'] ?? false) == true)
                IconButton(
                    tooltip: communityText('Delete story'),
                    onPressed: _deleteCurrent,
                    icon: const Icon(Icons.delete_outline_rounded))
            ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
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
                                              ? _progress.clamp(0, 1).toDouble()
                                              : 0,
                                      child: const ColoredBox(
                                          color: Colors.white)))))))),
          Expanded(
              child: PageView.builder(
                  controller: _pages,
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
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _storyMedia(story)),
                      if ('${story['caption'] ?? ''}'.trim().isNotEmpty &&
                          story['media_type'] != 'text')
                        Positioned(
                            left: 22,
                            right: 22,
                            bottom: 18,
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
                  }))
        ]));
  }
}

class SocialStoryComposer extends StatefulWidget {
  const SocialStoryComposer({super.key, this.api});
  final CommunityApi? api;

  @override
  State<SocialStoryComposer> createState() => _SocialStoryComposerState();
}

class _SocialStoryComposerState extends State<SocialStoryComposer> {
  late final CommunityApi _api;
  late final bool _ownsApi;
  final _caption = TextEditingController();
  PlatformFile? _file;
  Uint8List? _thumbnailBytes;
  int? _durationSeconds;
  double? _aspectRatio;
  String _type = 'text';
  bool _saving = false;
  bool _metadataLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? CommunityApi();
  }

  @override
  void dispose() {
    _caption.dispose();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  Future<void> _pick(String type) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: type == 'image'
            ? ['jpg', 'jpeg', 'png', 'gif', 'webp']
            : ['mp4', 'mov', 'webm']);
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
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
            filePath: _file?.path,
            fileMime: _mime(_file?.extension),
            thumbnailBytes: _thumbnailBytes,
            thumbnailFileName: 'story-thumbnail.jpg',
            thumbnailMime: 'image/jpeg');
      } else {
        await _api.request('POST', 'social-stories',
            data: storyData,
            filePath: _file?.path,
            fileMime: _mime(_file?.extension));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _preview() {
    if (_file?.path != null && _type == 'image') {
      return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.file(File(_file!.path!), fit: BoxFit.cover));
    }
    if (_file?.path != null && _type == 'video') {
      if (_metadataLoading) {
        return const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xff101826)),
            child:
                Center(child: CircularProgressIndicator(color: Colors.white)));
      }
      return DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xff172a46), Color(0xff07111f)])),
          child: Stack(fit: StackFit.expand, children: [
            if (_thumbnailBytes != null)
              Image.memory(_thumbnailBytes!, fit: BoxFit.cover),
            ColoredBox(color: Colors.black26),
            const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 70)),
            if (_durationSeconds != null)
              Positioned(
                  right: 12,
                  bottom: 12,
                  child: _StoryDurationBadge(seconds: _durationSeconds!))
          ]));
    }
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff6246d9), Color(0xffa66cff)])),
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                    _caption.text.isEmpty
                        ? communityText('Your story preview')
                        : _caption.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)))));
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
          backgroundColor: const Color(0xfff5f8fd),
          appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              title: Text(communityText('Create story'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded))
              ]),
          bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded),
                  label: Text(_saving
                      ? communityText('Publishing…')
                      : communityText('Share story')),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder()))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            SizedBox(height: 360, child: _preview()),
            const SizedBox(height: 14),
            TextField(
                controller: _caption,
                maxLength: 1000,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: communityText('Add a caption'),
                    hintText: communityText('Share a moment with your team'),
                    border: const OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pick('image'),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(communityText('Photo')))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _pick('video'),
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(communityText('Video'))))
            ]),
            if (_file != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_file!.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600)))
          ])));
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
        appBar: AppBar(title: Text(communityText('Search feed'))),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
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
      appBar: AppBar(
          title: Text(_unreadCount > 0
              ? '${communityText('Notifications')} ($_unreadCount)'
              : communityText('Notifications')),
          actions: [
            if (_unreadCount > 0)
              TextButton(
                  onPressed: _markingAll ? null : _markAll,
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
    Navigator.push(
        context,
        MaterialPageRoute(
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
        appBar: AppBar(title: Text(communityText('Post'))),
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
                        padding: const EdgeInsets.all(12),
                        children: [
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(children: [
                                          CircleAvatar(
                                              backgroundImage: avatar.isNotEmpty
                                                  ? NetworkImage(avatar)
                                                  : null,
                                              child: avatar.isEmpty
                                                  ? const Icon(
                                                      Icons.person_outline)
                                                  : null),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    '${author?['name'] ?? communityText('Employee')}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                Text(
                                                    '${author?['department'] ?? ''}${author?['department'] != null ? ' · ' : ''}${_date(post['created_at'])}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              ])),
                                        ]),
                                        const SizedBox(height: 10),
                                        _PostContent(post: post),
                                        const SizedBox(height: 8),
                                        Row(children: [
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
                                              label: Text(
                                                  communityText('Comments')))
                                        ]),
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
      appBar: AppBar(title: Text(communityText('Saved posts'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_posts.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(communityText('No saved posts yet.'),
                                  textAlign: TextAlign.center)),
                        for (final post in _posts)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                            '${(post['author'] as Map?)?['name'] ?? communityText('Employee')}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(_date(post['created_at']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                        const SizedBox(height: 8),
                                        _PostContent(post: post),
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

class _PostContent extends StatelessWidget {
  _PostContent({required this.post, this.nested = false});
  final Map<String, dynamic> post;
  final bool nested;
  List<Map<String, dynamic>> _mediaItems() {
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if ('${post['body'] ?? ''}'.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableText('${post['body']}')),
      if (media.length == 1)
        CommunityMedia(
            type: media.first['media_type'] as String,
            url: media.first['media_url'] as String,
            playbackUrl: media.first['playback_url'] as String?,
            thumbnailUrl: '${media.first['thumbnail_url'] ?? ''}',
            durationSeconds: media.first['duration_seconds'],
            aspectRatio: media.first['aspect_ratio'],
            autoPlay: media.first['media_type'] == 'video',
            onImageTap: media.first['media_type'] == 'image'
                ? () => _openViewer(context, media, 0)
                : null)
      else if (media.length > 1)
        _PostMediaGallery(
            items: media,
            onImageTap: (index) => _openViewer(context, media, index)),
      if (!nested && post['original_post_id'] != null)
        Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12)),
            child: post['original'] is Map
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Text(
                            '${(post['original']['author'] as Map?)?['name'] ?? communityText('Employee')}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _PostContent(
                            post: Map<String, dynamic>.from(
                                post['original'] as Map),
                            nested: true),
                      ])
                : Text(communityText(
                    'The original post is no longer available.'))),
    ]);
  }
}

class _PostMediaGallery extends StatelessWidget {
  const _PostMediaGallery({required this.items, required this.onImageTap});
  final List<Map<String, dynamic>> items;
  final ValueChanged<int> onImageTap;

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
        final cell = (constraints.maxWidth - 5) / 2;
        return SizedBox(
            height: cell * 2 + 5,
            child: Row(children: [
              Expanded(child: _tile(visible[0], 0)),
              const SizedBox(width: 5),
              Expanded(
                  child: Column(children: [
                Expanded(child: _tile(visible[1], 1)),
                const SizedBox(height: 5),
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
              crossAxisCount: 2, crossAxisSpacing: 5, mainAxisSpacing: 5),
          itemBuilder: (context, index) {
            return _tile(visible[index], index);
          }),
      Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(children: [
            const Icon(Icons.collections_rounded,
                size: 16, color: Colors.blueGrey),
            const SizedBox(width: 5),
            Text('${items.length} ${communityText('media items')}',
                style: const TextStyle(
                    color: Colors.blueGrey, fontWeight: FontWeight.w600))
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

class SocialPostComposer extends StatefulWidget {
  SocialPostComposer({super.key, this.post, this.api});
  final CommunityApi? api;
  final Map<String, dynamic>? post;
  @override
  State<SocialPostComposer> createState() => _SocialPostComposerState();
}

class _SocialPostComposerState extends State<SocialPostComposer> {
  final _body = TextEditingController();
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
  String? _error;
  bool get _isShare => widget.post?['original_post_id'] != null;

  @override
  void initState() {
    super.initState();
    _body.text = '${widget.post?['body'] ?? ''}';
    _url.text = '${widget.post?['media_url'] ?? ''}';
    _type = '${widget.post?['media_type'] ?? 'text'}';
    _visibility = '${widget.post?['visibility'] ?? 'company'}';
    _location.text = '${widget.post?['location_name'] ?? ''}';
    _loadComposerProfile();
  }

  @override
  void dispose() {
    _body.dispose();
    _url.dispose();
    _audienceIds.dispose();
    _location.dispose();
    _pollQuestion.dispose();
    _pollClosesAt.dispose();
    for (final option in _pollOptions) option.dispose();
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
    } catch (_) {}
  }

  String get _draftKey => 'social_feed_draft_${widget.post?['id'] ?? 'new'}';

  Future<void> _restoreDraft() async {
    if (widget.post != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      final draft = jsonDecode(raw) as Map;
      setState(() {
        _body.text = '${draft['body'] ?? _body.text}';
        _url.text = '${draft['media_url'] ?? _url.text}';
        _location.text = '${draft['location_name'] ?? _location.text}';
        _visibility = '${draft['visibility'] ?? _visibility}';
        _pollEnabled = draft['poll_enabled'] == true;
        _pollMultiple = draft['poll_multiple'] == true;
        _pollQuestion.text = '${draft['poll_question'] ?? ''}';
        final options = (draft['poll_options'] as List? ?? []);
        for (var i = 0; i < options.length && i < _pollOptions.length; i++) {
          _pollOptions[i].text = '${options[i]}';
        }
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _draftKey,
        jsonEncode({
          'body': _body.text,
          'media_url': _url.text,
          'location_name': _location.text,
          'visibility': _visibility,
          'poll_enabled': _pollEnabled,
          'poll_multiple': _pollMultiple,
          'poll_question': _pollQuestion.text,
          'poll_options': _pollOptions.map((item) => item.text).toList(),
        }));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(communityText('Draft saved on this device.'))));
    }
  }

  Future<void> _clearDraft() async {
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
    if (emoji != null && mounted) {
      final value = _body.selection.isValid
          ? _body.selection.baseOffset.clamp(0, _body.text.length).toInt()
          : _body.text.length;
      setState(() => _body.text =
          '${_body.text.substring(0, value)}$emoji${_body.text.substring(value)}');
    }
  }

  Future<void> _chooseLocation() async {
    final value = await showDialog<String>(
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
    if (value != null && mounted) setState(() => _location.text = value);
  }

  Future<void> _pick() async {
    final extensions = _type == 'image'
        ? ['jpg', 'jpeg', 'png', 'gif', 'webp']
        : _type == 'document'
            ? ['pdf', 'doc', 'docx', 'xls', 'xlsx']
            : ['mp4', 'mov', 'webm'];
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: _type == 'image',
        allowedExtensions: extensions);
    if (result == null || !mounted) return;
    final max = (_type == 'image'
            ? 10
            : _type == 'document'
                ? 25
                : 100) *
        1024 *
        1024;
    final files = result.files;
    setState(() {
      if (files.isEmpty ||
          files.any((file) => file.size > max || file.path == null)) {
        _error = communityText(_type == 'image'
            ? 'Select a 10 MB or smaller file.'
            : _type == 'document'
                ? 'Select a 25 MB or smaller file.'
                : 'Select a 100 MB or smaller file.');
      } else {
        _files = files;
        _file = files.length == 1 ? files.first : null;
        _thumbnailBytes = null;
        _durationSeconds = null;
        _aspectRatio = null;
        _metadataLoading = _type == 'video' && files.length == 1;
        _url.clear();
        _error = null;
      }
    });
    if (_type == 'video' && files.length == 1 && files.first.path != null) {
      await _prepareVideoMetadata(files.first);
    }
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
    if (!_isShare && _type == 'text' && _body.text.trim().isEmpty) {
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
        if (_pollClosesAt.text.trim().isNotEmpty)
          payload['poll_closes_at'] = _pollClosesAt.text.trim();
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

  Widget _actionTile(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback? onTap}) {
    return SizedBox(
        width: 92,
        child: Material(
            color: const Color(0xfff5f8ff),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(height: 5),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600))
                    ])))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final name = '${_profile?['name'] ?? 'Your name'}';
    final avatar = '${_profile?['avatar'] ?? ''}';
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
            backgroundColor: const Color(0xfff5f8fd),
            appBar: AppBar(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                    tooltip: communityText('Back'),
                    onPressed:
                        _saving ? null : () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded)),
                centerTitle: true,
                title: Text(
                    widget.post == null
                        ? communityText('Create post')
                        : communityText('Edit post'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                      tooltip: communityText('Close'),
                      onPressed:
                          _saving ? null : () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded))
                ]),
            bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_error != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(_error!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600)))),
                  FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: Text(_saving
                          ? communityText('Publishing…')
                          : widget.post == null
                              ? communityText('Publish post')
                              : communityText('Save changes')),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)))
                ])),
            body: ListView(
                cacheExtent: 1600,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 29,
                                backgroundColor: primary.withValues(alpha: .12),
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? Icon(Icons.person,
                                        color: primary, size: 28)
                                    : null),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Icon(Icons.badge_outlined,
                                        size: 16, color: Colors.blueGrey),
                                    const SizedBox(width: 5),
                                    Flexible(
                                        child: Text(
                                            '${_profile?['department'] ?? communityText('Employee')}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.blueGrey,
                                                fontWeight: FontWeight.w600)))
                                  ])
                                ])),
                            if (!_isShare)
                              OutlinedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                          setState(() => _showAudience = true),
                                  icon: Icon(_visibility == 'company'
                                      ? Icons.public
                                      : Icons.groups_outlined),
                                  label: Text(_visibility == 'company'
                                      ? communityText('Public')
                                      : _visibilityLabel()),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: primary,
                                      shape: const StadiumBorder()))
                          ]))),
                  const SizedBox(height: 12),
                  Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: Colors.blueGrey.withValues(alpha: .12))),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Column(children: [
                            TextField(
                                controller: _body,
                                enabled: !_saving,
                                maxLines: 5,
                                maxLength: 10000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                    hintText: communityText(
                                        'What would you like to share?'),
                                    hintStyle: const TextStyle(
                                        color: Color(0xff60708f), fontSize: 20),
                                    border: InputBorder.none,
                                    counterText: '')),
                            Row(children: [
                              IconButton(
                                  tooltip: communityText('Add emoji'),
                                  onPressed: _saving ? null : _pickEmoji,
                                  icon: Icon(Icons.emoji_emotions_outlined,
                                      color: primary)),
                              const Spacer(),
                              Text('${_body.text.length}/10000',
                                  style: theme.textTheme.bodySmall),
                              IconButton(
                                  tooltip: communityText('Text style'),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() =>
                                          _body.text = '**${_body.text}**'),
                                  icon: Icon(Icons.format_bold_rounded,
                                      color: primary))
                            ])
                          ]))),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 86,
                      child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                        _actionTile(
                            icon: Icons.photo_library_rounded,
                            color: const Color(0xff1769e8),
                            label: communityText('Photo'),
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                      _type = 'image';
                                      _pick();
                                    })),
                        const SizedBox(width: 8),
                        _actionTile(
                            icon: Icons.videocam_rounded,
                            color: const Color(0xffef3340),
                            label: communityText('Video'),
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                      _type = 'video';
                                      _pick();
                                    })),
                        const SizedBox(width: 8),
                        _actionTile(
                            icon: Icons.insert_drive_file_rounded,
                            color: const Color(0xff6644e8),
                            label: communityText('File'),
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                      _type = 'document';
                                      _pick();
                                    })),
                        const SizedBox(width: 8),
                        _actionTile(
                            icon: Icons.emoji_emotions_rounded,
                            color: const Color(0xffffa600),
                            label: communityText('Emoji'),
                            onTap: _saving ? null : _pickEmoji),
                        const SizedBox(width: 8),
                        _actionTile(
                            icon: Icons.location_on_rounded,
                            color: const Color(0xff1b69e8),
                            label: communityText('Location'),
                            onTap: _saving ? null : _chooseLocation),
                        const SizedBox(width: 8),
                        _actionTile(
                            icon: Icons.more_horiz_rounded,
                            color: Colors.blueGrey,
                            label: communityText('More'),
                            onTap: _saving
                                ? null
                                : () => setState(() => _showMore = !_showMore))
                      ])),
                  if (_showMore || _type != 'text' || _files.isNotEmpty)
                    Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 10),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              if (_type != 'text')
                                TextField(
                                    controller: _url,
                                    enabled: !_saving && _files.isEmpty,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                        labelText: communityText(
                                            'Paste a link or video URL'),
                                        prefixIcon:
                                            const Icon(Icons.link_rounded),
                                        border: const OutlineInputBorder())),
                              if (_type != 'text') const SizedBox(height: 8),
                              if (['image', 'video', 'document']
                                  .contains(_type))
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading:
                                        Icon(Icons.attach_file, color: primary),
                                    title: Text(_files.isEmpty
                                        ? communityText('Choose an attachment')
                                        : _files
                                            .map((file) => file.name)
                                            .join(', ')),
                                    subtitle: Text(communityText(
                                        'Photos, videos and documents are supported.')),
                                    trailing: IconButton(
                                        onPressed: _saving ? null : _pick,
                                        icon: const Icon(Icons.chevron_right))),
                              if (_type == 'video' && _metadataLoading)
                                const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: LinearProgressIndicator()),
                              if (_type == 'video' && _thumbnailBytes != null)
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.memory(_thumbnailBytes!,
                                                  fit: BoxFit.cover),
                                              const ColoredBox(
                                                  color: Colors.black26),
                                              const Center(
                                                  child: Icon(
                                                      Icons
                                                          .play_circle_fill_rounded,
                                                      color: Colors.white,
                                                      size: 54)),
                                              if (_durationSeconds != null)
                                                Positioned(
                                                    right: 10,
                                                    bottom: 10,
                                                    child: _StoryDurationBadge(
                                                        seconds:
                                                            _durationSeconds!))
                                            ]))),
                              if (_location.text.isNotEmpty)
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.red),
                                    title: Text(_location.text),
                                    trailing: IconButton(
                                        onPressed: () =>
                                            setState(() => _location.clear()),
                                        icon: const Icon(Icons.close)))
                            ]))),
                  const SizedBox(height: 12),
                  Card(
                      elevation: 0,
                      color: primary.withValues(alpha: .08),
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: SwitchListTile.adaptive(
                          secondary: Icon(Icons.poll_rounded,
                              color: primary, size: 30),
                          title: Text(communityText('Add a poll'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(communityText('Let your team vote!')),
                          value: _pollEnabled,
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  setState(() => _pollEnabled = value))),
                  if (_pollEnabled)
                    Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 10),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              TextField(
                                  controller: _pollQuestion,
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                      labelText: communityText('Poll question'),
                                      border: const OutlineInputBorder())),
                              for (var index = 0;
                                  index < _pollOptions.length;
                                  index++)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextField(
                                        controller: _pollOptions[index],
                                        maxLength: 160,
                                        decoration: InputDecoration(
                                            labelText:
                                                '${communityText('Option')} ${index + 1}',
                                            border:
                                                const OutlineInputBorder()))),
                              SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      communityText('Allow multiple answers')),
                                  value: _pollMultiple,
                                  onChanged: (value) =>
                                      setState(() => _pollMultiple = value)),
                              TextField(
                                  controller: _pollClosesAt,
                                  decoration: InputDecoration(
                                      labelText: communityText(
                                          'Poll closes at (optional ISO date)'),
                                      border: const OutlineInputBorder()))
                            ]))),
                  const SizedBox(height: 12),
                  Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                          onTap: _saving
                              ? null
                              : () => setState(
                                  () => _showAudience = !_showAudience),
                          leading: Icon(Icons.shield_rounded,
                              color: primary, size: 30),
                          title: Text(communityText('Post visibility'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(_visibilityLabel()),
                          trailing: Icon(_showAudience
                              ? Icons.expand_less
                              : Icons.chevron_right))),
                  if (_showAudience)
                    Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 8),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              DropdownButtonFormField<String>(
                                  initialValue: _visibility,
                                  decoration: InputDecoration(
                                      labelText: communityText(
                                          'Choose who can see this post'),
                                      border: const OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'company',
                                        child: Text('All company employees')),
                                    DropdownMenuItem(
                                        value: 'department',
                                        child: Text('Specific departments')),
                                    DropdownMenuItem(
                                        value: 'employees',
                                        child: Text('Selected employees')),
                                    DropdownMenuItem(
                                        value: 'management',
                                        child: Text('Management only')),
                                    DropdownMenuItem(
                                        value: 'hr', child: Text('HR only'))
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(() =>
                                          _visibility = value ?? 'company')),
                              if (_visibility == 'department' ||
                                  _visibility == 'employees')
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: TextField(
                                        controller: _audienceIds,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                            labelText: communityText(
                                                'Audience IDs (comma separated)'),
                                            border:
                                                const OutlineInputBorder())))
                            ]))),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(_error!,
                            style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextButton.icon(
                            onPressed: _saving ? null : _saveDraft,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(communityText('Save Draft')))),
                    const SizedBox(height: 28, child: VerticalDivider()),
                    Expanded(
                        child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => Navigator.maybePop(context),
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(communityText('Cancel'))))
                  ])
                ])));
  }
}

class _ExpandableCommentText extends StatefulWidget {
  const _ExpandableCommentText({super.key, required this.text});
  final String text;
  @override
  State<_ExpandableCommentText> createState() => _ExpandableCommentTextState();
}

class _ExpandableCommentTextState extends State<_ExpandableCommentText> {
  static const _style = TextStyle(fontSize: 16, height: 1.18);
  static const _maxLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: _maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      if (!overflows) {
        return Text(widget.text, style: _style);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              widget.text,
              style: _style,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff65707e),
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
  final List<Map<String, dynamic>> _comments = [];
  bool _loading = false;
  bool _sending = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  int? _replyParent;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _api.dispose();
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
    final value = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(communityText('Edit comment')),
              content: TextField(
                  controller: controller, maxLines: 4, maxLength: 2000),
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
    final confirm = await showDialog<bool>(
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
        backgroundColor: const Color(0xffdbe7fa),
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? const Icon(Icons.person_outline_rounded, color: Color(0xff5068a0))
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final canComment =
        context.watch<DashboardProvider>().features['social_feed.comment'] ==
            '1';
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xff182230),
            elevation: 0,
            centerTitle: true,
            title: Text(communityText('Comments'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            bottom: const PreferredSize(
                preferredSize: Size.fromHeight(5),
                child: SizedBox(
                    width: 42,
                    height: 4,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Color(0xffaeb5bd),
                            borderRadius:
                                BorderRadius.all(Radius.circular(4))))))),
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
                                child: Text(communityText('Most relevant'))),
                            PopupMenuItem(
                                value: 'newest',
                                child: Text(communityText('Newest'))),
                          ],
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(communityText('Most relevant'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20)
                      ])))),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                    children: [
                      if (_comments.isEmpty && !_loading)
                        Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(communityText('No comments yet.'))),
                      for (final comment in _comments)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800))),
                                          Text(
                                              ' · ${_date(comment['created_at'])}',
                                              style: const TextStyle(
                                                  color: Color(0xff75808d),
                                                  fontSize: 12))
                                        ]),
                                        const SizedBox(height: 4),
                                        Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 9),
                                            decoration: BoxDecoration(
                                                color: const Color(0xfff0f2f5),
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: _ExpandableCommentText(
                                                key: ValueKey(comment['id']),
                                                text: '${comment['body']}')),
                                        Row(children: [
                                          if (canComment)
                                            TextButton(
                                                onPressed: () => setState(() =>
                                                    _replyParent =
                                                        comment['id'] as int),
                                                style: TextButton.styleFrom(
                                                    minimumSize: Size.zero,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 4)),
                                                child: Text(
                                                    communityText('Reply'),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700))),
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
                                                      const EdgeInsets.all(6),
                                                  child: Row(children: [
                                                    Text(
                                                        comment['my_reaction'] ==
                                                                null
                                                            ? '♡'
                                                            : (communityReactions[
                                                                    comment[
                                                                        'my_reaction']] ??
                                                                '👍'),
                                                        style: const TextStyle(
                                                            fontSize: 17)),
                                                    if ((comment[
                                                                'reactions_count'] ??
                                                            0) >
                                                        0)
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 3),
                                                          child: Text(
                                                              '${comment['reactions_count']}',
                                                              style: const TextStyle(
                                                                  color: Color(
                                                                      0xff65707e),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)))
                                                  ]))),
                                          if ((comment['replies_count'] ?? 0) >
                                              0)
                                            TextButton(
                                                onPressed: () =>
                                                    _loadReplies(comment),
                                                style: TextButton.styleFrom(
                                                    minimumSize: Size.zero,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 4)),
                                                child: Text(
                                                    '${comment['replies_count']} ${communityText('replies')}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700))),
                                          const Spacer(),
                                          if (comment['can_edit'] == true)
                                            IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () => _edit(comment),
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18)),
                                          if (comment['can_delete'] == true)
                                            IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _delete(comment),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18))
                                        ])
                                      ]))
                                ])),
                      for (final comment in _comments)
                        if (comment['replies'] is List)
                          Padding(
                              padding: const EdgeInsets.only(left: 34),
                              child: Column(children: [
                                for (final reply in comment['replies'] as List)
                                  ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.subdirectory_arrow_right,
                                          size: 18),
                                      title: Text(
                                          '${(reply['author'] as Map?)?['name'] ?? communityText('Employee')}'),
                                      subtitle: Text('${reply['body']}'))
                              ])),
                      if (_loading) Center(child: CircularProgressIndicator()),
                      if (_hasMore && !_loading && _comments.isNotEmpty)
                        TextButton(
                            onPressed: _load,
                            child: Text(communityText('Load more comments'))),
                      if (_error != null)
                        TextButton(
                            onPressed: () => _load(reset: _comments.isEmpty),
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
                      child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _replyParent == null
                              ? communityText('Write a comment…')
                              : communityText('Write a reply…'),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xfff0f2f5),
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
                            borderSide:
                                const BorderSide(color: Color(0xff1769e8)),
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
                        backgroundColor: const Color(0xff1769e8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ]));
  }
}
