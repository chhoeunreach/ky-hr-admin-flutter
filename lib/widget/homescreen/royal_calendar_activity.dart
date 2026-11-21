import 'dart:async';

import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceReportResponse.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeAttendance.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeTodayAttendance.dart';
import 'package:cnattendance/data/source/network/model/employeeleavecalendarbyday/EmployeeLeavesByDayResponse.dart';
import 'package:cnattendance/data/source/network/model/hollidays/Holidays.dart';
import 'package:cnattendance/provider/holidaycontroller.dart';
import 'package:cnattendance/provider/leavecalendarcontroller.dart';
import 'package:cnattendance/repositories/attendancereportrepository.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:cnattendance/utils/attendance_status.dart';
import 'package:cnattendance/widget/attendancescreen/attendance_status_label.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:table_calendar/table_calendar.dart';

import 'royal_dashboard_widgets.dart';

typedef RoyalCalendarBuilder = Widget Function(
    BuildContext context, RoyalCalendarParts parts);

class RoyalCalendarParts {
  const RoyalCalendarParts({
    this.clock,
    this.today,
    this.calendar,
    this.recent,
  });

  final Widget? clock;
  final Widget? today;
  final Widget? calendar;
  final Widget? recent;
}

class RoyalCalendarActivity extends StatefulWidget {
  const RoyalCalendarActivity({
    super.key,
    required this.clock,
    required this.checkIn,
    required this.checkOut,
    required this.hours,
    required this.hasAttendance,
    required this.showClock,
    required this.showTodayAttendance,
    required this.hasHolidays,
    required this.hasOfficeCalendar,
    required this.isAd,
    required this.attendanceLoading,
    required this.attendanceError,
    required this.builder,
  });

  final ValueListenable<DateTime> clock;
  final String checkIn, checkOut, hours;
  final bool hasAttendance, hasHolidays, hasOfficeCalendar, isAd;
  final bool showClock, showTodayAttendance;
  final bool attendanceLoading, attendanceError;
  final RoyalCalendarBuilder builder;

  @override
  State<RoyalCalendarActivity> createState() => _RoyalCalendarActivityState();
}

class _RoyalCalendarActivityState extends State<RoyalCalendarActivity> {
  final _attendance = AttendanceReportRepository();
  final _holidays = HolidayController();
  final _officeCalendar = LeaveCalendarController();
  final _reports = <(int, int), Future<AttendanceReportResponse>>{};
  final _details = <String, Future<EmployeeLeavesByDayResponse>>{};
  Future<List<Holidays>>? _holidayList;
  Future<Set<String>>? _companyLeaveDates;
  late DateTime _today;
  late DateTime _selected;
  late DateTime _focused;
  late Future<_MonthData> _month;
  late Future<List<EmployeeAttendance>> _recent;
  late Future<
          ({List<EmployeeAttendance> rows, EmployeeTodayAttendance? summary})>
      _todayAttendance;

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd', 'en').format(date);

  @override
  void initState() {
    super.initState();
    _today = royalLocalTime(widget.clock.value);
    _selected = _focused = _today;
    _load();
  }

  @override
  void didUpdateWidget(covariant RoyalCalendarActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    final now = royalLocalTime(widget.clock.value);
    final dayChanged = !isSameDay(_today, now);
    if (dayChanged && isSameDay(_selected, _today)) {
      _selected = _focused = now;
    }
    _today = now;
    if (oldWidget.isAd != widget.isAd ||
        oldWidget.hasAttendance != widget.hasAttendance ||
        oldWidget.hasOfficeCalendar != widget.hasOfficeCalendar ||
        oldWidget.hasHolidays != widget.hasHolidays ||
        oldWidget.checkIn != widget.checkIn ||
        oldWidget.checkOut != widget.checkOut ||
        (oldWidget.attendanceLoading && !widget.attendanceLoading) ||
        dayChanged) {
      _reports.clear();
      _details.clear();
      _holidayList = null;
      _companyLeaveDates = null;
      _load();
    }
  }

