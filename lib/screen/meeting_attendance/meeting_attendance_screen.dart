import 'package:cnattendance/model/meeting_attendance.dart';
import 'package:cnattendance/repositories/meeting_attendance_repository.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/customqrscanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';

class MeetingAttendanceScreen extends StatefulWidget {
  const MeetingAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<MeetingAttendanceScreen> createState() =>
      _MeetingAttendanceScreenState();
}

class _MeetingAttendanceScreenState extends State<MeetingAttendanceScreen> {
  final _repository = MeetingAttendanceRepository();
  List<MeetingAttendanceItem> _meetings = [];
  bool _isLoading = true;
  bool _isScanning = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    try {
      final meetings = await _repository.getMeetings();
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = null;
        _meetings = meetings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _scanMeetingQr() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      final qrPayload = await showCustomQrScanner(context);
      if (!mounted || qrPayload == null || qrPayload.trim().isEmpty) return;
      EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black,
      );
      final response = await _repository.scan(qrPayload.trim());
      if (!mounted) return;
      showToast(response.message);
      await _loadMeetings();
    } catch (e) {
      if (mounted) showToast(e.toString());
    } finally {
      EasyLoading.dismiss(animation: true);
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: enterprise.primary,
        title: Text(
          translate('more_screen.meeting_attendance'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMeetings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _ScanCard(onScan: _isScanning ? null : _scanMeetingQr),
                  const SizedBox(height: 12),
                  Text(
                    '${_meetings.where((m) => m.isJoined).length} joined · '
                    '${_meetings.where((m) => m.canCheckIn).length} open for check-in',
                    style: TextStyle(color: enterprise.mutedText),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 12),
                    Text(_loadError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton.icon(
                        onPressed: _loadMeetings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ],
                  const SizedBox(height: 16),
                  if (_meetings.isEmpty && _loadError == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          'No assigned meetings found',
                          style: TextStyle(
                            color: enterprise.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final meeting in _meetings) ...[
                      _MeetingAttendanceCard(
                        meeting: meeting,
                        onScan: meeting.canCheckIn && !_isScanning
                            ? _scanMeetingQr
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return EnterpriseGlass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [enterprise.primary, enterprise.accent],
              ),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Scan the meeting QR to record your meeting attendance.',
              style: TextStyle(
                color: enterprise.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onScan,
            icon: Icon(Icons.qr_code_scanner_rounded, color: enterprise.text),
          ),
        ],
      ),
    );
  }
}

class _MeetingAttendanceCard extends StatelessWidget {
  const _MeetingAttendanceCard({required this.meeting, this.onScan});

  final VoidCallback? onScan;

  final MeetingAttendanceItem meeting;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return EnterpriseGlass(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: meeting.isJoined
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meeting.isJoined
                      ? 'Joined'
                      : switch (meeting.attendanceStatus) {
                          'disabled' => 'Disabled',
                          'upcoming' => 'Upcoming',
                          'closed' => 'Closed',
                          _ => 'Pending',
                        },
                  style: TextStyle(
                    color: meeting.isJoined ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MeetingMeta(icon: Icons.place_outlined, text: meeting.venue),
          const SizedBox(height: 6),
          _MeetingMeta(
            icon: Icons.event_outlined,
            text: '${meeting.meetingDate} • ${meeting.meetingStartTime}',
          ),
          if (meeting.checkInOpensAt != null &&
              meeting.checkInClosesAt != null) ...[
            const SizedBox(height: 6),
            _MeetingMeta(
              icon: Icons.schedule,
              text:
                  'Check-in: ${DateFormat('MMM d, HH:mm').format(meeting.checkInOpensAt!.toLocal())}'
                  ' – ${DateFormat('MMM d, HH:mm').format(meeting.checkInClosesAt!.toLocal())}',
            ),
          ],
          if (meeting.canCheckIn) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan to join')),
          ],
          if (meeting.checkedInAtFormatted != null) ...[
            const SizedBox(height: 6),
            _MeetingMeta(
              icon: Icons.verified_rounded,
              text: 'Checked in ${meeting.checkedInAtFormatted}',
            ),
          ],
        ],
      ),
    );
  }
}

class _MeetingMeta extends StatelessWidget {
  const _MeetingMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: enterprise.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: enterprise.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
