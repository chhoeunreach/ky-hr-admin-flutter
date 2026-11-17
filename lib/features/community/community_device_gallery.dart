import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// One photo or video exposed by the in-app gallery.
@immutable
class CommunityGalleryItem {
  const CommunityGalleryItem({
    required this.id,
    required this.isVideo,
    required this.width,
    required this.height,
    required this.thumbnail,
    required this.file,
    this.title,
    this.duration,
    this.size,
  });

  final String id;
  final bool isVideo;
  final int width;
  final int height;
  final String? title;
  final Duration? duration;

  /// Optional byte size so tests can avoid real file I/O.
  final int? size;
  final Future<Uint8List?> Function(int pixels) thumbnail;
  final Future<File?> Function() file;
}

/// A page of device media, shaped so the UI never talks to a plugin directly.
@immutable
class CommunityGalleryPage {
  const CommunityGalleryPage({
    this.items = const [],
    this.hasNext = false,
    this.permissionDenied = false,
  });

  final List<CommunityGalleryItem> items;
  final bool hasNext;
  final bool permissionDenied;
}

typedef CommunityGalleryLoader = Future<CommunityGalleryPage> Function({
  required String type,
  required int page,
  required int size,
});

/// Tests and previews replace this with deterministic media.
@visibleForTesting
CommunityGalleryLoader? debugCommunityGalleryLoader;

Future<CommunityGalleryPage> loadCommunityGalleryPage({
  required String type,
  required int page,
  required int size,
}) {
  final override = debugCommunityGalleryLoader;
  if (override != null) {
    return override(type: type, page: page, size: size);
  }
  return _loadDeviceGallery(type: type, page: page, size: size);
}

Future<CommunityGalleryPage> _loadDeviceGallery({
  required String type,
  required int page,
  required int size,
}) async {
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.hasAccess) {
    return const CommunityGalleryPage(permissionDenied: true);
  }
  final paths = await PhotoManager.getAssetPathList(
    type: type == 'video' ? RequestType.video : RequestType.image,
    onlyAll: true,
    filterOption: FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    ),
  );
  if (paths.isEmpty) return const CommunityGalleryPage();
  final path = paths.first;
  final total = await path.assetCountAsync;
  final assets = await path.getAssetListPaged(page: page, size: size);
  return CommunityGalleryPage(
    hasNext: assets.length == size && total > (page + 1) * size,
    items: [
      for (final asset in assets)
        CommunityGalleryItem(
          id: asset.id,
          isVideo: asset.type == AssetType.video,
          width: asset.width,
          height: asset.height,
          title: asset.title,
          duration: asset.type == AssetType.video
              ? Duration(seconds: asset.duration)
              : null,
          thumbnail: (pixels) => asset.thumbnailDataWithSize(
            ThumbnailSize.square(pixels),
            quality: 82,
          ),
          file: () => asset.file,
        ),
    ],
  );
}