  void _load() {
    _loadMonth();
    final previous = DateTime(_today.year, _today.month - 1, 1);
    _todayAttendance = _loadTodayAttendance(_rowsFor(_today));
    _recent = Future.wait([
      _todayAttendance.then((today) => today.rows),
      _rowsFor(previous),
    ]).then(
      (months) => months.expand((rows) => rows).toList()
        ..sort((a, b) => b.attendanceDateAd.compareTo(a.attendanceDateAd)),
    );
  }

  Future<({List<EmployeeAttendance> rows, EmployeeTodayAttendance? summary})>
      _loadTodayAttendance(Future<List<EmployeeAttendance>> todayRows) async {
    final date = widget.isAd ? _today : _today.toNepaliDateTime();
    final currentMonth = _reports[(date.year, date.month)];
    final rows = await todayRows;
    final report = await currentMonth;
    return (rows: rows, summary: report?.data.employeeTodayAttendance);
  }

  void _loadMonth() {
    final focused = _focused;
    final holidays = widget.hasHolidays
        ? _holidayList ??= _holidays
            .getHolidays(showLoader: false)
            .then(
              (value) => value.data ?? const <Holidays>[],
            )
            .timeout(const Duration(seconds: 15))
        : Future.value(const <Holidays>[]);
    final leaves = widget.hasOfficeCalendar
        ? _companyLeaveDates ??= _officeCalendar
            .getLeaves()
            .then(
              (value) => {
                for (final entry in value.data)
                  if ((int.tryParse(entry.leaveCount) ?? 0) > 0) entry.date,
              },
            )
            .timeout(const Duration(seconds: 15))
        : Future.value(const <String>{});
    _month = Future.wait<Object>([_rowsFor(focused), holidays, leaves]).then(
      (values) => _MonthData(
        {
          for (final row in values[0] as List<EmployeeAttendance>)
            row.attendanceDateAd: row,
        },
        {
          for (final holiday in values[1] as List<Holidays>)
            holiday.eventDate: holiday,
        },
        values[2] as Set<String>,
      ),
    );
  }

  Future<List<EmployeeAttendance>> _rowsFor(DateTime date) async {
    if (!widget.hasAttendance) return const [];
    final first = DateTime(date.year, date.month);
    final last = DateTime(date.year, date.month + 1, 0);
    final endpoints = widget.isAd
        ? {(date.year, date.month)}
        : {
            (first.toNepaliDateTime().year, first.toNepaliDateTime().month),
            (last.toNepaliDateTime().year, last.toNepaliDateTime().month),
          };
    // The existing endpoint resolves the year server-side.
    final year = widget.isAd ? _today.year : _today.toNepaliDateTime().year;
    final results = await Future.wait([
      for (final key in endpoints)
        if (key.$1 == year)
          _reports.putIfAbsent(
            key,
            () => _attendance
                .getAttendanceReport(key.$2 - 1)
                .timeout(const Duration(seconds: 15)),
          ),
    ]);
    return [
      for (final row
          in results.expand((report) => report.data.employeeAttendance))
        if (DateTime.tryParse(row.attendanceDateAd) case final DateTime value)
          if (value.year == date.year && value.month == date.month) row,
    ];
  }

  void _retry() => setState(() {
        _reports.clear();
        _holidayList = null;
        _companyLeaveDates = null;
        _load();
      });

  @override
  Widget build(BuildContext context) {
    final showCalendar =
        widget.hasAttendance || widget.hasHolidays || widget.hasOfficeCalendar;
    return FutureBuilder<_MonthData>(
      future: _month,
      builder: (context, snapshot) {
        final showAttendance =
            widget.hasAttendance && widget.showTodayAttendance;
        return widget.builder(
          context,
          RoyalCalendarParts(
            clock:
                widget.showClock ? RoyalClockCard(clock: widget.clock) : null,
            today: showAttendance ? _buildToday(snapshot) : null,
            calendar: showCalendar ? _buildCalendar(snapshot) : null,
            recent: widget.hasAttendance ? _buildRecent() : null,
          ),
        );
      },
    );
  }

