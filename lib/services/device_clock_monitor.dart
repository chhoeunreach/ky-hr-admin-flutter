import 'dart:async';

import 'package:cnattendance/services/device_clock_service.dart';

/// Background monitor for the device-clock-vs-server check.
///
/// Checks run quietly in the background (no dialogs, no loading overlays),
/// are throttled by [freshWindow] and cached so callers can read
/// [latest] without ever waiting on the network. The server hit itself is a
/// quick check ([DeviceClockService] uses a short timeout).
class DeviceClockMonitor {
  DeviceClockMonitor({DeviceClockService? service, Duration? freshWindow})
      : _service = service ?? DeviceClockService(),
        _freshWindow = freshWindow ?? const Duration(minutes: 2);

  static final DeviceClockMonitor instance = DeviceClockMonitor();

  final DeviceClockService _service;
  final Duration _freshWindow;
  final StreamController<DeviceClockCheck> _controller =
      StreamController<DeviceClockCheck>.broadcast();

  DeviceClockCheck? _latest;
  DateTime? _checkedAt;
  Future<DeviceClockCheck?>? _inFlight;
  Timer? _timer;

  /// Last known check, may be null before the first background check lands.
  DeviceClockCheck? get latest => _latest;

  DateTime? get checkedAt => _checkedAt;

  /// Emits every check result (correct / incorrect / unavailable).
  Stream<DeviceClockCheck> get results => _controller.stream;

  bool isFresh({Duration? staleAfter}) {
    final checkedAt = _checkedAt;
    if (checkedAt == null) return false;
    return DateTime.now().difference(checkedAt) < (staleAfter ?? _freshWindow);
  }

  /// Starts periodic background checks and runs the first one right away.
  void start({Duration interval = const Duration(minutes: 5)}) {
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Returns the cached result when still fresh, otherwise triggers a quick
  /// background check against the server. Never throws.
  ///
  /// Set [staleAfter] to require a younger cached result (e.g. before an
  /// attendance submit), or [force] to always re-check the server.
  Future<DeviceClockCheck?> refresh(
      {bool force = false, Duration? staleAfter}) {
    if (!force && isFresh(staleAfter: staleAfter)) {
      return Future.value(_latest);
    }
    return _inFlight ??= _runCheck();
  }

  /// Forces a quick server check right now (reuses an in-flight one).
  Future<DeviceClockCheck?> checkNow() => refresh(force: true);

  Future<DeviceClockCheck?> _runCheck() async {
    try {
      final result = await _service.check();
      _latest = result;
      _checkedAt = DateTime.now();
      if (!_controller.isClosed) _controller.add(result);
      return result;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
    _service.dispose();
  }
}
