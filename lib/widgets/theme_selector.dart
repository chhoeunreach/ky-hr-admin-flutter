import 'dart:io';

import 'package:cnattendance/features/appearance/app_appearance_api.dart';
import 'package:cnattendance/model/app_theme_option.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widgets/theme_layout_editor.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final enterprise = EnterpriseTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * 0.44).clamp(118.0, 150.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: enterprise.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Theme Mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const _RefreshAppearanceButton(),
                  IconButton(
                    tooltip: 'Customize layout',
                    color: enterprise.accent,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    onPressed: () => _openLayoutEditor(context, provider.currentThemeOption),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: enterprise.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ThemeSelectorPage(),
                        ),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.availableThemeOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final option = provider.availableThemeOptions[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _ThemePreviewCard(
                        option: option,
                        selected: provider.isSelected(option),
                        compact: true,
                      ),
                    );
                  },
                ),
              ),
              if (provider.currentThemeId == AppThemeMode.rosePink.id) ...[
                const SizedBox(height: 8),
                _RoseEffectSettings(provider: provider, enterprise: enterprise),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RefreshAppearanceButton extends StatefulWidget {
  const _RefreshAppearanceButton();

  @override
  State<_RefreshAppearanceButton> createState() =>
      _RefreshAppearanceButtonState();
}

class _RefreshAppearanceButtonState extends State<_RefreshAppearanceButton> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final config = await AppAppearanceApi().fetch();
      if (!mounted) return;
      await context.read<ThemeProvider>().applyServerAppearance(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App appearance and floating effects refreshed'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not refresh app appearance. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return IconButton(
      tooltip: 'Refresh app appearance and floating effects',
      color: enterprise.accent,
      onPressed: _refreshing ? null : _refresh,
      icon: _refreshing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: enterprise.accent,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
    );
  }
}

class _RoseEffectSettings extends StatelessWidget {
  const _RoseEffectSettings({required this.provider, required this.enterprise});

  final ThemeProvider provider;
  final EnterpriseTheme enterprise;

  static const _options = <(String, String, IconData)>[
    ('floating_hearts', 'Floating hearts', Icons.favorite_border),
    ('rose_petals', 'Rose petals', Icons.local_florist_outlined),
    ('heart_glow', 'Heart glow', Icons.blur_on),
    ('sparkle_effects', 'Sparkles', Icons.auto_awesome),
    ('qr_pulse', 'QR pulse', Icons.qr_code_2),
    ('reduce_animations', 'Reduce motion', Icons.motion_photos_off_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enterprise.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: enterprise.glassStroke),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _options.length; i += 2)
            Row(
              children: [
                Expanded(child: _effectTile(context, _options[i])),
                Expanded(child: _effectTile(context, _options[i + 1])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _effectTile(BuildContext context, (String, String, IconData) option) {
    final (key, label, icon) = option;
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      secondary: Icon(icon, size: 16, color: enterprise.accent),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: enterprise.text,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      value: provider.effectEnabled(key),
      onChanged: (value) => provider.setEffect(key, value),
    );
  }
}

class ThemeSelectorPage extends StatelessWidget {
  const ThemeSelectorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final colors = provider.colors;
    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Choose Your Theme'),
        actions: [
          IconButton(
            tooltip: 'Customize layout',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _openLayoutEditor(context, provider.currentThemeOption),
          ),
          TextButton(
            onPressed: () async {
              await context.read<ThemeProvider>().resetToSystemMode();
              if (!context.mounted) return;
              _showThemeSnack(context, 'Theme reset to system mode');
            },
            child: Text(
              'Reset',
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor ??
                    AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.availableThemeOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (context, index) {
          final option = provider.availableThemeOptions[index];
          return _ThemePreviewCard(
            option: option,
            selected: provider.isSelected(option),
            compact: false,
          );
        },
      ),
    );
  }
}

Future<void> _showBackgroundOptions(
    BuildContext context, AppThemeMode mode) =>
    _showBackgroundOptionsForId(context, mode.id);

Future<void> _showBackgroundOptionsForId(
    BuildContext context, String themeId) async {
  final provider = context.read<ThemeProvider>();
  final currentPath = provider.backgroundForId(themeId);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from this device'),
            onTap: () => Navigator.pop(sheetContext, 'choose'),
          ),
          if (currentPath != null)
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Use theme default'),
              onTap: () => Navigator.pop(sheetContext, 'reset'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  try {
    if (action == 'reset') {
      await provider.setBackgroundForId(themeId, null);
      if (currentPath != null) {
        final oldFile = File(currentPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      if (context.mounted) _showThemeSnack(context, 'Theme background reset');
      return;
    }

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (image == null || !context.mounted) return;

    final directory = await getApplicationDocumentsDirectory();
    final backgroundDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}theme_backgrounds');
    await backgroundDirectory.create(recursive: true);
    final extension = _backgroundImageExtension(image.path);
    final destination = File(
      '${backgroundDirectory.path}${Platform.pathSeparator}'
      '${themeId}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(image.path).copy(destination.path);
    await provider.setBackgroundForId(themeId, destination.path);

    if (currentPath != null && currentPath != destination.path) {
      final oldFile = File(currentPath);
      if (await oldFile.exists()) await oldFile.delete();
    }
    if (context.mounted) _showThemeSnack(context, 'Theme background updated');
  } catch (error) {
    if (context.mounted) {
      _showThemeSnack(context, 'Could not update background: $error');
    }
  }
}

String _backgroundImageExtension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '.jpg';
  final extension = path.substring(dot).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
      ? extension
      : '.jpg';
}

void _openLayoutEditor(BuildContext context, [AppThemeOption? option]) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ThemeLayoutEditor(option: option),
  ));
}

