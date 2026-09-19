import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/services/attendance_sync_service.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/attendance_selfie_camera.dart';
import 'package:cnattendance/widget/attendance_bottom_sheet.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/customnfcdialog.dart';
import 'package:cnattendance/widget/profile/note_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

// import 'package:qr_bar_code_scanner_dialog/qr_bar_code_scanner_dialog.dart';

import '../customqrscanner.dart';

class CheckAttendance extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CheckAttendanceState();
}

class CheckAttendanceState extends State<CheckAttendance>
    with SingleTickerProviderStateMixin {
  static const Duration _zoneRefreshInterval = Duration(minutes: 1);

  late final AnimationController _pulseController;
  late final Timer _clockTimer;
  final TransformationController _mapTransformationController =
      TransformationController();
  DateTime _now = DateTime.now();
  bool _isRefreshingZone = false;
  double? _zoneDistanceMeters;
  String? _zoneError;
  DateTime? _lastZoneRefreshAt;
  String formattedDate =
      DateFormat('EEEE , MMMM d , yyyy').format(DateTime.now());
  String nepaliFormattedDate =
      NepaliDateFormat('EEE , MMMM d , yyyy').format(NepaliDateTime.now());

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapTransformationController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  double _contrastRatio(Color first, Color second) {
    final firstLum = first.computeLuminance();
    final secondLum = second.computeLuminance();
    final lighter = firstLum > secondLum ? firstLum : secondLum;
    final darker = firstLum > secondLum ? secondLum : firstLum;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _readableColor(Color background, Color preferred, Color fallback) {
    return _contrastRatio(background, preferred) >=
            _contrastRatio(background, fallback)
        ? preferred
        : fallback;
  }

  Widget _attendanceIcon({
    required String attendanceType,
    required bool repeat,
    required Color color,
  }) {
    return Lottie.asset(
      attendanceType == "QR"
          ? 'assets/raw/qr.json'
          : attendanceType == "NFC"
              ? 'assets/raw/nfc.json'
              : 'assets/raw/fingerprint.json',
      width: 60,
      height: 60,
      repeat: repeat,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.colorFilter(
            ['**'],
            value: ColorFilter.mode(color, BlendMode.srcATop),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshZoneStatus({bool force = false}) async {
    if (!mounted || _isRefreshingZone) return;

    final provider = context.read<DashboardProvider>();
    final hasWorkspace = provider.effectiveWorkspaceRadiusMeters != null;
    if (!hasWorkspace) {
      if (_zoneDistanceMeters != null || _zoneError != null) {
        setState(() {
          _zoneDistanceMeters = null;
          _zoneError = null;
          _lastZoneRefreshAt = null;
        });
      }
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastZoneRefreshAt != null &&
        now.difference(_lastZoneRefreshAt!) < _zoneRefreshInterval) {
      return;
    }

    setState(() {
      _isRefreshingZone = true;
      _zoneError = null;
    });

    try {
      final distance = await provider.getWorkspaceDistanceMeters();
      if (!mounted) return;
      setState(() {
        _zoneDistanceMeters = distance;
        _zoneError = distance == null
            ? translate('attendance_messages.zone_unavailable')
            : null;
        _lastZoneRefreshAt = DateTime.now();
        _isRefreshingZone = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _zoneDistanceMeters = null;
        _zoneError = translate('attendance_messages.zone_unavailable');
        _lastZoneRefreshAt = DateTime.now();
        _isRefreshingZone = false;
      });
    }
  }

  Future<bool> _ensureWithinScanDistanceIfPossible() async {
    final provider = context.read<DashboardProvider>();
    if (!provider.isWorkspaceRadiusEnabled) {
      return true;
    }
    try {
      final distance = await provider.getWorkspaceDistanceMeters(
        forceHighAccuracy: true,
      );
      if (!mounted) return false;

      final accuracy = provider.currentLocationAccuracyMeters;
      if (accuracy != null &&
          accuracy > DashboardProvider.scanAttendanceMaxAccuracyMeters) {
        _showAttendanceWarning(
          translate('attendance_messages.gps_accuracy_warning')
              .replaceAll('{accuracy}', accuracy.toStringAsFixed(2))
              .replaceAll(
                '{allowed}',
                DashboardProvider.scanAttendanceMaxAccuracyMeters
                    .toStringAsFixed(0),
              ),
        );
        return false;
      }

      if (distance == null) {
        return true;
      }

      final allowedDistance =
          provider.effectiveWorkspaceRadiusMeters ?? distance;

      if (distance > allowedDistance) {
        _showAttendanceWarning(
          translate('attendance_messages.outside_scan_radius')
              .replaceAll('{distance}', distance.toStringAsFixed(2))
              .replaceAll('{allowed}', allowedDistance.toStringAsFixed(0)),
        );
        return false;
      }

      return true;
    } catch (_) {
      if (!mounted) return false;
      _showAttendanceWarning(
        translate('attendance_messages.gps_unavailable_warning'),
      );
      return false;
    }
  }

  void _showAttendanceWarning(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: CustomAlertDialog(message),
        );
      },
    );
  }

  String _formatMeters(double meters) {
    return meters.toStringAsFixed(meters >= 100 ? 0 : 1);
  }

  String _formatCoordinate(double? coordinate) {
    if (coordinate == null || coordinate == 0) {
      return '-';
    }
    return coordinate.toStringAsFixed(6);
  }

  String _zoneMessage(String key, double distance, double allowedDistance) {
    return translate(key)
        .replaceAll('{distance}', _formatMeters(distance))
        .replaceAll('{allowed}', _formatMeters(allowedDistance));
  }

  void _zoomAttendanceMap(double factor) {
    final currentScale = _mapTransformationController.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(1.0, 3.0).toDouble();
    _mapTransformationController.value = Matrix4.identity()
      ..scaleByDouble(nextScale, nextScale, 1, 1);
  }

  Widget? _buildZoneStatusCard({
    required DashboardProvider provider,
    required EnterpriseTheme enterprise,
  }) {
    if (!provider.isAttendanceMapEnabled ||
        !provider.isWorkspaceRadiusEnabled) {
      return null;
    }

    final allowedDistance = provider.effectiveWorkspaceRadiusMeters ??
        provider.workspaceRadiusMeters ??
        100;
    final hasBranchLocation = provider.workspaceLatitude != null &&
        provider.workspaceLongitude != null;

    final distance =
        _zoneDistanceMeters ?? provider.lastWorkspaceDistanceMeters;
    final hasDistance =
        hasBranchLocation && distance != null && _zoneError == null;
    final isInZone = hasDistance && distance <= allowedDistance;
    final currentLatitude = provider.locationStatus['latitude'];
    final currentLongitude = provider.locationStatus['longitude'];
    final hasCurrentLocation = currentLatitude != null &&
        currentLongitude != null &&
        currentLatitude != 0 &&
        currentLongitude != 0;
    final statusColor = _isRefreshingZone
        ? enterprise.secondary
        : hasDistance
            ? (isInZone ? Colors.green.shade600 : Colors.redAccent)
            : enterprise.secondary;
    final title = !hasBranchLocation
        ? translate('attendance_messages.branch_location_missing')
        : _isRefreshingZone
            ? translate('attendance_messages.zone_checking')
            : hasDistance
                ? translate(isInZone
                    ? 'attendance_messages.scan_available'
                    : 'attendance_messages.scan_not_available')
                : (_zoneError ??
                    translate('attendance_messages.zone_unavailable'));
    final detail = !hasBranchLocation
        ? translate('attendance_messages.branch_location_missing_detail')
        : hasDistance
            ? _zoneMessage(
                isInZone
                    ? 'attendance_messages.zone_in_detail'
                    : 'attendance_messages.zone_out_detail',
                distance,
                allowedDistance,
              )
            : translate('attendance_messages.zone_unavailable_detail');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: EnterpriseGlass(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        radius: 12,
        glowColor: statusColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInZone
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enterprise.mutedText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: translate('attendance_messages.refresh_zone'),
                    onPressed: _isRefreshingZone
                        ? null
                        : () => _refreshZoneStatus(force: true),
                    icon: _isRefreshingZone
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          )
                        : Icon(Icons.refresh_rounded,
                            color: statusColor, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 126,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: hasBranchLocation
                    ? _AttendanceGoogleMapFrame(
                        branchLatitude: provider.workspaceLatitude!,
                        branchLongitude: provider.workspaceLongitude!,
                        currentLatitude:
                            hasCurrentLocation ? currentLatitude : null,
                        currentLongitude:
                            hasCurrentLocation ? currentLongitude : null,
                        configuredMapUrl: provider.attendanceMapUrl,
                        enterprise: enterprise,
                      )
                    : Stack(
                        children: [
                          InteractiveViewer(
                            transformationController:
                                _mapTransformationController,
                            minScale: 1,
                            maxScale: 3,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: CustomPaint(
                              painter: _AttendanceZoneMapPainter(
                                branchLatitude: provider.workspaceLatitude,
                                branchLongitude: provider.workspaceLongitude,
                                currentLatitude:
                                    hasCurrentLocation ? currentLatitude : null,
                                currentLongitude: hasCurrentLocation
                                    ? currentLongitude
                                    : null,
                                allowedDistanceMeters: allowedDistance,
                                distanceMeters: distance,
                                inZone: isInZone,
                                mapBackground: enterprise.isDark
                                    ? const Color(0xFF142233)
                                    : const Color(0xFFEAF3F6),
                                branchColor: enterprise.primary,
                                currentColor: statusColor,
                                radiusColor:
                                    statusColor.withValues(alpha: 0.28),
                                textColor: enterprise.text,
                                mutedTextColor: enterprise.mutedText,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _MapZoomControls(
                              enterprise: enterprise,
                              onZoomIn: () => _zoomAttendanceMap(1.25),
                              onZoomOut: () => _zoomAttendanceMap(0.8),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 6),
            _ZoneParameterGrid(
              children: [
                _ZoneParameterItem(
                  icon: Icons.social_distance_rounded,
                  label: translate('attendance_messages.distance_from_branch'),
                  value: hasDistance
                      ? '${_formatMeters(distance)} m'
                      : translate('attendance_messages.zone_checking'),
                  color: statusColor,
                ),
                _ZoneParameterItem(
                  icon: Icons.radio_button_checked_rounded,
                  label: translate('attendance_messages.allowed_radius'),
                  value: '${_formatMeters(allowedDistance)} m',
                  color: enterprise.secondary,
                ),
                _ZoneParameterItem(
                  icon: Icons.business_rounded,
                  label: translate('attendance_messages.branch_gps'),
                  value:
                      '${_formatCoordinate(provider.workspaceLatitude)}, ${_formatCoordinate(provider.workspaceLongitude)}',
                  color: enterprise.primary,
                ),
                _ZoneParameterItem(
                  icon: Icons.my_location_rounded,
                  label: translate('attendance_messages.device_gps'),
                  value:
                      '${_formatCoordinate(currentLatitude)}, ${_formatCoordinate(currentLongitude)}',
                  color: statusColor,
                ),
                if (provider.currentLocationAccuracyMeters != null)
                  _ZoneParameterItem(
                    icon: Icons.gps_fixed_rounded,
                    label: translate('attendance_messages.gps_accuracy'),
                    value:
                        '${_formatMeters(provider.currentLocationAccuracyMeters!)} m',
                    color: enterprise.accent,
                  ),
              ],
              enterprise: enterprise,
            ),
          ],
        ),
      ),
    );
  }

  void showNFCScanner() {
    if (Platform.isAndroid) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomNfcDialog(NFCMODE.scan),
          );
        },
      );
    }

    if (Platform.isIOS) {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          onAttendanceVerify(
              "nfc", base64.encode(utf8.encode(findKey(tag.data))));
          NfcManager.instance.stopSession();
        },
      );
    }
  }

  Future<void> scanQr() async {
    final ok = await _ensureWithinScanDistanceIfPossible();
    if (!ok) return;

    final result = await showCustomQrScanner(context);
    if (result != null && result.trim().isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final provider = context.read<DashboardProvider>();
      final selfie = provider.isAttendanceSelfieEnabled
          ? await _captureAttendanceSelfie()
          : null;
      if (provider.isAttendanceSelfieEnabled && selfie == null) {
        showToast(translate('attendance_messages.selfie_required'));
        return;
      }

      if (provider.isNoteEnabled) {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (context) {
              return NoteBottomSheet(
                result,
                "qr",
                attendanceSelfie: selfie,
              );
            });
      } else {
        onAttendanceVerify("qr", result, attendanceSelfie: selfie);
      }
    }
  }

  Future<File?> _captureAttendanceSelfie() async {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AttendanceSelfieCamera(),
      ),
    );
  }

  bool isWithinRadius(double lat1, double lon1, double lat2, double lon2,
      double radiusInMeters) {
    final distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distance <= radiusInMeters;
  }

  void onAttendanceVerify(String type, String identifier,
      {File? attendanceSelfie}) async {
    final provider = context.read<DashboardProvider>();
    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    try {
      if (type == "qr" || type == "nfc") {
        final ok = await _ensureWithinScanDistanceIfPossible();
        if (!ok) return;
      }

      EasyLoading.show(
          status: translate('loader.requesting'),
          maskType: EasyLoadingMaskType.black);
      final response = await provider.verifyAttendanceApi(
        type,
        "",
        identifier: identifier,
        attendanceSelfie: attendanceSelfie,
        offlineRequestId: offlineRequestId,
        recordedAt: recordedAt,
      );
      if (!mounted) return;
      EasyLoading.dismiss(animation: true);

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(response.message),
          );
        },
      );
    } catch (e) {
      final message = e.toString();
      if (_isOfflineQueueableError(e)) {
        await _queueOfflineAttendance(
          syncService: syncService,
          provider: provider,
          type: type,
          identifier: identifier,
          note: "",
          attendanceSelfie: attendanceSelfie,
          offlineRequestId: offlineRequestId,
          recordedAt: recordedAt,
        );
        if (!mounted) return;
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(
                translate('attendance_messages.saved_offline'),
              ),
            );
          },
        );
        return;
      }

      final extra = await provider.buildWorkspaceDistanceInfoIfNeeded(message);
      if (!mounted) return;
      EasyLoading.dismiss(animation: true);
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(
                extra == null ? message : '$message\n\n$extra'),
          );
        },
      );
    }
  }

  bool _isOfflineQueueableError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains("failed host lookup") ||
        message.contains("connection refused") ||
        message.contains("connection timed out") ||
        message.contains("network is unreachable") ||
        message.contains("software caused connection abort") ||
        message.contains("connection reset");
  }

  Future<void> _queueOfflineAttendance({
    required AttendanceSyncService syncService,
    required DashboardProvider provider,
    required String type,
    required String identifier,
    required String note,
    required File? attendanceSelfie,
    required String offlineRequestId,
    required DateTime recordedAt,
  }) async {
    await provider.getCheckInStatus();
    await syncService.queueAttendance(
      attendanceType: type,
      identifier: identifier,
      attendanceStatusType: "",
      note: note,
      latitude: provider.locationStatus['latitude'].toString(),
      longitude: provider.locationStatus['longitude'].toString(),
      routerBssid: "",
      selfie: attendanceSelfie,
      offlineRequestId: offlineRequestId,
      recordedAt: recordedAt,
    );
  }

  Future<void> _handleAttendanceTap(String attandanceType) async {
    if (attandanceType == "QR") {
      scanQr();
    } else if (attandanceType == "NFC") {
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        showToast(
            "NFC is not present. Please enable NFC or try different method");
        return;
      }
      showNFCScanner();
    } else {
      showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) {
            return AttedanceBottomSheet();
          });
    }
  }

  Widget _buildClock(EnterpriseTheme enterprise, bool isAD) {
    final hourMinute = DateFormat('HH:mm').format(_now);
    final period = DateFormat('a').format(_now);
    final seconds = DateFormat('ss').format(_now);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Column(
        key: ValueKey(seconds),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  period,
                  style: TextStyle(
                    color: enterprise.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hourMinute,
                style: TextStyle(
                  color: enterprise.text,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  seconds,
                  style: TextStyle(
                    color: enterprise.text.withValues(alpha: 0.84),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAD ? formattedDate : nepaliFormattedDate,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enterprise.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceControl({
    required EnterpriseTheme enterprise,
    required String attandanceType,
    required bool animated,
    required bool isCheckedIn,
  }) {
    final diameter =
        MediaQuery.sizeOf(context).shortestSide >= 600 ? 190.0 : 168.0;
    final qrCircleColor = isCheckedIn ? enterprise.accent : enterprise.primary;
    final qrIconColor =
        _readableColor(qrCircleColor, Colors.white, Colors.black);

    return RepaintBoundary(
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = animated ? _pulseController.value : 0.0;
            final spread = 5 + (pulse * 18);
            final ringOpacity = animated ? 0.32 - (pulse * 0.18) : 0.22;
            return Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: qrCircleColor.withValues(alpha: ringOpacity),
                    blurRadius: 34 + (pulse * 18),
                    spreadRadius: spread,
                  ),
                  BoxShadow(
                    color: enterprise.accent.withValues(alpha: 0.20),
                    blurRadius: 46,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + (pulse * 0.10),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: qrCircleColor.withValues(alpha: ringOpacity),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: enterprise.accent.withValues(alpha: 0.42),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: enterprise.accent.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          enterprise.accent,
                          qrCircleColor,
                          enterprise.secondary,
                          enterprise.accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: qrCircleColor.withValues(alpha: 0.26),
                          blurRadius: 26,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: enterprise.isDark ? 0.18 : 0.70),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(
                              alpha: enterprise.isDark ? 0.18 : 0.74),
                          qrCircleColor.withValues(
                              alpha: enterprise.isDark ? 0.36 : 0.18),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: enterprise.isDark ? 0.20 : 0.82),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _handleAttendanceTap(attandanceType),
                      child: SizedBox(
                        width: diameter - 58,
                        height: diameter - 58,
                        child: Center(
                          child: _attendanceIcon(
                            attendanceType: attandanceType,
                            repeat: animated,
                            color: qrIconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _attendanceAvailabilityMessage(List<String> attendanceMethods) {
    final methods =
        attendanceMethods.map((method) => method.toLowerCase()).toList();

    if (methods.isEmpty) {
      return translate('attendance_messages.attendance_not_available');
    }

    if (!methods.contains("qr")) {
      return translate('attendance_messages.qr_scan_disabled');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final attendanceList = dashboardProvider.attendanceList;
    final attandanceType = context.watch<PrefProvider>().attendanceType;
    final isAD = dashboardProvider.isAD;
    final attendanceMethod = dashboardProvider.attendanceMethods;
    final animated = dashboardProvider.animated;
    final enterprise = EnterpriseTheme.of(context);
    final isCheckedIn =
        attendanceList['check-in'] != "-" && attendanceList['check-out'] == "-";
    final panelTextColor = enterprise.text;
    final progressBackgroundColor = enterprise.text.withValues(alpha: 0.14);
    final productionProgressColor =
        isCheckedIn ? enterprise.accent : enterprise.secondary;
    final attendanceMessage = _attendanceAvailabilityMessage(attendanceMethod);
    final zoneStatusCard = _buildZoneStatusCard(
      provider: dashboardProvider,
      enterprise: enterprise,
    );
    if (zoneStatusCard != null &&
        dashboardProvider.effectiveWorkspaceRadiusMeters != null &&
        !_isRefreshingZone &&
        _lastZoneRefreshAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshZoneStatus();
      });
    }
    context.read<PrefProvider>().getAttendanceType(attendanceMethod);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildClock(enterprise, isAD),
          const SizedBox(height: 10),
          if (attendanceMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EnterpriseGlass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                radius: 12,
                glowColor: enterprise.secondary,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: enterprise.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attendanceMessage,
                        style: TextStyle(
                          color: panelTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (attendanceMethod.isNotEmpty)
            _buildAttendanceControl(
              enterprise: enterprise,
              attandanceType: attandanceType,
              animated: animated,
              isCheckedIn: isCheckedIn,
            ),
          if (attendanceMethod.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "${translate('home_screen.check_in')} | ${translate('home_screen.check_out')}",
                style: TextStyle(
                  color: panelTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (zoneStatusCard != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: zoneStatusCard,
            ),
          const SizedBox(height: 8),
          EnterpriseGlass(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            radius: 14,
            glowColor: productionProgressColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: productionProgressColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Working Time',
                        style: TextStyle(
                          color: panelTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      attendanceList['production_hour'],
                      style: TextStyle(
                        color: panelTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearPercentIndicator(
                  animation: true,
                  animationDuration: 1000,
                  lineHeight: 9.0,
                  padding: EdgeInsets.zero,
                  percent: attendanceList['production-time']!,
                  barRadius: const Radius.circular(20),
                  backgroundColor: progressBackgroundColor,
                  linearGradient: LinearGradient(
                    colors: [productionProgressColor, enterprise.accent],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      attendanceList['check-in']!,
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      attendanceList['check-out']!,
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> checkAd() async {
    final pref = Provider.of<PrefProvider>(context);
    if (await pref.getIsAd()) {
      formattedDate = DateFormat('EEEE , MMMM d , yyyy').format(DateTime.now());
    } else {
      nepaliFormattedDate = NepaliDateFormat('EEE , MMMM d , yyyy')
          .format(DateTime.now().toNepaliDateTime());
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    checkAd();
  }
}

class _ZoneParameterItem {
  const _ZoneParameterItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _ZoneParameterGrid extends StatelessWidget {
  const _ZoneParameterGrid({
    required this.children,
    required this.enterprise,
  });

  final List<_ZoneParameterItem> children;
  final EnterpriseTheme enterprise;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 360
            ? (constraints.maxWidth - 6) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 6,
          runSpacing: 5,
          children: children.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Row(
                children: [
                  Icon(item.icon, color: item.color, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          color: enterprise.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        children: [
                          TextSpan(text: '${item.label}: '),
                          TextSpan(
                            text: item.value,
                            style: TextStyle(
                              color: enterprise.text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.enterprise,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final EnterpriseTheme enterprise;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enterprise.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: enterprise.glassStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapZoomButton(
            icon: Icons.add_rounded,
            tooltip: translate('attendance_messages.zoom_in'),
            onTap: onZoomIn,
            enterprise: enterprise,
          ),
          Container(
            width: 22,
            height: 1,
            color: enterprise.glassStroke,
          ),
          _MapZoomButton(
            icon: Icons.remove_rounded,
            tooltip: translate('attendance_messages.zoom_out'),
            onTap: onZoomOut,
            enterprise: enterprise,
          ),
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.enterprise,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final EnterpriseTheme enterprise;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 24,
          child: Icon(icon, color: enterprise.text, size: 17),
        ),
      ),
    );
  }
}

class _AttendanceGoogleMapFrame extends StatefulWidget {
  const _AttendanceGoogleMapFrame({
    required this.branchLatitude,
    required this.branchLongitude,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.configuredMapUrl,
    required this.enterprise,
  });

  final double branchLatitude;
  final double branchLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final String configuredMapUrl;
  final EnterpriseTheme enterprise;

  @override
  State<_AttendanceGoogleMapFrame> createState() =>
      _AttendanceGoogleMapFrameState();
}

class _AttendanceGoogleMapFrameState extends State<_AttendanceGoogleMapFrame>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  String? _lastMapUrl;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );
    _loadMap();
  }

  @override
  void didUpdateWidget(covariant _AttendanceGoogleMapFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = _mapUrl();
    if (url != _lastMapUrl) {
      _loadMap(url);
    }
  }

  String _mapUrl() {
    final configuredUrl = _normalizeConfiguredMapUrl(widget.configuredMapUrl);
    if (configuredUrl != null) {
      return configuredUrl;
    }

    final branchLatitude = _formatMapCoordinate(widget.branchLatitude);
    final branchLongitude = _formatMapCoordinate(widget.branchLongitude);
    final hasCurrentLocation =
        widget.currentLatitude != null && widget.currentLongitude != null;
    if (hasCurrentLocation) {
      final currentLatitude = _formatMapCoordinate(widget.currentLatitude!);
      final currentLongitude = _formatMapCoordinate(widget.currentLongitude!);
      return 'https://maps.google.com/maps'
          '?f=d'
          '&saddr=$currentLatitude,$currentLongitude'
          '&daddr=$branchLatitude,$branchLongitude'
          '&hl=en'
          '&z=16'
          '&output=embed';
    }
    return 'https://maps.google.com/maps'
        '?q=$branchLatitude,$branchLongitude'
        '&hl=en'
        '&z=16'
        '&output=embed';
  }

  String _formatMapCoordinate(double value) => value.toStringAsFixed(5);

  String? _normalizeConfiguredMapUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }

    final isGoogleMapHost = uri.host.contains('google.') ||
        uri.host.contains('goo.gl') ||
        uri.host.contains('maps.app.goo.gl');
    if (!isGoogleMapHost) {
      return trimmed;
    }

    final hasEmbedOutput = uri.queryParameters['output'] == 'embed' ||
        uri.path.toLowerCase().contains('/embed');
    if (hasEmbedOutput) {
      return trimmed;
    }

    final query = uri.queryParameters['q'];
    if (query != null && query.trim().isNotEmpty) {
      return Uri.https('maps.google.com', '/maps', {
        'q': query,
        'hl': uri.queryParameters['hl'] ?? 'en',
        'z': uri.queryParameters['z'] ?? '16',
        'output': 'embed',
      }).toString();
    }

    return trimmed;
  }

  Future<void> _loadMap([String? nextMapUrl]) async {
    final mapUrl = nextMapUrl ?? _mapUrl();
    if (mapUrl == _lastMapUrl && !_isLoading) {
      return;
    }
    _lastMapUrl = mapUrl;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final escapedMapUrl = const HtmlEscape().convert(mapUrl);
    await _controller.loadHtmlString('''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      width: 100%;
      overflow: hidden;
      background: #eef3f6;
    }
    iframe {
      border: 0;
      height: 100%;
      width: 100%;
      display: block;
    }
  </style>
</head>
<body>
  <iframe
    src="$escapedMapUrl"
    loading="lazy"
    referrerpolicy="no-referrer-when-downgrade"
    allowfullscreen>
  </iframe>
</body>
</html>
''');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        Positioned(
          left: 7,
          top: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.enterprise.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.enterprise.glassStroke),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_rounded,
                    color: widget.enterprise.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Google Map',
                    style: TextStyle(
                      color: widget.enterprise.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          ColoredBox(
            color: widget.enterprise.surface.withValues(alpha: 0.20),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.enterprise.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceZoneMapPainter extends CustomPainter {
  const _AttendanceZoneMapPainter({
    required this.branchLatitude,
    required this.branchLongitude,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.allowedDistanceMeters,
    required this.distanceMeters,
    required this.inZone,
    required this.mapBackground,
    required this.branchColor,
    required this.currentColor,
    required this.radiusColor,
    required this.textColor,
    required this.mutedTextColor,
  });

  final double? branchLatitude;
  final double? branchLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final double allowedDistanceMeters;
  final double? distanceMeters;
  final bool inZone;
  final Color mapBackground;
  final Color branchColor;
  final Color currentColor;
  final Color radiusColor;
  final Color textColor;
  final Color mutedTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawMapBase(canvas, size);

    final branch = Offset(size.width * 0.5, size.height * 0.52);
    final current = _currentPoint(size, branch);
    final radiusPixels = _radiusPixels(size);

    final radiusPaint = Paint()
      ..color = radiusColor
      ..style = PaintingStyle.fill;
    final radiusBorderPaint = Paint()
      ..color = currentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(branch, radiusPixels, radiusPaint);
    canvas.drawCircle(branch, radiusPixels, radiusBorderPaint);

    if (current != null) {
      final routeShadowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final linePaint = Paint()
        ..color = currentColor.withValues(alpha: 0.82)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(branch, current, routeShadowPaint);
      canvas.drawLine(branch, current, linePaint);
      _drawMarker(canvas, current, currentColor, Icons.my_location_rounded);
    }

    _drawMarker(canvas, branch, branchColor, Icons.business_rounded);

    final radiusLabel = '${allowedDistanceMeters.toStringAsFixed(0)} m';
    _drawPillText(
      canvas,
      radiusLabel,
      Offset(
        (branch.dx + radiusPixels + 7).clamp(8, size.width - 62).toDouble(),
        (branch.dy - 10).clamp(8, size.height - 24).toDouble(),
      ),
      mutedTextColor,
    );

    if (distanceMeters != null && current != null) {
      _drawPillText(
        canvas,
        '${distanceMeters!.toStringAsFixed(distanceMeters! >= 100 ? 0 : 1)} m',
        Offset(
          ((branch.dx + current.dx) / 2 - 22)
              .clamp(8, size.width - 58)
              .toDouble(),
          ((branch.dy + current.dy) / 2 - 24)
              .clamp(8, size.height - 24)
              .toDouble(),
        ),
        inZone ? currentColor : currentColor,
      );
    }
  }

  void _drawMapBase(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = mapBackground);

    final waterPaint = Paint()..color = const Color(0xFFBFDDF0);
    final parkPaint = Paint()..color = const Color(0xFFCFE8CC);
    final blockPaint = Paint()..color = Colors.white.withValues(alpha: 0.54);
    final minorRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final majorRoadPaint = Paint()
      ..color = const Color(0xFFFFF1B8)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final majorRoadEdgePaint = Paint()
      ..color = const Color(0xFFE4D59C)
      ..strokeWidth = 5.8
      ..strokeCap = StrokeCap.round;

    final water = Path()
      ..moveTo(size.width * 0.74, 0)
      ..cubicTo(size.width * 0.92, size.height * 0.18, size.width * 0.78,
          size.height * 0.54, size.width, size.height * 0.72)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(water, waterPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.08,
          size.width * 0.24,
          size.height * 0.28,
        ),
        const Radius.circular(12),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.58,
          size.height * 0.58,
          size.width * 0.20,
          size.height * 0.24,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFCFE8CC).withValues(alpha: 0.78),
    );

    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.10 + i * 0.19),
            size.height * 0.48,
            size.width * 0.10,
            size.height * 0.12,
          ),
          const Radius.circular(5),
        ),
        blockPaint,
      );
    }

    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.73),
      Offset(size.width * 0.98, size.height * 0.20),
      majorRoadEdgePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.73),
      Offset(size.width * 0.98, size.height * 0.20),
      majorRoadPaint,
    );

    final roads = <List<Offset>>[
      [
        Offset(size.width * 0.10, size.height * 0.22),
        Offset(size.width * 0.90, size.height * 0.22),
      ],
      [
        Offset(size.width * 0.16, size.height * 0.92),
        Offset(size.width * 0.40, size.height * 0.10),
      ],
      [
        Offset(size.width * 0.52, size.height * 0.95),
        Offset(size.width * 0.50, size.height * 0.04),
      ],
      [
        Offset(size.width * 0.05, size.height * 0.55),
        Offset(size.width * 0.68, size.height * 0.42),
      ],
      [
        Offset(size.width * 0.64, size.height * 0.06),
        Offset(size.width * 0.92, size.height * 0.88),
      ],
    ];
    for (final road in roads) {
      canvas.drawLine(road.first, road.last, minorRoadPaint);
    }
  }

  Offset? _currentPoint(Size size, Offset branch) {
    if (branchLatitude == null ||
        branchLongitude == null ||
        currentLatitude == null ||
        currentLongitude == null) {
      return null;
    }

    const metersPerDegreeLatitude = 111320.0;
    final averageLatitude =
        ((branchLatitude! + currentLatitude!) / 2) * math.pi / 180;
    final metersPerDegreeLongitude = metersPerDegreeLatitude *
        math.cos(averageLatitude).abs().clamp(0.08, 1);
    final dx =
        (currentLongitude! - branchLongitude!) * metersPerDegreeLongitude;
    final dy = (currentLatitude! - branchLatitude!) * metersPerDegreeLatitude;
    final scale = _scale(size);
    final point = Offset(branch.dx + dx * scale, branch.dy - dy * scale);
    return Offset(
      point.dx.clamp(16, size.width - 16).toDouble(),
      point.dy.clamp(16, size.height - 16).toDouble(),
    );
  }

  double _scale(Size size) {
    final spanMeters = math.max(
      allowedDistanceMeters,
      math.max(distanceMeters ?? 0, 50),
    );
    final availableRadius = math.min(size.width, size.height) * 0.34;
    return availableRadius / spanMeters;
  }

  double _radiusPixels(Size size) {
    return (allowedDistanceMeters * _scale(size))
        .clamp(18, math.min(size.width, size.height) * 0.38)
        .toDouble();
  }

  void _drawMarker(Canvas canvas, Offset point, Color color, IconData icon) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(point + const Offset(0, 2), 12, shadowPaint);

    canvas.drawCircle(
      point,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(point, 7.5, Paint()..color = color);
    canvas.drawCircle(point, 3.2, Paint()..color = Colors.white);
  }

  void _drawPillText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        textPainter.width + 12,
        textPainter.height + 7,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    textPainter.paint(canvas, offset + const Offset(6, 3));
  }

  @override
  bool shouldRepaint(covariant _AttendanceZoneMapPainter oldDelegate) {
    return branchLatitude != oldDelegate.branchLatitude ||
        branchLongitude != oldDelegate.branchLongitude ||
        currentLatitude != oldDelegate.currentLatitude ||
        currentLongitude != oldDelegate.currentLongitude ||
        allowedDistanceMeters != oldDelegate.allowedDistanceMeters ||
        distanceMeters != oldDelegate.distanceMeters ||
        inZone != oldDelegate.inZone ||
        mapBackground != oldDelegate.mapBackground ||
        currentColor != oldDelegate.currentColor;
  }
}
