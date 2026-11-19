import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:flutter/material.dart';

class BannerSlideSwitcher extends StatelessWidget {
  const BannerSlideSwitcher({
    super.key,
    required this.transition,
    required this.child,
  });

  static const duration = Duration(milliseconds: 480);

  final String transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (transition == BannerSlideshowConfig.transitionInstant ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _buildTransition,
      child: child,
    );
  }

  Widget _buildTransition(Widget slide, Animation<double> animation) {
    final animatedSlide = switch (transition) {
      BannerSlideshowConfig.transitionSlide => SlideTransition(
          position: Tween(begin: const Offset(.08, 0), end: Offset.zero)
              .animate(animation),
          child: slide,
        ),
      BannerSlideshowConfig.transitionSlideUp => SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero)
              .animate(animation),
          child: slide,
        ),
      BannerSlideshowConfig.transitionZoom => ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(animation),
          child: slide,
        ),
      _ => slide,
    };
    return FadeTransition(opacity: animation, child: animatedSlide);
  }
}
