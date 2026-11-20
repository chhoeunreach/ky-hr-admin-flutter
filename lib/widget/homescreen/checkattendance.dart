import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/repositories/meeting_attendance_repository.dart';
import 'package:cnattendance/repositories/payroll_queue_repository.dart';
import 'package:cnattendance/services/attendance_sync_service.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/attendance_verify_feedback.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/qr_scan_router.dart';
import 'package:cnattendance/widget/attendance_selfie_camera.dart';
import 'package:cnattendance/widget/attendance_bottom_sheet.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_summary.dart';
import 'package:cnattendance/widget/homescreen/payroll_queue_ticket_dialog.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/customnfcdialog.dart';
import 'package:cnattendance/widget/device_clock_gate.dart';
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

import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'home_model_view.dart';
import 'royal_dashboard_widgets.dart';
import '../customqrscanner.dart';

class CheckAttendance extends StatefulWidget {
  final PersistentTabController? controller;
  final HomeBannerConfig? bannerConfig;
  final Map<LayoutItem, Widget> otherSections;
  final bool dashboardLoading, dashboardError;
  final VoidCallback? onRetryDashboard;

  const CheckAttendance(
      {Key? key,
      this.controller,
      this.bannerConfig,
      this.otherSections = const {},
      this.dashboardLoading = false,
      this.dashboardError = false,
      this.onRetryDashboard})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => CheckAttendanceState();
}

