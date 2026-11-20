# Team Board

Team leader: **opencode** (this repo)
Human lead: **you** (fixes errors, approves, commits)

## Agents

| Agent | Role | Scope |
|---|---|---|
| ChatGPT (VSCode) | UI / widgets / screens | `lib/screen/`, `lib/widget/`, themes, layout |
| Antigravity | Logic / API / refactor / tests | providers, services, utils, data layer |

## Rules

1. Only work tasks marked `assigned to you`.
2. Change status: `todo` → `in_progress` → `done` → `review`.
3. Do not commit. Human lead commits after review.
4. Do not touch files owned by the other agent while it is `in_progress`.
5. When blocked, set `blocked` and write why.
6. One task in progress per agent at a time.

## WIP / Uncommitted work (owner: human lead)

- `lib/screen/dashboard/attendancescreen.dart`
- `lib/screen/dashboard/dashboard_screen.dart`
- `lib/screen/dashboard/leavescreen.dart`
- `lib/screen/dashboard/morescreen.dart`
- Notes: HeaderProfile `showMenuButton: false` on subscreens; hide nav bar on repair detail; show menu button on More tab again.

## Tasks

| ID | Task | Assignee | Status | Notes |
|---|---|---|---|---|
| T0 | Fix error 10 | human | in_progress | You are on this |
| T1 | Remove 8 unused imports + 4 unused private methods in `lib/widget/` (checkattendance, attendance_bottom_sheet, earlyleavesheet, issueleavesheet) | ChatGPT | todo | UI cleanup only; do not change behavior |
| T2 | Migrate deprecated `WillPopScope` → `PopScope` in leave/profile bottom sheets (`earlyleavesheet`, `issueleavesheet`, `note_bottom_sheet`, `attendance_bottom_sheet`) | Antigravity | todo | Keep back-button behavior identical; run `flutter analyze` after |
| T3 | Replace deprecated `activeColor` → `activeThumbColor` (`securitycheck.dart`, `asset_bottom_sheet.dart`) + fix `prefer_final_locals` in `lib/utils/` and `*_controller.dart` | Antigravity | todo | Small safe fixes |
| T4 | Verify dashboard WIP (menu button / repair nav bar) on device, then commit with human | ChatGPT | blocked | Waiting for human's error-10 fix + review of uncommitted dashboard files |
| T5 | APK clone protection: signature/package gate, block all services if cloned | opencode (lead) | review | Implemented — needs device smoke test |
| T6 | Home **Scan In / Scan Out** buttons + full scan chain (QR/NFC/wifi + offline) | opencode (lead) | done | Superseded by T7 — buttons removed per user (keep original single-button flow); `attendanceStatus` plumbing retained |
| T7 | One-tap **multi-QR router** on home Scan: attendance / queue pass / meeting / payroll / server config | opencode (lead) | review | Implemented — needs device smoke test |

## Done

- **T7 (lead):** One-click multi-function scan on the home Scan button (UI flow unchanged — still a single button).
  - New `lib/utils/qr_scan_router.dart` classifies a scanned string:
    - `meeting-qr:` prefix → `MeetingAttendanceRepository.scan`
    - JSON `type: attendance_queue_pass` → attendance as `attendance_type: qr_pass`
    - URL path `/payroll-queue/join/{token}` → new `lib/repositories/payroll_queue_repository.dart` → `POST api/v1/payroll-queue/join` (bare 32-char token deliberately NOT matched — can collide with base64 attendance identifiers)
    - Plain / base64-JSON server URL (`ServerConfiguration.parse`) → confirm dialog + `ServerStatusService.switchServer` + dashboard refresh
    - fallback → daily attendance QR (existing selfie/note/offline flow)
  - Wired in `checkattendance.dart` `scanQr()`; GPS preflight before camera kept (test contract); distance gate in `onAttendanceVerify` now includes `qr_pass`
  - Constant `PAYROLL_QUEUE_JOIN_URL` added
  - **T6 buttons removed:** classic `_buildScanInOutActions` + royal `_ScanInOutButton` row + `onScanAction` param deleted from `home_model_view.dart`; original single Scan button restored
  - Verified: `flutter analyze` 0 errors; full `flutter test` → **511 passed, 0 failed** (incl. new `test/qr_scan_router_test.dart`, `royal_dashboard_test` preflight contract)

- **T6 (lead):** Scan In / Scan Out completed end-to-end (later superseded by T7 — buttons removed, plumbing kept).
  - Home classic + royal: buttons `home-scan-in` / `home-scan-out` → `onScanAction('checkIn'|'checkOut')`
  - `CheckAttendance` threads status through QR, NFC (Android+iOS), note sheet, wifi direct submit, offline queue
  - `verifyAttendanceApi` now sends `attendance_status_type` for all types (not only wifi)
  - `NoteBottomSheet`, `CustomNfcDialog` accept `attendanceStatus`
  - i18n `home_screen.scan_in` / `scan_out` in all 12 locales
  - Center button still auto (empty status) — server infers direction
  - Verified: `flutter analyze` 0 errors; `royal_dashboard_test` + `home_quote_customization_test` pass

- **T5 (lead):** APK clone/re-sign protection shipped to working tree.
  - Native verify channel `cnattendance/app_integrity` in `MainActivity.kt` (cert SHA-256 + package name vs `BuildConfig`)
  - Expected fingerprints in `android/app/build.gradle` (release = upload keystore, debug = Android debug keystore)
  - Early gate in `lib/main.dart` **before** Firebase/push/chat/background — on fail shows `IntegrityBlockedScreen`, wipes session, returns
  - Guards in `PushNotificationService.initialize` + FCM background handler, `BackgroundSyncManager.initialize` + Workmanager task, `IncomingChatListener.start`
  - New: `lib/security/app_integrity.dart`, `lib/security/integrity_blocked_screen.dart`
  - Verified: `flutter analyze` → 0 errors; `:app:compileDebugKotlin` → OK

## Review queue

- **T5** — lead ready for human review. Device tests: (1) debug build opens normally, (2) re-signed APK shows "App blocked" and no push/sync runs.
- **T7** — lead ready for human review. Device tests: one home Scan tap routes each QR type: (1) attendance QR → normal check-in/out, (2) queue-pass JSON → `qr_pass` attendance, (3) `meeting-qr:` → meeting result dialog, (4) payroll join URL → join + ticket dialog, (5) server URL → confirm + switch toast; outside-radius still blocks with warning; Scan In/Out buttons are gone (single button restored).
