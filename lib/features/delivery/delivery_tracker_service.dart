import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'delivery_api.dart';

class DeliveryTrackerService {
  DeliveryTrackerService._();
  static final DeliveryTrackerService instance = DeliveryTrackerService._();

  static const String _prefActiveDeliveryIdKey = 'ky_active_delivery_id';

  final DeliveryApi _api = DeliveryApi();
  Timer? _timer;
  int? _activeDeliveryId;
  bool _isPinging = false;
  Position? _lastPingedPosition;
  DateTime? _lastPingTime;

  final ValueNotifier<Position?> currentPosition = ValueNotifier<Position?>(null);
  final ValueNotifier<bool> isTracking = ValueNotifier<bool>(false);

  int? get activeDeliveryId => _activeDeliveryId;

  /// Start periodic GPS pinging for an active delivery
  Future<bool> startTracking(int deliveryId) async {
    _activeDeliveryId = deliveryId;
    _lastPingedPosition = null;
    _lastPingTime = null;
    isTracking.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefActiveDeliveryIdKey, deliveryId);

    // Initial immediate ping
    await _sendPing();

    // Start 15s interval timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _sendPing();
    });

    return true;
  }

  /// Stop tracking immediately (on completion or cancellation)
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    _activeDeliveryId = null;
    _lastPingedPosition = null;
    _lastPingTime = null;
    isTracking.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefActiveDeliveryIdKey);
  }

  /// Check if there was an active delivery saved from previous session
  Future<int?> getSavedActiveDeliveryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefActiveDeliveryIdKey);
  }

  Future<void> _sendPing() async {
    if (_activeDeliveryId == null || _isPinging) return;
    _isPinging = true;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      currentPosition.value = position;

      // Thermal & Battery Optimization:
      // If driver hasn't moved at least 10 meters and last ping was less than 45 seconds ago,
      // skip cellular transmission to prevent modem overheating and battery drain.
      final now = DateTime.now();
      final hasMoved = _lastPingedPosition == null ||
          Geolocator.distanceBetween(
                _lastPingedPosition!.latitude,
                _lastPingedPosition!.longitude,
                position.latitude,
                position.longitude,
              ) >= 10.0;

      final forceHeartbeat = _lastPingTime == null ||
          now.difference(_lastPingTime!).inSeconds >= 45;

      if (!hasMoved && !forceHeartbeat) {
        return;
      }

      if (_activeDeliveryId != null) {
        final success = await _api.pingLocation(
          deliveryId: _activeDeliveryId!,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed,
        );

        if (success) {
          _lastPingedPosition = position;
          _lastPingTime = now;
        }
      }
    } catch (e) {
      debugPrint('GPS Ping Error: $e');
    } finally {
      _isPinging = false;
    }
  }
}
