import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
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
                  const Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Theme Mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
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
                  itemCount: AppThemeMode.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final mode = AppThemeMode.values[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _ThemePreviewCard(
                        mode: mode,
                        selected: provider.mode == mode,
                        compact: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ThemeSelectorPage extends StatelessWidget {
  const ThemeSelectorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final colors = AppThemeData.info(provider.mode).colors;
    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Choose Your Theme'),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<ThemeProvider>().resetToSystemMode();
              if (!context.mounted) return;
              _showThemeSnack(context, 'Theme reset to system mode');
            },
            child: const Text(
              'Reset',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: AppThemeMode.values.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (context, index) {
          final mode = AppThemeMode.values[index];
          return _ThemePreviewCard(
            mode: mode,
            selected: provider.mode == mode,
            compact: false,
          );
        },
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final AppThemeMode mode;
  final bool selected;
  final bool compact;

  const _ThemePreviewCard({
    required this.mode,
    required this.selected,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final info = AppThemeData.info(mode);
    final colors = info.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        await context.read<ThemeProvider>().setMode(mode);
        if (!context.mounted) return;
        _showThemeSnack(context, 'Theme updated to ${info.name}');
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
            color: selected ? colors.accentColor : Colors.white24,
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
                Icon(info.icon,
                    color: colors.textColor, size: compact ? 18 : 24),
                const Spacer(),
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
              info.name,
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
                info.description,
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
                _ColorDot(color: colors.primaryColor),
                _ColorDot(color: colors.secondaryColor),
                _ColorDot(color: colors.accentColor),
                _ColorDot(color: colors.cardColor),
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
        border: Border.all(color: Colors.white24),
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

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white54),
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
