import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..setBackgroundColor(Colors.white)
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
        ? content
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
      background: #ffffff;
      color: #263247;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 16px;
      line-height: 1.65;
      overflow-wrap: anywhere;
      word-break: break-word;
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
      border: 1px solid #d8e0ec;
      padding: 8px;
      vertical-align: top;
    }

    a {
      color: #036eb7;
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF036EB7),
            ),
          ),
      ],
    );
  }
}