  Widget _buildToday(AsyncSnapshot<_MonthData> calendar) => FutureBuilder<
          ({List<EmployeeAttendance> rows, EmployeeTodayAttendance? summary})>(
        future: _todayAttendance,
        builder: (context, snapshot) {
          final key = _dateKey(_today);
          final rows = (snapshot.data?.rows ?? const <EmployeeAttendance>[])
              .where((row) => row.attendanceDateAd == key);
          final summary = snapshot.data?.summary;
          final summaryStatus = summary?.resolvedDayStatus;
          final exception = rows
                  .map((row) => row.resolvedDayStatus)
                  .where(attendanceExceptions.contains)
                  .firstOrNull ??
              (attendanceExceptions.contains(summaryStatus)
                  ? summaryStatus
                  : null);
          String withReportedTime(String value, String? summaryValue,
              String Function(EmployeeAttendance) timeForRow) {
            if (hasAttendanceTime(value)) return value;
            if (summaryValue != null && hasAttendanceTime(summaryValue)) {
              return summaryValue;
            }
            return rows.map(timeForRow).where(hasAttendanceTime).firstOrNull ??
                '-';
          }

          final checkIn = withReportedTime(
              widget.checkIn, summary?.checkInAt, (row) => row.checkIn);
          final checkOut = withReportedTime(
              widget.checkOut, summary?.checkOutAt, (row) => row.checkOut);
          final loading = widget.attendanceLoading ||
              snapshot.connectionState != ConnectionState.done ||
              (widget.hasHolidays &&
                  !calendar.hasData &&
                  calendar.connectionState != ConnectionState.done);
          final status = switch (exception) {
            final String dayStatus => attendanceStatusLabel(dayStatus, ''),
            _ when hasAttendanceTime(checkIn) || hasAttendanceTime(checkOut) =>
              null,
            _ when calendar.data?.holidays.containsKey(key) == true =>
              attendanceStatusLabel('holiday', ''),
            _ when widget.attendanceError || snapshot.hasError =>
              translate('royal.attendance_unavailable'),
            _ when loading => translate('royal.attendance_pending'),
            _ => attendanceStatusLabel('absent', ''),
          };
          return RoyalTodayAttendance(
            checkIn: checkIn,
            checkOut: checkOut,
            hours: widget.hours,
            status: status,
          );
        },
      );

