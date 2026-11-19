import 'dart:math' as math;

import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Keeps one decoration layer above the app's navigator and its menus.
class RosePinkEffectsOverlay extends StatelessWidget {
  const RosePinkEffectsOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRosePink = context.select<ThemeProvider, bool>(
      (settings) => settings.mode == AppThemeMode.rosePink,
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (isRosePink) const Positioned.fill(child: RosePinkEffects()),
      ],
    );
  }
}

class RosePinkEffects extends StatefulWidget {
  const RosePinkEffects({super.key});

  @override
  State<RosePinkEffects> createState() => _RosePinkEffectsState();
}

class _RosePinkEffectsState extends State<RosePinkEffects>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _motionEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAnimation();
  }

  void _syncAnimation() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!_motionEnabled ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effects = context.select(
      (ThemeProvider settings) => (
        hearts: settings.effectEnabled('floating_hearts'),
        petals: settings.effectEnabled('rose_petals'),
        glow: settings.effectEnabled('heart_glow'),
        sparkles: settings.effectEnabled('sparkle_effects'),
        reduceMotion: settings.effectEnabled('reduce_animations'),
      ),
    );
    final hasEffects =
        effects.hearts || effects.petals || effects.glow || effects.sparkles;
    final reduceMotion = effects.reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _motionEnabled = hasEffects && !reduceMotion;
    _syncAnimation();
    if (!hasEffects) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RoseEffectsPainter(
            animation: reduceMotion ? null : _controller,
            hearts: effects.hearts,
            petals: effects.petals,
            glow: effects.glow,
            sparkles: effects.sparkles,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RoseEffectsPainter extends CustomPainter {
  _RoseEffectsPainter({
    required this.animation,
    required this.hearts,
    required this.petals,
    required this.glow,
    required this.sparkles,
  }) : super(repaint: animation);

  final Animation<double>? animation;
  final bool hearts;
  final bool petals;
  final bool glow;
  final bool sparkles;

  double get progress => animation?.value ?? 0.5;

  static const _heartSizes = <double>[
    12,
    18,
    30,
    15,
    36,
    22,
    14,
    32,
    20,
    26,
    10,
    34
  ];
  static final _hearts = _heartSizes.map(_heartPath).toList(growable: false);
  static final _glowHeart = _heartPath(36);
  static final _petal = Path()
    ..moveTo(0, -5)
    ..quadraticBezierTo(7, -3, 4, 4)
    ..quadraticBezierTo(0, 8, -4, 3)
    ..quadraticBezierTo(-7, -3, 0, -5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (glow) _paintGlow(canvas, size);
    if (hearts) _paintHearts(canvas, size);
    if (sparkles) _paintSparkles(canvas, size);
    if (petals) _paintPetals(canvas, size);
  }

  void _paintGlow(Canvas canvas, Size size) {
    final pulse = (1 + math.sin(progress * math.pi * 2)) / 2;
    final halo = Paint()
      ..color = const Color(0xffff6098).withValues(alpha: 0.22 + pulse * 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final center = Paint()
      ..color = const Color(0xffff94ba).withValues(alpha: 0.10 + pulse * 0.05);

    for (final (x, y) in [(0.08, 0.30), (0.92, 0.70)]) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.drawPath(_glowHeart, halo);
      canvas.drawPath(_glowHeart, center);
      canvas.restore();
    }
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final phase = (progress + i * 0.137) % 1;
      final x = size.width * (0.10 + ((i * 31) % 80) / 100);
      final y = size.height * ((i * 23 % 100) / 100);
      final fade = 0.45 + math.sin(phase * math.pi * 2) * 0.35;
      paint.color = const Color(0xffff8db8).withValues(alpha: fade * 0.50);
      canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), paint);
      canvas.drawLine(Offset(x - 3, y), Offset(x + 3, y), paint);
    }
  }

  void _paintHearts(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _hearts.length; i++) {
      final phase = (progress + i * 0.173) % 1;
      final x = size.width * (0.08 + ((i * 37) % 83) / 100) +
          math.sin((phase * math.pi * 2) + i) * 9;
      final y = size.height * (1 - phase);
      final fade = math.sin(phase * math.pi) * 0.24;
      canvas.save();
      canvas.translate(x, y);
      paint.color = const Color(0xffff97bc).withValues(alpha: fade);
      canvas.drawPath(_hearts[i], paint);
      canvas.restore();
    }
  }

  void _paintPetals(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final phase = (progress + i * 0.217) % 1;
      final x = size.width * (0.12 + ((i * 29) % 77) / 100) +
          math.sin(phase * math.pi * 2 + i) * 12;
      final y = size.height * phase;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(phase * math.pi * 2 + i) * 0.55);
      paint.color = const Color(0xfffb7ca5).withValues(alpha: 0.24);
      canvas.drawPath(_petal, paint);
      canvas.restore();
    }
  }

  static Path _heartPath(double s) => Path()
    ..moveTo(0, s * 0.85)
    ..cubicTo(-s * 1.55, -s * 0.12, -s * 0.86, -s * 1.12, 0, -s * 0.48)
    ..cubicTo(s * 0.86, -s * 1.12, s * 1.55, -s * 0.12, 0, s * 0.85)
    ..close();

  @override
  bool shouldRepaint(covariant _RoseEffectsPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.hearts != hearts ||
      oldDelegate.petals != petals ||
      oldDelegate.glow != glow ||
      oldDelegate.sparkles != sparkles;
}
