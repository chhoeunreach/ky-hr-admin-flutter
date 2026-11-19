import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class AppMotion extends StatelessWidget {
  const AppMotion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled =
        context.select((ThemeProvider settings) => settings.animationsEnabled);
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(disableAnimations: media.disableAnimations || !enabled),
      child: child,
    );
  }
}

class AnimationSettingsTile extends StatelessWidget {
  const AnimationSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final settings = context.watch<ThemeProvider>();
    return SwitchListTile(
      value: settings.animationsEnabled,
      onChanged: settings.setAnimationsEnabled,
      activeThumbColor: enterprise.accent,
      secondary: Icon(Icons.animation, color: enterprise.accent),
      dense: true,
      title: Text(
        translate('more_screen.animation'),
        style: TextStyle(
          color: enterprise.text,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