  Widget _buildCalendar(AsyncSnapshot<_MonthData> snapshot) {
    final data =
        snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
    return RoyalPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          RoyalPanelTitle(Icons.calendar_month, translate('royal.calendar')),
          Row(
            children: [
              _monthButton(-1),
              Expanded(
                  child: Text(
                DateFormat.yMMM(Localizations.localeOf(context).languageCode)
                    .format(_focused),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              )),
              _monthButton(1),
            ],
          ),
          TableCalendar<int>(
            key: ValueKey((_focused.year, _focused.month)),
            locale: Localizations.localeOf(context).languageCode,
            currentDay: _today,
            firstDay: DateTime(_today.year - 1),
            lastDay: DateTime(_today.year + 1, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (date) => isSameDay(_selected, date),
            rowHeight: 29,
            daysOfWeekHeight: 25,
            availableGestures: AvailableGestures.horizontalSwipe,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 9),
              weekendStyle:
                  TextStyle(fontSize: 9, color: RoyalColors.lightGold),
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(fontSize: 10),
              weekendTextStyle: TextStyle(fontSize: 10),
              todayTextStyle: TextStyle(fontSize: 10, color: Colors.white),
              selectedTextStyle:
                  TextStyle(fontSize: 10, color: RoyalColors.navy),
              todayDecoration: BoxDecoration(
                  color: RoyalColors.royalBlue, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(
                  color: RoyalColors.gold, shape: BoxShape.circle),
            ),
            headerVisible: false,
            onPageChanged: _changeMonth,
            onDaySelected: (day, focused) {
              if (_focused.month != focused.month ||
                  _focused.year != focused.year) {
                _changeMonth(focused);
              }
              setState(() => _selected = day);
              _showDay(day, data);
            },
            eventLoader: (date) {
              final key = _dateKey(date);
              final row = data?.rows[key];
              return [
                if (row != null &&
                    (royalHasTime(row.checkIn) || royalHasTime(row.checkOut)))
                  0,
                if (row?.leaveStatus != null ||
                    row?.timeLeaveStatus != null ||
                    data?.companyLeaveDates.contains(key) == true)
                  1,
                if (data?.holidays.containsKey(key) == true) 2,
              ];
            },
            calendarBuilders: CalendarBuilders<int>(
              dowBuilder: (context, date) => Center(
                child: Text(
                  MaterialLocalizations.of(context)
                      .narrowWeekdays[date.weekday % 7],
                  style: const TextStyle(fontSize: 9),
                ),
              ),
              markerBuilder: (context, date, items) => items.isEmpty
                  ? null
                  : Positioned(
                      bottom: 1,
                      child: Row(
                        spacing: 2,
                        children: [
                          for (final item in items)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: [
                                  RoyalColors.success,
                                  const Color(0xffd5b6ff),
                                  RoyalColors.gold
                                ][item],
                              ),
                              child: const SizedBox.square(dimension: 3),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator()
          else if (snapshot.hasError)
            TextButton(
                onPressed: _retry, child: Text(translate('royal.retry'))),
        ],
      ),
    );
  }

  Widget _monthButton(int direction) {
    final next = DateTime(_focused.year, _focused.month + direction);
    final local = MaterialLocalizations.of(context);
    return IconButton(
      tooltip:
          direction < 0 ? local.previousMonthTooltip : local.nextMonthTooltip,
      onPressed: next.year < _today.year - 1 || next.year > _today.year + 1
          ? null
          : () => _changeMonth(next),
      icon: Icon(direction < 0 ? Icons.chevron_left : Icons.chevron_right,
          color: RoyalColors.lightGold,
          size: 18),
    );
  }

  Widget _activityBadge(IconData icon, [Color? color]) {
    final gradient = switch (icon) {
      Icons.logout => const [Color(0xFFE11D48), Color(0xFFFB7185)],
      Icons.login => const [Color(0xFF059669), Color(0xFF34D399)],
      Icons.event_busy => const [Color(0xFF9333EA), Color(0xFFC084FC)],
      Icons.schedule => const [Color(0xFFEA580C), Color(0xFFFBBF24)],
      Icons.celebration => const [Color(0xFFEC4899), Color(0xFFF472B6)],
      Icons.cake_outlined => const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      _ => color != null
          ? [color, Color.lerp(color, Colors.white, 0.28)!]
          : const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    };
    return Container(
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
            color: gradient.first.withValues(alpha: 0.38),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  void _changeMonth(DateTime date) {
    setState(() {
      _focused = date;
      _loadMonth();
    });
  }

  Widget _buildRecent() => RoyalPanel(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 5,
          children: [
            RoyalPanelTitle(Icons.history, translate('royal.recent')),
            FutureBuilder<List<EmployeeAttendance>>(
              future: _recent,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return TextButton(
                      onPressed: _retry, child: Text(translate('royal.retry')));
                }
                final locale = Localizations.localeOf(context).languageCode;
                final items = [
                  for (final row
                      in snapshot.data ?? const <EmployeeAttendance>[])
                    ..._activityItems(row),
                ].take(4).toList();
                if (items.isEmpty) {
                  return Text(translate('royal.no_activity'),
                      style: const TextStyle(fontSize: 11));
                }
                return Column(
                  children: [
                    for (final (title, date, detail, color, icon) in items)
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => AttendanceScreen()),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            spacing: 8,
                            children: [
                              _activityBadge(icon, color),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800)),
                                    Text(
                                      '${DateFormat.MMMd(locale).format(date)} · $detail',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: RoyalColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Iterable<(String, DateTime, String, Color, IconData)> _activityItems(
      EmployeeAttendance row) sync* {
    final day = DateTime.tryParse(row.attendanceDateAd);
    if (day == null || _dateKey(day).compareTo(_dateKey(_today)) > 0) return;
    final isToday = isSameDay(_today, day);
    final checkOut = isToday && royalHasTime(widget.checkOut)
        ? widget.checkOut
        : row.checkOut;
    final checkIn =
        isToday && royalHasTime(widget.checkIn) ? widget.checkIn : row.checkIn;
    if (royalHasTime(checkOut)) {
      yield (
        translate('home_screen.check_out'),
        day,
        checkOut,
        RoyalColors.danger,
        Icons.logout
      );
    }
    if (royalHasTime(checkIn)) {
      yield (
        translate('home_screen.check_in'),
        day,
        checkIn,
        RoyalColors.success,
        Icons.login
      );
    }
    if (row.leaveStatus case final String status when status.isNotEmpty) {
      yield (
        translate('attendance_screen.leave_request'),
        day,
        _requestStatus(status),
        RoyalColors.gold,
        Icons.event_busy
      );
    }
    if (row.timeLeaveStatus case final String status when status.isNotEmpty) {
      yield (
        translate('attendance_screen.time_leave_request'),
        day,
        _requestStatus(status),
        RoyalColors.gold,
        Icons.schedule
      );
    }
  }

  String _requestStatus(String status) => switch (status.toLowerCase()) {
        'approved' => translate('royal.approved'),
        'pending' => translate('royal.attendance_pending'),
        'review' => translate('royal.in_review'),
        _ => status,
      };

  void _showDay(DateTime day, _MonthData? data) {
    final key = _dateKey(day);
    final row = data?.rows[key];
    final holiday = data?.holidays[key];
    Future<EmployeeLeavesByDayResponse> request() => _details.putIfAbsent(
          key,
          () => _officeCalendar
              .getLeavesByDay(key)
              .timeout(const Duration(seconds: 15)),
        );
    Future<EmployeeLeavesByDayResponse>? details =
        widget.hasOfficeCalendar ? request() : null;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
                DateFormat.yMMMMEEEEd(
                        Localizations.localeOf(context).languageCode)
                    .format(day),
                style: Theme.of(context).textTheme.titleLarge),
            if (row != null)
              for (final (title, _, detail, color, icon) in _activityItems(row))
                ListTile(
                    leading: _activityBadge(icon, color),
                    title: Text(title),
                    subtitle: Text(detail)),
            if (holiday != null)
              ListTile(
                  leading: _activityBadge(Icons.celebration),
                  title: Text(holiday.event),
                  subtitle: Text(holiday.description)),
            if (details != null)
              FutureBuilder<EmployeeLeavesByDayResponse>(
                future: details,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return TextButton(
                      onPressed: () => setSheetState(() {
                        _details.remove(key);
                        details = request();
                      }),
                      child: Text(translate('royal.retry')),
                    );
                  }
                  final office = snapshot.data?.data;
                  final items = [
                    if (office?.holidays case final item? when holiday == null)
                      ListTile(
                          leading: _activityBadge(Icons.celebration),
                          title: Text(item.event),
                          subtitle: Text(item.description)),
                    for (final leave in office?.employeeLeaves ?? [])
                      ListTile(
                          leading: _activityBadge(Icons.event_busy),
                          title: Text(leave.userName),
                          subtitle: Text(_requestStatus(leave.leaveStatus))),
                    for (final birthday in office?.birthdays ?? [])
                      ListTile(
                          leading: _activityBadge(Icons.cake_outlined),
                          title: Text(birthday.name)),
                  ];
                  return items.isEmpty &&
                          holiday == null &&
                          (row == null || _activityItems(row).isEmpty)
                      ? Text(translate('royal.no_events'))
                      : Column(children: items);
                },
              )
            else if (holiday == null &&
                (row == null || _activityItems(row).isEmpty))
              Text(translate('royal.no_events')),
          ],
        ),
      ),
    );
  }
}

class _MonthData {
  const _MonthData(this.rows, this.holidays, this.companyLeaveDates);

  final Map<String, EmployeeAttendance> rows;
  final Map<String, Holidays> holidays;
  final Set<String> companyLeaveDates;
}
