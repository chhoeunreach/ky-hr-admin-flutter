import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ChatFileBubble extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final bool isIncoming;

  const ChatFileBubble({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.isIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        fileName.trim().isEmpty ? _fileNameFromUrl(fileUrl) : fileName;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _openFile,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isIncoming
                    ? const Color(0xff1684f8)
                    : const Color(0x26000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'File attachment' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to open',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    final uri = Uri.tryParse(fileUrl.trim());
    if (!_isSafeFileUri(uri) || !await _isReachableFile(uri)) {
      showToast('This file link is invalid on the server.');
      return;
    }
    await launchUrl(uri!, mode: LaunchMode.externalApplication);
  }

  Future<bool> _isReachableFile(Uri? uri) async {
    if (uri == null) {
      return false;
    }

    try {
      final response = await http.head(uri).timeout(const Duration(seconds: 8));
      final contentType =
          response.headers['content-type']?.toLowerCase().trim() ?? '';
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      return !contentType.contains('text/html');
    } catch (_) {
      return false;
    }
  }

  bool _isSafeFileUri(Uri? uri) {
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final path = uri.path.trim().toLowerCase();
    if (path.isEmpty || path == '/' || path.endsWith('.html')) {
      return false;
    }

    return path.startsWith('/storage/chat/files/') ||
        path.endsWith('.pdf') ||
        path.endsWith('.doc') ||
        path.endsWith('.docx') ||
        path.endsWith('.xls') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.ppt') ||
        path.endsWith('.pptx') ||
        path.endsWith('.txt') ||
        path.endsWith('.csv') ||
        path.endsWith('.zip') ||
        path.endsWith('.rar');
  }

  String _fileNameFromUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.pathSegments.isEmpty) {
      return '';
    }
    return Uri.decodeComponent(uri.pathSegments.last);
  }
}
