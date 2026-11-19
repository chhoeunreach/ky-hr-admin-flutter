import 'dart:async';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/services/attendance_sync_service.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/buttonborder.dart';

class NoteBottomSheet extends StatefulWidget {
  final String identifier;
  final String type;
  final File? attendanceSelfie;
  final bool returnNote;

  NoteBottomSheet(
    this.identifier,
    this.type, {
    this.attendanceSelfie,
    this.returnNote = false,
  });

  @override
  State<StatefulWidget> createState() => NoteBottomSheetState();
}

class NoteBottomSheetState extends State<NoteBottomSheet> {
  bool isEnabled = true;
  bool isLoading = false;

  void onAttendanceVerify(String type, String identifier) async {
    final provider = context.read<DashboardProvider>();
    final syncService = AttendanceSyncService();
    final offlineRequestId = syncService.createOfflineRequestId();
    final recordedAt = DateTime.now();
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    try {
      setState(() {
        EasyLoading.show(
            status: translate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      final response = await provider.verifyAttendanceApi(
        type,
        "",
        identifier: identifier,
        attendanceSelfie: widget.attendanceSelfie,
        offlineRequestId: offlineRequestId,
        recordedAt: recordedAt,
      );
      if (!mounted) return;
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: rootContext,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(response.message),
            );
          },
        );
      });
    } catch (e) {
      final message = e.toString();
      if (_isOfflineQueueableError(e)) {
        await _queueOfflineAttendance(
          syncService: syncService,
          provider: provider,
          type: type,
          identifier: identifier,
          note: "",
          offlineRequestId: offlineRequestId,
          recordedAt: recordedAt,
        );
        if (!mounted) return;
        setState(() {
          EasyLoading.dismiss(animation: true);
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
        });
        return;
      }
      final extra = await provider.buildWorkspaceDistanceInfoIfNeeded(message);
      if (!mounted) return;
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: rootContext,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(
                  extra == null ? message : '$message\n\n$extra'),
            );
          },
        );
      });
    }
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
                              if (widget.returnNote) {
                                Navigator.pop(
                                    context, provider.noteController.text);
                                return;
                              }
                              final syncService = AttendanceSyncService();
                              final offlineRequestId =
                                  syncService.createOfflineRequestId();
                              final recordedAt = DateTime.now();
                              final rootContext =
                                  Navigator.of(context, rootNavigator: true)
                                      .context;
                              try {
                                isLoading = true;
                                setState(() {
                                  EasyLoading.show(
                                      status: translate('loader.requesting'),
                                      maskType: EasyLoadingMaskType.black);
                                });
                                var status = await provider.getCheckInStatus();
                                if (status) {
                                  final response =
                                      await provider.verifyAttendanceApi(
                                    widget.type,
                                    provider.noteController.text,
                                    identifier: widget.identifier,
                                    attendanceSelfie: widget.attendanceSelfie,
                                    offlineRequestId: offlineRequestId,
                                    recordedAt: recordedAt,
                                  );
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
                                          child: CustomAlertDialog(
                                              response.message),
                                        );
                                      },
                                    );
                                  });
                                }
                              } catch (e) {
                                print(e);
                                final message = e.toString();
                                if (_isOfflineQueueableError(e)) {
                                  await _queueOfflineAttendance(
                                    syncService: syncService,
                                    provider: provider,
                                    type: widget.type,
                                    identifier: widget.identifier,
                                    note: provider.noteController.text,
                                    offlineRequestId: offlineRequestId,
                                    recordedAt: recordedAt,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    EasyLoading.dismiss(animation: true);
                                    Navigator.pop(context);
                                    isLoading = false;
                                  });
                                  provider.noteController.clear();
                                  showDialog(
                                    context: rootContext,
                                    builder: (context) {
                                      return Dialog(
                                        child: CustomAlertDialog(
                                          translate(
                                              'attendance_messages.saved_offline'),
                                        ),
                                      );
                                    },
                                  );
                                  return;
                                }
                                final extra = await provider
                                    .buildWorkspaceDistanceInfoIfNeeded(
                                        message);
                                if (!mounted) return;
                                setState(() {
                                  EasyLoading.dismiss(animation: true);
                                  Navigator.pop(context);
                                  isLoading = false;
                                });
                                showDialog(
                                  context: rootContext,
                                  builder: (context) {
                                    return Dialog(
                                      child: CustomAlertDialog(extra == null
                                          ? message
                                          : '$message\n\n$extra'),
                                    );
                                  },
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                translate('create_salary_screen.submit'),
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
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                translate('common.go_back'),
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
      selfie: widget.attendanceSelfie,
      offlineRequestId: offlineRequestId,
      recordedAt: recordedAt,
    );
  }
}
