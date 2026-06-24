import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Valid values for the `status` column of the `image_uploads` table.
class UploadStatus {
  static const String pending = 'pending';
  static const String uploading = 'uploading';
}

class ImageUploadRecord {
  final int id;
  final String localPath;
  final String status;
  final int retryCount;
  final String createdAt;
  final String updatedAt;

  ImageUploadRecord({
    required this.id,
    required this.localPath,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImageUploadRecord.fromMap(Map<String, dynamic> map) {
    return ImageUploadRecord(
      id: map['id'] as int,
      localPath: map['local_path'] as String,
      status: map['status'] as String,
      retryCount: map['retry_count'] as int? ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }
}

/// Singleton wrapper around the local `image_uploads` queue table.
///
/// This table tracks every image that has been compressed and saved
/// locally but not yet confirmed uploaded to the server. A row is only
/// removed once the server has acknowledged the upload (HTTP 200/201) and
/// the local file has been deleted.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'image_uploads.db';
  static const int _dbVersion = 1;
  static const String table = 'image_uploads';

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await initDatabase();
    return _db!;
  }

  Future<Database> initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_path TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      },
    );
  }

  String _now() => DateTime.now().toIso8601String();

  /// Inserts a new `pending` row for [localPath]. Returns the new row id.
  Future<int> insertUpload(String localPath) async {
    try {
      final db = await _database;
      final now = _now();
      final id = await db.insert(table, {
        'local_path': localPath,
        'status': UploadStatus.pending,
        'retry_count': 0,
        'created_at': now,
        'updated_at': now,
      });
      developer.log('Queued upload #$id for $localPath', name: 'DatabaseHelper');
      return id;
    } catch (e, st) {
      developer.log('insertUpload failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns every row currently in `pending` status, oldest first.
  Future<List<ImageUploadRecord>> getPendingUploads() async {
    try {
      final db = await _database;
      final rows = await db.query(
        table,
        where: 'status = ?',
        whereArgs: [UploadStatus.pending],
        orderBy: 'created_at ASC',
      );
      return rows.map(ImageUploadRecord.fromMap).toList();
    } catch (e, st) {
      developer.log('getPendingUploads failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
      return [];
    }
  }

  /// Atomically claims a row by flipping it from `pending` to `uploading`.
  /// The `WHERE status = pending` clause is the guard against two workers
  /// uploading the same file: only the caller whose UPDATE actually matched
  /// a pending row gets `true` back and should proceed with the upload.
  Future<bool> markAsUploading(int id) async {
    try {
      final db = await _database;
      final count = await db.update(
        table,
        {'status': UploadStatus.uploading, 'updated_at': _now()},
        where: 'id = ? AND status = ?',
        whereArgs: [id, UploadStatus.pending],
      );
      return count > 0;
    } catch (e, st) {
      developer.log('markAsUploading failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
      return false;
    }
  }

  /// Upload failed: put the row back to `pending` and bump `retry_count` so
  /// it gets retried on the next sync pass instead of being lost.
  Future<void> markAsPendingAndIncrementRetry(int id) async {
    try {
      final db = await _database;
      await db.rawUpdate(
        'UPDATE $table SET status = ?, retry_count = retry_count + 1, updated_at = ? WHERE id = ?',
        [UploadStatus.pending, _now(), id],
      );
    } catch (e, st) {
      developer.log('markAsPendingAndIncrementRetry failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
    }
  }

  /// Upload succeeded and the local file has already been deleted by the
  /// caller — remove the row, there's nothing left to track.
  Future<void> deleteUploadRecord(int id) async {
    try {
      final db = await _database;
      await db.delete(table, where: 'id = ?', whereArgs: [id]);
    } catch (e, st) {
      developer.log('deleteUploadRecord failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
    }
  }

  /// Safety net for app/process kills mid-upload: any row left in
  /// `uploading` for longer than [staleAfter] almost certainly belongs to a
  /// worker that died before it could mark success or failure. Reset it
  /// back to `pending` so it gets picked up again instead of being stuck.
  Future<void> resetStuckUploadingToPending({
    Duration staleAfter = const Duration(minutes: 10),
  }) async {
    try {
      final db = await _database;
      final cutoff = DateTime.now().subtract(staleAfter).toIso8601String();
      final count = await db.update(
        table,
        {'status': UploadStatus.pending},
        where: 'status = ? AND updated_at < ?',
        whereArgs: [UploadStatus.uploading, cutoff],
      );
      if (count > 0) {
        developer.log('Reset $count stuck uploading row(s) to pending',
            name: 'DatabaseHelper');
      }
    } catch (e, st) {
      developer.log('resetStuckUploadingToPending failed: $e',
          name: 'DatabaseHelper', error: e, stackTrace: st);
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
