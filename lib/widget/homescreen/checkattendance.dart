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
  Timer? _zoneTimer;
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
    _zoneTimer = Timer.periodic(_zoneRefreshInterval, (_) {
      _refreshZoneStatus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshZoneStatus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer.cancel();
    _zoneTimer?.cancel();
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

  Widget? _buildZoneStatusCard({
    required DashboardProvider provider,
    required EnterpriseTheme enterprise,
  }) {
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
      padding: const EdgeInsets.only(bottom: 12),
      child: EnterpriseGlass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        radius: 14,
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enterprise.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          color: enterprise.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
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
                          color: statusColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 128,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _AttendanceZoneMapPainter(
                    branchLatitude: provider.workspaceLatitude,
                    branchLongitude: provider.workspaceLongitude,
                    currentLatitude:
                        hasCurrentLocation ? currentLatitude : null,
                    currentLongitude:
                        hasCurrentLocation ? currentLongitude : null,
                    allowedDistanceMeters: allowedDistance,
                    distanceMeters: distance,
                    inZone: isInZone,
                    mapBackground: enterprise.isDark
                        ? const Color(0xFF142233)
                        : const Color(0xFFEAF3F6),
                    gridColor: enterprise.text.withValues(alpha: 0.08),
                    branchColor: enterprise.primary,
                    currentColor: statusColor,
                    radiusColor: statusColor.withValues(alpha: 0.28),
                    textColor: enterprise.text,
                    mutedTextColor: enterprise.mutedText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ZoneParameterChip(
                  icon: Icons.business_rounded,
                  label: translate('attendance_messages.branch_gps'),
                  value:
                      '${_formatCoordinate(provider.workspaceLatitude)}, ${_formatCoordinate(provider.workspaceLongitude)}',
                  color: enterprise.primary,
                  enterprise: enterprise,
                ),
                _ZoneParameterChip(
                  icon: Icons.my_location_rounded,
                  label: translate('attendance_messages.device_gps'),
                  value:
                      '${_formatCoordinate(currentLatitude)}, ${_formatCoordinate(currentLongitude)}',
                  color: statusColor,
                  enterprise: enterprise,
                ),
                _ZoneParameterChip(
                  icon: Icons.social_distance_rounded,
                  label: translate('attendance_messages.distance_from_branch'),
                  value: hasDistance
                      ? '${_formatMeters(distance)} m'
                      : translate('attendance_messages.zone_checking'),
                  color: statusColor,
                  enterprise: enterprise,
                ),
                _ZoneParameterChip(
                  icon: Icons.radio_button_checked_rounded,
                  label: translate('attendance_messages.allowed_radius'),
                  value: '${_formatMeters(allowedDistance)} m',
                  color: enterprise.secondary,
                  enterprise: enterprise,
                ),
                if (provider.currentLocationAccuracyMeters != null)
                  _ZoneParameterChip(
                    icon: Icons.gps_fixed_rounded,
                    label: translate('attendance_messages.gps_accuracy'),
                    value:
                        '${_formatMeters(provider.currentLocationAccuracyMeters!)} m',
                    color: enterprise.accent,
                    enterprise: enterprise,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _ZoneLegendDot(
                    color: enterprise.primary,
                    label: translate('attendance_messages.branch_location'),
                    enterprise: enterprise,
                  ),
                  const SizedBox(width: 12),
                  _ZoneLegendDot(
                    color: statusColor,
                    label: translate('attendance_messages.current_location'),
                    enterprise: enterprise,
                  ),
                ],
              ),
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
        !_isRefreshingZone &&
        _lastZoneRefreshAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshZoneStatus();
      });
    }
    context.read<PrefProvider>().getAttendanceType(attendanceMethod);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildClock(enterprise, isAD),
          const SizedBox(height: 16),
          if (attendanceMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EnterpriseGlass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                radius: 14,
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
          if (zoneStatusCard != null) zoneStatusCard,
          if (attendanceMethod.isNotEmpty)
            _buildAttendanceControl(
              enterprise: enterprise,
              attandanceType: attandanceType,
              animated: animated,
              isCheckedIn: isCheckedIn,
            ),
          if (attendanceMethod.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${translate('home_screen.check_in')} | ${translate('home_screen.check_out')}",
                style: TextStyle(
                  color: panelTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 10),
          EnterpriseGlass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            radius: 18,
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
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  animation: true,
                  animationDuration: 1000,
                  lineHeight: 12.0,
                  padding: EdgeInsets.zero,
                  percent: attendanceList['production-time']!,
                  barRadius: const Radius.circular(20),
                  backgroundColor: progressBackgroundColor,
                  linearGradient: LinearGradient(
                    colors: [productionProgressColor, enterprise.accent],
                  ),
                ),
                const SizedBox(height: 6),
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

class _ZoneParameterChip extends StatelessWidget {
  const _ZoneParameterChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.enterprise,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final EnterpriseTheme enterprise;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: enterprise.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enterprise.mutedText,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneLegendDot extends StatelessWidget {
  const _ZoneLegendDot({
    required this.color,
    required this.label,
    required this.enterprise,
  });

  final Color color;
  final String label;
  final EnterpriseTheme enterprise;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enterprise.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
    required this.gridColor,
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
  final Color gridColor;
  final Color branchColor;
  final Color currentColor;
  final Color radiusColor;
  final Color textColor;
  final Color mutedTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = mapBackground;
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    _drawGrid(canvas, size);

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
      final linePaint = Paint()
        ..color = currentColor.withValues(alpha: 0.82)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
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

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
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
      ..color = color.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(point, 13, shadowPaint);

    final markerPaint = Paint()..color = color;
    canvas.drawCircle(point, 9, markerPaint);
    canvas.drawCircle(point, 4, Paint()..color = Colors.white);
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
