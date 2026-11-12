# Meeting attendance

Create or edit a meeting in Laravel **Team Meetings** and assign its participants.
Open **QR & Attendance** beside that meeting to display or print its QR code,
inspect the attendee register, or export CSV. Refresh the register to see new scans.
Meeting creation and participant assignment continue to use the existing meeting form.

Employees open **More → Meeting Attendance** in Flutter and scan the organizer's
QR. Only assigned employees in the meeting's company can join. A successful scan
records server time once; repeated scans keep the original check-in time.
Pull to refresh the list after settings or assignments change.

Administrators with `edit_team_meeting` can enable/disable check-in, specify an
opening and closing time, and replace the QR. Blank opening/closing times use
the start/end of the meeting date in Laravel's configured timezone. Explicit
windows can cross midnight. `show_team_meeting` controls access to the QR,
register, and CSV. Mobile menu/function permissions remain managed by the existing
`meeting-attendance` permission configuration.

QR codes contain authenticated encrypted meeting/version data. Replacing a QR
invalidates older copies. Legacy numeric, `meeting:ID`, and JSON meeting-ID codes
are no longer accepted; display or print the QR from the new admin page.
QR contents are never included in employee meeting-list responses.

## Installation

Backend sibling project: `../hr-ky-admin`.
The existing `2026_08_17_000001_create_meeting_attendances_table.php` migration
is required. Install the new settings migration when deploying the backend:

```sh
php artisan migrate --path=database/migrations/2026_11_12_000005_add_meeting_checkin_controls.php --force
```

The migration was applied to the configured development database on 2026-11-12.
Deploy the backend and Flutter updates together. Reprint older meeting QR codes.

## Verification

```sh
# Flutter project
flutter test test/meeting_attendance_test.dart
flutter analyze lib/model/meeting_attendance.dart lib/repositories/meeting_attendance_repository.dart lib/screen/meeting_attendance/meeting_attendance_screen.dart test/meeting_attendance_test.dart

# Laravel project
php vendor/bin/phpunit --filter MeetingCheckInTest
```

Tests cover encrypted and invalid payloads, QR replacement, original timestamp
preservation, participant/company authorization, disabled and timed check-in,
admin register/export, settings validation, and edit permissions. Camera capture
and printed QR readability still require a physical-device check.
