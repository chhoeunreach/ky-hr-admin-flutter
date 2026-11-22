import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'community_api.dart';
import 'community_device_gallery.dart';
import 'community_media.dart';
import 'community_strings.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

const _pickerInk = AppColors.customFF0B0F14;
const _pickerSurface = AppColors.customFF161D27;
const _pickerBlue = AppColors.customFF1877F2;

/// Opens the in-app photo/video gallery (never the document picker).
Future<List<PlatformFile>> pickCommunityMedia(
  BuildContext context,
  String type, {
  bool multiple = true,
  int maxSelection = 10,
}) async {
  final files = await Navigator.of(context).push<List<PlatformFile>>(
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CommunityMediaPicker(
              type: type, multiple: multiple, maxSelection: maxSelection)));
  return files ?? const [];
}

/// A Facebook-style device gallery with multi-select and paging.
class CommunityMediaPicker extends StatefulWidget {
  const CommunityMediaPicker({
    super.key,
    required this.type,
    this.multiple = true,
    this.maxSelection = 10,
  });

  final String type;
  final bool multiple;
  final int maxSelection;

  @override
  State<CommunityMediaPicker> createState() => _CommunityMediaPickerState();
}

class _CommunityMediaPickerState extends State<CommunityMediaPicker> {
  static const _pageSize = 60;

  final _scroll = ScrollController();
  final _items = <CommunityGalleryItem>[];
  final _selected = <String, CommunityGalleryItem>{};
  var _page = 0;
  var _loading = false;
  var _hasNext = true;
  var _denied = false;
  var _converting = false;
  String? _error;

