import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'image_service.dart';

const String kUploadTaskName = 'offline_image_upload_task';
const String kPeriodicUploadTaskName = 'offline_image_upload_periodic_task';

/// Entry point Workmanager calls in its own background isolate (Android) /
/// background execution context (iOS). Must stay a top-level function with
/// the `vm:entry-point` pragma — Workmanager cannot invoke closures or
/// instance methods here because this code runs outside the main isolate.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        developer.log('No connectivity, skipping upload pass',
            name: 'BackgroundSync');
        return true; // not a failure — just nothing to do right now
      }
      await ImageService().processPendingUploads();
      return true;
    } catch (e, st) {
      developer.log('Background sync task failed: $e',
          name: 'BackgroundSync', error: e, stackTrace: st);
      // Returning false tells Workmanager to retry with its own backoff.
      return false;
    }
  });
}

/// Thin wrapper around Workmanager for scheduling upload-queue sync passes.
///
/// iOS note: background execution time is opportunistic and not guaranteed
/// (BGTaskScheduler), so the one-off "upload now" task is a best-effort
/// nudge, not a guarantee of immediate upload — the queue + retry/backoff
/// design in [DatabaseHelper] is what actually guarantees delivery
/// eventually, not the scheduling call itself.
class BackgroundSyncManager {
  BackgroundSyncManager._internal();
  static final BackgroundSyncManager instance =
      BackgroundSyncManager._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
    _initialized = true;
  }

  /// Fires once, as soon as the constraints (network) are met. Call this
  /// right after queueing a new image so it uploads promptly instead of
  /// waiting for the next periodic tick.
  Future<void> scheduleOneOffUpload() async {
    await Workmanager().registerOneOffTask(
      kUploadTaskName,
      kUploadTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Optional periodic safety-net sync — catches anything the one-off tasks
  /// missed (e.g. the app was killed before a one-off task could run).
  /// Android enforces a 15-minute minimum interval for periodic tasks.
  Future<void> schedulePeriodicUpload() async {
    await Workmanager().registerPeriodicTask(
      kPeriodicUploadTaskName,
      kPeriodicUploadTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> cancelAll() => Workmanager().cancelAll();
}
