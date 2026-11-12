import 'community_strings.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'community_api.dart';
import 'community_media.dart';

class FlashViewPresenter {
  static final Set<String> _sessionSeen = {};
  static bool _presenting = false;

  static Future<void> showPending(BuildContext context,
      {CommunityApi? apiClient}) async {
    if (_presenting ||
        context.read<DashboardProvider>().features['flash_view.view'] != '1')
      return;
    _presenting = true;
    final api = apiClient ?? CommunityApi();
    try {
      final preferences = Preferences();
      final account =
          '${await preferences.getUserId()}:${(await preferences.getToken()).hashCode}';
      final response = await api.request('GET', 'flash-views');
      for (final raw in response['data'] as List? ?? []) {
        if (!context.mounted) break;
        final item = Map<String, dynamic>.from(raw as Map);
        final key = '$account:${item['id']}:${item['revision']}';
        if (_sessionSeen.contains(key)) continue;
        if (context.read<DashboardProvider>().features['flash_view.view'] !=
            '1') break;
        final dismissed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: Row(children: [
                  Icon(Icons.bolt, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text('${item['title']}'))
                ]),
                content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ('${item['body'] ?? ''}'.isNotEmpty)
                          Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text('${item['body']}')),
                        CommunityMedia(
                            type: '${item['media_type']}',
                            playbackUrl: item['playback_url'] as String?,
                            url: '${item['media_url'] ?? ''}'),
                        if (communityMediaUri(
                                'link', '${item['link_url'] ?? ''}')
                            case final Uri uri)
                          TextButton(
                              onPressed: () => launchUrl(uri,
                                  mode: LaunchMode.externalApplication),
                              child: Text(
                                  '${item['link_label'] ?? communityText('Learn more')}')),
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(communityText('Close')))
                ],
              )),
        );
        if (dismissed == true) {
          _sessionSeen.add(key);
          try {
            await api.request('POST', 'flash-views/${item['id']}/acknowledge',
                data: {'revision': item['revision']});
          } catch (_) {
            // The popup may appear again next session if dismissal could not sync.
          }
        }
      }
    } catch (_) {
      // Optional announcements must never prevent dashboard use.
    } finally {
      api.dispose();
      _presenting = false;
    }
  }
}
