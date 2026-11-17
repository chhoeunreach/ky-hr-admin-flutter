import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/community_strings.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:flutter/material.dart';

/// Home displays existing stories using the feed's cards and viewer.
class HomeStoriesPanel extends StatefulWidget {
  const HomeStoriesPanel({super.key, this.api});

  final CommunityApi? api;

  @override
  State<HomeStoriesPanel> createState() => _HomeStoriesPanelState();
}

class _HomeStoriesPanelState extends State<HomeStoriesPanel> {
  late final _api = widget.api ?? CommunityApi();
  final List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.request('GET', 'social-stories');
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll((response['data'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map)));
      });
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(int index) async {
    FeedVideoAutoplayManager.instance.pauseAll();
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) =>
          SocialStoryViewer(groups: _groups, initialGroup: index, api: _api),
    ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              tooltip: communityText('Refresh stories'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          if (!_loading && _error == null && _groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(communityText('No active stories.')),
            )
          else
            SocialStoriesStrip(
              groups: _groups,
              loading: _loading,
              error: _error,
              canCreate: false,
              onCreate: () {},
              onRetry: _load,
              onOpen: _open,
            ),
        ],
      );
}
