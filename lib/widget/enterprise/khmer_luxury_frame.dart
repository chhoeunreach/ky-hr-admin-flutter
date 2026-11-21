import 'dart:math' as math;

import 'package:cnattendance/theme/royal_blue_day_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum KhmerFrameStyle { gold, royalBlue, goldBlue, subtle, premium }

/// Adds a thin ornamental frame around an existing widget without adding
/// padding or changing its measured size.
class KhmerLuxuryFrame extends StatelessWidget {
  const KhmerLuxuryFrame({
    super.key,
    required this.child,
    this.style = KhmerFrameStyle.goldBlue,
    this.radius = 22,
    this.showCornerOrnaments = true,
    this.cornerSize = 22,
  });

  final Widget child;
  final KhmerFrameStyle style;
  final double radius;
  final bool showCornerOrnaments;
  final double cornerSize;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: KhmerLuxuryColors.deepRoyalBlue.withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _KhmerFramePainter(style: style, radius: radius),
              ),
            ),
          ),
          if (showCornerOrnaments && style != KhmerFrameStyle.subtle) ...[
            _corner(top: 0, left: 0, angle: 0),
            _corner(top: 0, right: 0, angle: math.pi / 2),
            _corner(bottom: 0, right: 0, angle: math.pi),
            _corner(bottom: 0, left: 0, angle: math.pi * 1.5),
          ],
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double angle,
  }) =>
      Positioned(
        top: top,
        right: right,
        bottom: bottom,
        left: left,
        width: cornerSize,
        height: cornerSize,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: angle,
            child: SizedBox.square(
              dimension: cornerSize,
              child: SvgPicture.asset(
                '$royalDayAssets/ornaments/khmer_corner.svg',
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  KhmerLuxuryColors.metallicGold,
                  BlendMode.srcIn,
                ),
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      );
}

class _KhmerFramePainter extends CustomPainter {
  const _KhmerFramePainter({required this.style, required this.radius});

  final KhmerFrameStyle style;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outer = Offset.zero & size;
    final outerRect = outer.deflate(.75);
    final borderColor = switch (style) {
      KhmerFrameStyle.gold ||
      KhmerFrameStyle.goldBlue =>
        KhmerLuxuryColors.metallicGold,
      KhmerFrameStyle.royalBlue => KhmerLuxuryColors.royalBlue,
      KhmerFrameStyle.subtle =>
        KhmerLuxuryColors.skyBlue.withValues(alpha: .65),
      KhmerFrameStyle.premium => KhmerLuxuryColors.brightGold,
    };
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    if (style == KhmerFrameStyle.premium) {
      paint.shader = const LinearGradient(
        colors: [
          KhmerLuxuryColors.brightGold,
          KhmerLuxuryColors.metallicGold,
          KhmerLuxuryColors.darkGold,
          KhmerLuxuryColors.brightGold,
        ],
      ).createShader(outerRect);
    } else {
      paint.color = borderColor;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(radius)),
      paint,
    );
    if (style == KhmerFrameStyle.goldBlue) {
      paint
        ..shader = null
        ..color = KhmerLuxuryColors.royalBlue
        ..strokeWidth = .8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          outerRect.deflate(3),
          Radius.circular(radius > 3 ? radius - 3 : 0),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KhmerFramePainter oldDelegate) =>
      style != oldDelegate.style || radius != oldDelegate.radius;
}
