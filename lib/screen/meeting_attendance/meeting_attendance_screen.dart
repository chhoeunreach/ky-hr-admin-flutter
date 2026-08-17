import 'package:cnattendance/model/meeting_attendance.dart';
import 'package:cnattendance/repositories/meeting_attendance_repository.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/customqrscanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';

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
        _meetings = meetings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      showToast(e.toString());
    }
  }

  Future<void> _scanMeetingQr() async {
    final qrPayload = await showCustomQrScanner(context);
    if (qrPayload == null || qrPayload.trim().isEmpty) {
      return;
    }

    try {
      EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black,
      );
      final response = await _repository.scan(qrPayload.trim());
      EasyLoading.dismiss(animation: true);
      showToast(response.message);
      await _loadMeetings();
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
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
        title: const Text(
          'Meeting Attendance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                  _ScanCard(onScan: _scanMeetingQr),
                  const SizedBox(height: 16),
                  if (_meetings.isEmpty)
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
                      _MeetingAttendanceCard(meeting: meeting),
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

  final VoidCallback onScan;

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
  const _MeetingAttendanceCard({required this.meeting});

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
                  meeting.isJoined ? 'Joined' : 'Pending',
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
