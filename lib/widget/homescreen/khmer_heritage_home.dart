import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KhmerHeritagePanel extends StatelessWidget {
  const KhmerHeritagePanel({
    super.key,
    required this.child,
    this.ornaments = false,
  });

  final Widget child;
  final bool ornaments;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final radius = BorderRadius.circular(19);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: theme.accent.withValues(alpha: .66)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: theme.cardGradient),
          child: ornaments
              ? Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LotusBorder(theme.accent),
                      ),
                    ),
                    child,
                  ],
                )
              : child,
        ),
      ),
    );
  }
}

class KhmerHeritageStatus extends StatelessWidget {
  const KhmerHeritageStatus({
    super.key,
    required this.now,
    required this.greeting,
    required this.khmerGreeting,
  });

  final DateTime now;
  final String greeting;
  final String khmerGreeting;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final local = MaterialLocalizations.of(context);
    final clock = KhmerHeritagePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Text(
              khmerGreeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(greeting, style: TextStyle(color: theme.text, fontSize: 11)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('HH:mm:ss').format(now),
                style: TextStyle(
                  color: theme.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              local.formatFullDate(now),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.text, fontSize: 10),
            ),
          ],
        ),
      ),
    );
    final calendar = KhmerHeritagePanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    color: theme.accent, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    local.formatMonthYear(now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                for (var offset = 1 - now.weekday;
                    offset <= 7 - now.weekday;
                    offset++)
                  Expanded(child: _day(local, theme, offset)),
              ],
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(12) > 17) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [clock, calendar],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 7,
            children: [Expanded(child: clock), Expanded(child: calendar)],
          ),
        );
      },
    );
  }

  Widget _day(MaterialLocalizations local, EnterpriseTheme theme, int offset) {
    final date = DateTime(now.year, now.month, now.day + offset);
    final today = offset == 0;
    final dayLabel = local.narrowWeekdays[date.weekday % 7];
    return Semantics(
      label: local.formatFullDate(date),
      selected: today,
      excludeSemantics: true,
      child: Column(
        spacing: 3,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(dayLabel,
                style: TextStyle(color: theme.mutedText, fontSize: 9)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              color: today ? theme.accent : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                local.formatDecimal(date.day),
                style: TextStyle(
                  color: today ? theme.secondary : theme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LotusBorder extends CustomPainter {
  const _LotusBorder(this.gold);

  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gold.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.save();
    canvas.translate(size.width - 26, size.height + 3);
    for (final angle in [-1.15, -.73, -.36, 0.0, .36, .73, 1.15]) {
      canvas.save();
      canvas.rotate(angle);
      final height = 34 - angle.abs() * 9;
      final petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-13, -height * .56, 0, -height)
        ..quadraticBezierTo(13, -height * .56, 0, 0);
      canvas.drawPath(petal, paint);
      canvas.drawLine(Offset.zero, Offset(0, -height * .67), paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LotusBorder oldDelegate) => oldDelegate.gold != gold;
}
