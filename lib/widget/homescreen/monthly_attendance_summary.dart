import 'dart:async';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_strings.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/homescreen/home_highlights_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

class HomeAttendanceClockSummary extends StatelessWidget {
  const HomeAttendanceClockSummary(
      {super.key,
      required this.clock,
      required this.summary,
      this.highlightsEnabled = false,
      this.highlightsApi});

  final Widget clock;
  final MonthlyAttendanceSummary? summary;
  final bool highlightsEnabled;
  final HomeHighlightApi? highlightsApi;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final indicator = highlightsEnabled
            ? _HomeAttendanceTabs(summary: summary, api: highlightsApi)
            : HomeMonthlyAttendanceSummary(summary: summary);
        if (constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              children: [clock, const SizedBox(height: 10), indicator]);
        }
        return Row(children: [
          Expanded(child: clock),
          const SizedBox(width: 12),
          Expanded(child: indicator)
        ]);
      });
}

class _HomeAttendanceTabs extends StatefulWidget {
  const _HomeAttendanceTabs({required this.summary, this.api});

  final MonthlyAttendanceSummary? summary;
  final HomeHighlightApi? api;

  @override
  State<_HomeAttendanceTabs> createState() => _HomeAttendanceTabsState();
}

class _HomeAttendanceTabsState extends State<_HomeAttendanceTabs>
    with WidgetsBindingObserver {
  late final HomeHighlightApi _api = widget.api ?? HomeHighlightApi();
  late final bool _ownsApi = widget.api == null;
  final List<HomeHighlight> _items = [];
  int _tab = 0;
  int _generation = 0;
  bool _loading = true;
  String? _error;
  HomeHighlightDisplaySettings _displaySettings =
      const HomeHighlightDisplaySettings();
  Timer? _switchTimer;
  Timer? _settingsTimer;
  bool _foreground = true;

  void _scheduleSwitch() {
    _switchTimer?.cancel();
    _switchTimer = null;
    if (!_foreground ||
        !_displaySettings.autoSwitchEnabled ||
        _items.isEmpty ||
        _error != null) return;
    final seconds = _tab == 0
        ? _displaySettings.lateBonusSeconds
        : _displaySettings.highlightsSeconds;
    _switchTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      if ((ModalRoute.of(context)?.isCurrent ?? true)) {
        setState(() => _tab = _tab == 0 ? 1 : 0);
      }
      _scheduleSwitch();
    });
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    _scheduleSwitch();
    if (tab == 1 && !_loading) _load(silent: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _settingsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground && !_loading) _load(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _load(silent: true);
      _scheduleSwitch();
    } else {
      _switchTimer?.cancel();
      _switchTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _switchTimer?.cancel();
    _settingsTimer?.cancel();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      if (!silent) _error = null;
    });
    try {
      final feed = await _api.feed();
      if (!mounted || generation != _generation) return;
      final changed = !_displaySettings.sameAs(feed.settings);
      setState(() {
        _items
          ..clear()
          ..addAll(feed.items);
        _displaySettings = feed.settings;
        _error = null;
        _loading = false;
        if (_items.isEmpty && _displaySettings.autoSwitchEnabled) _tab = 0;
      });
      if (changed || !(_switchTimer?.isActive ?? false) || _items.isEmpty)
        _scheduleSwitch();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (silent && _items.isNotEmpty) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      _scheduleSwitch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return Material(
      color: theme.surface.withValues(alpha: .85),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.text.withValues(alpha: .10))),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: _HomeAttendanceTab(
                    label: homeHighlightsText('Late & Bonus'),
                    icon: Icons.insights_rounded,
                    selected: _tab == 0,
                    onTap: () => _selectTab(0),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _HomeAttendanceTab(
                    label: homeHighlightsText('Highlights'),
                    icon: Icons.auto_awesome_rounded,
                    selected: _tab == 1,
                    showDot: _items.isNotEmpty,
                    onTap: () => _selectTab(1),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.text.withValues(alpha: .08),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tab == 0
                ? HomeMonthlyAttendanceSummary(
                    key: const ValueKey('home-late-bonus-tab'),
                    summary: widget.summary,
                    embedded: true,
                  )
                : HomeHighlightCarousel(
                    key: const ValueKey('home-highlights-tab'),
                    api: _api,
                    items: _items,
                    loading: _loading,
                    error: _error,
                    onRetry: _load,
                  ),
          ),
        ],
      ),
    );
  }
}

