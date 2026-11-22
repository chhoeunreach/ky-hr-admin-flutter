import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';

class RichNoticeDescriptionViewer extends StatefulWidget {
  final String html;
  final String? baseUrl;

  const RichNoticeDescriptionViewer({
    Key? key,
    required this.html,
    this.baseUrl,
  }) : super(key: key);

  @override
  State<RichNoticeDescriptionViewer> createState() =>
      _RichNoticeDescriptionViewerState();
}

class _RichNoticeDescriptionViewerState
    extends State<RichNoticeDescriptionViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant RichNoticeDescriptionViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.baseUrl != widget.baseUrl) {
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await _controller.loadHtmlString(
      _document(widget.html),
      baseUrl: widget.baseUrl,
    );
  }

  String _document(String content) {
    final body = _looksLikeHtml(content)
        ? _normalizeImageSources(content)
        : const HtmlEscape().convert(content).replaceAll('\n', '<br>');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      min-height: 100%;
      background: ${AppPalette.cssRgb(AppPalette.white)};
      color: ${AppPalette.cssRgb(AppPalette.customFF263247)};
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 16px;
      line-height: 1.65;
      overflow-wrap: anywhere;
      word-break: break-word;
      overflow-y: auto;
      -webkit-overflow-scrolling: touch;
      -webkit-user-select: text;
      user-select: text;
    }

    body {
      padding: 0;
    }

    * {
      box-sizing: border-box;
      max-width: 100%;
    }

    p {
      margin: 0 0 14px;
    }

    ul, ol {
      padding-left: 22px;
      margin: 0 0 14px;
    }

    li {
      margin: 6px 0;
    }

    img, video {
      display: block;
      max-width: 100% !important;
      height: auto !important;
      margin: 12px auto;
      border-radius: 14px;
    }

    table {
      width: 100% !important;
      border-collapse: collapse;
      margin: 12px 0;
      display: block;
      overflow-x: auto;
    }

    th, td {
      border: 1px solid ${AppPalette.cssRgb(AppPalette.customFFD8E0EC)};
      padding: 8px;
      vertical-align: top;
    }

    a {
      color: ${AppPalette.cssRgb(AppPalette.customFF036EB7)};
    }
  </style>
</head>
<body>
  $body
</body>
</html>
''';
  }

  bool _looksLikeHtml(String value) {
    return RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(value);
  }

  String _normalizeImageSources(String html) {
    final baseUrl = widget.baseUrl?.trim();
    final baseUri =
        baseUrl == null || baseUrl.isEmpty ? null : Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      return html;
    }

    return html.replaceAllMapped(
      RegExp(r'''(<img\b[^>]*\bsrc=["'])([^"']+)(["'][^>]*>)''',
          caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        final source = match.group(2)!;
        final suffix = match.group(3)!;
        return '$prefix${_absoluteImageUrl(source, baseUri)}$suffix';
      },
    );
  }

  String _absoluteImageUrl(String source, Uri baseUri) {
    final trimmed = source.trim();
    if (trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('file:')) {
      return trimmed;
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      if (parsed.scheme == 'http' && baseUri.scheme == 'https') {
        return parsed.replace(scheme: 'https').toString();
      }
      return trimmed;
    }

    if (trimmed.startsWith('//')) {
      return '${baseUri.scheme}:$trimmed';
    }

    final root = '${baseUri.scheme}://${baseUri.host}'
        '${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    if (trimmed.startsWith('/')) {
      return '$root$trimmed';
    }

    return Uri.parse(root).resolve(trimmed).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.customFF036EB7,
            ),
          ),
      ],
    );
  }
}
