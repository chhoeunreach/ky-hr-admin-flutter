import 'dart:math' as math;
import 'dart:ui';

import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

class PremiumBackground extends StatefulWidget {
  final Widget child;

  const PremiumBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  static const _worldMapProvider = AssetImage('assets/images/world_map.png');
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_worldMapProvider, context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final recipe = _PremiumBackgroundRecipe.forMode(enterprise.mode);
    return Stack(
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return _AnimatedPremiumLayers(
                enterprise: enterprise,
                recipe: recipe,
                progress: _controller.value,
              );
            },
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: Opacity(
              opacity: recipe.mapOpacity,
              child: Image(
                image: _worldMapProvider,
                fit: BoxFit.cover,
                color: recipe.mapTint,
                colorBlendMode: BlendMode.softLight,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        Positioned.fill(child: _BlurEffectsLayer(recipe: recipe)),
        widget.child,
      ],
    );
  }
}

class EnterpriseBackground extends StatelessWidget {
  final Widget child;

  const EnterpriseBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(child: child);
  }
}

class _AnimatedPremiumLayers extends StatelessWidget {
  final EnterpriseTheme enterprise;
  final _PremiumBackgroundRecipe recipe;
  final double progress;

  const _AnimatedPremiumLayers({
    required this.enterprise,
    required this.recipe,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final begin = Alignment.lerp(
      Alignment.topLeft,
      Alignment.topRight,
      progress,
    )!;
    final end = Alignment.lerp(
      Alignment.bottomRight,
      Alignment.bottomLeft,
      progress,
    )!;
    final glowShift = (progress - 0.5) * 2;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: recipe.gradientColors,
                stops: const [0, 0.34, 0.70, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GlowPainter(
              topLeft: recipe.topLeftGlow,
              topRight: recipe.topRightGlow,
              center: recipe.centerGlow,
              shift: glowShift,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _ThemeDetailPainter(
              recipe: recipe,
              progress: progress,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _CitySkylinePainter(
              color: recipe.skylineColor,
              accentColor: recipe.skylineAccentColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color topLeft;
  final Color topRight;
  final Color center;
  final double shift;

  const _GlowPainter({
    required this.topLeft,
    required this.topRight,
    required this.center,
    required this.shift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawGlow(Offset centerPoint, double radius, Color color) {
      final rect = Rect.fromCircle(center: centerPoint, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(rect);
      canvas.drawCircle(centerPoint, radius, paint);
    }

    drawGlow(
      Offset(size.width * (0.14 + shift * 0.04), size.height * 0.12),
      size.shortestSide * 0.74,
      topLeft,
    );
    drawGlow(
      Offset(size.width * (0.88 - shift * 0.05), size.height * 0.18),
      size.shortestSide * 0.64,
      topRight,
    );
    drawGlow(
      Offset(size.width * (0.52 + shift * 0.03), size.height * 0.52),
      size.shortestSide * 0.76,
      center,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.center != center ||
        oldDelegate.shift != shift;
  }
}

class _ThemeDetailPainter extends CustomPainter {
  final _PremiumBackgroundRecipe recipe;
  final double progress;

  const _ThemeDetailPainter({
    required this.recipe,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawWaves(canvas, size);
    _drawParticles(canvas, size);
    _drawModeDetails(canvas, size);
  }

  void _drawWaves(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = recipe.waveColor;
    final yBase = size.height * recipe.waveY;
    for (var i = 0; i < 7; i++) {
      final path = Path();
      final offset = (progress * size.width * 0.12) + (i * 18);
      path.moveTo(-40, yBase + i * 13);
      for (var x = -40.0; x <= size.width + 40; x += 36) {
        final t = (x + offset) / size.width;
        final y = yBase +
            i * 13 +
            (recipe.waveAmplitude *
                size.height *
                0.10 *
                (0.7 + i * 0.05) *
                (0.5 - (t - 0.5).abs()));
        path.quadraticBezierTo(
          x + 18,
          y - recipe.waveAmplitude * 22,
          x + 36,
          y,
        );
      }
      canvas.drawPath(
        path,
        wavePaint..color = recipe.waveColor.withValues(alpha: 0.18 + i * 0.022),
      );
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (var i = 0; i < recipe.particleCount; i++) {
      final x = ((i * 97) % 1000) / 1000 * size.width;
      final y = ((i * 151) % 1000) / 1000 * size.height;
      final radius = 1.2 + (i % 5) * 0.8;
      final paint = Paint()
        ..color = recipe.particleColor.withValues(alpha: 0.14 + (i % 4) * 0.04)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(x + (progress - 0.5) * (i % 3) * 18, y),
        radius,
        paint,
      );
    }
  }

  void _drawModeDetails(Canvas canvas, Size size) {
    switch (recipe.detailStyle) {
      case _BackgroundDetailStyle.none:
        return;
      case _BackgroundDetailStyle.goldLines:
        _drawGoldLines(canvas, size);
        return;
      case _BackgroundDetailStyle.glassPanels:
        _drawGlassPanels(canvas, size);
        return;
      case _BackgroundDetailStyle.hex:
        _drawHex(canvas, size);
        return;
      case _BackgroundDetailStyle.leaves:
        _drawLeaves(canvas, size);
        return;
      case _BackgroundDetailStyle.flowers:
        _drawFlowers(canvas, size);
        return;
      case _BackgroundDetailStyle.bubbles:
        _drawBubbles(canvas, size);
        return;
    }
  }

  void _drawGoldLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = recipe.detailColor.withValues(alpha: 0.38);
    for (var i = 0; i < 5; i++) {
      final path = Path()
        ..moveTo(0, size.height * (0.62 + i * 0.035))
        ..cubicTo(
          size.width * 0.35,
          size.height * (0.44 + i * 0.02),
          size.width * 0.65,
          size.height * (0.88 - i * 0.025),
          size.width,
          size.height * (0.58 + i * 0.018),
        );
      canvas.drawPath(path, paint);
    }
  }

  void _drawGlassPanels(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = recipe.detailColor.withValues(alpha: 0.36);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.055);
    for (final rect in [
      Rect.fromLTWH(size.width * 0.60, size.height * 0.10, 92, 72),
      Rect.fromLTWH(size.width * 0.73, size.height * 0.42, 74, 110),
      Rect.fromLTWH(size.width * 0.14, size.height * 0.64, 92, 86),
    ]) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, paint);
    }
  }

  void _drawHex(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = recipe.detailColor.withValues(alpha: 0.28);
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 4; col++) {
        final center = Offset(
          size.width * 0.78 + col * 22,
          size.height * 0.58 + row * 20,
        );
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = 3.14159 / 3 * i;
          final p = Offset(
            center.dx + 10 * math.cos(angle),
            center.dy + 10 * math.sin(angle),
          );
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawLeaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = recipe.detailColor.withValues(alpha: 0.32);
    for (var i = 0; i < 9; i++) {
      final rect = Rect.fromCenter(
        center: Offset(
            size.width * (0.12 + i * 0.055), size.height * (0.82 - i * 0.025)),
        width: 20,
        height: 42,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(-0.8 + i * 0.18);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: rect.width, height: rect.height),
          paint);
      canvas.restore();
    }
  }

  void _drawFlowers(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = recipe.detailColor.withValues(alpha: 0.18);
    for (var flower = 0; flower < 3; flower++) {
      final center = Offset(size.width * (0.76 + flower * 0.08),
          size.height * (0.74 + flower * 0.06));
      for (var i = 0; i < 8; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * 0.785);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(0, -18), width: 18, height: 42),
            paint);
        canvas.restore();
      }
      canvas.drawCircle(center, 12,
          paint..color = recipe.detailColor.withValues(alpha: 0.26));
    }
  }

  void _drawBubbles(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = recipe.detailColor.withValues(alpha: 0.24);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(size.width * ((i * 0.17) % 1),
            size.height * (0.18 + ((i * 0.11) % 0.62))),
        8 + (i % 5) * 6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeDetailPainter oldDelegate) {
    return oldDelegate.recipe != recipe || oldDelegate.progress != progress;
  }
}

class _CitySkylinePainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  const _CitySkylinePainter({
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.29;
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accentColor.withValues(alpha: 0.32);

    final buildings = <Rect>[
      Rect.fromLTWH(size.width * 0.72, baseY + 22, 20, 96),
      Rect.fromLTWH(size.width * 0.76, baseY - 12, 28, 130),
      Rect.fromLTWH(size.width * 0.81, baseY + 8, 24, 110),
      Rect.fromLTWH(size.width * 0.86, baseY - 36, 34, 154),
      Rect.fromLTWH(size.width * 0.92, baseY + 18, 22, 100),
    ];

    for (final rect in buildings) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, paint..color = color);
      canvas.drawRRect(rrect, stroke);
      for (var y = rect.top + 14; y < rect.bottom - 8; y += 14) {
        canvas.drawLine(
          Offset(rect.left + 4, y),
          Offset(rect.right - 4, y),
          stroke..color = accentColor.withValues(alpha: 0.16),
        );
      }
    }

    final towerPath = Path()
      ..moveTo(size.width * 0.66, baseY + 118)
      ..lineTo(size.width * 0.70, baseY - 52)
      ..lineTo(size.width * 0.74, baseY + 118)
      ..close();
    canvas.drawPath(towerPath, paint..color = color.withValues(alpha: 0.75));
    canvas.drawPath(
        towerPath, stroke..color = accentColor.withValues(alpha: 0.26));
  }

