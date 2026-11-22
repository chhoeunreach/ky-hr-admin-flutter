import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

MaterialPageRoute<T> recordRoute<T>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) =>
    MaterialPageRoute<T>(
      fullscreenDialog: fullscreenDialog,
      builder: (context) => RecordTheme(
        child: Builder(builder: builder),
      ),
    );

class RecordTheme extends StatelessWidget {
  const RecordTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final enterprise = EnterpriseTheme.of(context);
    final surface = enterprise.contentSurface;
    final foreground = recordContrastColor(surface, enterprise.text);
    final lighterSurface =
        foreground.computeLuminance() < surface.computeLuminance();
    final surfaceTint = lighterSurface ? AppColors.white : AppColors.black;
    Color container(double amount) => Color.lerp(surface, surfaceTint, amount)!;
    final accent = recordContrastColor(
      surface,
      lighterSurface ? enterprise.primary : enterprise.accent,
    );
    final secondaryText = recordContrastColor(
      surface,
      Color.lerp(foreground, surface, .28)!,
    );
    final bar = enterprise.primary;
    final barText = recordContrastColor(bar, enterprise.text);
    final scheme = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: recordContrastColor(accent, surface),
      surface: surface,
      onSurface: foreground,
      onSurfaceVariant: secondaryText,
      outline: secondaryText,
      outlineVariant: foreground.withValues(alpha: .25),
      surfaceContainerLowest: surface,
      surfaceContainerLow: container(.03),
      surfaceContainer: container(.06),
      surfaceContainerHigh: container(.09),
      surfaceContainerHighest: container(.12),
      error: recordContrastColor(surface, base.colorScheme.error),
    );
    final appBar = base.appBarTheme;
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: surface,
        canvasColor: surface,
        cardColor: surface,
        textTheme: base.textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
        appBarTheme: appBar.copyWith(
          backgroundColor: bar,
          foregroundColor: barText,
          iconTheme: (appBar.iconTheme ?? const IconThemeData())
              .copyWith(color: barText),
          actionsIconTheme: (appBar.actionsIconTheme ?? const IconThemeData())
              .copyWith(color: barText),
          titleTextStyle: (appBar.titleTextStyle ?? base.textTheme.titleLarge)
              ?.copyWith(color: barText),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: container(.06),
          labelStyle: TextStyle(color: secondaryText),
          hintStyle: TextStyle(color: secondaryText),
          errorStyle: TextStyle(color: scheme.error),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accent, width: 1.6),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: surface,
          modalBackgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          dragHandleColor: secondaryText,
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: surface,
          titleTextStyle:
              base.dialogTheme.titleTextStyle?.copyWith(color: foreground),
          contentTextStyle:
              base.dialogTheme.contentTextStyle?.copyWith(color: secondaryText),
        ),
      ),
      child: child,
    );
  }
}

Color recordContrastColor(Color background, Color preferred) {
  final luminance = background.computeLuminance();
  double ratio(Color color) {
    final ink = color.computeLuminance();
    return ink >= luminance
        ? (ink + .05) / (luminance + .05)
        : (luminance + .05) / (ink + .05);
  }

  if (ratio(preferred) >= 4.5) return preferred;
  final target = ratio(AppColors.black) >= ratio(AppColors.white)
      ? AppColors.black
      : AppColors.white;
  var low = 0.0;
  var high = 1.0;
  for (var step = 0; step < 10; step++) {
    final amount = (low + high) / 2;
    if (ratio(Color.lerp(preferred, target, amount)!) >= 4.5) {
      high = amount;
    } else {
      low = amount;
    }
  }
  return Color.lerp(preferred, target, high)!;
}
