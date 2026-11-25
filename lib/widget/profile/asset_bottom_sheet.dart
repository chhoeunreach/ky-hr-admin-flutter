import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/screen/assetscreen/assetscontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AssetBottomSheet extends StatefulWidget {
  final AssetData asset;

  AssetBottomSheet(this.asset);

  @override
  State<StatefulWidget> createState() => AssetBottomSheetState();
}

class AssetBottomSheetState extends State<AssetBottomSheet> {
  final reason = TextEditingController();
  bool isWorking = true;

  bool get _isReturned =>
      widget.asset.notes != null && widget.asset.notes!.trim().isNotEmpty;

  void dismissLoader() {
    EasyLoading.dismiss(animation: true);
  }

  void showLoader() {
    EasyLoading.show(
        status: "Requesting...", maskType: EasyLoadingMaskType.black);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssetController model =
        Get.isRegistered<AssetController>() ? Get.find() : Get.put(AssetController());
    final enterprise = EnterpriseTheme.of(context);
    final inputFill = enterprise.isDark ? AppColors.white12 : const Color(0xFFF8FAFC);
    final inputBorderSide = BorderSide(
      color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
      width: 1,
    );

    return Container(
      decoration: BoxDecoration(
        color: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: 20,
          right: 20,
          left: 20,
          bottom: (MediaQuery.of(context).viewInsets.bottom) + 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.asset.asset,
                    style: TextStyle(
                        fontSize: 18,
                        color: enterprise.text,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: enterprise.text, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (!_isReturned) const SizedBox(height: 10),
            if (!_isReturned)
              Row(
                children: [
                  Text(
                    "Is Working Condition",
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    activeThumbColor: enterprise.primary,
                    value: isWorking,
                    onChanged: (value) {
                      setState(() {
                        isWorking = value;
                      });
                    },
                  )
                ],
              ),
            if (!_isReturned) const SizedBox(height: 6),
            if (!_isReturned)
              TextField(
                textAlignVertical: TextAlignVertical.top,
                controller: reason,
                maxLines: 3,
                onTapOutside: (event) {
                  final FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                style: TextStyle(color: enterprise.text, fontSize: 14),
                cursorColor: enterprise.primary,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Write a response...',
                  hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 14),
                  fillColor: inputFill,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: inputBorderSide),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: enterprise.primary, width: 1.5)),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.red)),
                ),
              ),
            if (!_isReturned) const SizedBox(height: 12),
            if (_isReturned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: enterprise.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remarks / Notes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: enterprise.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.asset.notes ?? "",
                      style: TextStyle(fontSize: 14, color: enterprise.text),
                    ),
                  ],
                ),
              ),
            if (!_isReturned)
              Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enterprise.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      sendResponse(model, isWorking);
                    },
                    child: const Text(
                      'Submit Return',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    )),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> sendResponse(AssetController model, bool isWorking) async {
    if (reason.text.isEmpty) {
      showToast("Response can't be empty");
      return;
    }
    try {
      showLoader();
      final (status, message) =
          await model.sendResponse(widget.asset.id, reason.text, isWorking);
      if (!mounted) {
        dismissLoader();
        return;
      }
      dismissLoader();
      showToast(message);
      if (status) {
        await model.getAssets();
        if (mounted) Get.back();
      }
    } catch (e) {
      dismissLoader();
      if (mounted) showToast(unknownError(e));
    }
  }
}