class CheckAttendanceState extends State<CheckAttendance>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _zoneRefreshInterval = Duration(minutes: 1);

  late final AnimationController _pulseController;
  late final Timer _clockTimer;
  final TransformationController _mapTransformationController =
      TransformationController();
  DateTime _now = DateTime.now();
  late final ValueNotifier<DateTime> _clockNow = ValueNotifier(_now);
  List<String>? _resolvedAttendanceMethods;
  bool _clockEnabled = true;
  bool _foreground = true;
  bool _animateAttendance = false;
  bool _isRefreshingZone = false;
  bool _attendanceInFlight = false;
  double? _zoneDistanceMeters;
  String? _zoneError;
  DateTime? _lastZoneRefreshAt;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    WidgetsBinding.instance.addObserver(this);
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    if (!mounted ||
        !_clockEnabled ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final now = DateTime.now();
    _clockNow.value = now;
    final royal = EnterpriseTheme.of(context).isRoyalBlueGold;
    final current = royal ? royalLocalTime(now) : now;
    final previous = royal ? royalLocalTime(_now) : _now;
    final dayChanged = current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
    if (dayChanged) {
      setState(() => _now = now);
      final provider = context.read<DashboardProvider>();
      if (provider.features['attendance'] == '1') {
        unawaited(provider.refreshMonthlyAttendanceSummary());
        if (royal) widget.onRetryDashboard?.call();
      }
    }
  }

  void _syncPulse() {
    final shouldAnimate = _clockEnabled && _foreground && _animateAttendance;
    if (shouldAnimate && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!shouldAnimate && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clockEnabled = TickerMode.valuesOf(context).enabled;
    final dashboard = context.watch<DashboardProvider>();
    _animateAttendance = dashboard.animated &&
        dashboard.attendanceMethods.isNotEmpty &&
        !MediaQuery.disableAnimationsOf(context);
    _syncPulse();
    final methods = dashboard.attendanceMethods;
    if (!listEquals(_resolvedAttendanceMethods, methods)) {
      final snapshot = List<String>.of(methods);
      _resolvedAttendanceMethods = snapshot;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          unawaited(context.read<PrefProvider>().getAttendanceType(snapshot));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPulse();
    if (_foreground) _updateClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockNow.dispose();
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
      if (force &&
          EnterpriseTheme.of(context).isRoyalBlueGold &&
          provider.isLocationEnabled) {
        setState(() => _isRefreshingZone = true);
        try {
          await provider.getCheckInStatus();
        } catch (error) {
          if (mounted) _showAttendanceWarning(error.toString());
        } finally {
          if (mounted) setState(() => _isRefreshingZone = false);
        }
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
    final royal = EnterpriseTheme.of(context).isRoyalBlueGold;
    if (!provider.isWorkspaceRadiusEnabled) {
      if (!royal || !provider.isLocationEnabled) return true;
      try {
        if (await provider.getCheckInStatus()) return mounted;
      } catch (error) {
        if (mounted) _showAttendanceWarning(error.toString());
        return false;
      }
      if (mounted) {
        _showAttendanceWarning(
            translate('attendance_messages.gps_unavailable_warning'));
      }
      return false;
    }
    try {
      final distance = await provider.getWorkspaceDistanceMeters(
        forceHighAccuracy: true,
      );
      if (!mounted) return false;

      if (royal) setState(() => _zoneDistanceMeters = distance);
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
        if (royal) {
          _showAttendanceWarning(
              translate('attendance_messages.gps_unavailable_warning'));
        }
        return !royal;
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

  void showNFCScanner({String attendanceStatus = ''}) {
    if (Platform.isAndroid) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomNfcDialog(
              NFCMODE.scan,
              attendanceStatus: attendanceStatus,
            ),
          );
        },
      );
    }

    if (Platform.isIOS) {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          onAttendanceVerify(
            "nfc",
            base64.encode(utf8.encode(findKey(tag.data))),
            attendanceStatus: attendanceStatus,
          );
          NfcManager.instance.stopSession();
        },
      );
    }
  }

  Future<void> scanQr({bool royal = false, String attendanceStatus = ''}) async {
    final ok = await _ensureWithinScanDistanceIfPossible();
    if (!ok || !mounted) return;

    final result = await showCustomQrScanner(context);
    if (result == null || result.trim().isEmpty || !mounted) return;

    final route = QrScanRouter.classify(result);
    if (!route.isAttendance) {
      await _handleDirectScan(route);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final provider = context.read<DashboardProvider>();
    final selfie = provider.isAttendanceSelfieEnabled
        ? await _captureAttendanceSelfie()
        : null;
    if (!mounted) return;
    if (provider.isAttendanceSelfieEnabled && selfie == null) {
      showToast(translate('attendance_messages.selfie_required'));
      return;
    }

    if (provider.isNoteEnabled && royal) {
      final note = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (context) => NoteBottomSheet(
          route.payload,
          route.attendanceType,
          attendanceSelfie: selfie,
          returnNote: true,
          attendanceStatus: attendanceStatus,
        ),
      );
      if (mounted && note != null) {
        await onAttendanceVerify(route.attendanceType, route.payload,
            attendanceSelfie: selfie,
            note: note,
            attendanceStatus: attendanceStatus);
      }
    } else if (provider.isNoteEnabled) {
      await showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) {
            return NoteBottomSheet(
              route.payload,
              route.attendanceType,
              attendanceSelfie: selfie,
              attendanceStatus: attendanceStatus,
            );
          });
    } else {
      await onAttendanceVerify(route.attendanceType, route.payload,
          attendanceSelfie: selfie, attendanceStatus: attendanceStatus);
    }
  }

  /// Handles scans that are not daily attendance: meeting check-in, payroll
  /// queue join, and server configuration switch.
  Future<void> _handleDirectScan(QrScanRoute route) async {
    if (route.kind == QrScanKind.serverConfig) {
      await _handleServerConfigScan(route.payload);
      return;
    }

    EasyLoading.show(
      status: translate('loader.requesting'),
      maskType: EasyLoadingMaskType.black,
    );
    String message;
    final payroll = PayrollQueueRepository();
    PayrollQueueTicket? ticket;
    try {
      if (route.kind == QrScanKind.meeting) {
        final response =
            await MeetingAttendanceRepository().scan(route.payload);
        message = response.message;
      } else {
        final result = await payroll.join(route.payrollToken!);
        message = result.message;
        ticket = result.ticket;
      }
    } catch (error) {
      message = error.toString();
    } finally {
      EasyLoading.dismiss(animation: true);
    }

    if (!mounted) return;
    final joinedTicket = ticket;
    await showDialog<void>(
      context: context,
      builder: (_) => joinedTicket == null
          ? Dialog(child: CustomAlertDialog(message))
          : PayrollQueueTicketDialog(
              message: message,
              initialTicket: joinedTicket,
              loadTicket: () => payroll.getTicket(joinedTicket.id),
            ),
    );
  }

  Future<void> _handleServerConfigScan(String scannedValue) async {
    final service = ServerStatusService();
    final String targetUrl;
    try {
      targetUrl = service.normalizeScannedServer(scannedValue);
    } on FormatException {
      showToast(translate('alerts.invalid_qr'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final enterprise = EnterpriseTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: enterprise.surface,
          title: Row(
            children: [
              Icon(Icons.swap_horiz_rounded,
                  color: enterprise.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  translate('server_status.change_server_title'),
                  style: TextStyle(color: enterprise.text, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate('server_status.change_server_message'),
                style: TextStyle(color: enterprise.text, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SelectableText(
                targetUrl,
                style: TextStyle(color: enterprise.mutedText, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(translate('server_status.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(translate('server_status.confirm')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    EasyLoading.show(
      status: translate('server_status.checking_server'),
      maskType: EasyLoadingMaskType.black,
    );
    final result = await service.switchServer(scannedValue);
    if (!mounted) return;
    EasyLoading.dismiss(animation: true);

    if (result.isConnected) {
      try {
        await context.read<DashboardProvider>().getDashboard();
      } catch (error) {
        debugPrint('Server changed, but dashboard refresh failed: $error');
      }
      if (!mounted) return;
      showToast(translate('server_status.server_changed_successfully'));
    } else {
      showToast(result.message);
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

  Future<void> onAttendanceVerify(String type, String identifier,
      {File? attendanceSelfie,
      String note = '',
      String attendanceStatus = ''}) async {
    if (!mounted) return;
    final provider = context.read<DashboardProvider>();
    if (type == 'qr' || type == 'qr_pass' || type == 'nfc') {
      final ok = await _ensureWithinScanDistanceIfPossible();
      if (!ok || !mounted) return;
    }

    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    String message;
    var showRetry = false;
    EasyLoading.show(
      status: translate('attendance_messages.verifying'),
      maskType: EasyLoadingMaskType.black,
    );
    try {
      final response = await provider.verifyAttendanceApi(
        type,
        note,
        identifier: identifier,
        attendanceStatus: attendanceStatus,
        attendanceSelfie: attendanceSelfie,
        offlineRequestId: offlineRequestId,
        recordedAt: recordedAt,
      );
      message = response.message;
    } catch (error) {
      message = error.toString();
      if (_isOfflineQueueableError(error)) {
        try {
          await _queueOfflineAttendance(
            syncService: syncService,
            provider: provider,
            type: type,
            identifier: identifier,
            note: note,
            attendanceStatus: attendanceStatus,
            attendanceSelfie: attendanceSelfie,
            offlineRequestId: offlineRequestId,
            recordedAt: recordedAt,
          );
          message = translate('attendance_messages.saved_offline');
        } catch (queueError) {
          showRetry = true;
          message = attendanceVerifyFailureMessage(queueError.toString());
        }
      } else {
        showRetry = true;
        final extra =
            await provider.buildWorkspaceDistanceInfoIfNeeded(message);
        message = attendanceVerifyFailureMessage(
            extra == null ? message : '$message\n\n$extra');
      }
    } finally {
      EasyLoading.dismiss(animation: true);
    }

    if (!mounted) return;
    final retry = await showDialog<bool>(
          context: context,
          builder: (_) => Dialog(
            child: CustomAlertDialog(
              message,
              actionLabel:
                  showRetry ? translate('attendance_messages.check_again') : null,
            ),
          ),
        ) ??
        false;

    if (retry && showRetry && mounted) {
      await _retryAttendanceScan(type, attendanceStatus);
    }
  }

  Future<void> _retryAttendanceScan(
      String type, String attendanceStatus) async {
    if (!mounted) return;
    if (type == 'nfc') {
      showNFCScanner(attendanceStatus: attendanceStatus);
      return;
    }
    final royal = EnterpriseTheme.of(context).isRoyalBlueGold;
    await scanQr(royal: royal, attendanceStatus: attendanceStatus);
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
    String attendanceStatus = '',
    required File? attendanceSelfie,
    required String offlineRequestId,
    required DateTime recordedAt,
  }) async {
    await provider.getCheckInStatus();
    await syncService.queueAttendance(
      attendanceType: type,
      identifier: identifier,
      attendanceStatusType: attendanceStatus,
      note: note,
      latitude: provider.locationStatus['latitude'].toString(),
      longitude: provider.locationStatus['longitude'].toString(),
      routerBssid: "",
      selfie: attendanceSelfie,
      offlineRequestId: offlineRequestId,
      recordedAt: recordedAt,
    );
  }

  Future<void> _handleAttendanceTap(String attendanceType,
      {String attendanceStatus = ''}) async {
    if (_attendanceInFlight || !mounted) return;
    final royal = EnterpriseTheme.of(context).isRoyalBlueGold;
    if (royal) setState(() => _attendanceInFlight = true);
    try {
      await _openAttendance(attendanceType,
          royal: royal, attendanceStatus: attendanceStatus);
    } catch (error) {
      if (mounted) _showAttendanceWarning(error.toString());
    } finally {
      if (royal && mounted) setState(() => _attendanceInFlight = false);
    }
  }

  Future<void> _openAttendance(String attandanceType,
      {required bool royal, String attendanceStatus = ''}) async {
    final clockOk = await ensureDeviceClockAllowsAction(context);
    if (!clockOk || !mounted) return;

    if (attandanceType.toUpperCase() == "QR") {
      if (royal &&
          !context.read<DashboardProvider>().attendanceMethods.any(
                (method) => method.toLowerCase() == 'qr',
              )) return;
      await scanQr(royal: royal, attendanceStatus: attendanceStatus);
    } else if (attandanceType.toUpperCase() == "NFC") {
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        showToast(translate('attendance_messages.nfc_not_present'));
        return;
      }
      showNFCScanner(attendanceStatus: attendanceStatus);
    } else {
      // Default / wifi: the center button opens the sheet with both choices.
      // An explicit checkIn / checkOut (when supplied) submits directly.
      if (attendanceStatus == 'checkIn' || attendanceStatus == 'checkOut') {
        await _submitWifiAttendance(attendanceStatus);
        return;
      }
      await showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) {
            return AttedanceBottomSheet();
          });
    }
  }

  Future<void> _submitWifiAttendance(String attendanceStatus) async {
    final provider = context.read<DashboardProvider>();
    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    EasyLoading.show(
      status: translate('loader.requesting'),
      maskType: EasyLoadingMaskType.black,
    );
    String message;
    try {
      final response = await provider.verifyAttendanceApi(
        'wifi',
        '',
        attendanceStatus: attendanceStatus,
        offlineRequestId: offlineRequestId,
        recordedAt: recordedAt,
      );
      message = response.message;
    } catch (error) {
      message = error.toString();
      if (_isOfflineQueueableError(error)) {
        try {
          await provider.getCheckInStatus();
          await syncService.queueAttendance(
            attendanceType: 'wifi',
            identifier: '',
            attendanceStatusType: attendanceStatus,
            note: '',
            latitude: provider.locationStatus['latitude'].toString(),
            longitude: provider.locationStatus['longitude'].toString(),
            routerBssid: '',
            selfie: null,
            offlineRequestId: offlineRequestId,
            recordedAt: recordedAt,
          );
          message = translate('attendance_messages.saved_offline');
        } catch (queueError) {
          message = queueError.toString();
        }
      } else {
        final extra =
            await provider.buildWorkspaceDistanceInfoIfNeeded(message);
        if (extra != null) message = '$message\n\n$extra';
      }
    } finally {
      EasyLoading.dismiss(animation: true);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: CustomAlertDialog(message)),
    );
  }

  Widget _buildClock(EnterpriseTheme enterprise, bool isAD, DateTime now) {
    final hourMinute = DateFormat('HH:mm').format(now);
    final period = DateFormat('a').format(now);
    final seconds = DateFormat('ss').format(now);
    return Column(
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
          isAD
              ? DateFormat('EEEE , MMMM d , yyyy').format(now)
              : NepaliDateFormat('EEE , MMMM d , yyyy')
                  .format(now.toNepaliDateTime()),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enterprise.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
          child: RepaintBoundary(
              child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(alignment: Alignment.center, children: [
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
                      Colors.white
                          .withValues(alpha: enterprise.isDark ? 0.18 : 0.74),
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
            ]),
          )),
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
                  child!,
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
    final enterprise = EnterpriseTheme.of(context);

    final allowedDistance = (dashboardProvider.effectiveWorkspaceRadiusMeters ??
            dashboardProvider.workspaceRadiusMeters ??
            50)
        .toDouble();
    final hasBranchLocation = dashboardProvider.workspaceLatitude != null &&
        dashboardProvider.workspaceLongitude != null;
    final distance =
        _zoneDistanceMeters ?? dashboardProvider.lastWorkspaceDistanceMeters;
    final hasDistance =
        hasBranchLocation && distance != null && _zoneError == null;
    final isInZone = hasDistance && distance <= allowedDistance;
    final currentLatitude = dashboardProvider.locationStatus['latitude'];
    final currentLongitude = dashboardProvider.locationStatus['longitude'];
    final hasCurrentLocation = currentLatitude != null &&
        currentLongitude != null &&
        currentLatitude != 0 &&
        currentLongitude != 0;

    final Widget mapWidget = hasBranchLocation
        ? _AttendanceGoogleMapFrame(
            branchLatitude: dashboardProvider.workspaceLatitude!,
            branchLongitude: dashboardProvider.workspaceLongitude!,
            currentLatitude: hasCurrentLocation ? currentLatitude : null,
            currentLongitude: hasCurrentLocation ? currentLongitude : null,
            configuredMapUrl: dashboardProvider.attendanceMapUrl,
            enterprise: enterprise,
          )
        : Stack(
            children: [
              InteractiveViewer(
                transformationController: _mapTransformationController,
                minScale: 1,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(80),
                child: CustomPaint(
                  painter: _AttendanceZoneMapPainter(
                    branchLatitude: dashboardProvider.workspaceLatitude,
                    branchLongitude: dashboardProvider.workspaceLongitude,
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
                    branchColor: enterprise.primary,
                    currentColor: isInZone
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFE11D48),
                    radiusColor: (isInZone
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE11D48))
                        .withValues(alpha: 0.28),
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
          );

    if (!enterprise.isRoyalBlueGold &&
        dashboardProvider.effectiveWorkspaceRadiusMeters != null &&
        !_isRefreshingZone &&
        _lastZoneRefreshAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshZoneStatus();
      });
    }

    return HomeModelView(
      clockNow: _clockNow,
      summary: dashboardProvider.monthlyAttendanceSummary,
      pulseController: _pulseController,
      animated: _animateAttendance,
      onAttendanceTap: () => _handleAttendanceTap(attandanceType),
      onRefreshZone: () => _refreshZoneStatus(force: true),
      allowedDistanceMeters: allowedDistance,
      distanceMeters: distance,
      isInZone: isInZone,
      isRefreshingZone: _isRefreshingZone,
      attendanceList: attendanceList,
      scannerBusy: _attendanceInFlight,
      dashboardLoading: widget.dashboardLoading,
      dashboardError: widget.dashboardError,
      onRetryDashboard: widget.onRetryDashboard,
      mapWidget: mapWidget,
      controller: widget.controller,
      bannerConfig: widget.bannerConfig,
      otherSections: widget.otherSections,
    );
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
                    translate('attendance_messages.google_map'),
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
