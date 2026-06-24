import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'background_sync_manager.dart';
import 'database_helper.dart';

/// Placeholder upload endpoint — replace with your real API before shipping.
const String kImageUploadUrl = 'https://api.example.com/upload';

class ImageUploadException implements Exception {
  final String message;
  ImageUploadException(this.message);
  @override
  String toString() => 'ImageUploadException: $message';
}

/// Handles compressing, locally persisting, queueing and uploading images
/// for the offline-first upload pipeline.
///
/// Every public method here is safe to call repeatedly: `uploadImageFile`
/// never throws (network/server/timeout failures all just return `false`
/// so the caller can decide to retry), and `processPendingUploads` can be
/// invoked from both the immediate one-off sync and the periodic
/// background task without risk of double-processing the same row.
class ImageService {
  ImageService({Dio? dio, DatabaseHelper? db})
      : _dio = dio ?? Dio(),
        _db = db ?? DatabaseHelper.instance;

  final Dio _dio;
  final DatabaseHelper _db;

  /// Compresses [originalFile] and writes the result into the app's
  /// documents directory under `upload_queue/`. Returns the new local path.
  Future<String> compressAndSaveImage(File originalFile) async {
    if (!await originalFile.exists()) {
      throw ImageUploadException(
          'Source file does not exist: ${originalFile.path}');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory(p.join(docsDir.path, 'upload_queue'));
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalFile.path)}';
    final targetPath = p.join(queueDir.path, fileName);

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );

      if (compressed == null) {
        throw ImageUploadException('Compression returned null');
      }
      return compressed.path;
    } catch (e) {
      // Compression can fail for unsupported formats/codecs. Fall back to
      // copying the original rather than losing the image entirely.
      developer.log('Compression failed ($e), copying original instead',
          name: 'ImageService');
      final copy = await originalFile.copy(targetPath);
      return copy.path;
    }
  }

  /// Compresses, saves locally and inserts a `pending` row for
  /// [originalFile], then kicks an immediate background sync attempt.
  /// Returns the queue row id.
  Future<int> queueImageForUpload(File originalFile) async {
    final localPath = await compressAndSaveImage(originalFile);
    final id = await _db.insertUpload(localPath);

    // Best-effort kick — if scheduling fails (e.g. Workmanager not yet
    // initialized) the periodic task will still pick the row up later, so
    // we deliberately swallow errors here rather than losing the queued row.
    try {
      await BackgroundSyncManager.instance.scheduleOneOffUpload();
    } catch (e) {
      developer.log('Could not schedule immediate sync: $e',
          name: 'ImageService');
    }
    return id;
  }

  /// Uploads the file at [localPath] as multipart field `image`.
  /// Returns `true` only on HTTP 200/201. Never throws — every failure mode
  /// (missing file, timeout, server error, network failure) resolves to
  /// `false` so the caller treats it as "retry later".
  Future<bool> uploadImageFile(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      developer.log('Local file missing, cannot upload: $localPath',
          name: 'ImageService');
      return false;
    }

    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          localPath,
          filename: p.basename(localPath),
        ),
      });

      final response = await _dio.post(
        kImageUploadUrl,
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final success = response.statusCode == 200 || response.statusCode == 201;
      if (!success) {
        developer.log('Upload rejected with status ${response.statusCode}',
            name: 'ImageService');
      }
      return success;
    } on DioException catch (e) {
      // Covers connection timeout, send/receive timeout, network failure
      // and non-2xx server responses (DioException.response is non-null
      // for the latter) — all of them just mean "try again later".
      developer.log('Upload failed: ${e.message}',
          name: 'ImageService', error: e);
      return false;
    } catch (e, st) {
      developer.log('Unexpected upload error: $e',
          name: 'ImageService', error: e, stackTrace: st);
      return false;
    }
  }

  /// Runs one full pass over the pending queue: claim -> upload -> cleanup.
  /// Safe to call concurrently from multiple entry points (immediate sync,
  /// periodic task) because `markAsUploading` only succeeds for the worker
  /// that actually wins the pending->uploading transition.
  Future<void> processPendingUploads() async {
    await _db.resetStuckUploadingToPending();
    final pending = await _db.getPendingUploads();

    for (final record in pending) {
      final claimed = await _db.markAsUploading(record.id);
      if (!claimed) {
        // Another worker already claimed this row between our SELECT and
        // UPDATE — skip it rather than upload it twice.
        continue;
      }

      final success = await uploadImageFile(record.localPath);

      if (success) {
        // Delete the file first: if the row delete somehow failed after a
        // successful file delete, the worst case is a harmless leftover
        // row pointing at a file that no longer exists. The reverse order
        // (DB delete then file delete failing) would silently leak the
        // file forever with no record of it ever existing.
        await _deleteLocalFileSafely(record.localPath);
        await _db.deleteUploadRecord(record.id);
        developer.log('Upload #${record.id} complete, row removed',
            name: 'ImageService');
      } else {
        await _db.markAsPendingAndIncrementRetry(record.id);
        developer.log(
            'Upload #${record.id} failed, will retry (attempt ${record.retryCount + 1})',
            name: 'ImageService');
      }
    }
  }

  Future<void> _deleteLocalFileSafely(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // A failed delete must never block removing the DB row — the upload
      // already succeeded server-side; a leftover local file is just a
      // harmless bit of disk usage, not a correctness problem.
      developer.log('Failed to delete local file $localPath: $e',
          name: 'ImageService');
    }
  }
}
