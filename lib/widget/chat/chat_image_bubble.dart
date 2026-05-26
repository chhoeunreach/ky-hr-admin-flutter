import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ChatImageBubble extends StatelessWidget {
  final String imageUrl;
  final int? width;
  final int? height;

  const ChatImageBubble({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * .72;
    final aspectRatio = _aspectRatio().clamp(.75, 1.6);
    final imageHeight = maxWidth / aspectRatio;
    final trimmedUrl = imageUrl.trim();

    if (!_canRenderAsImage(trimmedUrl)) {
      debugPrint('[CHAT_IMAGE] skipped non-image url=$trimmedUrl');
      return _ImageUnavailableBubble(
        width: maxWidth,
        height: 120,
        url: trimmedUrl,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          trimmedUrl,
          width: maxWidth,
          height: imageHeight,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              width: maxWidth,
              height: imageHeight,
              color: const Color(0xff14264c),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: maxWidth,
            height: 120,
            color: const Color(0xff14264c),
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canRenderAsImage(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return false;
    }

    final path = uri.path.toLowerCase();
    if (path.isEmpty || path == '/' || path.endsWith('.html')) {
      return false;
    }

    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.bmp',
    ];
    return imageExtensions.any(path.endsWith);
  }

  double _aspectRatio() {
    final imageWidth = width;
    final imageHeight = height;
    if (imageWidth == null ||
        imageHeight == null ||
        imageWidth <= 0 ||
        imageHeight <= 0) {
      return 4 / 3;
    }

    return imageWidth / imageHeight;
  }
}

class _ImageUnavailableBubble extends StatelessWidget {
  final double width;
  final double height;
  final String url;

  const _ImageUnavailableBubble({
    required this.width,
    required this.height,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openUrl,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xff14264c),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xff24406f)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 30,
            ),
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(url.trim());
    if (!_isSafeMediaUri(uri) || !await _isReachableImage(uri)) {
      showToast('This media link is invalid on the server. Please re-upload it.');
      return;
    }
    await launchUrl(uri!, mode: LaunchMode.externalApplication);
  }

  Future<bool> _isReachableImage(Uri? uri) async {
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
      if (contentType.contains('text/html')) {
        return false;
      }
      return contentType.startsWith('image/');
    } catch (_) {
      return false;
    }
  }

  bool _isSafeMediaUri(Uri? uri) {
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final path = uri.path.trim().toLowerCase();
    if (path.isEmpty || path == '/' || path.endsWith('.html')) {
      return false;
    }

    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.bmp',
    ];

    if (imageExtensions.any(path.endsWith)) {
      return true;
    }

    return path.startsWith('/storage/chat/images/');
  }
}