  @override
  bool shouldRepaint(covariant _CitySkylinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accentColor != accentColor;
  }
}

class _BlurEffectsLayer extends StatelessWidget {
  final _PremiumBackgroundRecipe recipe;

  const _BlurEffectsLayer({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              recipe.blurTop,
              Colors.transparent,
              recipe.blurBottom,
            ],
          ),
        ),
      ),
    );
  }
}

enum _BackgroundDetailStyle {
  none,
  goldLines,
  glassPanels,
  hex,
  leaves,
  flowers,
  bubbles,
}

class _PremiumBackgroundRecipe {
  final List<Color> gradientColors;
  final Color mapTint;
  final double mapOpacity;
  final Color topLeftGlow;
  final Color topRightGlow;
  final Color centerGlow;
  final Color waveColor;
  final double waveY;
  final double waveAmplitude;
  final Color particleColor;
  final int particleCount;
  final _BackgroundDetailStyle detailStyle;
  final Color detailColor;
  final Color skylineColor;
  final Color skylineAccentColor;
  final Color blurTop;
  final Color blurBottom;

  const _PremiumBackgroundRecipe({
    required this.gradientColors,
    required this.mapTint,
    required this.mapOpacity,
    required this.topLeftGlow,
    required this.topRightGlow,
    required this.centerGlow,
    required this.waveColor,
    required this.waveY,
    required this.waveAmplitude,
    required this.particleColor,
    required this.particleCount,
    required this.detailStyle,
    required this.detailColor,
    required this.skylineColor,
    required this.skylineAccentColor,
    required this.blurTop,
    required this.blurBottom,
  });

