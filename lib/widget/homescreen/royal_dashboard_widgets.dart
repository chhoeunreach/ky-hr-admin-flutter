import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/models/top_bonus_employee.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_details.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';

const _decorations = 'assets/royal_blue_gold/decorations';

DateTime royalLocalTime(DateTime time) =>
    time.toUtc().add(const Duration(hours: 7));

String royalGreeting(DateTime time) => time.hour < 12
    ? 'morning'
    : time.hour < 17
        ? 'afternoon'
        : 'evening';

class RoyalPanel extends StatelessWidget {
  const RoyalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
    this.goldEdge = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool goldEdge;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(
          color: (goldEdge ? theme.accent : RoyalColors.skyBlue)
              .withValues(alpha: .65),
        ),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Material(
          color: theme.secondary,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.secondary, theme.surface, RoyalColors.navy],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class RoyalPanelPair extends StatelessWidget {
  const RoyalPanelPair({super.key, required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(13) > 18;
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [first, second],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [Expanded(child: first), Expanded(child: second)],
                );
        },
      );
}

class RoyalPanelTitle extends StatelessWidget {
  const RoyalPanelTitle(this.icon, this.label, {super.key, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final List<Color> gradient = color != null
        ? [color!, Color.lerp(color!, Colors.white, 0.28)!]
        : switch (icon) {
            Icons.badge_outlined => const [Color(0xFF2563EB), Color(0xFF60A5FA)],
            Icons.trending_up => const [Color(0xFF059669), Color(0xFF34D399)],
            Icons.auto_awesome => const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
            Icons.calendar_month => const [Color(0xFF9333EA), Color(0xFFC084FC)],
            Icons.history => const [Color(0xFF0284C7), Color(0xFF38BDF8)],
            _ => [theme.accent, RoyalColors.lightGold],
          };
    return Row(
      spacing: 7,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.38),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 13.5),
          ),
        ),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class RoyalClockCard extends StatelessWidget {
  const RoyalClockCard({super.key, required this.clock});

  final ValueListenable<DateTime> clock;

  @override
  Widget build(BuildContext context) => RoyalPanel(
        goldEdge: true,
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: 2,
              width: 95,
              child: Opacity(
                opacity: .24,
                child: SvgPicture.asset('$_decorations/angkor_silhouette.svg'),
              ),
            ),
            ValueListenableBuilder<DateTime>(
              valueListenable: clock,
              builder: (context, time, _) {
                final now = royalLocalTime(time);
                final greeting = royalGreeting(now);
                final locale = Localizations.localeOf(context).languageCode;
                final twelveHour = !MediaQuery.alwaysUse24HourFormatOf(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      switch (greeting) {
                        'morning' => 'អរុណសួស្តី!',
                        'afternoon' => 'ទិវាសួស្តី!',
                        _ => 'សាយណ្ហសួស្តី!',
                      },
                      style: TextStyle(
                        color: EnterpriseTheme.of(context).accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      switch (greeting) {
                        'morning' => 'Good morning!',
                        'afternoon' => 'Good afternoon!',
                        _ => 'Good evening!',
                      },
                      style: const TextStyle(fontSize: 11),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (twelveHour
                                ? DateFormat.jms(locale)
                                : DateFormat.Hms(locale))
                            .format(now),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Row(
                      spacing: 5,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: RoyalColors.gold),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMMEEEEd(locale).format(now),
                            style: const TextStyle(
                                fontSize: 10, color: RoyalColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

bool royalHasTime(String value) =>
    value.trim().isNotEmpty && value.trim() != '-';

class RoyalTodayAttendance extends StatelessWidget {
  const RoyalTodayAttendance({
    super.key,
    required this.checkIn,
    required this.checkOut,
    required this.hours,
    this.status,
  });

  final String checkIn;
  final String checkOut;
  final String hours;
  final String? status;

  @override
  Widget build(BuildContext context) => RoyalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 7,
          children: [
            RoyalPanelTitle(Icons.badge_outlined, translate('royal.today')),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _metric(translate('home_screen.check_in'), checkIn,
                    RoyalColors.success),
                _metric(translate('home_screen.check_out'), checkOut,
                    RoyalColors.danger),
              ],
            ),
            if (royalHasTime(checkIn) && royalHasTime(hours))
              Text('${translate('royal.total_hours')}  ·  $hours',
                  style: const TextStyle(
                      color: RoyalColors.lightGold, fontSize: 11)),
            Text(
              status ??
                  translate(royalHasTime(checkOut)
                      ? 'royal.checked_out'
                      : royalHasTime(checkIn)
                          ? 'royal.checked_in'
                          : 'royal.not_checked_in'),
              style: const TextStyle(
                  color: RoyalColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _metric(String label, String value, Color color) => DecoratedBox(
        decoration: BoxDecoration(
          color: RoyalColors.navy.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: RoyalColors.textSecondary, fontSize: 10)),
              Text(royalHasTime(value) ? value : '—',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}

class RoyalQuotation extends StatelessWidget {
  const RoyalQuotation({
    super.key,
    required this.text,
    this.translation,
    this.author,
    required this.onTap,
  });

  final String text;
  final String? translation;
  final String? author;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RoyalPanel(
        padding: EdgeInsets.zero,
        goldEdge: true,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: -12,
                bottom: -9,
                child: SvgPicture.asset('$_decorations/lotus.svg', width: 54),
              ),
              Positioned(
                right: -10,
                bottom: 0,
                child: Opacity(
                  opacity: .55,
                  child: SvgPicture.asset('$_decorations/angkor_silhouette.svg',
                      width: 74),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 9),
                child: Column(
                  spacing: 3,
                  children: [
                    Text('“ $text ”',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: RoyalColors.lightGold,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Container(width: 32, height: 1, color: RoyalColors.gold),
                    if (translation != null)
                      Text(translation!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    if (author != null && author!.trim().isNotEmpty)
                      Text(author!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class RoyalAttendanceHighlights extends StatelessWidget {
  const RoyalAttendanceHighlights({
    super.key,
    required this.summary,
    required this.employees,
    required this.quote,
    required this.onQuote,
    this.loading = false,
    this.onRetry,
  });

  final MonthlyAttendanceSummary? summary;
  final List<TopBonusEmployee> employees;
  final String? quote;
  final VoidCallback onQuote;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final monthly = summary;
    final currency = monthly == null
        ? null
        : NumberFormat.simpleCurrency(
                locale: Localizations.localeOf(context).languageCode,
                name: monthly.bonusCurrency)
            .format(monthly.bonusTarget);
    final ranked = employees.take(3).toList();
    return RoyalPanelPair(
      first: RoyalPanel(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            RoyalPanelTitle(Icons.trending_up, translate('royal.late_bonus')),
            if (loading)
              const LinearProgressIndicator()
            else if (monthly == null && onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(translate('royal.retry')),
              )
            else
              InkWell(
                onTap: monthly == null
                    ? null
                    : () => showMonthlyAttendanceDetails(context, monthly),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      _metric(
                          Icons.schedule_rounded,
                          RoyalColors.danger,
                          const [Color(0xFFEF4444), Color(0xFFF87171)],
                          translate('royal.late_month'),
                          '${monthly?.totalLateCount ?? monthly?.lateCount ?? '—'}'),
                      _metric(
                          Icons.savings_rounded,
                          RoyalColors.success,
                          const [Color(0xFF10B981), Color(0xFF34D399)],
                          translate('royal.bonus_target'),
                          currency ?? '—'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      second: RoyalPanel(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 3,
          children: [
            RoyalPanelTitle(Icons.auto_awesome, translate('royal.highlights')),
            _link(
              icon: Icons.emoji_events_rounded,
              gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              title: translate('royal.top_bonus'),
              subtitle: ranked.isEmpty && !loading
                  ? translate('royal.no_rankings')
                  : translate('royal.this_month'),
              onTap: ranked.isEmpty ? null : () => _showRankings(context),
            ),
            if (ranked.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [
                  for (final employee in ranked)
                    Tooltip(message: employee.name, child: _avatar(employee)),
                ],
              ),
            if (quote != null)
              _link(
                icon: Icons.format_quote_rounded,
                gradient: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                title: translate('royal.quotation'),
                subtitle: quote!,
                onTap: onQuote,
              ),
          ],
        ),
      ),
    );
  }

  Widget _metric(IconData icon, Color color, List<Color> gradient,
          String label, String value) =>
      Row(
        spacing: 7,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.38),
                  blurRadius: 5,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 13, color: Colors.white),
            ),
          ),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: gradient.first, fontWeight: FontWeight.w900)),
          ),
        ],
      );

  Widget _link({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(
            spacing: 7,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9.5, color: RoyalColors.textSecondary)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    size: 14, color: RoyalColors.gold),
            ],
          ),
        ),
      );

  Widget _avatar(TopBonusEmployee employee) => CircleAvatar(
        radius: 13,
        backgroundColor: RoyalColors.navy,
        child: employee.avatar.isEmpty
            ? const Icon(Icons.person, size: 15, color: RoyalColors.lightGold)
            : ClipOval(
                child: CachedNetworkImage(
                  imageUrl: employee.avatar,
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  memCacheWidth: 104,
                  errorWidget: (_, __, ___) => const Icon(Icons.person,
                      size: 15, color: RoyalColors.lightGold),
                ),
              ),
      );

  void _showRankings(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(translate('royal.top_bonus'),
                style: Theme.of(context).textTheme.titleLarge),
            for (final (index, employee) in employees.indexed)
              ListTile(
                leading: _avatar(employee),
                title: Text('${index + 1}. ${employee.name}'),
                subtitle:
                    Text('${employee.completedDays} / ${employee.workingDays}'),
                trailing: Text(NumberFormat.percentPattern()
                    .format(employee.progressPercent / 100)),
              ),
          ],
        ),
      );
}

class RoyalAttendanceScanner extends StatelessWidget {
  const RoyalAttendanceScanner({
    super.key,
    required this.animation,
    required this.animate,
    required this.method,
    required this.status,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool animate;
  final String method;
  final String? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final qr = method.toLowerCase() == 'qr';
    final label = translate(qr ? 'royal.scan' : 'dashboard_screen.attendance');
    final diameter =
        (MediaQuery.sizeOf(context).width * .36).clamp(130.0, 160.0);
    final button = Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: DecoratedBox(
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: RoyalColors.goldGradient),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: RoyalColors.royalBlue,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1,
                  colors: [
                    RoyalColors.electricBlue,
                    RoyalColors.royalBlue,
                    RoyalColors.navy
                  ],
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: diameter - 8,
                  child: Icon(
                    qr
                        ? Icons.qr_code_scanner_rounded
                        : method.toLowerCase() == 'nfc'
                            ? Icons.nfc_rounded
                            : Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: Column(
        spacing: 4,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 66,
                child: SvgPicture.asset('$_decorations/gold_wave.svg',
                    fit: BoxFit.fill),
              ),
              Positioned(
                bottom: 21,
                left: 10,
                child: Opacity(
                  opacity: .55,
                  child: SvgPicture.asset('$_decorations/lotus.svg', width: 58),
                ),
              ),
              Positioned(
                bottom: 21,
                right: 10,
                child: Opacity(
                  opacity: .55,
                  child: SvgPicture.asset('$_decorations/lotus.svg', width: 58),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: AnimatedBuilder(
                  animation: animate ? animation : kAlwaysDismissedAnimation,
                  child: button,
                  builder: (context, child) {
                    final t = animate ? animation.value : 0.0;
                    final breathe = animate
                        ? 1 + 0.028 * (0.5 - 0.5 * math.cos(t * math.pi * 2))
                        : 1.0;
                    return SizedBox(
                      width: diameter,
                      height: diameter,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (animate)
                            for (final phase in const [0.0, 0.5])
                              IgnorePointer(
                                child: Transform.scale(
                                  scale: 1 + .45 * ((t + phase) % 1),
                                  child: Opacity(
                                    opacity: (1 - ((t + phase) % 1)) * .55,
                                    child: Container(
                                      width: diameter,
                                      height: diameter,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: phase == 0
                                              ? RoyalColors.gold
                                              : RoyalColors.skyBlue,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          if (animate)
                            IgnorePointer(
                              child: Transform.rotate(
                                angle: t * math.pi * 2,
                                child: CustomPaint(
                                  size: Size.square(diameter + 18),
                                  painter: _GoldArcPainter(),
                                ),
                              ),
                            ),
                          Transform.scale(
                            scale: breathe,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: RoyalColors.skyBlue
                                        .withValues(alpha: .42),
                                    blurRadius: 14 + t * 12,
                                  ),
                                  BoxShadow(
                                    color: RoyalColors.gold
                                        .withValues(alpha: .14 + .16 * t),
                                    blurRadius: 22 + t * 14,
                                    spreadRadius: t * 5,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (qr)
            DecoratedBox(
              decoration: BoxDecoration(
                  gradient: RoyalColors.goldGradient,
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                child: Text(translate('royal.auto_attendance'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: RoyalColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          if (status != null)
            Text(status!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RoyalColors.lightGold)),
        ],
      ),
    );
  }
}

class _GoldArcPainter extends CustomPainter {
  const _GoldArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        transform: GradientRotation(-math.pi / 2),
        colors: [
          Colors.transparent,
          RoyalColors.lightGold,
          RoyalColors.gold,
          RoyalColors.darkGold,
          Colors.transparent,
        ],
        stops: [0.0, .2, .45, .7, 1.0],
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 1.15,
      false,
      stroke,
    );
    canvas.drawArc(rect.deflate(2), math.pi / 2, math.pi * .55, false, stroke);
  }

  @override
  bool shouldRepaint(covariant _GoldArcPainter oldDelegate) => false;
}
