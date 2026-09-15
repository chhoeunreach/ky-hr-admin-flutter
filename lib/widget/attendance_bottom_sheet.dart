import 'dart:async';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/services/attendance_sync_service.dart';
import 'package:cnattendance/utils/wifiinfo.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/buttonborder.dart';

class AttedanceBottomSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AttendanceBottomSheetState();
}

class AttendanceBottomSheetState extends State<AttedanceBottomSheet> {
  bool isEnabled = true;
  bool isLoading = false;

  void onCheckOut(String note) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    try {
      setState(() {
        isLoading = true;
        EasyLoading.show(
            status: translate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      var status = await provider.getCheckInStatus();
      if (status) {
        final response = await provider.verifyAttendanceApi("wifi", note,
            attendanceStatus: "checkOut",
            offlineRequestId: offlineRequestId,
            recordedAt: recordedAt);
        isEnabled = true;
        if (!mounted) {
          return;
        }
        setState(() {
          EasyLoading.dismiss(animation: true);
          Navigator.pop(context);
          isLoading = false;
          showDialog(
            context: rootContext,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(response.message),
              );
            },
          );
        });
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      final message = e.toString();
      if (message == "Unauthenticated") {
        return;
      }
      if (_isOfflineQueueableError(e)) {
        await _queueOfflineWifiAttendance(
          syncService: syncService,
          provider: provider,
          attendanceStatusType: "checkOut",
          note: note,
          offlineRequestId: offlineRequestId,
          recordedAt: recordedAt,
        );
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        Navigator.pop(context);
        showDialog(
          context: rootContext,
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
      setState(() {
        isLoading = false;
      });
      Navigator.pop(context);
      showDialog(
        context: rootContext,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(
                extra == null ? message : '$message\n\n$extra'),
          );
        },
      );
    }
  }

  void onCheckIn(String note) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    try {
      isLoading = true;
      setState(() {
        EasyLoading.show(
            status: translate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      var status = await provider.getCheckInStatus();
      if (status) {
        final response = await provider.verifyAttendanceApi("wifi", note,
            attendanceStatus: "checkIn",
            offlineRequestId: offlineRequestId,
            recordedAt: recordedAt);
        isEnabled = true;
        if (!mounted) {
          return;
        }
        setState(() {
          EasyLoading.dismiss(animation: true);
          Navigator.pop(context);
          isLoading = false;
          showDialog(
            context: rootContext,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(response.message),
              );
            },
          );
        });
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      final message = e.toString();
      if (message == "Unauthenticated") {
        return;
      }
      if (_isOfflineQueueableError(e)) {
        await _queueOfflineWifiAttendance(
          syncService: syncService,
          provider: provider,
          attendanceStatusType: "checkIn",
          note: note,
          offlineRequestId: offlineRequestId,
          recordedAt: recordedAt,
        );
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {
          isLoading = false;
        });
        showDialog(
          context: rootContext,
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
      Navigator.pop(context);
      setState(() {
        isLoading = false;
      });
      showDialog(
        context: rootContext,
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

  Future<void> _queueOfflineWifiAttendance({
    required AttendanceSyncService syncService,
    required DashboardProvider provider,
    required String attendanceStatusType,
    required String note,
    required String offlineRequestId,
    required DateTime recordedAt,
  }) async {
    await syncService.queueAttendance(
      attendanceType: "wifi",
      identifier: "",
      attendanceStatusType: attendanceStatusType,
      note: note,
      latitude: provider.locationStatus['latitude'].toString(),
      longitude: provider.locationStatus['longitude'].toString(),
      routerBssid: await WifiInfo().wifiBSSID() ?? "",
      selfie: null,
      offlineRequestId: offlineRequestId,
      recordedAt: recordedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return WillPopScope(
      onWillPop: () async {
        return !isLoading;
      },
      child: Container(
        decoration: RadialDecoration(),
        padding: EdgeInsets.only(
            top: 20,
            right: 20,
            left: 20,
            bottom: (MediaQuery.of(context).viewInsets.bottom) + 10),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${translate('home_screen.check_in')} / ${translate('home_screen.check_out')}",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      )),
                ],
              ),
              Visibility(
                visible: provider.isNoteEnabled,
                child: TextField(
                  controller: provider.noteController,
                  textAlignVertical: TextAlignVertical.top,
                  maxLines: 3,
                  onTapOutside: (event) {
                    FocusScopeNode currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus &&
                        currentFocus.focusedChild != null) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                  style: TextStyle(color: Colors.white),
                  //editing controller of this TextField
                  cursorColor: Colors.white,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: translate('home_screen.note'),
                    hintStyle: TextStyle(color: Colors.white),
                    labelStyle: TextStyle(color: Colors.white),
                    fillColor: Colors.white24,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            bottomRight: Radius.circular(10))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            bottomRight: Radius.circular(10))),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            bottomRight: Radius.circular(10))),
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            bottomRight: Radius.circular(10))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(right: 5),
                        child: TextButton(
                            style: TextButton.styleFrom(
                                backgroundColor: HexColor("#036eb7"),
                                shape: ButtonBorder()),
                            onPressed: () async {
                              isEnabled
                                  ? onCheckIn(provider.noteController.text)
                                  : null;
                              isEnabled = false;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                translate('home_screen.check_in'),
                                style: TextStyle(color: Colors.white),
                              ),
                            )),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 5),
                        child: TextButton(
                            style: TextButton.styleFrom(
                                backgroundColor: HexColor("#036eb7"),
                                shape: ButtonBorder()),
                            onPressed: () {
                              isEnabled
                                  ? onCheckOut(provider.noteController.text)
                                  : null;
                              isEnabled = false;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                translate('home_screen.check_out'),
                                style: TextStyle(color: Colors.white),
                              ),
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
