import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class KyOptionalUpdatePrompt {
  const KyOptionalUpdatePrompt._();

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic>? release,
  ) async {
    if (release == null || !context.mounted) return;
    final versionName = '${release['version_name'] ?? ''}'.trim();
    final releaseNotes = '${release['release_notes'] ?? ''}'.trim();
    final downloadUrl = Uri.tryParse('${release['download_url'] ?? ''}');
    final officialHost =
        downloadUrl?.scheme == 'https' && downloadUrl?.host == 'kneayerng.com';

    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('App update available'),
        content: Text([
          if (versionName.isNotEmpty) 'Version $versionName is available.',
          if (releaseNotes.isNotEmpty) releaseNotes,
        ].join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: officialHost
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (shouldDownload != true || downloadUrl == null || !officialHost) return;
    await launchUrl(downloadUrl, mode: LaunchMode.externalApplication);
  }
}
