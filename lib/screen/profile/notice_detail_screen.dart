import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/notification.dart' as app_notification;
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/notice/rich_notice_description_viewer.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NoticeDetailScreen extends StatefulWidget {
  final app_notification.Notification notice;

  const NoticeDetailScreen({Key? key, required this.notice}) : super(key: key);

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late String fullDescription;
  bool isLoadingFullDescription = false;
  String? appBaseUrl;

  @override
  void initState() {
    super.initState();
    fullDescription = widget.notice.description;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFullDescription();
    });
  }

  Future<void> _loadFullDescription() async {
    if (widget.notice.id <= 0 || isLoadingFullDescription) {
      return;
    }

    setState(() {
      isLoadingFullDescription = true;
    });

    try {
      final preferences = Preferences();
      final baseUrl = await preferences.getAppUrl();
      appBaseUrl = baseUrl;
      final uri = Uri.parse(
        '$baseUrl${Constant.NOTICE_URL}/${widget.notice.id}',
      );
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
            description.trim() != fullDescription.trim() &&
            mounted) {
          setState(() {
            fullDescription = description;
          });
        }
      }
    } catch (_) {
      // Keep the list description if the detail endpoint is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingFullDescription = false;
        });
      }
    }
  }

  String _readDescription(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'description_html',
        'description',
        'notice_description',
        'message',
        'body',
        'content',
      ]) {
        final found = value[key]?.toString();
        if (found != null && found.trim().isNotEmpty) {
          return found;
        }
      }

      for (final key in const ['data', 'notice']) {
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
    final theme = Theme.of(context);

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(translate('general_screen.notification_detail')),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NoticeHeader(notice: widget.notice),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
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
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.article_outlined,
                                    color: Color(0xFF036EB7),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Description',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: const Color(0xFF172033),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (isLoadingFullDescription)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF036EB7),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_hasImage(fullDescription))
                              SizedBox(
                                height: 320,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: RichNoticeDescriptionViewer(
                                    html: fullDescription.trim().isEmpty
                                        ? '-'
                                        : fullDescription,
                                    baseUrl: appBaseUrl,
                                  ),
                                ),
                              )
                            else
                              SelectionArea(
                                child: Html(
                                  data: fullDescription.trim().isEmpty
                                      ? '-'
                                      : fullDescription,
                                  style: _descriptionHtmlStyle(),
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF036EB7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.open_in_full_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'View full description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () async {
                                  await _loadFullDescription();
                                  if (mounted) {
                                    _showFullDescriptionSheet();
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
    );
  }

  Map<String, Style> _descriptionHtmlStyle() {
    return {
      "body": Style(
        color: const Color(0xFF263247),
        fontSize: FontSize(15.5),
        fontWeight: FontWeight.w500,
        lineHeight: const LineHeight(1.65),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      "p": Style(
        color: const Color(0xFF263247),
        lineHeight: const LineHeight(1.65),
        margin: Margins.only(bottom: 12),
      ),
      "li": Style(
        color: const Color(0xFF263247),
        lineHeight: const LineHeight(1.6),
      ),
      "a": Style(
        color: const Color(0xFF036EB7),
        textDecoration: TextDecoration.underline,
      ),
    };
  }

  bool _hasImage(String html) {
    return RegExp(r'<img\b', caseSensitive: false).hasMatch(html);
  }

  void _showFullDescriptionSheet() {
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8E0EC),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.notice.title.trim().isEmpty
                                  ? 'Notice'
                                  : widget.notice.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF172033),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF52607A),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE6ECF4)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: RichNoticeDescriptionViewer(
                          html: fullDescription.trim().isEmpty
                              ? '-'
                              : fullDescription,
                          baseUrl: appBaseUrl,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF036EB7),
                            side: const BorderSide(color: Color(0xFFB9D8F2)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
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
    final text = html_parser.parseFragment(fullDescription).text?.trim() ??
        fullDescription.trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description copied')),
      );
    }
  }
}

class _NoticeHeader extends StatelessWidget {
  final app_notification.Notification notice;

  const _NoticeHeader({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy').format(notice.date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            notice.title.trim().isEmpty ? 'Notice' : notice.title,
            style: const TextStyle(
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
