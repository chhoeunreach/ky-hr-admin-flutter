# Royal Blue & Gold dashboard

Select **Royal Blue & Gold** from the app’s Theme Mode selector. The selector lists it alongside the existing themes and stores it under the new identifier `royal_blue_gold` only after selection. Layout customization is keyed by this identifier as well. English and Khmer dashboard strings use the existing localization files. The theme uses the existing Angkor Wat JPEG as offline artwork, Material icons for controls, and three original SVGs for decoration.

## Laravel integration

The routes below were verified in the adjacent `hr-ky-admin` checkout under the authenticated API group. Flutter resolves the server through the existing Preferences configuration.

| Dashboard data | Existing Laravel route |
| --- | --- |
| Employee name, username, avatar, online status, today’s snapshot, configured attendance methods, leaderboard and branch location | `GET /api/dashboard` |
| Monthly lateness, deduction and attendance bonus target | `GET /api/dashboard/attendance-summary` |
| Banner slideshow | `GET /api/banner-slideshow/` |
| Active motivational quotes | `GET /api/quotes` |
| Employee stories and viewing progress | `GET /api/social-stories` and `POST /api/social-stories/{story}/view` |
| Published company highlights | `GET /api/home-highlights` |
| Attendance submission with server-selected action | `POST /api/employees/attendance` |
| Personal attendance and leave entries | `GET /api/employees/attendance-detail?month=…` |
| Company leave marks and selected date details | `GET /api/leave-requests/employee-leave-calendar` and `GET /api/employee/office-calendar?leave_date=…` |
| Company holidays | `GET /api/holidays` |
| Header notifications | `GET /api/notifications` |

The client passes QR identifiers to the existing attendance endpoint without a requested check-in or check-out action. It reuses the current location, device clock, note and selfie requirements and existing offline request IDs. The server resolves the attendance action and performs its configured validations. The separate Attendance tab opens the existing history destination.

## Backend gaps and proposed changes

- `EmployeeMonthlyAttendanceSummary` returns monthly lateness and `bonus.target_amount`. To show **Late Today** and an **earned or paid bonus**, extend the authenticated response with a server-computed daily late status and separate authorized payroll amounts, status and currency. Keep the target field because it represents a different value.
- Banner order comes from the stored slide array. Extend `BannerSlideshowApiController` and the web editor to validate and persist optional `subtitle`, `actionLabel`, `startsAt` and `endsAt`. The Flutter banner supports these fields when present. Use offset-bearing dates, validate that the end follows the start, and enforce the publication window in the employee API. Keep existing admin permissions and URL/image validation.
- The existing quote editor and API already support author, active status, configured order and rotation. Extend `MobileQuoteController` and `MobileQuoteApiController` to accept an optional English translation and a publication window. Include the translation and return published items only, in admin-defined order. Apply existing Mobile Quote permissions to the update path. Both content features already use `AppSetting` JSON, so these additions can use the existing storage.
- The checked-out server applies GPS requirements according to `AppHelper::isEmployeeLocationRequired()` and verifies NFC and QR as distinct attendance methods. It exposes no server-backed **NFC OR GPS** preflight policy for a QR submission. Supporting that policy requires a server-defined rule, a verified NFC proof tied to the employee and scan attempt, and enforcement when `employees/attendance` processes the QR submission. Flutter uses the existing policy and does not substitute an unverified NFC value for GPS.
- The attendance report resolves the year on the server. The dashboard can browse other years for supported company data, but personal attendance and leave markers require a year-aware report endpoint for those months. The company leave-marker API covers its existing two-month window. The selected-day office endpoint may still return details outside that window.
- Recent activity comes from authorized employee attendance-report rows. Its leave entries describe affected dates and request status. Separate bonus-payment, attendance-adjustment, and leave-submission timestamps require a user-scoped event feed. The published Highlights feed contains company highlights. The inspected backend has no saved-story collection or media counts for those items.

## File inventory

### Created

- `lib/theme/royal_colors.dart`
- `lib/widget/homescreen/royal_dashboard_widgets.dart`
- `lib/widget/homescreen/royal_calendar_activity.dart`
- `lib/widget/homescreen/royal_quick_actions.dart`
- `assets/royal_blue_gold/decorations/angkor_silhouette.svg`
- `assets/royal_blue_gold/decorations/gold_wave.svg`
- `assets/royal_blue_gold/decorations/lotus.svg`
- `test/royal_dashboard_test.dart`
- `docs/royal_blue_gold_dashboard.md`

### Modified

- **Dashboard and navigation** — `lib/screen/dashboard/dashboard_screen.dart`, `lib/screen/dashboard/homescreen.dart`, `lib/widget/headerprofile.dart`, `lib/widget/homescreen/home_model_view.dart`
- **Theme and asset registration** — `lib/theme/app_theme_data.dart`, `lib/theme/app_theme_mode.dart`, `lib/theme/enterprise_theme.dart`, `lib/theme/theme_layout.dart`, `lib/widget/enterprise/enterprise_background.dart`, `lib/widgets/theme_layout_editor.dart`, `assets/i18n/en.json`, `assets/i18n/km.json`, `pubspec.yaml`
- **Attendance and profile** — `lib/widget/homescreen/checkattendance.dart`, `lib/widget/customqrscanner.dart`, `lib/widget/profile/note_bottom_sheet.dart`, `lib/provider/dashboardprovider.dart`, `lib/provider/prefprovider.dart`, `lib/models/monthly_attendance_summary.dart`, `lib/data/source/network/model/dashboard/EmployeeTodayAttendance.dart`, `lib/data/source/network/model/attendancestatus/AttendanceStatus.dart`
- **Content and calendar** — `lib/features/banner_slideshow/banner_slideshow_api.dart`, `lib/model/banner_slideshow_config.dart`, `lib/features/quotes/mobile_quote_api.dart`, `lib/provider/holidaycontroller.dart`, `lib/provider/leavecalendarcontroller.dart`, `lib/repositories/attendancereportrepository.dart`, `lib/data/source/network/connect.dart`

The reused image `assets/images/angkor_wat_banner.jpg` was already present in the workspace.