class _ThemePreviewCard extends StatelessWidget {
  final AppThemeOption option;
  final bool selected;
  final bool compact;

  _ThemePreviewCard({
    Key? key,
    AppThemeOption? option,
    AppThemeMode? mode,
    required this.selected,
    required this.compact,
  })  : option = option ??
            AppThemeOption.fromCoreMode(mode ?? AppThemeMode.royalBlueGold),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.colorsForId(option.id);
    final onDark = colors.isDark;
    final hasCustomBackground = themeProvider.backgroundForId(option.id) != null;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        await context.read<ThemeProvider>().setThemeById(option.id);
        if (!context.mounted) return;
        _showThemeSnack(context, 'Theme updated to ${option.name}');
      },
      child: AnimatedContainer(
        duration: AppThemeData.animationDuration,
        padding: EdgeInsets.all(compact ? 9 : 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.gradientColors,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? colors.accentColor
                : onDark
                    ? AppColors.white24
                    : AppColors.black.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primaryColor.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(option.icon,
                    color: colors.textColor, size: compact ? 18 : 24),
                const Spacer(),
                if (!option.isSystem) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: colors.accentColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.accentColor.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Custom',
                      style: TextStyle(
                        color: colors.textColor,
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (!compact)
                  IconButton(
                    tooltip: hasCustomBackground
                        ? 'Change background'
                        : 'Choose background',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 30, height: 30),
                    onPressed: () => _showBackgroundOptionsForId(context, option.id),
                    icon: Icon(
                      hasCustomBackground
                          ? Icons.wallpaper_rounded
                          : Icons.add_photo_alternate_outlined,
                      color: colors.textColor,
                      size: 19,
                    ),
                  ),
                AnimatedOpacity(
                  duration: AppThemeData.animationDuration,
                  opacity: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle,
                    color: colors.accentColor,
                    size: compact ? 18 : 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 7 : 10),
            Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textColor,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 15,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                option.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textColor.withValues(alpha: 0.72),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
            const Spacer(),
            _MiniDashboardPreview(colors: colors, compact: compact),
            SizedBox(height: compact ? 4 : 8),
            Row(
              children: [
                _ColorDot(color: colors.primaryColor, onDark: onDark),
                _ColorDot(color: colors.secondaryColor, onDark: onDark),
                _ColorDot(color: colors.accentColor, onDark: onDark),
                _ColorDot(color: colors.cardColor, onDark: onDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDashboardPreview extends StatelessWidget {
  final dynamic colors;
  final bool compact;

  const _MiniDashboardPreview({required this.colors, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 32 : 70,
      padding: EdgeInsets.all(compact ? 5 : 6),
      decoration: BoxDecoration(
        color: colors.cardColor.withValues(alpha: colors.isDark ? 0.76 : 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.isDark
                ? AppColors.white24
                : AppColors.black.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: compact ? 5 : 7, backgroundColor: colors.accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: compact ? 5 : 7,
                  decoration: BoxDecoration(
                    color: colors.textColor.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                  child: _PreviewTile(
                      color: colors.primaryColor, compact: compact)),
              SizedBox(width: compact ? 3 : 4),
              Expanded(
                  child: _PreviewTile(
                      color: colors.secondaryColor, compact: compact)),
              SizedBox(width: compact ? 3 : 4),
              Expanded(
                  child: _PreviewTile(
                      color: colors.accentColor, compact: compact)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Color color;
  final bool compact;

  const _PreviewTile({required this.color, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 10 : 14,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool onDark;

  const _ColorDot({required this.color, required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: onDark
                ? AppColors.white54
                : AppColors.black.withValues(alpha: 0.16)),
      ),
    );
  }
}

void _showThemeSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
}
