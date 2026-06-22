import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
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
  late final AnimationController _pulseController;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();
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

  Future<bool> _ensureWithinScanDistanceIfPossible() async {
    final provider = context.read<DashboardProvider>();
    final distance = await provider.getWorkspaceDistanceMeters(
      forceHighAccuracy: true,
    );
    if (!mounted) return false;

    if (distance == null) {
      return true;
    }

    if (distance > DashboardProvider.scanAttendanceMaxDistanceMeters) {
      final message =
          'សូមអភ័យទោលោកអ្នកនៅក្រៅតំបនការងា\nចំងាយជាក់ស្ដែក៖ ${distance.toStringAsFixed(2)} ម៉ែត្រ';
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(message),
          );
        },
      );
      return false;
    }

    return true;
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
    final result = await showCustomQrScanner(context);
    if (result != null && result.trim().isNotEmpty) {
      final provider = context.read<DashboardProvider>();
      if (provider.isNoteEnabled) {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (context) {
              return NoteBottomSheet(result, "qr");
            });
      } else {
        onAttendanceVerify("qr", result);
      }
    }
  }

  bool isWithinRadius(double lat1, double lon1, double lat2, double lon2,
      double radiusInMeters) {
    final distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distance <= radiusInMeters;
  }

  void onAttendanceVerify(String type, String identifier) async {
    final provider = context.read<DashboardProvider>();
    try {
      if (type == "qr" || type == "nfc") {
        final ok = await _ensureWithinScanDistanceIfPossible();
        if (!ok) return;
      }

      EasyLoading.show(
          status: translate('loader.requesting'),
          maskType: EasyLoadingMaskType.black);
      final response =
          await provider.verifyAttendanceApi(type, "", identifier: identifier);
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  period,
                  style: TextStyle(
                    color: enterprise.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hourMinute,
                style: TextStyle(
                  color: enterprise.text,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  seconds,
                  style: TextStyle(
                    color: enterprise.text.withValues(alpha: 0.84),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAD ? formattedDate : nepaliFormattedDate,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enterprise.mutedText,
              fontSize: 13,
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
        MediaQuery.sizeOf(context).shortestSide >= 600 ? 220.0 : 198.0;
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

  @override
  Widget build(BuildContext context) {
    final attendanceList =
        Provider.of<DashboardProvider>(context).attendanceList;
    final attandanceType = context.watch<PrefProvider>().attendanceType;
    final isAD = context.watch<DashboardProvider>().isAD;
    final attendanceMethod =
        context.watch<DashboardProvider>().attendanceMethods;
    final animated = context.watch<DashboardProvider>().animated;
    final enterprise = EnterpriseTheme.of(context);
    final isCheckedIn =
        attendanceList['check-in'] != "-" && attendanceList['check-out'] == "-";
    final panelTextColor = enterprise.text;
    final progressBackgroundColor = enterprise.text.withValues(alpha: 0.14);
    final productionProgressColor =
        isCheckedIn ? enterprise.accent : enterprise.secondary;
    context.read<PrefProvider>().getAttendanceType(attendanceMethod);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildClock(enterprise, isAD),
          const SizedBox(height: 26),
          if (attendanceMethod.isNotEmpty)
            _buildAttendanceControl(
              enterprise: enterprise,
              attandanceType: attandanceType,
              animated: animated,
              isCheckedIn: isCheckedIn,
            ),
          if (attendanceMethod.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                "${translate('home_screen.check_in')} | ${translate('home_screen.check_out')}",
                style: TextStyle(
                  color: panelTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 18),
          EnterpriseGlass(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 24,
            glowColor: productionProgressColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: productionProgressColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Working Time',
                        style: TextStyle(
                          color: panelTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      attendanceList['production_hour'],
                      style: TextStyle(
                        color: panelTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearPercentIndicator(
                  animation: true,
                  animationDuration: 1000,
                  lineHeight: 16.0,
                  padding: EdgeInsets.zero,
                  percent: attendanceList['production-time']!,
                  barRadius: const Radius.circular(20),
                  backgroundColor: progressBackgroundColor,
                  linearGradient: LinearGradient(
                    colors: [productionProgressColor, enterprise.accent],
                  ),
                ),
                const SizedBox(height: 10),
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