  static _PremiumBackgroundRecipe forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return _recipe(
          colors: const [
            Color(0xffedf6ff),
            Color(0xffc7dcff),
            Color(0xffeaf3ff),
            Color(0xfff8fbff),
          ],
          mapTint: const Color(0xff60a5fa),
          mapOpacity: 0.11,
          glow: const Color(0xff60a5fa),
          accent: const Color(0xff1d4ed8),
          wave: const Color(0xff2563eb),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xff3b82f6),
          light: true,
        );
      case AppThemeMode.dark:
        return _recipe(
          colors: const [
            Color(0xff020617),
            Color(0xff06143a),
            Color(0xff020b25),
            Color(0xff01030a),
          ],
          mapTint: const Color(0xff1d4ed8),
          mapOpacity: 0.12,
          glow: const Color(0xff2563eb),
          accent: const Color(0xff60a5fa),
          wave: const Color(0xff2563eb),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xff3b82f6),
        );
      case AppThemeMode.kyEnterprise:
        return _recipe(
          colors: const [
            Color(0xff03122f),
            Color(0xff062b66),
            Color(0xff031a43),
            Color(0xff010814),
          ],
          mapTint: const Color(0xff0ea5ff),
          mapOpacity: 0.12,
          glow: const Color(0xff0369ff),
          accent: const Color(0xfffbbf24),
          wave: const Color(0xfff59e0b),
          detail: _BackgroundDetailStyle.goldLines,
          detailColor: const Color(0xfffbbf24),
        );
      case AppThemeMode.neoGlass:
        return _recipe(
          colors: const [
            Color(0xff160a3a),
            Color(0xff3b168f),
            Color(0xff11146c),
            Color(0xff09051f),
          ],
          mapTint: const Color(0xffa78bfa),
          mapOpacity: 0.11,
          glow: const Color(0xff7c3aed),
          accent: const Color(0xff38bdf8),
          wave: const Color(0xffa855f7),
          detail: _BackgroundDetailStyle.glassPanels,
          detailColor: const Color(0xffc4b5fd),
        );
      case AppThemeMode.premiumGradient:
        return _recipe(
          colors: const [
            Color(0xff063946),
            Color(0xff0f766e),
            Color(0xff075985),
            Color(0xff031621),
          ],
          mapTint: const Color(0xff22d3ee),
          mapOpacity: 0.12,
          glow: const Color(0xff14b8a6),
          accent: const Color(0xff38bdf8),
          wave: const Color(0xff22d3ee),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xff67e8f9),
        );
      case AppThemeMode.amoled:
        return _recipe(
          colors: const [
            Color(0xff000000),
            Color(0xff031407),
            Color(0xff000000),
            Color(0xff000000),
          ],
          mapTint: const Color(0xff22c55e),
          mapOpacity: 0.12,
          glow: const Color(0xff16a34a),
          accent: const Color(0xff4ade80),
          wave: const Color(0xff22c55e),
          detail: _BackgroundDetailStyle.hex,
          detailColor: const Color(0xff22c55e),
        );
      case AppThemeMode.sunset:
        return _recipe(
          colors: const [
            Color(0xfffff7ed),
            Color(0xffffd29f),
            Color(0xffff8a1c),
            Color(0xfffff1d6),
          ],
          mapTint: const Color(0xfff97316),
          mapOpacity: 0.11,
          glow: const Color(0xffffedd5),
          accent: const Color(0xfffb923c),
          wave: const Color(0xffffffff),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xfffffbeb),
          light: true,
        );
      case AppThemeMode.oceanBlue:
        return _recipe(
          colors: const [
            Color(0xff021526),
            Color(0xff075985),
            Color(0xff0369a1),
            Color(0xff020617),
          ],
          mapTint: const Color(0xff38bdf8),
          mapOpacity: 0.12,
          glow: const Color(0xff0284c7),
          accent: const Color(0xff22d3ee),
          wave: const Color(0xff38bdf8),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xff7dd3fc),
        );
      case AppThemeMode.forestGreen:
        return _recipe(
          colors: const [
            Color(0xff02140a),
            Color(0xff064e3b),
            Color(0xff052e16),
            Color(0xff010704),
          ],
          mapTint: const Color(0xff22c55e),
          mapOpacity: 0.12,
          glow: const Color(0xff16a34a),
          accent: const Color(0xff4ade80),
          wave: const Color(0xff22c55e),
          detail: _BackgroundDetailStyle.leaves,
          detailColor: const Color(0xff4ade80),
        );
      case AppThemeMode.royalPurple:
        return _recipe(
          colors: const [
            Color(0xff180733),
            Color(0xff4c1d95),
            Color(0xff2e1065),
            Color(0xff090018),
          ],
          mapTint: const Color(0xffc084fc),
          mapOpacity: 0.12,
          glow: const Color(0xff9333ea),
          accent: const Color(0xffd946ef),
          wave: const Color(0xffc084fc),
          detail: _BackgroundDetailStyle.bubbles,
          detailColor: const Color(0xffd8b4fe),
        );
      case AppThemeMode.copperBrown:
        return _recipe(
          colors: const [
            Color(0xff170703),
            Color(0xff431407),
            Color(0xff7c2d12),
            Color(0xff090302),
          ],
          mapTint: const Color(0xfff97316),
          mapOpacity: 0.11,
          glow: const Color(0xffc2410c),
          accent: const Color(0xfffdba74),
          wave: const Color(0xfffb923c),
          detail: _BackgroundDetailStyle.hex,
          detailColor: const Color(0xfff97316),
        );
      case AppThemeMode.rosePink:
        return _recipe(
          colors: const [
            Color(0xff881337),
            Color(0xffbe123c),
            Color(0xfff43f5e),
            Color(0xff3b0718),
          ],
          mapTint: const Color(0xffff8aaa),
          mapOpacity: 0.12,
          glow: const Color(0xffe11d48),
          accent: const Color(0xffffb3c7),
          wave: const Color(0xffff8aaa),
          detail: _BackgroundDetailStyle.flowers,
          detailColor: const Color(0xffffb3c7),
        );
    }
  }

  static _PremiumBackgroundRecipe _recipe({
    required List<Color> colors,
    required Color mapTint,
    required double mapOpacity,
    required Color glow,
    required Color accent,
    required Color wave,
    required _BackgroundDetailStyle detail,
    required Color detailColor,
    bool light = false,
  }) {
    return _PremiumBackgroundRecipe(
      gradientColors: colors,
      mapTint: mapTint,
      mapOpacity: mapOpacity,
      topLeftGlow: glow.withValues(alpha: light ? 0.30 : 0.22),
      topRightGlow: accent.withValues(alpha: light ? 0.28 : 0.20),
      centerGlow: wave.withValues(alpha: light ? 0.22 : 0.14),
      waveColor: wave,
      waveY: light ? 0.67 : 0.62,
      waveAmplitude: light ? 0.92 : 1.0,
      particleColor: accent,
      particleCount: light ? 18 : 28,
      detailStyle: detail,
      detailColor: detailColor,
      skylineColor: accent.withValues(alpha: light ? 0.08 : 0.10),
      skylineAccentColor: detailColor,
      blurTop: Colors.white.withValues(alpha: light ? 0.10 : 0.02),
      blurBottom: Colors.black.withValues(alpha: light ? 0.05 : 0.24),
    );
  }
}
