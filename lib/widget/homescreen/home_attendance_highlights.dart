import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class HomeAttendanceHighlights extends StatelessWidget {
  const HomeAttendanceHighlights({super.key, required this.summary});

  final MonthlyAttendanceSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final enterprise = EnterpriseTheme.of(context);
    final topBonusEmployees =
        context.watch<DashboardProvider>().topBonusEmployees;
    void openDetails() => showMonthlyAttendanceDetails(context, summary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Late and its deduction stay together; the monthly bonus is shown
            // inside Highlights so the two sections are visually distinct.
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: EnterpriseGlass(
                  radius: 18,
                  padding: const EdgeInsets.all(8),
                  glowColor: enterprise.primary,
                  glowOpacity: 0.18,
                  glowingBorder: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 4,
                    children: [
                      _cardHeader(
                        enterprise: enterprise,
                        icon: Icons.insights_rounded,
                        title: translate(enterprise.isKhmerHeritage
                            ? 'attendance_screen.attendance_summary'
                            : 'home_attendance.late'),
                        action: translate('home_attendance.details'),
                        onTap: openDetails,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _lateBonusMetric(
                              enterprise: enterprise,
                              icon: Icons.access_time_filled_rounded,
                              color: const Color(0xFFEF4444),
                              label: translate('home_attendance.total_late'),
                              value:
                                  '${summary?.totalLateCount ?? summary?.lateCount ?? '—'}',
                              onTap: openDetails,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _lateBonusMetric(
                              enterprise: enterprise,
                              icon: Icons.remove_circle_outline_rounded,
                              color: const Color(0xFFF59E0B),
                              label: translate('home_attendance.reduc'),
                              value: summary == null
                                  ? '—'
                                  : (summary.deduction > 0
                                      ? '-\$${summary.deduction.toStringAsFixed(2)}'
                                      : '\$0.00'),
                              onTap: openDetails,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: openDetails,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    translate('home_attendance.approved_late'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: enterprise.text,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    summary == null
                                        ? '—'
                                        : '${summary.excusedLateCount ?? summary.approvedLateCount ?? 0} ${summary.month.isNotEmpty ? "(${summary.month})" : ""}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: enterprise.mutedText,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Right Card: Highlights
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120),
                child: EnterpriseGlass(
                  radius: 18,
                  padding: const EdgeInsets.all(8),
                  glowColor: enterprise.primary,
                  glowOpacity: 0.18,
                  glowingBorder: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _cardHeader(
                        enterprise: enterprise,
                        icon: Icons.auto_awesome_rounded,
                        title: 'Highlights',
                        action: 'View All',
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                HomeHighlightsScreen(api: HomeHighlightApi()),
                          ));
                        },
                      ),
                      const SizedBox(height: 4),
                      _monthlyBonusMetric(
                        enterprise: enterprise,
                        summary: summary,
                        onTap: openDetails,
                      ),
                      const SizedBox(height: 4),
                      // Top Bonus Row
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Top Bonus',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: enterprise.text,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  topBonusEmployees.isEmpty
                                      ? translate(
                                          'home_highlights.no_top_bonus_employee')
                                      : topBonusEmployees.first.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: enterprise.mutedText,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (topBonusEmployees.isNotEmpty &&
                              !enterprise.isKhmerHeritage)
                            SizedBox(
                              width: 42,
                              height: 20,
                              child: Stack(
                                children: [
                                  for (var i = 0;
                                      i < topBonusEmployees.length && i < 3;
                                      i++)
                                    Positioned(
                                      left: i * 11,
                                      child: Tooltip(
                                        message: topBonusEmployees[i].name,
                                        child: _topBonusAvatar(
                                            topBonusEmployees[i].avatar),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (enterprise.isKhmerHeritage &&
                          topBonusEmployees.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final employee in topBonusEmployees.take(3))
                                Tooltip(
                                  message: employee.name,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: enterprise.accent),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: _topBonusAvatar(employee.avatar),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader({
    required EnterpriseTheme enterprise,
    required IconData icon,
    required String title,
    required String action,
    required VoidCallback onTap,
  }) {
    return Row(
      spacing: 4,
      children: [
        Expanded(
          child: Row(
            spacing: 4,
            children: [
              Icon(icon, color: enterprise.accent, size: 15),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Flexible(
                  child: Text(
                    action,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: enterprise.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: enterprise.accent, size: 11),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lateBonusMetric({
    required EnterpriseTheme enterprise,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final heritage = enterprise.isKhmerHeritage;
    final fill = heritage ? Color.lerp(enterprise.text, color, .19)! : color;
    return Material(
      color: heritage
          ? fill
          : fill.withValues(alpha: enterprise.isDark ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 2,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color: heritage ? enterprise.primary : color, size: 12),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: heritage
                            ? enterprise.secondary
                            : enterprise.mutedText,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  color: heritage ? enterprise.secondary : enterprise.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthlyBonusMetric({
    required EnterpriseTheme enterprise,
    required MonthlyAttendanceSummary? summary,
    required VoidCallback onTap,
  }) {
    final progress = summary?.progress ?? 0.0;
    final percentage = (progress * 100).round();
    const color = Color(0xFF10B981);
    return Material(
      color: color.withValues(alpha: enterprise.isDark ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 2,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, color: color, size: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${translate('home_attendance.bonus')} (M)',
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Text(
                      summary == null ? '— / 100%' : '$percentage% / 100%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      summary == null
                          ? '—'
                          : '\$${summary.bonusTarget.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor:
                            enterprise.text.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _topBonusAvatar(String avatarUrl) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 19,
          height: 19,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ColoredBox(color: Color(0xFFE2E8F0)),
          errorWidget: (_, __, ___) => const ColoredBox(
            color: Color(0xFFE2E8F0),
            child:
                Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