class _HomeAttendanceTab extends StatelessWidget {
  const _HomeAttendanceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final color = selected ? theme.secondary : theme.mutedText;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.secondary.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showDot) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A server-calculated preview; opening the card explains what progress means.
class HomeMonthlyAttendanceSummary extends StatelessWidget {
  const HomeMonthlyAttendanceSummary(
      {super.key, required this.summary, this.embedded = false});

  final MonthlyAttendanceSummary? summary;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final data = summary;
    String tr(String key) => translate('home_attendance.$key');
    final amount =
        data == null ? '—' : '\$${data.bonusTarget.toStringAsFixed(2)}';
    final percentage =
        data == null ? '—' : '${(data.progress * 100).toStringAsFixed(0)}%';
    final lateFormula = tr('late_formula')
        .replaceAll('{total}', '${data?.totalLateCount ?? '—'}')
        .replaceAll('{excused}', '${data?.excusedLateCount ?? '—'}')
        .replaceAll('{deductible}', '${data?.lateCount ?? '—'}');
    void openDetails() => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(tr('details_title')),
            content: Text(data == null
                ? tr('unavailable')
                : '${tr('month')}: ${data.month}\n\n'
                    '${tr('total_late')}: ${data.totalLateCount ?? '—'}\n'
                    '$lateFormula\n'
                    '${tr('late_formula_explanation')}\n\n'
                    '${tr('approved_late')}: ${data.approvedLateCount ?? '—'}\n'
                    '${tr('approved_time_leave')}: ${data.approvedTimeLeaveCount ?? '—'}\n'
                    '${tr('deduction')}: \$${data.deduction.toStringAsFixed(2)}\n\n'
                    '${tr('bonus')}: $amount · $percentage\n'
                    '${tr('days').replaceAll('{completed}', '${data.completedDays}').replaceAll('{total}', '${data.workingDays}')}\n\n'
                    '${tr('explanation')}'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('close')))
            ],
          ),
        );
    final content = Padding(
      padding: const EdgeInsets.all(10),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: theme.text, fontSize: 11, fontWeight: FontWeight.w600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('month'),
                style: TextStyle(color: theme.mutedText, fontSize: 10)),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 14, color: theme.secondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(
                      '${tr('total_late')} ${data?.totalLateCount ?? '—'}')),
              Text(
                  data == null
                      ? '—'
                      : '${data.deduction > 0 ? '-' : ''}\$${data.deduction.toStringAsFixed(2)}',
                  key: const ValueKey('home-late-deduction')),
            ]),
            const SizedBox(height: 5),
            Tooltip(
              message: tr('late_formula_explanation'),
              child: Text(lateFormula,
                  key: const ValueKey('home-late-formula'),
                  style: TextStyle(
                      color: theme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 5),
            Text(
                '${tr('approved_late')}: ${data?.approvedLateCount ?? '—'} · '
                '${tr('approved_time_leave')}: ${data?.approvedTimeLeaveCount ?? '—'}',
                key: const ValueKey('home-approved-attendance'),
                style: TextStyle(color: theme.mutedText, fontSize: 10)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('${tr('bonus')} $amount')),
              const SizedBox(width: 4),
              Text(percentage,
                  key: const ValueKey('home-bonus-progress'),
                  style: TextStyle(
                      color: theme.secondary, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data?.progress ?? 0,
                minHeight: 4,
                color: theme.secondary,
                backgroundColor: theme.text.withValues(alpha: .10),
              ),
            ),
          ],
        ),
      ),
    );
    if (embedded) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: openDetails,
        child: content,
      );
    }
    return Material(
      color: theme.surface.withValues(alpha: .85),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.text.withValues(alpha: .10))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: openDetails,
        child: content,
      ),
    );
  }
}
