import 'package:cnattendance/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('insert -> claim -> success path removes the row', () async {
    final db = DatabaseHelper.instance;
    final id = await db.insertUpload('/tmp/fake_image_1.jpg');

    final pendingBefore = await db.getPendingUploads();
    expect(pendingBefore.any((r) => r.id == id), isTrue);

    final claimed = await db.markAsUploading(id);
    expect(claimed, isTrue);

    // A second claim attempt on the same row must fail — this is the
    // duplicate-upload guard.
    final claimedAgain = await db.markAsUploading(id);
    expect(claimedAgain, isFalse);

    final pendingAfterClaim = await db.getPendingUploads();
    expect(pendingAfterClaim.any((r) => r.id == id), isFalse);

    await db.deleteUploadRecord(id);
    final pendingAfterDelete = await db.getPendingUploads();
    expect(pendingAfterDelete.any((r) => r.id == id), isFalse);
  });

  test('failed upload resets to pending and increments retry_count', () async {
    final db = DatabaseHelper.instance;
    final id = await db.insertUpload('/tmp/fake_image_2.jpg');

    await db.markAsUploading(id);
    await db.markAsPendingAndIncrementRetry(id);

    final pending = await db.getPendingUploads();
    final record = pending.firstWhere((r) => r.id == id);
    expect(record.status, UploadStatus.pending);
    expect(record.retryCount, 1);

    await db.deleteUploadRecord(id);
  });

  test('resetStuckUploadingToPending recovers rows older than staleAfter',
      () async {
    final db = DatabaseHelper.instance;
    final id = await db.insertUpload('/tmp/fake_image_3.jpg');
    await db.markAsUploading(id);

    // Force the row to look old by resetting with a zero-length staleAfter.
    await db.resetStuckUploadingToPending(staleAfter: Duration.zero);

    final pending = await db.getPendingUploads();
    expect(pending.any((r) => r.id == id), isTrue);

    await db.deleteUploadRecord(id);
  });
}
