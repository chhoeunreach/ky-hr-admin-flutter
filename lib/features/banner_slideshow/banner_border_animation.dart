import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class BannerBorderAnimation extends StatelessWidget {
  const BannerBorderAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      return const SizedBox.shrink();
    }
    return const IgnorePointer(
      child: RepaintBoundary(child: _PulsingBorder()),
    );
  }
}

class _PulsingBorder extends StatefulWidget {
  const _PulsingBorder();

  @override
  State<_PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<_PulsingBorder>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final opacity = .18 + .62 * Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.white.withValues(alpha: opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
