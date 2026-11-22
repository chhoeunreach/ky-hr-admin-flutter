import 'package:cnattendance/utils/app_update_payload.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buttonborder.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AppUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;
  final String? alertTitle;
  final bool isForceUpdate;

  const AppUpdateDialog({
    Key? key,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
    this.alertTitle,
    this.isForceUpdate = false,
  }) : super(key: key);

  Future<void> _launchDownload() async {
    try {
      await launchUrl(appUpdateDownloadUri(downloadUrl),
          mode: LaunchMode.externalApplication);
    } catch (error) {
      if (kDebugMode)
        debugPrint('App update: failed to open download URL: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleFromKey = translate('app_update.title');
    final titleText = (alertTitle != null && alertTitle!.trim().isNotEmpty)
        ? alertTitle!.trim()
        : (titleFromKey.isNotEmpty ? titleFromKey : 'មានកំណែអាប់ដេតថ្មី!');
    final descText = (releaseNotes != null && releaseNotes!.trim().isNotEmpty)
        ? releaseNotes!.trim()
        : (isForceUpdate
            ? translate('app_update.mandatory_desc')
            : translate('app_update.optional_desc'));
    final currentLabel = translate('app_update.current_version');
    final latestLabel = translate('app_update.latest_version');
    final updateNowText = translate('app_update.update_now');
    final laterText = translate('app_update.later');

    return PopScope(
      canPop: !isForceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 12,
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.customFF036EB7.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 38,
                    color: AppColors.customFF036EB7,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titleText.isNotEmpty ? titleText : 'មានកំណែអាប់ដេតថ្មី!',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                descText.isNotEmpty
                    ? descText
                    : (isForceUpdate
                        ? 'តម្រូវឱ្យធ្វើបច្ចុប្បន្នភាពជាចាំបាច់ដើម្បីបន្តប្រើប្រាស់កម្មវិធី។'
                        : 'កំណែថ្មីនៃ Digital HR ត្រូវបានដាក់ឱ្យប្រើប្រាស់ជាមួយនឹងការកែលម្អបន្ថែម។'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          currentLabel.isNotEmpty
                              ? currentLabel
                              : 'កំណែបច្ចុប្បន្ន',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentVersion.isNotEmpty
                              ? 'v$currentVersion'
                              : 'v1.0.0',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black87,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.grey.shade500,
                    ),
                    Column(
                      children: [
                        Text(
                          latestLabel.isNotEmpty ? latestLabel : 'កំណែចុងក្រោយ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.customFF036EB7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestVersion.isNotEmpty ? 'v$latestVersion' : 'New',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.customFF036EB7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (releaseNotes != null && releaseNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 90),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseNotes!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.customFF036EB7,
                    shape: ButtonBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                  ),
                  onPressed: _launchDownload,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded,
                          color: AppColors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        updateNowText.isNotEmpty
                            ? updateNowText
                            : 'អាប់ដេតឥឡូវនេះ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isForceUpdate) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      laterText.isNotEmpty ? laterText : 'ពេលក្រោយ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final _shownAutomaticUpdates = <String>{};
Future<void>? _activeUpdateDialog;
bool _activeUpdateIsRequired = false;

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required String currentVersion,
  required String latestVersion,
  required String downloadUrl,
  String? releaseNotes,
  String? alertTitle,
  bool isForceUpdate = false,
  bool automatic = false,
}) async {
  final updateKey = '${latestVersion.trim()}|$isForceUpdate';
  final activeDialog = _activeUpdateDialog;
  if (automatic && activeDialog != null) {
    if (!isForceUpdate || _activeUpdateIsRequired) return;
    await activeDialog;
    if (!context.mounted || _activeUpdateDialog != null) return;
  }
  if (automatic && !_shownAutomaticUpdates.add(updateKey)) return;

  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: !isForceUpdate,
    builder: (ctx) => AppUpdateDialog(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      alertTitle: alertTitle,
      isForceUpdate: isForceUpdate,
    ),
  );
  if (automatic) {
    _activeUpdateDialog = dialog;
    _activeUpdateIsRequired = isForceUpdate;
  }
  try {
    await dialog;
  } finally {
    if (identical(_activeUpdateDialog, dialog)) {
      _activeUpdateDialog = null;
      _activeUpdateIsRequired = false;
    }
  }
}
