import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ChatLocationBubble extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isIncoming;

  const ChatLocationBubble({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isIncoming,
  });

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.white;
    const secondary = AppColors.white70;
    final iconBackground =
        isIncoming ? AppColors.customFF1684F8 : AppColors.custom33000000;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openMaps,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 104,
              decoration: BoxDecoration(
                color: isIncoming
                    ? AppColors.customFF193260
                    : AppColors.custom22FFFFFF,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapGridPainter(
                        lineColor: isIncoming
                            ? AppColors.custom44FFFFFF
                            : AppColors.custom40FFFFFF,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              "Location",
              style: TextStyle(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MapGridPainter extends CustomPainter {
  final Color lineColor;

  const _MapGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var x = -size.width; x < size.width * 2; x += 34) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    for (var y = 18.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
