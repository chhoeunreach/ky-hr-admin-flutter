import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/app_update_dialog.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/notice/rich_notice_description_viewer.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const String _iosTestFlightUpdateUrl =
    'https://testflight.apple.com/join/hPG4ZA38';

class GeneralScreen extends StatefulWidget {
  @override
  State<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  final outputDate = "".obs;
  String fullMessage = "";
  bool isLoadingFullMessage = false;
  String? appBaseUrl;

  Future<void> checkAd(DateTime tempDate) async {
    final preferences = Preferences();
    final isAd = await preferences.getEnglishDate();
    if (!isAd) {
      outputDate.value =
          NepaliDateFormat("dd-MM-yyyy").format(tempDate.toNepaliDateTime());
    }
  }

  Future<void> _openDownload(String url) async {
    final targetUrl = Platform.isIOS
        ? _iosTestFlightUpdateUrl
        : (url.trim().isNotEmpty ? url.trim() : 'https://hr.kneayerng.com');
    final parsed = Uri.tryParse(targetUrl);
    final uri = parsed != null && parsed.hasScheme && parsed.hasAuthority
        ? parsed
        : Uri.parse(Platform.isIOS
            ? _iosTestFlightUpdateUrl
            : 'https://hr.kneayerng.com');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _loadFullDescription(
    int id,
    String fallback, {
    int noticeId = 0,
    String type = '',
  }) async {
    final normalizedType = type.trim().toLowerCase();
    final detailId = normalizedType == 'notice' && noticeId > 0 ? noticeId : id;
    if (detailId <= 0 || isLoadingFullMessage) {
      return;
    }

    setState(() {
      isLoadingFullMessage = true;
    });

    try {
      final preferences = Preferences();
      final baseUrl = await preferences.getAppUrl();
      appBaseUrl = baseUrl;
      final detailPath = normalizedType == 'notice'
          ? '${Constant.NOTICE_URL}/$detailId'
          : '${Constant.NOTIFICATION_URL}/$detailId';
      final uri = Uri.parse('$baseUrl$detailPath');
      final token = await preferences.getToken();
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        final description = _readDescription(decoded);
        if (description.trim().isNotEmpty &&
            description.trim() != fallback.trim() &&
            mounted) {
          setState(() {
            fullMessage = description;
          });
        }
      }
    } catch (_) {
      // Keep the description from the notification list if detail loading fails.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingFullMessage = false;
        });
      }
    }
  }

  String _readDescription(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'description_html',
        'description',
        'message',
        'body',
        'content',
        'notification_description',
      ]) {
        final found = value[key]?.toString();
        if (found != null && found.trim().isNotEmpty) {
          return found;
        }
      }

      for (final key in const ['data', 'notification', 'notice']) {
        final nested = _readDescription(value[key]);
        if (nested.trim().isNotEmpty) {
          return nested;
        }
      }
    }

    return "";
  }

  @override
  Widget build(BuildContext context) {
    final param = Get.arguments is Map ? Get.arguments as Map : {};
    final id = int.tryParse(param["id"]?.toString() ?? "") ?? 0;
    final noticeId = int.tryParse(param["notice_id"]?.toString() ?? "") ?? 0;
    final title = param["title"]?.toString() ?? "";
    final message = param["message"]?.toString() ?? "";
    final type = param["type"]?.toString().toLowerCase() ?? "";
    if (fullMessage.isEmpty) {
      fullMessage = message;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFullDescription(
          id,
          message,
          noticeId: noticeId,
          type: type,
        );
      });
    }
    final date = param["date"]?.toString() ?? "";
    final downloadUrl = _platformDownloadUrl(param);

    final isUpdate = type == "app_update" ||
        title.contains('អាប់ដេត') ||
        title.toLowerCase().contains('update') ||
        message.contains('អាប់ដេត') ||
        message.toLowerCase().contains('update') ||
        message.contains('កំណែថ្មី');

    if (date.isNotEmpty) {
      try {
        DateTime? tempDate = DateTime.tryParse(date);
        if (tempDate == null) {
          tempDate = DateFormat("yyyy-MM-dd").parse(date);
        }
        final outputFormat = DateFormat('MM-dd-yyyy');
        outputDate.value = outputFormat.format(tempDate);
        checkAd(tempDate);
      } catch (_) {}
    }

    return Scaffold(
      body: Container(
        decoration: RadialDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(translate('general_screen.notification_detail'),
                style: TextStyle(color: Colors.white)),
            elevation: 0,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _NotificationHeader(
                          title: title.isNotEmpty ? title : "Notification",
                          date: outputDate,
                          isUpdate: isUpdate,
                        ),
                        SizedBox(height: 14),
                        if (isUpdate) ...[
                          Card(
                            elevation: 4,
                            color: HexColor("#036eb7"),
                            margin: EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.system_update_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              translate('app_update.title'),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'hr.kneayerng.com',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                HexColor("#036eb7"),
                                            shape: ButtonBorder(),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            elevation: 2,
                                          ),
                                          icon: Icon(Icons.download_rounded,
                                              size: 18),
                                          label: Text(
                                            translate('app_update.update_now'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _openDownload(downloadUrl),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side:
                                              BorderSide(color: Colors.white70),
                                          foregroundColor: Colors.white,
                                          shape: ButtonBorder(),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 12),
                                        ),
                                        child: Icon(Icons.visibility_rounded,
                                            size: 18, color: Colors.white),
                                        onPressed: () async {
                                          final details =
                                              await AppDeviceInfo.getDetails();
                                          await showAppUpdateDialog(
                                            context: context,
                                            currentVersion: details.appVersion,
                                            latestVersion: '',
                                            downloadUrl: downloadUrl,
                                            releaseNotes: fullMessage,
                                            alertTitle: title,
                                            isForceUpdate: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(18, 18, 18, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.article_outlined,
                                      color: Color(0xFF036EB7),
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Description",
                                      style: TextStyle(
                                        color: Color(0xFF172033),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (isLoadingFullMessage)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF036EB7),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 14),
                              if (_hasImage(fullMessage))
                                SizedBox(
                                  height: 320,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: RichNoticeDescriptionViewer(
                                      html: fullMessage.trim().isEmpty
                                          ? '-'
                                          : fullMessage,
                                      baseUrl: appBaseUrl,
                                    ),
                                  ),
                                )
                              else
                                SelectionArea(
                                  child: Html(
                                    data: fullMessage.trim().isEmpty
                                        ? '-'
                                        : fullMessage,
                                    style: _descriptionHtmlStyle(),
                                  ),
                                ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF036EB7),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: Icon(Icons.open_in_full_rounded,
                                      size: 18),
                                  label: Text(
                                    'View full description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await _loadFullDescription(
                                      id,
                                      message,
                                      noticeId: noticeId,
                                      type: type,
                                    );
                                    if (mounted) {
                                      _showFullDescriptionSheet(
                                        title.isNotEmpty
                                            ? title
                                            : 'Notification',
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _platformDownloadUrl(Map param) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = param[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final platformUrl = Platform.isIOS
        ? read([
            'ios_url',
            'app_store_url',
            'apple_store_url',
            'ios_download_url',
          ])
        : read([
            'android_url',
            'play_store_url',
            'android_download_url',
          ]);

    if (platformUrl.isNotEmpty) return platformUrl;
    if (Platform.isIOS) return _iosTestFlightUpdateUrl;

    final fallbackUrl = read(['download_url', 'url']);
    return fallbackUrl.isNotEmpty ? fallbackUrl : 'https://hr.kneayerng.com';
  }

  Map<String, Style> _descriptionHtmlStyle() {
    return {
      "body": Style(
        color: Color(0xFF263247),
        fontSize: FontSize(15.5),
        fontWeight: FontWeight.w500,
        lineHeight: LineHeight(1.65),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      "p": Style(
        color: Color(0xFF263247),
        lineHeight: LineHeight(1.65),
        margin: Margins.only(bottom: 12),
      ),
      "li": Style(
        color: Color(0xFF263247),
        lineHeight: LineHeight(1.6),
      ),
      "a": Style(
        color: Color(0xFF036EB7),
        textDecoration: TextDecoration.underline,
      ),
    };
  }

  bool _hasImage(String html) {
    return RegExp(r'<img\b', caseSensitive: false).hasMatch(html);
  }

  void _showFullDescriptionSheet(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0xFFD8E0EC),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF172033),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded),
                            color: Color(0xFF52607A),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Color(0xFFE6ECF4)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: RichNoticeDescriptionViewer(
                          html: fullMessage.trim().isEmpty ? '-' : fullMessage,
                          baseUrl: appBaseUrl,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF036EB7),
                            side: BorderSide(color: Color(0xFFB9D8F2)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(Icons.copy_rounded, size: 18),
                          label: Text(
                            'Copy description text',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: () => _copyDescriptionText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyDescriptionText(BuildContext context) async {
    final text = html_parser.parseFragment(fullMessage).text?.trim() ??
        fullMessage.trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description copied')),
      );
    }
  }
}

class _NotificationHeader extends StatelessWidget {
  final String title;
  final RxString date;
  final bool isUpdate;

  const _NotificationHeader({
    required this.title,
    required this.date,
    required this.isUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUpdate
                      ? Icons.system_update_alt_rounded
                      : Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Obx(
                  () => date.value.isNotEmpty
                      ? Text(
                          date.value,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(
                          translate('notification_screen.notifications'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            title.trim().isEmpty ? "Notification" : title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
