import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_strings.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeHighlightDetailScreen extends StatelessWidget {
  const HomeHighlightDetailScreen({super.key, required this.highlight});

  final HomeHighlight highlight;

  Future<void> _openLink(BuildContext context, String? value) async {
    final uri = Uri.tryParse(value?.trim() ?? '');
    var opened = false;
    if (uri != null &&
        uri.userInfo.isEmpty &&
        ((['https', 'http'].contains(uri.scheme) && uri.host.isNotEmpty) ||
            (uri.scheme == 'mailto' && uri.path.isNotEmpty))) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {/* Surface missing handlers as a recoverable message. */}
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(homeHighlightsText('Could not open link.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final date = highlight.startsAt ?? highlight.createdAt;
    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.surface,
        foregroundColor: theme.text,
        iconTheme: IconThemeData(color: theme.text),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? BackButton(color: theme.text)
            : null,
        title: Text(homeHighlightsText('Highlight')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlight.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: highlight.imageUrl!,
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 230,
                      color: theme.text.withValues(alpha: .06),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.secondary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: theme.text.withValues(alpha: .06),
                      child: Icon(Icons.image_not_supported_outlined,
                          color: theme.mutedText),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                highlight.title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: theme.mutedText),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy').format(date.toLocal()),
                      style: TextStyle(
                        color: theme.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if ((highlight.body ?? '').trim().isNotEmpty)
                SelectionArea(
                  child: Html(
                    data: highlight.body!,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        color: theme.text,
                        fontSize: FontSize(15),
                        lineHeight: LineHeight(1.6),
                      ),
                      'a': Style(color: theme.secondary),
                      'img': Style(width: Width(100, Unit.percent)),
                    },
                    onLinkTap: (url, attributes, element) =>
                        _openLink(context, url),
                  ),
                )
              else
                Text(
                  highlight.snippet,
                  style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              if ((highlight.linkUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openLink(context, highlight.linkUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      (highlight.linkLabel ?? '').trim().isNotEmpty
                          ? highlight.linkLabel!
                          : homeHighlightsText('Read more'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
