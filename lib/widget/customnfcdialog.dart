import 'dart:convert';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/utils/attendance_verify_feedback.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/profile/note_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

enum NFCMODE { scan, add }

class CustomNfcDialog extends StatefulWidget {
  final NFCMODE mode;

  /// `checkIn` / `checkOut` from home Scan In / Scan Out; empty = auto.
  final String attendanceStatus;

  CustomNfcDialog(this.mode, {this.attendanceStatus = ''});

  @override
  State<StatefulWidget> createState() => CustomDialogState();
}

class CustomDialogState extends State<CustomNfcDialog> {
  @override
  void initState() {
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        if (widget.mode == NFCMODE.add) {
          onAddNfc(base64.encode(utf8.encode(findKey(tag.data))));
        }

        if (widget.mode == NFCMODE.scan) {
          final provider = context.read<DashboardProvider>();
          if (provider.isNoteEnabled) {
            Get.back();
            showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                builder: (context) {
                  return NoteBottomSheet(
                    base64.encode(utf8.encode(findKey(tag.data))),
                    "nfc",
                    attendanceStatus: widget.attendanceStatus,
                  );
                });
          } else {
            onAttendanceVerify(
                "nfc", base64.encode(utf8.encode(findKey(tag.data))));
          }
        }
      },
    );
    super.initState();
  }

  void onAttendanceVerify(String type, String identifier) async {
    final provider = context.read<DashboardProvider>();
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    try {
      setState(() {
        EasyLoading.show(
            status: translate('attendance_messages.verifying'),
            maskType: EasyLoadingMaskType.black);
      });
      final response = await provider.verifyAttendanceApi(
        type,
        "",
        identifier: identifier,
        attendanceStatus: widget.attendanceStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        EasyLoading.dismiss(animation: true);
        Navigator.pop(context);
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
      EasyLoading.dismiss(animation: true);
      final message = e.toString();
      final extra = await provider.buildWorkspaceDistanceInfoIfNeeded(message);
      final failureMessage = attendanceVerifyFailureMessage(
          extra == null ? message : '$message\n\n$extra');
      if (!mounted) return;
      Navigator.pop(context);
      final retry = await showDialog<bool>(
            context: rootContext,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(
                  failureMessage,
                  actionLabel: translate('attendance_messages.check_again'),
                ),
              );
            },
          ) ??
          false;
      if (retry) {
        showDialog(
          context: rootContext,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              child: CustomNfcDialog(
                NFCMODE.scan,
                attendanceStatus: widget.attendanceStatus,
              ),
            );
          },
        );
      }
    }
  }

  void onAddNfc(String identifier) async {
    try {
      setState(() {
        EasyLoading.show(
            status: translate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      await context.read<MoreScreenProvider>().addNfcApi("nfc", identifier);
      if (!mounted) {
        return;
      }
      setState(() {
        EasyLoading.dismiss(animation: true);
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog("Nfc Added Successfully"),
            );
          },
        );
      });
    } catch (e) {
      setState(() {
        EasyLoading.dismiss(animation: true);
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(e.toString()),
            );
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Lottie.asset("assets/raw/scanner.json",
                width: 150, height: 150),
          ),
          Text(
            textAlign: TextAlign.center,
            translate('common.scan_nfc'),
            style: TextStyle(fontSize: 15),
          ),
          SizedBox(
            height: 20,
          ),
          Container(
            width: double.infinity,
            child: ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: AppColors.customFF036EB7,
                    shape: ButtonBorder()),
                onPressed: () {
                  Navigator.pop(context);
                  NfcManager.instance.stopSession();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(translate('common.close'),
                      style: TextStyle(color: AppColors.white)),
                )),
          )
        ],
      ),
    );
  }
}