  bool get _videos => widget.type == 'video';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasNext)) return;
    if (reset) {
      _page = 0;
      _hasNext = true;
      _error = null;
      _denied = false;
      _items.clear();
    }
    setState(() => _loading = true);
    try {
      final page = await loadCommunityGalleryPage(
          type: widget.type, page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _denied = page.permissionDenied;
        _hasNext = page.hasNext;
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => existing.add(item.id)));
        _page++;
      });
    } catch (error) {
      if (mounted) setState(() => _error = communityError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(CommunityGalleryItem item) {
    if (!widget.multiple) {
      _selected
        ..clear()
        ..[item.id] = item;
      _finish();
      return;
    }
    setState(() {
      if (_selected.remove(item.id) == null) {
        if (_selected.length >= widget.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(communityText(
                  'You can select up to ${widget.maxSelection} items.'))));
          return;
        }
        _selected[item.id] = item;
      }
    });
  }

  Future<void> _finish() async {
    if (_selected.isEmpty || _converting) return;
    setState(() => _converting = true);
    try {
      final files = <PlatformFile>[];
      // Selection can change while media is being downloaded from cloud storage.
      final selected = List<CommunityGalleryItem>.of(_selected.values);
      for (final item in selected) {
        final file = await item.file();
        if (!mounted) return;
        if (file == null)
          throw StateError(communityText('That media is no longer available.'));
        files.add(PlatformFile(
          name: item.title?.isNotEmpty == true
              ? item.title!
              : file.uri.pathSegments.last,
          path: file.path,
          size: item.size ?? await file.length(),
        ));
      }
      if (mounted) Navigator.pop(context, files);
    } catch (error) {
      if (mounted) {
        setState(() => _converting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(communityError(error))));
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await PhotoManager.openSetting();
    } catch (_) {}
    if (mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final pixels = (MediaQuery.sizeOf(context).width /
            3 *
            MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(180, 640)
        .toInt();
    return Scaffold(
        backgroundColor: _pickerInk,
        appBar: AppBar(
            backgroundColor: _pickerInk,
            foregroundColor: AppColors.white,
            elevation: 0,
            leading: IconButton(
                tooltip: communityText('Close'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded)),
            title: Text(
                _videos ? communityText('Videos') : communityText('Photos')),
            actions: [
              if (widget.multiple)
                Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                        child: Text(
                            '${_selected.length}/${widget.maxSelection}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.white70))))
            ]),
        body: _body(pixels),
        bottomNavigationBar: widget.multiple
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          communityText(_selected.isEmpty
                              ? 'Select media to continue'
                              : '${_selected.length} selected'),
                          style: const TextStyle(
                              color: AppColors.white70,
                              fontWeight: FontWeight.w600))),
                  FilledButton.icon(
                      onPressed:
                          _selected.isEmpty || _converting ? null : _finish,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.black,
                          minimumSize: const Size(128, 48),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      icon: _converting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(_selected.isEmpty
                          ? communityText('Add')
                          : '${communityText('Add')} (${_selected.length})'))
                ]))
            : null);
  }

  Widget _body(int pixels) {
    if (_denied) {
      return _CenterState(
          icon: Icons.lock_outline_rounded,
          title: communityText('Photo access is needed'),
          message: communityText(
              'Allow access so you can browse your gallery and share media.'),
          action: FilledButton(
              onPressed: _openSettings,
              child: Text(communityText('Open settings'))));
    }
    if (_error != null && _items.isEmpty) {
      return _CenterState(
          icon: Icons.cloud_off_rounded,
          title: communityText('Could not load your gallery'),
          message: _error!,
          action: FilledButton(
              onPressed: () => _load(reset: true),
              child: Text(communityText('Retry'))));
    }
    if (_items.isEmpty && _loading) {
      return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
          itemCount: 18,
          itemBuilder: (_, __) => const DecoratedBox(
              decoration: BoxDecoration(color: _pickerSurface)));
    }
    if (_items.isEmpty) {
      return _CenterState(
          icon: _videos
              ? Icons.videocam_off_outlined
              : Icons.photo_library_outlined,
          title: communityText(_videos ? 'No videos found' : 'No photos found'),
          message: communityText('New media will appear here automatically.'));
    }
    final count = _items.length;
    return RefreshIndicator(
        color: _pickerBlue,
        backgroundColor: _pickerSurface,
        onRefresh: () => _load(reset: true),
        child: GridView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
            itemCount: count + (_hasNext || _loading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= count) {
                return const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white54)));
              }
              final item = _items[index];
              final number = _selected.containsKey(item.id)
                  ? _selected.keys.toList().indexOf(item.id) + 1
                  : 0;
              return _GalleryTile(
                  item: item,
                  pixels: pixels,
                  selected: number > 0,
                  number: number,
                  onTap: () => _toggle(item));
            }));
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile(
      {required this.item,
      required this.pixels,
      required this.selected,
      required this.number,
      required this.onTap});

  final CommunityGalleryItem item;
  final int pixels;
  final bool selected;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = item.duration;
    final label = duration == null
        ? null
        : communityMediaDurationLabel(duration.inSeconds);
    return GestureDetector(
        key: ValueKey('gallery-item-${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: _pickerSurface),
          _GalleryThumbnail(item: item, pixels: pixels),
          if (item.isVideo)
            Positioned(
                left: 6,
                bottom: 6,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.white, size: 15),
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 4, color: AppColors.black)
                            ]))
                  ]
                ])),
          if (selected)
            const DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                        BorderSide(color: _pickerBlue, width: 3)))),
          if (selected)
            Positioned(
                top: 6,
                right: 6,
                child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: _pickerBlue, shape: BoxShape.circle),
                    child: Text('$number',
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800))))
        ]));
  }
}

class _GalleryThumbnail extends StatefulWidget {
  const _GalleryThumbnail({required this.item, required this.pixels});
  final CommunityGalleryItem item;
  final int pixels;

  @override
  State<_GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<_GalleryThumbnail> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.item.thumbnail(widget.pixels);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
              child: Icon(Icons.image_outlined,
                  color: AppColors.white24, size: 26));
        }
        return Image.memory(bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: widget.pixels,
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.white24, size: 26)));
      });
}

class _CenterState extends StatelessWidget {
  const _CenterState(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.white54, size: 52),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.white60, height: 1.4, fontSize: 14)),
            if (action != null) ...[const SizedBox(height: 20), action!]
          ])));
}
