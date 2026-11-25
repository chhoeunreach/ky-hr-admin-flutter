import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Represents a compressed photo item with size stats.
class CompressedAssetPhoto {
  final File file;
  final String originalPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;

  CompressedAssetPhoto({
    required this.file,
    required this.originalPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
  });

  String get readableSize {
    final bytes = compressedSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get readableOriginalSize {
    final bytes = originalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get savingsPercentage {
    if (originalSizeBytes <= 0 || compressedSizeBytes >= originalSizeBytes) return 0;
    return (((originalSizeBytes - compressedSizeBytes) / originalSizeBytes) * 100).round();
  }
}

/// Helper utility to handle compression for asset photos.
class AssetImageCompressor {
  /// Compresses a single image from [sourcePath] with standard high-res settings.
  /// Falls back to the original file if compression fails (e.g. in unit tests or unsupported format).
  static Future<CompressedAssetPhoto> compressFile(
    String sourcePath, {
    int minWidth = 1280,
    int minHeight = 1280,
    int quality = 80,
  }) async {
    final sourceFile = File(sourcePath);
    int originalSize = 0;
    try {
      if (await sourceFile.exists()) {
        originalSize = await sourceFile.length();
      }
    } catch (_) {}

    try {
      final tempDir = Directory.systemTemp;
      final ext = p.extension(sourcePath).toLowerCase();
      final targetExt = (ext == '.png' || ext == '.webp') ? ext : '.jpg';
      final targetFormat = ext == '.png'
          ? CompressFormat.png
          : (ext == '.webp' ? CompressFormat.webp : CompressFormat.jpeg);

      final targetPath = p.join(
        tempDir.path,
        'asset_cmp_${DateTime.now().microsecondsSinceEpoch}_${p.basenameWithoutExtension(sourcePath)}$targetExt',
      );

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: targetFormat,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);
        if (await compressedFile.exists()) {
          final compSize = await compressedFile.length();
          return CompressedAssetPhoto(
            file: compressedFile,
            originalPath: sourcePath,
            originalSizeBytes: originalSize,
            compressedSizeBytes: compSize,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AssetImageCompressor error ($e), fallback to original.');
      }
    }

    return CompressedAssetPhoto(
      file: sourceFile,
      originalPath: sourcePath,
      originalSizeBytes: originalSize,
      compressedSizeBytes: originalSize,
    );
  }

  /// Compresses multiple images sequentially to minimize memory spikes on mobile devices.
  static Future<List<CompressedAssetPhoto>> compressMultiple(
    List<String> sourcePaths, {
    int minWidth = 1280,
    int minHeight = 1280,
    int quality = 80,
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <CompressedAssetPhoto>[];
    for (int i = 0; i < sourcePaths.length; i++) {
      onProgress?.call(i + 1, sourcePaths.length);
      final item = await compressFile(
        sourcePaths[i],
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );
      results.add(item);
    }
    return results;
  }
}
